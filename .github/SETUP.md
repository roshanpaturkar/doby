# GitHub repo setup checklist

One-time tasks after pushing the repo to maximize Doby's discoverability.
None of these live in code — they're all in **Settings → General** on
github.com (and one in the "About" panel on the repo's main page).

A perfect README without these is invisible to GitHub's own search.

---

## 1. Repository description (≤ 160 chars)

Paste this into the **Description** field at the top of Settings → General:

> Doby — a free-elf AI for your terminal. Self-hosted, open-source, Dockerized. Your keys, your data, your disk. Built on Hermes Agent. 🧦

This is what appears in GitHub search results, Google snippets, and the
embed cards on Twitter/Discord/Slack when someone shares the repo URL.

---

## 2. Repository topics (up to 20)

Click the ⚙️ gear next to **About** on the repo's main page and paste
these in (one at a time — GitHub's UI is a tag picker, not a comma list):

```
ai
ai-agent
ai-assistant
llm-agent
self-hosted
open-source
chatgpt-alternative
copilot-cli
claude-cli
gemini-cli
openrouter
terminal
docker
agentic-ai
harry-potter
dobby
hermes-agent
nous-research
private-ai
skills-framework
```

These power GitHub's topic-browse pages — `github.com/topics/chatgpt-alternative`,
`github.com/topics/harry-potter`, etc. Without topics, even a great README
won't surface to "browse by topic" users.

The fan-bait ones (`harry-potter`, `dobby`, `house-elf` if you have room)
are gold — those pages have low competition and high fan traffic.

---

## 3. Website link

In the "About" panel (same gear icon), set the **Website** field to:

- Your project landing page if you have one
- Or the README anchor URL (e.g. `https://github.com/<you>/doby#readme`)
- Or your personal site / Twitter

Optional but signals legitimacy to crawlers.

---

## 4. Social preview image (1280 × 640 PNG)

Settings → General → **Social preview** → Upload.

This is the image that appears in Twitter, Reddit, Discord, Slack, and
LinkedIn link previews. Often the deciding factor for whether someone
clicks. Default is the GitHub logo, which is fine but unmemorable.

**Suggested design:**

- **Background**: deep charcoal (#1a1a1a) or muted Gryffindor crimson (#3c1818)
- **Main element**: large 🧦 sock graphic *or* "Doby" wordmark, centered or upper-third
- **Tagline (large)**: "A free elf for your terminal"
- **Sub-tagline (small, lower-third)**: "Open-source · Self-hosted · MIT"
- **Accent color**: warm amber/gold (#d4a017) — HP feel without literal Hogwarts crests (trademark-safe)
- **Font**: clean sans-serif (Inter, Geist, IBM Plex) for technical credibility

**Tools**: Figma, Canva, Excalidraw, Photopea. Export PNG, ≤ 1 MB.

---

## 5. (Optional) Enable Discussions

Settings → Features → ✓ **Discussions**.

Gives fans a place to share custom personas, skins, and skills. Builds
community around the project and creates more indexed pages on the repo
domain (every Discussion thread is a crawlable URL).

Suggested categories: `Personas`, `Skins`, `Skills`, `Help`, `Show & Tell`.

---

## 6. (Optional) Pin the repo

If this is on your personal GitHub profile, pin Doby to your profile
so it shows up first. Helps with personal-brand SEO too.
