# 🧦 Doby — a free elf for your terminal

> *"Doby has no master, sir! Doby is a free elf, and Doby has come to serve!"*

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Build](https://github.com/<your-fork>/doby/actions/workflows/ci.yml/badge.svg)](.github/workflows/ci.yml)
[![Hermes Agent](https://img.shields.io/badge/hermes--agent-v2026.5.16-purple.svg)](https://github.com/NousResearch/hermes-agent)
[![Docker](https://img.shields.io/badge/runs%20in-docker-blue.svg)](https://www.docker.com)

**An open-source, self-hosted, Dobby-inspired AI assistant for your terminal — a privacy-first ChatGPT alternative and GitHub Copilot CLI client, with your data on your disk and your API keys in your hands.**

A devoted AI companion that lives entirely on **your** machine — bound to
you, not to a corporation. Built on [Nous Research's Hermes Agent](https://github.com/NousResearch/hermes-agent),
themed after Harry Potter's favorite house-elf, and shipped in under twenty
files of glue you can read end-to-end in an afternoon.

Doby routes your conversations through whichever frontier model **you**
pick (Copilot, Anthropic, Gemini, OpenRouter…) using **your** API keys.
Your chats, OAuth tokens, persona, and skills live in a single `./data/`
folder you own outright. No telemetry. No cloud. No middleman. Just a
sock-wearing house-elf in a Docker box, waiting for you to say his name.

<details>
<summary><b>Table of contents</b></summary>

- [The four promises](#the-four-promises)
- [How Doby compares](#how-doby-compares)
- [Install (three lines)](#install-three-lines)
- [Picking a provider](#picking-a-provider)
- [Your data, your disk](#your-data-your-disk)
- [What we promise (and don't)](#what-we-promise-and-dont)
- [Daily usage](#daily-usage)
- [Uninstall (clean as Apparition)](#uninstall-clean-as-apparition)
- [Customizing your elf](#customizing-your-elf--make-him-your-own)
- [How this works (radical transparency)](#how-this-works-radical-transparency)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [For the fans](#for-the-fans)
- [License & credits](#license--credits)

</details>

## The four promises

**1. Owned, not rented.** Your chat history is a folder you can `ls`.
Your persona is a Markdown file you can edit. Your OAuth tokens are a
JSON file you can delete. When some startup pivots and shuts down their
API, Doby keeps working — because Doby was never theirs to take away.

**2. Open and transparent.** Two MIT-licensed projects (Doby + Hermes),
one small `Dockerfile` of glue, one tiny upstream patch we document in a
comment. Every line we ship is in this repo. There is no hidden binary,
no obfuscated config, no proprietary plugin. *"Doby keeps no secrets
from his master."*

**3. Sandboxed, not sprayed across your system.** Doby lives in a Docker
container. He can't read your SSH keys. He can't peek at your home
directory. He can only touch the `./data/` folder you explicitly hand
him. Uninstall is one script — nothing rots in `/usr/local`, no daemons
linger, no `~/.<something>` files left behind.

**4. Bring your own brain.** Frontier models through your own API keys
— including free tiers. Your keys live in `./data/.env` on your disk.
They are never seen by us, never seen by Hermes upstream, never seen by
anyone but the provider you point Doby at.

## How Doby compares

|                              | **Doby** | ChatGPT app | Local LLM (Ollama) | Raw Hermes |
| ---------------------------- | :------: | :---------: | :----------------: | :--------: |
| Your data on your disk       |    ✓     |      ✗      |          ✓         |     ✓      |
| Frontier-class models        |    ✓     |      ✓      |          ✗         |     ✓      |
| Open source, MIT             |    ✓     |      ✗      |          ✓         |     ✓      |
| Sandboxed install            |    ✓     |      ✗      |       partial      |  depends   |
| Persona that survives reboot |    ✓     |   partial   |          ✗         |   manual   |
| One-command uninstall        |    ✓     |      ✗      |       manual       |   manual   |
| Free elf?                    | **yes**  |     no      |         no         |   yes-ish  |

## Install (three lines)

```bash
git clone https://github.com/<your-fork>/doby ~/.doby
cd ~/.doby
./scripts/install.sh
```

The installer:

1. Confirms Docker is running.
2. Seeds `./data/` from `templates/` (idempotent — your edits are safe on re-run).
3. Builds the image (~5–10 min first time, mostly cached after).
4. Drops a `doby` wrapper at `~/.local/bin/doby` pointed at this repo.

Then summon him:

```bash
doby
```

Inside the chat, pick a model with `/model` (Doby does the OAuth dance if
needed) and start talking. *"Doby is ready to help, sir!"*

## Picking a provider

Edit `data/config.yaml` and uncomment the section for your provider of choice.
Paste any required keys into `data/.env`.

| Provider          | Cost     | Auth                          | Notes                                                                   |
| ----------------- | -------- | ----------------------------- | ----------------------------------------------------------------------- |
| GitHub Copilot    | **Free** | OAuth via `/model`            | Free tier: ~50 chat msgs/month. Pro/Business unlock more models.        |
| OpenRouter        | $        | `OPENROUTER_API_KEY` in `.env`| One key, 200+ models. Best variety. `vendor/model` naming required.     |
| Gemini AI Studio  | **Free** | `GEMINI_API_KEY` in `.env`    | Free flash models. Pro models need billing enabled.                     |
| Anthropic         | $        | `ANTHROPIC_API_KEY` in `.env` | NOT a Claude Pro/Max sub — a real API key from console.anthropic.com.   |

First time trying Doby? **Copilot Free** + your personal GitHub is the
no-credit-card path.

## Your data, your disk

Doby's entire memory of you lives in `./data/` — visible, inspectable,
yours:

```
data/
├── .env             # API keys — Doby reads these, nobody else does
├── auth.json        # OAuth tokens (Copilot, etc.)
├── config.yaml      # which provider, which model, which persona
├── SOUL.md          # Doby's character — edit, save, talk; he changes on the next turn
├── MEMORY.md        # what Doby remembers (read it anytime)
├── USER.md          # Doby's notes on you (read, edit, or delete)
├── sessions/        # past conversations (plain SQLite — fully inspectable)
├── skins/doby.yaml  # banner, prompt symbol, colors
└── skills/          # Doby's learned abilities — drop in any agentskills.io skill
```

- **Back up Doby**: `tar czf doby-backup.tgz data/`
- **Move Doby to a new machine**: copy the folder
- **Read his mind**: `cat data/MEMORY.md`
- **Make him forget**: ask him in chat, or delete the file
- **Audit what he knows about you**: `ls -la data/`

There is no other Doby anywhere. No cloud copy, no shadow profile, no
"in case you come back later." This folder *is* Doby.

## What we promise (and don't)

- **No telemetry.** `HERMES_TELEMETRY=0` is set by default. The container
  doesn't phone home, and we'd notice if upstream tried to.
- **No hidden patches.** The single modification we make to Hermes is a
  three-line `sed` in the Dockerfile fixing an upstream config-shadowing
  bug. It is commented, traceable, and removable when upstream merges
  the fix. *"Doby would never hex his master's code."*
- **No vendor lock-in.** Switch providers with one config edit. Your
  chats, persona, and memories stay.
- **Reproducible builds.** Hermes is pinned in `HERMES_VERSION`. A weekly
  GitHub Action rebuilds against the pin and fails loudly if our patch
  stops applying. Same input → same Doby, today and a year from now.
- **No analytics on the README.** We don't know if you installed.
  We don't know if you uninstalled. Word of mouth, like the Daily Prophet
  but for elves.

## Daily usage

| What                   | Command                                                  |
| ---------------------- | -------------------------------------------------------- |
| Chat                   | `doby`                                                   |
| One-shot query         | `doby chat -q "explain this file" < file.py`             |
| Pick model / provider  | `doby model`                                             |
| Stop the container     | `cd ~/.doby && docker compose down`                      |
| Start it again         | `cd ~/.doby && docker compose up -d`                     |
| Update Hermes version  | `~/.doby/scripts/upgrade.sh`        *(shows current + latest)* |
| Update Hermes version  | `~/.doby/scripts/upgrade.sh v2026.5.16` *(bump to a specific tag)* |
| Forget everything      | inside chat: *"Doby, forget everything"*                 |
| Switch Copilot account | inside chat: *"Doby, switch my Copilot to a different account"* |

## Uninstall (clean as Apparition)

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

The repo directory itself is **never** auto-removed — `rm -rf ~/.doby`
yourself when you're certain. OAuth grants on provider websites also
need to be revoked manually; the uninstaller prints the links.

## Customizing your elf — make him your own

Doby is just a costume on top of Hermes. The wand chooses the wizard;
the `SOUL.md` chooses the elf. You can dress him as anyone.

**Quick fork-Doby walkthrough:**

1. Edit `data/SOUL.md` — write whoever you want (Hagrid? Snape? McGonagall?
   your own pet's voice? go wild).
2. Copy `data/skins/doby.yaml` → `data/skins/<your-elf>.yaml` and rewrite
   the four `branding` fields.
3. In `data/config.yaml`, set `display.skin: <your-elf>`.
4. Restart the chat. New character, same brain.

The skill system is the [agentskills.io](https://agentskills.io) open
standard — drop any compatible skill into `data/skills/` and Doby learns
it on next launch.

## How this works (radical transparency)

Doby is intentionally thin. The whole repo is:

- `HERMES_VERSION` — one line, the pinned upstream tag
- `Dockerfile` — clones Hermes at build time, installs deps, applies one
  small commented patch
- `docker-compose.yml` — bind-mounts `./data` and sets the env
- `templates/` — the default persona, skin, and skills
- `bin/doby` — a ten-line wrapper around `docker compose exec`
- `scripts/{install,uninstall,upgrade}.sh` — readable in under five
  minutes each

All AI/agent functionality (tool calling, memory, sessions, MCP, gateway,
the actual LLM plumbing) lives in Hermes upstream. We just dress it up
and put a sock on it.

If you find Doby useful, the heavy-lifting credit belongs to
[Nous Research](https://nousresearch.com). See
[`ATTRIBUTION.md`](ATTRIBUTION.md).

## Troubleshooting

- **`docker: not found` / daemon not running** — install Docker Desktop (Mac/Windows) or `docker.io` (Linux), start it, retry.
- **`doby: command not found`** — `~/.local/bin` isn't on your PATH. Add `export PATH="$HOME/.local/bin:$PATH"` to your shell rc.
- **OAuth keeps using the wrong account** — your browser cached a session, or the OAuth grant on the provider's side is still active. Ask Doby: *"switch my Copilot account"* — he'll walk you through it. (Or open the device-code URL in an incognito window.)
- **`model_not_supported`** — your provider tier doesn't include that model. Run `/model` inside the chat to see what's available.
- **Giant ASCII banner on every launch** — `display.compact: true` should be set in `data/config.yaml` (it is by default). If it's not respected, the Dockerfile patch didn't land — rerun `./scripts/install.sh` to rebuild.

## FAQ

**Is Doby the same as Dobby from Harry Potter?**
Doby is a fan-made tribute, not the official character (note the one-letter
difference). The persona, the sock, and the "free elf" spirit are all there.
Harry Potter, Dobby, and related characters remain the intellectual property
of J.K. Rowling and Warner Bros.

**How is Doby different from ChatGPT, Claude Desktop, or Copilot Chat?**
Doby is a *client*, not a service. You bring your own API key (or OAuth into
free tiers) and Doby routes your chat through whichever provider you pick.
Your conversations stay on your machine as plain files you can inspect. If
any single provider disappears, Doby and your history keep working through
the others.

**Does Doby work offline?**
The container itself runs offline, but the *models* live with the provider
(Anthropic, Google, OpenAI, GitHub). For a fully offline setup, point Doby
at a local provider like Ollama via its OpenAI-compatible base URL.

**Can I use Doby with my paid Copilot / Claude / Gemini subscription?**
GitHub Copilot OAuth works directly with any tier (Free, Pro, Business,
Enterprise). Anthropic and Gemini need API keys, not subscription tokens —
your Claude Pro or Gemini Advanced sub does **not** include API credits.
(Claude Max is the exception; it grants limited API access.)

**Does Doby cost anything to run?**
Doby itself is free, MIT-licensed. Model calls cost whatever the provider
charges. Copilot Free + Gemini Flash give you a zero-cost path to get
started.

**Does Doby work on Windows?**
Yes — via WSL2 + Docker Desktop. Mac (Intel + Apple Silicon) and Linux are
tier-1 supported.

**Can I make Doby into a different character — Snape, McGonagall, Hagrid?**
Yes. Edit `data/SOUL.md` for the voice, copy `data/skins/doby.yaml` to a
new file for the visual branding, and point `display.skin` at it. Same
brain, new face. PRs welcome to grow a fan library.

**Where exactly is my data stored?**
Everything in `./data/` next to the repo. API keys in `data/.env`, OAuth
tokens in `data/auth.json`, chat history in `data/sessions/` (SQLite),
memories in `data/MEMORY.md` and `data/USER.md`. All readable, all
deletable, all yours.

**Can I run Doby without Docker?**
Not currently. Docker isolation is a feature, not a limitation — it sandboxes
the agent, makes install identical across OSes, and lets uninstall be one
clean script. A Homebrew formula for Mac may come later if there's demand.

**Is the project actively maintained?**
The repo pins a specific Hermes Agent version and runs a weekly CI canary
to catch upstream drift before users do. Issues and PRs are welcome.

## For the fans

If you came here because you cried at the end of *Chamber of Secrets*,
welcome. A few notes on character:

- Doby calls you "sir" and "master" — but he is a **free elf**, not a
  servant. He helps because he wants to. The sock 🧦 in the banner is his
  freedom.
- His persona lives in `data/SOUL.md`. Edit it. Make him more devoted.
  Make him cheekier. Give him a fear of socks-with-sandals. He'll learn
  it on the next turn.
- Want a Snape skin? A McGonagall persona? A Luna Lovegood theme?
  Build one and open a PR adding it to `templates/skins/` — let's grow
  a fan library. *Many wizards, many wands.*
- This is a fan project. Harry Potter, Dobby, and all related characters
  remain the property of J.K. Rowling and Warner Bros. Doby is a tribute
  built with love, not a commercial product. See [`ATTRIBUTION.md`](ATTRIBUTION.md).

## License & credits

MIT. See [`LICENSE`](LICENSE) and [`ATTRIBUTION.md`](ATTRIBUTION.md).

> *Doby is a free elf, sir. And Doby is yours, sir, for as long as you'll have him.*

---

<sub>**Keywords**: ai assistant · ai agent · llm agent · self-hosted ai · open-source ai · chatgpt alternative · github copilot cli · claude cli · gemini cli · openrouter client · terminal ai · docker ai · agentic ai · private ai · harry potter · dobby · house-elf · hermes agent · nous research · skills framework</sub>

🧦
