# Vibe Code Tours — Student Setup

Point your AI coding tools (**Claude Code**, **opencode**, Cursor, Continue.dev) at the
bootcamp's shared LiteLLM proxy with your personal key.

> Your virtual key (`sk-...`) and the proxy URL come from your **cohort channel**.
> Throughout this guide, `$VIBE_PROXY` = that URL — export it once:
>
> ```bash
> export VIBE_PROXY="https://<from-your-channel>"
> ```

## Scripts

| Order | Script | What it does |
|---|---|---|
| 1 | [`student-setup.sh`](student-setup.sh) | Install dev tools — nvm+Node 22, uv+Python 3.12, git, gh, Claude Code, opencode |
| 2 | [`api-setup.sh`](api-setup.sh) | Configure Claude Code + opencode to use the Vibe proxy with your key |
| 3 | [`doctor.sh`](doctor.sh) | Chapter check — verify setup (ch-0) or homework (ch-1+) and post evidence to Discord |

`check-ch1.sh` still works — it's a one-line shim that forwards to `doctor.sh ch-1`.

---

## 📺 Screencasts

| Step | Cast |
|------|------|
| Install dev tools | [![app install](https://asciinema.org/a/MstAtCBkWpUk43U0.svg)](https://asciinema.org/a/MstAtCBkWpUk43U0) |
| Configure proxy key | [![api install](https://asciinema.org/a/EBlB712tx1WyZbcq.svg)](https://asciinema.org/a/EBlB712tx1WyZbcq) |
| Test Claude Code | [![claude test](https://asciinema.org/a/wmYbgICdBWAhK1Wo.svg)](https://asciinema.org/a/wmYbgICdBWAhK1Wo) |
| Test opencode | [![opencode test](https://asciinema.org/a/KOATEKBxjtco2MGX.svg)](https://asciinema.org/a/KOATEKBxjtco2MGX) |

> 🎬 Screencasts by **@Kaung Soe** — thank you!

---

## 0. Install dev tools (one time)

```bash
curl -fsSL https://raw.githubusercontent.com/vibe-code-tours/vibecode-setup/main/student-setup.sh | bash
```

Installs Node, Python, git, gh, librsvg (PNG badge), Claude Code, opencode. Idempotent — safe to re-run.

**Native Windows users:** install WSL first (`wsl --install` in PowerShell, reboot, open Ubuntu, then re-run the command above).

> **Already have Claude Code on Windows?** Run setup inside WSL anyway. It detects
> your existing Windows `claude` and won't install a second copy. `api-setup.sh`
> writes the proxy config into that install's `.claude/settings.json` — your
> same `claude` command just works (no split-brain second login).

### Install + set up GitHub CLI (`gh`)

`student-setup.sh` installs `gh` for you. To install it manually:

```bash
# Linux (Debian/Ubuntu) — official repo; stock apt gh is too old:
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
sudo apt update && sudo apt install -y gh

# macOS:
brew install gh

# No apt / blocked region (no sudo needed):
curl -sS https://webi.sh/gh | sh
```

Then **log in once** — Chapter 1+ homework needs it (profile-repo check, website
PR, and gist posting all go through `gh`):

```bash
gh auth login
```

Answer the prompts:

- **GitHub.com** (not Enterprise)
- **HTTPS** protocol
- **Yes** — authenticate Git with your GitHub credentials
- **Login with a web browser** → copy the one-time code, press Enter, paste it in the browser

> **No browser (headless WSL / SSH)?** Choose **Paste an authentication token** instead.
> Make one at https://github.com/settings/tokens (classic) with **`repo`**, **`read:org`**,
> and **`gist`** scopes, then paste it. (`gist` is required to post your Chapter 1 report.)

Verify:

```bash
gh auth status                 # Logged in to github.com as <you>
gh api user --jq .login        # prints your username
```

The token needs **`repo`** (read PRs) and **`gist`** (post the ch-1 report) scopes.
If `doctor.sh` warns about scope, or `gh gist create` fails, refresh:

```bash
gh auth refresh -s repo,read:org,gist
```

---

## 1. Configure the proxy key

Two paths. Pick one.

### Quick (key file)

No URLs to type. Two steps:

```bash
curl -fsSLO https://raw.githubusercontent.com/vibe-code-tours/vibecode-setup/main/api-setup.sh
curl -fsSLO https://raw.githubusercontent.com/vibe-code-tours/vibecode-setup/main/vibe-key.env.example
cp vibe-key.env.example vibe-key.env
```

Edit `vibe-key.env` and paste the two values from your cohort channel:

```
VIBE_PROXY=https://...        # proxy URL
VIBE_KEY=sk-...               # your key
```

Then **source** (not `bash`) so it applies to your current shell live:

```bash
source api-setup.sh
```

The script backs up any existing Claude login, configures Claude Code + opencode,
writes `~/.config/opencode/opencode.json`, tests your key, and activates everything
in this shell. Test it:

```bash
claude      # Claude Code
opencode    # opencode
```

To restore your previous Claude config later: `bash api-setup.sh --restore`
(api-setup keeps a full timestamped backup at `~/.claude-backup-<ts>/`.)

> Advanced: skip the key file — `bash api-setup.sh sk-KEY https://proxy-url`

### Manual

Add to `~/.bashrc` or `~/.zshrc`:

```bash
export VIBE_PROXY="https://<from-your-channel>"
# Claude Code — base has NO /v1 (Claude Code appends /v1/messages itself)
export ANTHROPIC_BASE_URL="$VIBE_PROXY"
export ANTHROPIC_AUTH_TOKEN="sk-YOUR-KEY"
export ANTHROPIC_MODEL="mimo-v2.5-pro"
export ANTHROPIC_SMALL_FAST_MODEL="mimo-v2.5"
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY="1"
# opencode — base HAS /v1
export OPENAI_BASE_URL="$VIBE_PROXY/v1"
export OPENAI_API_KEY="sk-YOUR-KEY"
```

> ⚠️ **Already logged into Claude Code (Max/Pro)?** The stored login overrides these vars.
> Remove it first: `mv ~/.claude/.credentials.json ~/.claude/.credentials.json.bak`
> (the `api-setup.sh` script does this for you automatically, with a full backup).

Reload (`source ~/.zshrc`), then `claude` or `opencode`.

**opencode** also needs `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "vibe": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Vibe Code Tours",
      "options": { "baseURL": "https://<from-your-channel>/v1", "apiKey": "sk-YOUR-KEY" },
      "models": {
        "mimo-v2.5": { "name": "MiMo v2.5 (fast)" },
        "mimo-v2.5-pro": { "name": "MiMo v2.5 Pro (reasoning)" },
        "deepseek-flash": { "name": "DeepSeek Flash (backup)" }
      }
    }
  },
  "model": "vibe/mimo-v2.5"
}
```

---

## 2. Chapter checks (`doctor.sh`)

`doctor.sh` is a single, chapter-aware self-check. Run it before each class to
verify your setup, and after each chapter to post your homework. Output drops
shareable artifacts into `~/.vibecode/doctor/`.

```bash
curl -fsSL https://raw.githubusercontent.com/vibe-code-tours/vibecode-setup/main/doctor.sh -o doctor.sh
bash doctor.sh           # chapter 0 (pre-class setup gate)
bash doctor.sh ch-1      # chapter 1 (homework: profile repo + PR)
```

All chapters share five checks:

1. Platform detection (mac / WSL / linux) + Claude install location
2. Tool versions — node, npm, python, git, gh, claude
3. GitHub auth (`gh auth` + identity)
4. GitHub read probe (PR list access)
5. Proxy ping — `claude -p` (preferred) or `curl $VIBE_PROXY` fallback

### Chapter 0 — setup gate

```bash
bash doctor.sh
```

Adds a Windows-claude conflict prompt if both WSL and Windows installs exist (recommend
**REPLACE**). Renders a warm-amber **badge card** from the static SVG template
(`card-template.svg`) and converts it to PNG.

**Post it in `#ch-0-intro` (Discord):** drag in the PNG from `~/.vibecode/doctor/`.
An instructor reacts ✅ or 👏 → the bot grants the `ch-0-done` role → `#ch-1` unlocks.
No PNG tool? Post the `.svg` or the plain `.txt` card instead, or tag `@instructor`
to `/unlock @you ch-0` after fixing the issue.

Useful flags:
- `--non-interactive` — auto-pick REPLACE on Windows-claude conflict (CI / scripted)
- `--keep` / `--replace` — force the conflict resolution choice

### Chapter 1 — homework

**1. Create the two things on GitHub first:**

- **Profile repo** — `github.com/<you>/<you>` with a README
- **Website PR** — a pull request to `vibe-code-tours/vibe-code-tours.github.io`

**2. Run the checker:**

```bash
bash doctor.sh ch-1          # old name still works: bash check-ch1.sh
```

It checks proxy API, `gh` auth, your profile repo, and your website PR. On **all
pass** it posts a public gist and prints your submit command. On any ❌, fix the
listed rows and re-run — the gist is not posted until everything passes.

**3. Post it in your cohort channel (Discord or Telegram):**

```
/ch1 <gist-url>
```

The bot re-verifies the profile repo + PR server-side and marks Chapter 1 done —
no instructor react needed.

Useful flags:
- `--no-post` — save the report markdown only, skip the gist post
  (post it manually later: `gh gist create --public ~/.vibecode/doctor/ch-1-report-*.md`)

### Output artifacts

```
~/.vibecode/doctor/
├── ch-0-results-<ts>.json    machine-readable
├── ch-0-report-<ts>.svg      / .png / .txt   ← drop in #ch-0-intro
├── ch-1-results-<ts>.json
└── ch-1-report-<ts>.md       ← gist source
```

### When proxy is down

doctor.sh exits with code 2 and prints recovery options:

| Path | How |
|------|-----|
| Gemini | free tier — [gemini.google.com](https://gemini.google.com) or `gemini` CLI |
| Ollama | offline — `ollama run qwen2.5-coder:7b` |
| Help | tag `@instructor` in `#help` for manual `/unlock` |

---

## 3. Models & switching

| Name | Use |
|------|-----|
| `mimo-v2.5` | Fast — daily coding, autocomplete (default) |
| `mimo-v2.5-pro` | Reasoning — architecture, hard bugs |
| `deepseek-flash` | Backup (auto-fallback when MiMo busy/down) |

Aliases route automatically — no config change:
`gpt-4o`, `gpt-4`, `gpt-3.5-turbo`, `claude-opus-4-8`, `claude-sonnet-4-6`,
`claude-haiku-4-5`, `o1` → MiMo.

```text
# Claude Code (inside TUI) — /model alone opens the picker
/model mimo-v2.5-pro
```

```bash
# opencode
opencode --model vibe/mimo-v2.5-pro
```

---

## 4. Other tools (Continue.dev, Cursor, anything OpenAI-compatible)

The proxy speaks OpenAI's `/v1` API for every model. Any tool that lets you set a base
URL + API key works — point it at `$VIBE_PROXY/v1` with your virtual key.

### Continue.dev (VS Code / JetBrains)

Edit `~/.continue/config.json`:

```json
{
  "models": [
    { "title": "Vibe — MiMo (fast)",        "provider": "openai", "model": "mimo-v2.5",      "apiBase": "https://<from-your-channel>/v1", "apiKey": "sk-YOUR-KEY" },
    { "title": "Vibe — MiMo Pro (reason)",   "provider": "openai", "model": "mimo-v2.5-pro",  "apiBase": "https://<from-your-channel>/v1", "apiKey": "sk-YOUR-KEY" },
    { "title": "Vibe — DeepSeek (backup)",   "provider": "openai", "model": "deepseek-flash", "apiBase": "https://<from-your-channel>/v1", "apiKey": "sk-YOUR-KEY" }
  ],
  "tabAutocompleteModel": {
    "title": "Autocomplete — MiMo", "provider": "openai", "model": "mimo-v2.5",
    "apiBase": "https://<from-your-channel>/v1", "apiKey": "sk-YOUR-KEY"
  }
}
```

`tabAutocompleteModel` routes inline completion to the fast model so your budget lasts.

### Cursor IDE (BYOK)

1. **Settings → Models → OpenAI API Key** (toggle on)
2. Paste your virtual key `sk-YOUR-KEY`
3. **Override OpenAI Base URL** → `https://<from-your-channel>/v1`
4. **Verify** — Cursor sends `/v1/models` to confirm
5. Add model IDs (`mimo-v2.5`, `mimo-v2.5-pro`, `deepseek-flash`) — Cursor's
   pre-built models are ignored once BYOK base URL is set

Cursor sometimes rejects unknown model names — keep them lowercase, matching exactly.

### Generic OpenAI-compatible

| Tool | How |
|---|---|
| `OPENAI_BASE_URL` / `OPENAI_API_KEY` (env) | `$VIBE_PROXY/v1` + `sk-YOUR-KEY` |
| OpenAI Python SDK | `OpenAI(base_url="$VIBE_PROXY/v1", api_key="sk-YOUR-KEY")` |
| LangChain | `ChatOpenAI(base_url="$VIBE_PROXY/v1", api_key="sk-YOUR-KEY")` |

---

## 5. Use your own API keys (optional)

Prefer your own account? No proxy, no bootcamp budget — your own cost.

### Google Gemini (free tier) — https://aistudio.google.com/apikey

```bash
# Claude Code
export ANTHROPIC_BASE_URL=https://generativelanguage.googleapis.com/v1beta
export ANTHROPIC_API_KEY=YOUR-GEMINI-API-KEY
# opencode
export GEMINI_API_KEY=YOUR-GEMINI-API-KEY
```

### OpenRouter (multi-model, some free) — https://openrouter.ai/keys

```bash
# Claude Code
export ANTHROPIC_BASE_URL=https://openrouter.ai/api/v1
export ANTHROPIC_API_KEY=YOUR-OPENROUTER-KEY
# opencode
export OPENAI_BASE_URL=https://openrouter.ai/api/v1
export OPENAI_API_KEY=YOUR-OPENROUTER-KEY
```

Free models (no credit): `qwen/qwen3-coder:free`, `meta-llama/llama-3.3-70b-instruct:free`

### DeepSeek Direct — https://platform.deepseek.com/api_keys

```bash
# Claude Code
export ANTHROPIC_BASE_URL=https://api.deepseek.com/v1
export ANTHROPIC_API_KEY=YOUR-DEEPSEEK-KEY
# opencode
export OPENAI_BASE_URL=https://api.deepseek.com/v1
export OPENAI_API_KEY=YOUR-DEEPSEEK-KEY
```

Full provider/pricing cheat sheet: [PRICING.md](PRICING.md).

---

## 6. Check balance & troubleshoot

```bash
curl -s "$VIBE_PROXY/key/info" \
  -H "Authorization: Bearer $ANTHROPIC_AUTH_TOKEN" | python3 -m json.tool
```

| Error | Meaning | Fix |
|-------|---------|-----|
| `403 key not allowed ... claude-opus-4-8` | old setup | re-run `api-setup.sh` (aliases added) |
| `Please run /login` | stored Claude login overrides env | api-setup backs it up + removes it |
| `/model` list empty | model discovery off | set `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1` |
| opencode: no models | env not enough | api-setup writes `~/.config/opencode/opencode.json` |
| `404 NotFoundError` | MiMo upstream blip | auto-falls back to DeepSeek — just retry |
| `401 Unauthorized` | bad/expired key | check with instructor |
| `429 Budget exceeded` | quota used up | wait for daily reset |
| `429 Rate limit` | too fast | wait 30–60s |
| `doctor.sh` exit 2 | proxy probe failed | see [§2 recovery options](#when-proxy-is-down) |

💡 **Tip:** coding 11 PM – 7 AM (Myanmar) costs the project less (DeepSeek off-peak) — code freely then.

---

*Never paste your key or the proxy URL in a public repo, gist, or screenshot.
Both come only from the cohort channel.*
