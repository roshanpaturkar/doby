# Backup & Sync

Keep Doby's brain in git: notes editable from anywhere, identity restorable
after a crash. Two private repos, two sync models.

| Repo | Holds | Direction | Why |
|------|-------|-----------|-----|
| **doby-vault** | `Documents/Obsidian Vault/` | **bidirectional** | You edit notes in Obsidian *and* Doby writes them. Central repo = source of truth. |
| **doby-state** | `SOUL.md`, `config.yaml`, `memories/`, `skins/` | one-way (host → repo) | Doby-authored identity. Mirror = crash recovery. |

> `skills/` is **not** mirrored by default — it's Hermes' bundled catalog
> (rebuilt from the image), and your custom skills already live in the repo's
> `skills/` (reinstalled by `install.sh`). Set `DOBY_BACKUP_SKILLS=1` only if you
> hand-author skills directly under `data/skills/`.

```
              ┌──────────── doby-vault (private) ────────────┐
              │            central source of truth            │
              └──▲───────────────────────────────────────▲───┘
       push/pull │                                         │ push/pull
   ┌─────────────┴──────────────┐            ┌─────────────┴──────────────┐
   │ VPS  (sync-vault.sh, cron) │            │ Laptop (obsidian-git plugin)│
   │ Doby reads/writes notes    │            │ you edit notes in Obsidian  │
   └────────────────────────────┘            └─────────────────────────────┘

   VPS data/ identity ──(backup-state.sh, cron)──► doby-state (private)  [backup only]
```

## What is NEVER backed up

`.env`, `auth.json`, `auth.lock` — your OAuth + provider tokens. They stay on
the box. After a restore you re-auth with `doby` → `/model`. Keeping secrets out
of git is the whole point; **never `git init` at `data/` root.**

---

## One-time setup

### 0. Create two empty private repos

On GitHub, create `doby-vault` and `doby-state` — **private**, no README, no
`.gitignore` (keep them empty so the seed push isn't rejected). Grab the SSH
URLs, e.g. `git@github.com:USER/doby-vault.git`.

### 1. Give the VPS push access (deploy keys)

The sync runs on the **host**, never inside the container — Doby never holds a
key, so a prompt-injected Doby can't push or exfiltrate. On the VPS:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/doby_deploy -N "" -C "doby-vps"
cat ~/.ssh/doby_deploy.pub
```

Add that public key as a **deploy key with write access** on *each* repo
(GitHub → repo → Settings → Deploy keys → Add, tick "Allow write access").
Then point SSH at it:

```bash
cat >> ~/.ssh/config <<'EOF'
Host github.com
  IdentityFile ~/.ssh/doby_deploy
  IdentitiesOnly yes
EOF
```

> A single deploy key can't be reused across two repos on GitHub. Either make
> two keys (one per repo, with a `Host github-vault` / `Host github-state`
> alias each), or use one key as a **machine-user** SSH key with access to both.
> Two keys + host aliases is the clean path; adjust the repo URLs to the alias.

### 2. Seed the repos (run on the authoritative box — the VPS)

```bash
cd /path/to/public-doby
DOBY_DATA_DIR=/path/to/data \
DOBY_VAULT_URL=git@github.com:USER/doby-vault.git \
DOBY_STATE_URL=git@github.com:USER/doby-state.git \
  ./scripts/backup-init.sh
```

This `git init`s the vault in place, seeds both repos, and prints the cron lines.

### 3. Cron (on the VPS)

`crontab -e`:

```cron
*/3  * * * * DOBY_DATA_DIR=/path/to/data /path/to/public-doby/scripts/sync-vault.sh    >> ~/doby-sync.log   2>&1
*/15 * * * * DOBY_DATA_DIR=/path/to/data DOBY_STATE_REPO=$HOME/doby-state /path/to/public-doby/scripts/backup-state.sh >> ~/doby-backup.log 2>&1
```

Vault every 3 min keeps conflict windows small; state every 15 min is plenty.

### 4. Edit notes from your laptop / phone

```bash
git clone git@github.com:USER/doby-vault.git ~/DobyVault
```

Open `~/DobyVault` in Obsidian → install the **obsidian-git** community plugin →
set:

- **Auto pull on startup**: on
- **Auto commit-and-sync interval**: 1–2 min (pulls then pushes)
- **Pull updates on startup / before push**: on

Now you and the VPS both pull→edit→push the same repo. Phone: Obsidian mobile +
obsidian-git works too, or just browse the repo on github.com.

---

## Conflicts (rare, never silent)

`sync-vault.sh` snapshots local edits, rebases onto the remote, then pushes. If
the *same lines* were edited on both sides within one sync window, the rebase
can't auto-merge. The script then:

1. aborts the rebase (working tree untouched),
2. pushes the divergent local work to `backup/conflict-<timestamp>` on origin,
3. exits non-zero and logs the branch name.

**Nothing is lost** — `main` keeps the remote version, your VPS-side edits are
safe on the `backup/conflict-*` branch. Resolve by hand:

```bash
cd "/path/to/data/Documents/Obsidian Vault"
git fetch origin
git merge origin/backup/conflict-<timestamp>   # fix markers, commit, push
git push origin --delete backup/conflict-<timestamp>
```

Tight cron intervals make this rare. If it nags, shorten the vault interval.

---

## Restore after a crash (same Doby on a fresh box)

```bash
cd /path/to/public-doby
DOBY_DATA_DIR=/path/to/data \
DOBY_VAULT_URL=git@github.com:USER/doby-vault.git \
DOBY_STATE_URL=git@github.com:USER/doby-state.git \
  ./scripts/restore-state.sh
```

Clones the vault as a live working tree (already wired for sync) and copies the
identity files back in. It refuses to clobber a non-empty vault unless you pass
`DOBY_RESTORE_FORCE=1` (which backs the old one aside first). Then:

```bash
./scripts/install.sh   # build image if needed
doby                   # → /model to re-OAuth
# re-add the cron lines above
```

Persona, memories, notes, skins, skills = identical. Only the provider login is
fresh.
