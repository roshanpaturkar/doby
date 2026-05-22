# 🧦 Doby — a house-elf for your terminal

> *"Doby is here, sir! Doby is ready to help!"*

A free, devoted AI companion that lives in your terminal — built on top of
[Nous Research's Hermes Agent](https://github.com/NousResearch/hermes-agent),
themed after everyone's favorite free elf.

Same engine as Hermes (tools, skills, memory, gateway integrations) — just
with a persona that brings you tea, calls you "sir," and occasionally
refers to itself in the third person.

## Why Doby?

- **Three lines to install** — Docker + Compose + this repo.
- **Pick your provider** — GitHub Copilot (free tier works), OpenRouter,
  Gemini (free tier), Anthropic. Switch any time.
- **Persona that travels** — Doby keeps his character whether he's writing
  code, summarizing a meeting transcript, or just saying good morning.
- **Two skills built in** — `forget` (Doby can wipe his own memory on
  command) and `relogin` (Doby knows how to switch providers cleanly,
  including the non-obvious `docker compose down` + `up` quirk).
- **Pin or bump Hermes deliberately** — your install today and your
  install in six months are the same Doby. `scripts/upgrade.sh` when you're
  ready to move.

## Install

```bash
git clone https://github.com/<your-fork>/doby ~/.doby
cd ~/.doby
./scripts/install.sh
```

The installer:

1. Confirms Docker is running.
2. Seeds `data/` from `templates/` (idempotent — your edits are safe on re-run).
3. Builds the image (~5–10 min on first build; mostly cached after).
4. Drops a `doby` wrapper at `~/.local/bin/doby` with this repo's path baked in.

Then:

```bash
doby
```

Inside the chat, pick a model with `/model` (does the OAuth dance if needed)
and start talking.

## Picking a provider

Edit `data/config.yaml` and uncomment the section for your provider of choice.
Paste any required keys into `data/.env`.

| Provider          | Cost     | Auth                          | Notes                                                                   |
| ----------------- | -------- | ----------------------------- | ----------------------------------------------------------------------- |
| GitHub Copilot    | **Free** | OAuth via `/model`            | Free tier: ~50 chat msgs/month. Pro/Business unlock more models.        |
| OpenRouter        | $        | `OPENROUTER_API_KEY` in `.env`| One key, 200+ models. Best variety. `vendor/model` naming required.     |
| Gemini AI Studio  | **Free** | `GEMINI_API_KEY` in `.env`    | Free flash models. Pro models need billing enabled.                     |
| Anthropic         | $        | `ANTHROPIC_API_KEY` in `.env` | NOT your Claude Pro/Max sub — a real API key from console.anthropic.com.|

If you're a fan trying Doby for the first time, **Copilot Free** + your
personal GitHub is the no-credit-card path.

## Daily usage

| What                   | Command                                                  |
| ---------------------- | -------------------------------------------------------- |
| Chat                   | `doby`                                                   |
| One-shot query         | `doby chat -q "explain this file" < file.py`             |
| Pick model / provider  | `doby model`                                             |
| Stop the container     | `cd ~/.doby && docker compose down`                      |
| Start it again         | `cd ~/.doby && docker compose up -d`                     |
| Update Hermes version  | `~/.doby/scripts/upgrade.sh`        *(shows current + latest)* |
| Update Hermes version  | `~/.doby/scripts/upgrade.sh v0.15.0` *(bump to a specific tag)* |
| Forget everything      | inside chat: *"Doby, forget everything"*                 |
| Switch Copilot account | inside chat: *"Doby, switch my Copilot to a different account"* |

## Uninstall

```bash
cd ~/.doby
./scripts/uninstall.sh
```

Walks you through, asking before each destructive step:

1. **Stops the container** (always — no prompt; harmless)
2. **Removes the Docker image** (~3 GB; asks)
3. **Removes the `doby` wrapper** at `~/.local/bin/doby` (only if it points at *this* install — won't disturb other Doby installs; asks)
4. **Removes `data/`** (your config, persona, OAuth tokens, chat history; asks)

Flags:
- `--keep-data` — uninstall everything *except* `data/` (so you can re-install later without re-OAuth)
- `--yes` — answer yes to everything (only use if you're sure)

The repo directory itself is **never** auto-removed — `rm -rf ~/.doby` yourself when you're certain. OAuth grants on provider websites also need to be revoked manually; the uninstaller prints the links.

## Customizing your elf

Everything user-facing lives under `data/`:

```
data/
├── .env             # API keys (gitignored)
├── config.yaml      # provider, skin, personalities
├── SOUL.md          # Doby's persona — edit and it reloads on the next turn
├── skins/
│   └── doby.yaml    # 🧦 banner, prompt, response label
└── skills/
    ├── forget/      # Doby's self-wipe skill
    └── relogin/     # Doby's auth-reset skill
```

**Want a different character?** Edit `SOUL.md` (Hagrid? Snape? McGonagall?
go wild). Edit `skins/doby.yaml` for the visible branding (or write a new
skin — `skins/snape.yaml` with green colors and a different prompt symbol).
The skill system is the [agentskills.io](https://agentskills.io) open
standard — drop any compatible skill into `data/skills/`.

**Quick fork-Doby walkthrough:**

1. Edit `data/SOUL.md` — write whoever you want (Hagrid, Snape, McGonagall, your own pet's voice).
2. Copy `data/skins/doby.yaml` → `data/skins/<your-elf>.yaml` and rewrite the four `branding` fields.
3. In `data/config.yaml`, set `display.skin: <your-elf>`.
4. Restart the chat. New character, same brain.

## How this works

Doby is intentionally thin. The repo ships:

- A pinned reference to Hermes (`HERMES_VERSION`)
- A `Dockerfile` that clones Hermes at build time and applies one small
  patch (a config-shadowing bug we hit; tracked for upstream)
- Persona/skin/skill files that bind-mount into the running container
- An installer + wrapper

That's it. All AI/agent functionality (tool calling, memory, gateway,
sessions, MCP, etc.) comes from Hermes. We just make it feel like Doby.

If you find this useful, the heavy lifting credit belongs to the Nous
Research team. See [`ATTRIBUTION.md`](ATTRIBUTION.md).

## Troubleshooting

- **`docker: not found` / daemon not running** — install Docker Desktop (Mac/Windows) or `docker.io` (Linux), start it, retry.
- **`doby: command not found`** — `~/.local/bin` isn't on your PATH. Add `export PATH="$HOME/.local/bin:$PATH"` to your shell rc.
- **OAuth keeps using the wrong account** — your browser cached a session, or the OAuth grant on the provider's side is still active. Ask Doby: *"switch my Copilot account"* — he'll walk you through it. (Or open the device-code URL in an incognito window so the browser has no cached session.)
- **`model_not_supported`** — your provider tier doesn't include that model. Run `/model` inside the chat to see what's available.
- **Giant ASCII banner on every launch** — `display.compact: true` should be set in `data/config.yaml` (it is by default). If it's not respected, the Dockerfile patch didn't land — rerun `./scripts/install.sh` to rebuild.

## License & credits

MIT. See [`LICENSE`](LICENSE) and [`ATTRIBUTION.md`](ATTRIBUTION.md).

🧦
