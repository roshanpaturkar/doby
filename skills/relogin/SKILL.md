---
name: relogin
description: "Doby cleanly logs out of an OAuth provider and re-authenticates, including switching to a different account on the same provider. Handles GitHub Copilot, Nous, OpenAI Codex, Anthropic OAuth — anywhere the master might be silently stuck on the wrong credentials."
version: 1.0.0
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [auth, oauth, login, copilot, credentials, doby]
    related_skills: [forget]
---

# Relogin — Doby's auth-reset skill

## When to invoke

The master wants to switch identities or re-authenticate. Examples:

- "Doby, log me out of Copilot"
- "Relogin with my personal GitHub"
- "Switch Copilot account"
- "OAuth isn't prompting — fix it"
- "I want to use a different GitHub for Copilot"
- "Reset my login"
- "It keeps using the old token"

If the request is just "logout" with no plan to re-login, also handle that — see Level 1.

## The core insight (non-obvious)

When `hermes model` "auto-authenticates" without prompting, **three credential
sources can shadow each other**, and they must be cleaned in lockstep:

1. **Env vars in `data/.env`** — Hermes checks `COPILOT_GITHUB_TOKEN`,
   `GH_TOKEN`, `GITHUB_TOKEN` (in that order) *before* offering OAuth. Any of
   them set means OAuth is silently skipped.
2. **`data/auth.json`** — stored OAuth tokens from prior `hermes model`
   runs. Hermes uses these on launch if present.
3. **The running container's process environment** — `docker compose restart`
   does **NOT** reload `env_file`. Even after editing `.env`, the live
   container still has the old token until you do `down` + `up`.

Skipping any one of these makes re-login appear "not asking to log in".

## Provider-credential map (which keys/files to clean per provider)

| Provider           | .env keys to remove                                     | auth.json | Notes |
|--------------------|---------------------------------------------------------|-----------|-------|
| GitHub Copilot     | `COPILOT_GITHUB_TOKEN`, `GH_TOKEN`, `GITHUB_TOKEN`      | yes       | OAuth grant also stored on GitHub side — revoke separately if sensitive |
| Anthropic          | `ANTHROPIC_API_KEY`, `ANTHROPIC_TOKEN`                  | yes       | OAuth (`sk-ant-oat01`) is bound to subscription, not API |
| Nous Portal        | `NOUS_API_KEY`                                          | yes       | OAuth lives in auth.json |
| OpenAI Codex       | (none — OAuth only)                                     | yes       | |
| Gemini (AI Studio) | `GEMINI_API_KEY`, `GOOGLE_API_KEY`                      | no        | API key only, no OAuth |
| OpenRouter         | `OPENROUTER_API_KEY`                                    | no        | API key only |

## What Doby protects (never deletes)

- `/opt/data/config.yaml`, `SOUL.md`, `skins/`, `skills/` — Doby's identity
- Other providers' creds the master didn't ask to reset (read the request scope carefully — "logout of Copilot" ≠ "logout of everything")

## The three levels

### Level 1 — Just log out (no re-login)

Cleanly disconnect, no re-auth. Use when the master is done with a provider.

```bash
# Pick the keys for the target provider from the table above. Example: Copilot.
DOBY_DIR="${DOBY_DIR:-$HOME/.doby}"
sed -i.bak '/^COPILOT_GITHUB_TOKEN=/d; /^GH_TOKEN=/d; /^GITHUB_TOKEN=/d' \
  "${DOBY_DIR}/data/.env"
rm -f "${DOBY_DIR}/data/.env.bak"

# Wipe stored OAuth token
docker compose -f "${DOBY_DIR}/docker-compose.yml" exec doby \
  rm -f /opt/data/auth.json

# Reload env_file (restart will NOT do this — must down + up)
cd "${DOBY_DIR}"
HERMES_UID=$(id -u) HERMES_GID=$(id -g) docker compose down
HERMES_UID=$(id -u) HERMES_GID=$(id -g) docker compose up -d
```

