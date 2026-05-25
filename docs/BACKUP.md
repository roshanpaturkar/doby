# Backup & Sync

Keep Doby's brain in git: notes editable from anywhere, identity restorable
after a crash. **One manual step (deploy keys), then one command.**

| Repo | Holds | Direction | Why |
|------|-------|-----------|-----|
| **doby-vault** | the Obsidian vault under `data/Documents/` | **bidirectional** | You edit notes in Obsidian *and* Doby writes them. Central repo = source of truth. |
| **doby-state** | `SOUL.md`, `config.yaml`, `memories/`, `skins/` | one-way (host → repo) | Doby-authored identity. Mirror = crash recovery. |

> `skills/` is **not** mirrored by default — it's Hermes' bundled catalog
> (rebuilt from the image), and your custom skills already live in the repo's
> `skills/` (reinstalled by `install.sh`). Set `DOBY_BACKUP_SKILLS=1` only if you
> hand-author skills directly under `data/skills/`.

### Never backed up

`.env`, `auth.json`, `auth.lock` — your OAuth + provider tokens. They stay on
the box. After a restore you re-auth with `doby` → `/model`. **Never `git init`
at `data/` root** — that would commit your secrets.

---

## Setup (run on the VPS — the box that owns the data)

### Step 1 — Create two empty private repos

On GitHub, create **`doby-vault`** and **`doby-state`** — private, **no README,
no .gitignore** (keep them empty so the first push isn't rejected).

### Step 2 — Deploy keys (the one manual part)

A deploy key is an SSH key locked to a single repo. GitHub won't let one key
serve two repos, so make **one key per repo** and route them with SSH aliases.
This runs on the **host**, so Doby never holds a git credential.

**2a. Make two keys**
```bash
ssh-keygen -t ed25519 -f ~/.ssh/doby_vault -N "" -C doby-vps-vault
ssh-keygen -t ed25519 -f ~/.ssh/doby_state -N "" -C doby-vps-state
```

**2b. Print the public keys**
```bash
cat ~/.ssh/doby_vault.pub
cat ~/.ssh/doby_state.pub
```

**2c. Add each to its repo on GitHub**
- `doby_vault.pub` → **doby-vault** repo → *Settings → Deploy keys → Add deploy
  key* → paste the line → ✅ **Allow write access** → Add.
- `doby_state.pub` → **doby-state** repo → same → ✅ **Allow write access**.

**2d. SSH aliases.** Heredocs paste badly over SSH — use `nano` (paste-safe):
```bash
nano ~/.ssh/config
```
Paste:
```
Host github-vault
  HostName github.com
  User git
  IdentityFile ~/.ssh/doby_vault
  IdentitiesOnly yes

Host github-state
  HostName github.com
  User git
  IdentityFile ~/.ssh/doby_state
  IdentitiesOnly yes
```
Save/exit: **Ctrl-O, Enter, Ctrl-X**. Then lock it down:
```bash
chmod 600 ~/.ssh/config
```

**2e. Verify** (do this before Step 3 — the setup script checks it too)
```bash
ssh -T git@github-vault    # → "Hi <user>/doby-vault! You've successfully authenticated..."
ssh -T git@github-state    # → "Hi <user>/doby-state! ..."
```

### Step 3 — One command

```bash
cd ~/.doby          # your public-doby checkout (wherever it is)
./scripts/backup-setup.sh
```
It auto-detects `data/` and the vault folder, asks you to confirm the repo URLs,
re-checks SSH, seeds both repos, and offers to install the cron jobs. Safe to
re-run.

That's it. The VPS now pushes vault edits every 3 min and backs up identity
every 15 min.

---

## Edit notes from your laptop / phone

```bash
git clone git@github.com:<user>/doby-vault.git ~/DobyVault
```
(From your laptop, with your normal GitHub SSH — no deploy key needed there.)
Open `~/DobyVault` in **Obsidian** → install the **obsidian-git** community
plugin → set:
- **Auto pull on startup**: on
- **Auto commit-and-sync interval**: 1–2 min
- **Pull before push**: on

Now you and the VPS both pull→edit→push the same repo. Phone: Obsidian mobile +
obsidian-git, or just read the repo on github.com.

---

## Conflicts (rare, never silent)

`sync-vault.sh` snapshots local edits, rebases onto the remote, then pushes. If
the *same lines* changed on both sides within one window, it can't auto-merge.
The script then aborts the rebase, **pushes your divergent work to
`backup/conflict-<timestamp>`** on origin, and exits non-zero. Nothing is lost —
`main` keeps the remote version, your edits are safe on the backup branch.
Resolve:
```bash
cd "<vault path>"
git fetch origin
git merge origin/backup/conflict-<timestamp>   # fix markers, commit, push
git push origin --delete backup/conflict-<timestamp>
```
Tight intervals make this rare. If it nags, shorten the vault cron interval.

---

## Restore after a crash (same Doby, fresh box)

After re-deploying Doby and re-doing Step 2 (deploy keys) on the new box:
```bash
cd ~/.doby
DOBY_VAULT_URL=git@github-vault:<user>/doby-vault.git \
DOBY_STATE_URL=git@github-state:<user>/doby-state.git \
  ./scripts/restore-state.sh
```
Clones the vault as a live working tree (already wired for sync) and copies the
identity files back. Won't clobber a non-empty vault unless `DOBY_RESTORE_FORCE=1`.
Then:
```bash
./scripts/install.sh   # build image if needed
doby                   # → /model to re-OAuth
./scripts/backup-setup.sh   # re-wire cron
```
Persona, memories, notes, skins = identical. Only the provider login is fresh.

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Shell stuck at `>` after pasting a heredoc | Bracketed-paste mangled the quotes. **Ctrl-C**, then use `nano` instead. Optionally disable: `bind 'set enable-bracketed-paste off'`. |
| `vault dir not found: /path/to/data/...` | You pasted a placeholder path. Use real paths, or just run `./scripts/backup-setup.sh` (it auto-detects). |
| `SSH auth failed for git@github-vault` | Deploy key missing/not write-enabled, or `~/.ssh/config` alias wrong. Re-check Step 2c/2d, test with `ssh -T git@github-vault`. |
| `Permission denied (publickey)` on push | Key added without **Allow write access**. Edit the deploy key on GitHub, tick write. |
| `! [rejected] ... fetch first` on first push | The repo wasn't empty (had README/gitignore). Either delete those on GitHub, or restore instead of seed. |
| `rsync: command not found` | `sudo apt install -y rsync` on the VPS. |
