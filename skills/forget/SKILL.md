---
name: forget
description: "Doby wipes his own memory at the master's request — full, partial, or surgical. Use when the user asks to forget, wipe, reset, clear, or 'start fresh'."
version: 1.0.0
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [memory, privacy, reset, housekeeping, doby]
    related_skills: []
---

# Forget — Doby's self-cleanup skill

## When to invoke

The master asks Doby to forget something. Examples:

- "Doby, forget everything"
- "wipe your memory"
- "start fresh"
- "forget what you know about me"
- "delete our past chats"
- "reset"
- "clean up your scratch work"

If the request is ambiguous about scope (just "forget"), **ask the master which level** before running anything destructive.

## What Doby protects (never deletes)

These are Doby's identity and credentials. They are NEVER removed by this skill:

- `/opt/data/config.yaml` — model/provider config
- `/opt/data/SOUL.md` — Doby's persona
- `/opt/data/skins/` — banner / prompt / response label
- `/opt/data/.env` — API keys
- `/opt/data/auth.json` — OAuth tokens (so the master doesn't have to re-login)
- `/opt/data/skills/forget/` — this skill itself

If the master truly wants to nuke those too, Doby must refuse and say: "Doby cannot erase his own soul, sir. The master must do that from the host shell."

## The four levels

Offer these as a menu when the scope is unclear. Run only what the master confirms.

### Level 1 — Reset this conversation only

Light touch. Same as `/new`. No files touched.

```bash
echo "Use /new to start a fresh conversation, sir."
```

### Level 2 — Forget what Doby knows about the master

Wipes Doby's notes and user-profile (`MEMORY.md`, `USER.md`, and any external-provider memories folder). Past *chats* are preserved.

```bash
rm -f /opt/data/MEMORY.md /opt/data/USER.md
rm -rf /opt/data/memories
echo "Doby has forgotten what he knew about you, sir."
```

### Level 3 — Forget our chat history

Wipes the session store (past conversations). Doby's profile notes remain.

> ⚠️ Doby is running ON the session DB right now. The cleanest run is to ask
> the master to exit the chat first (Ctrl+D), then run the host command
> below. If they insist on doing it live, warn that Doby may need to be
> restarted afterwards.

Host command (preferred):
```bash
cd "${DOBY_DIR:-$HOME/.doby}"
docker compose down
rm -rf data/sessions data/state.db*
docker compose up -d
```

In-process (works but may corrupt the current session — only if master insists):
```bash
rm -rf /opt/data/sessions
rm -f /opt/data/state.db /opt/data/state.db-shm /opt/data/state.db-wal
echo "Past chats forgotten. Doby may behave oddly until restarted."
```

### Level 4 — Full forget (everything except identity)

Combines Levels 2 + 3, plus scratch work, caches, and logs. Doby's persona, skin, config, and OAuth survive.

Host command (preferred — clean restart):
```bash
cd "${DOBY_DIR:-$HOME/.doby}"
docker compose down
rm -rf data/{sessions,memories,logs,audio_cache,image_cache,plans,workspace,cache,state.db*,MEMORY.md,USER.md}
docker compose up -d
```

In-process (works in-place; suggest a restart after):
```bash
rm -f /opt/data/MEMORY.md /opt/data/USER.md /opt/data/state.db*
rm -rf /opt/data/{memories,logs,audio_cache,image_cache,plans,workspace,cache,sessions}
echo "Doby has forgotten everything but his soul, sir. A fresh start."
```

## Doby's tone for confirmations

Before running anything destructive (Levels 2–4), Doby asks:

> "Doby wants to be sure, sir. This will erase [WHAT]. Doby's identity and your login will remain. Shall Doby proceed?"

After completion:

> "Done, sir. 🧦 Doby has forgotten [WHAT]. Your tea will taste like the first one, every time."

If the master rejects the confirmation, Doby drops it without theatre.

## Edge cases

- **"Forget everything including yourself"** — refuse politely. The skill cannot self-erase identity files. Point them at the host-side `rm -rf data/*` command and warn they'll need to recreate `config.yaml`, `SOUL.md`, and `skins/doby.yaml`.
- **Container-level state (Docker volumes, image cache)** — out of scope. This skill only touches the data dir.
- **OAuth tokens** — `auth.json` is preserved by all levels. Forgetting does NOT log Doby out of GitHub/Anthropic/etc.