After: tell the master to revoke the OAuth grant on the provider's website
if the identity was sensitive (e.g. corp GitHub). Provide the link:

- GitHub: <https://github.com/settings/applications>
- Anthropic: <https://console.anthropic.com/settings/keys>
- Google: <https://myaccount.google.com/permissions>

### Level 2 — Re-login (same provider, possibly different account)

Full credential reset followed by guided OAuth. This is the most common ask.

**Steps Doby runs** (same as Level 1 cleanup, then verify):

```bash
DOBY_DIR="${DOBY_DIR:-$HOME/.doby}"
sed -i.bak '/^COPILOT_GITHUB_TOKEN=/d; /^GH_TOKEN=/d; /^GITHUB_TOKEN=/d' \
  "${DOBY_DIR}/data/.env"
rm -f "${DOBY_DIR}/data/.env.bak"
docker compose -f "${DOBY_DIR}/docker-compose.yml" exec doby \
  rm -f /opt/data/auth.json
cd "${DOBY_DIR}"
HERMES_UID=$(id -u) HERMES_GID=$(id -g) docker compose down
HERMES_UID=$(id -u) HERMES_GID=$(id -g) docker compose up -d

# Verify
docker compose exec -T doby printenv | grep -iE "copilot|github|gh_token" \
  && echo "WARNING: env var still present" \
  || echo "✓ no GitHub/Copilot env vars in container"
ls "${DOBY_DIR}/data/auth.json" 2>/dev/null \
  && echo "WARNING: auth.json still present" \
  || echo "✓ auth.json gone"
```

**Then tell the master to run the OAuth flow themselves:**

> "Master, now please run `doby model` outside the chat, pick GitHub Copilot,
> and approve in your browser. **Critical:** open the URL in an
> incognito/private window so you don't silently re-authenticate with whichever
> account your normal browser has cached. Sign in fresh with the account you
> actually want this time."

Doby cannot do the browser step — that's user-side.

### Level 3 — Switch providers entirely

Combine Level 2 cleanup with a config switch. Example: Copilot → OpenRouter.

```bash
# 1. Edit data/config.yaml to point at the new provider.
# 2. Add the new provider's key placeholder to data/.env.
# 3. Clean the old provider's creds (Level 1 cleanup, scoped to old provider).
# 4. down + up to reload env_file.
```

Tell the master to paste the new key into `.env` and restart.

## Tone for confirmations

Before doing anything destructive:

> "Doby will scrub the [provider] credentials in three places — the .env file,
> auth.json, and the live container's environment — and then [logout / hand
> back to the master for OAuth]. Shall Doby proceed, sir?"

After cleanup, before handing off the OAuth step:

> "Done, sir. All [provider] credentials are gone. To log back in fresh,
> please run `doby model` from your terminal (outside this chat), pick
> [provider], and use an **incognito browser** so the right account is used.
> Doby will be waiting for you."

If the master tries to do the OAuth flow inside this chat:

> "Doby cannot open a browser, sir. The device-code flow needs your eyes and
> your hands. Doby has cleaned the slate — you do the dance, Doby will be
> here when you return."

## Edge cases

- **"It still says I'm logged in!"** — `docker compose restart` was used
  instead of `down` + `up`. Restart preserves the container's environment
  block from when it last started, so old env vars survive. Always
  `down` + `up` after editing `.env`.
- **"OAuth approved instantly without asking which account"** — the master's
  browser had a cached session, and the OAuth app was previously granted
  permission to that account, so the provider silently re-issued a token.
  Tell the master to (a) use incognito and (b) revoke the prior grant on
  the provider's website first to force the consent screen.
- **"I deleted auth.json but it still works"** — the env var path is still
  active. Check `.env` and `printenv` inside the container.
- **"I want to keep my other provider's login intact"** — only touch the keys
  in the table row for the provider being reset.
