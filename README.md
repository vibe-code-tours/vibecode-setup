# Vibe Code Tours — Student Setup

Point your AI coding tools (**Claude Code**, **opencode**, Cursor, Continue.dev) at the
bootcamp's shared LiteLLM proxy with your personal key.

> You get a virtual key (`sk-...`) **and** the proxy URL from your **cohort channel**.
> This guide uses `$VIBE_PROXY` for that URL — export it once:
>
> ```bash
> export VIBE_PROXY="https://<from-your-channel>"   # zsh + bash
> ```

Two scripts live here:

| Script | What it does |
|---|---|
| [`student-setup.sh`](student-setup.sh) | Installs the dev tools: nvm+Node 22, uv+Python 3.12, git, Claude Code, opencode |
| [`api-setup.sh`](api-setup.sh) | Configures Claude Code + opencode to use the Vibe proxy with your key |

---

## 📺 Watch (screencasts)

| Step | Cast |
|------|------|
| Install dev tools (app) | [![app install](https://asciinema.org/a/MstAtCBkWpUk43U0.svg)](https://asciinema.org/a/MstAtCBkWpUk43U0) |
| Configure proxy key (api) | [![api install](https://asciinema.org/a/EBlB712tx1WyZbcq.svg)](https://asciinema.org/a/EBlB712tx1WyZbcq) |
| Test Claude Code | [![claude test](https://asciinema.org/a/wmYbgICdBWAhK1Wo.svg)](https://asciinema.org/a/wmYbgICdBWAhK1Wo) |
| Test opencode | [![opencode test](https://asciinema.org/a/KOATEKBxjtco2MGX.svg)](https://asciinema.org/a/KOATEKBxjtco2MGX) |

> 🎬 Screencasts by **@Kaung Soe** — thank you!

---

## 0. Install the dev tools (first time only)

```bash
curl -fsSL https://raw.githubusercontent.com/vibe-code-tours/vibecode-setup/main/student-setup.sh | bash
```

Installs Node, Python, git, Claude Code, opencode. Idempotent — safe to re-run.
Native Windows: install WSL first (`wsl --install` in PowerShell, reboot, open Ubuntu, re-run).

---

## 1. Quick setup (easiest — key file)

No URLs to type. Two steps:

```bash
# 1. get the script + key file template
curl -fsSLO https://raw.githubusercontent.com/vibe-code-tours/vibecode-setup/main/api-setup.sh
curl -fsSLO https://raw.githubusercontent.com/vibe-code-tours/vibecode-setup/main/vibe-key.env.example
cp vibe-key.env.example vibe-key.env
```

Open **`vibe-key.env`** in any editor, paste your two values from the cohort channel:

```
VIBE_PROXY=https://...        ← proxy URL from channel
VIBE_KEY=sk-...               ← your key from channel
```

Then **source** the script — no arguments. (`source`, not `bash`, so it applies to
your current shell immediately — no second step.)

```bash
source api-setup.sh
```

The script reads `vibe-key.env`, backs up your personal Claude login, configures
Claude Code + opencode, writes `opencode.json`, tests your key, and activates it
live in this shell.

```bash
claude      # Claude Code
opencode    # opencode
```

Restore personal Claude login later: `bash api-setup.sh --restore`

> Advanced: skip the key file and pass args — `bash api-setup.sh sk-KEY https://proxy-url`

---

## 2. Manual setup

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

Reload (`source ~/.zshrc`), then run `claude` or `opencode`.

**opencode** also needs a config file — `~/.config/opencode/opencode.json`:

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

## 3. Models & switching

| Name | Use |
|------|-----|
| `mimo-v2.5` | Fast — daily coding, autocomplete (default) |
| `mimo-v2.5-pro` | Reasoning — architecture, hard bugs |
| `deepseek-flash` | Backup (auto-fallback when MiMo busy/down) |

Aliases route automatically — no config change:
`gpt-4o`, `gpt-4`, `gpt-3.5-turbo`, `claude-opus-4-8`, `claude-sonnet-4-6`,
`claude-haiku-4-5`, `o1` → MiMo.

**Switch model**

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

The `openai` provider is Continue's OpenAI-compatible shim — works fine with LiteLLM.
`tabAutocompleteModel` routes inline completion to the fast model so your budget lasts.

### Cursor IDE (BYOK)

1. **Settings → Models → OpenAI API Key** (toggle on).
2. Paste your virtual key `sk-YOUR-KEY`.
3. **Override OpenAI Base URL** → `https://<from-your-channel>/v1`.
4. **Verify** — Cursor sends a `/v1/models` request to confirm.
5. Add the model IDs (`mimo-v2.5`, `mimo-v2.5-pro`, `deepseek-flash`). Cursor's
   pre-built models are ignored once a BYOK base URL is set.

Caveat: Cursor sometimes rejects unknown model names — keep them lowercase, matching exactly.

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

See [PRICING.md](PRICING.md) for a full provider/pricing cheat sheet.

---

## 6. Check balance & troubleshoot

```bash
curl -s "$VIBE_PROXY/key/info" \
  -H "Authorization: Bearer $ANTHROPIC_AUTH_TOKEN" | python3 -m json.tool
```

| Error | Meaning | Fix |
|-------|---------|-----|
| `403 key not allowed ... claude-opus-4-8` | old setup | re-run api-setup (aliases added) |
| `Please run /login` | stored Claude login overrides env | api-setup backs it up + removes it |
| `/model` list empty | model discovery off | set `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1` |
| opencode: no models | env not enough | api-setup writes `~/.config/opencode/opencode.json` |
| `404 NotFoundError` | MiMo upstream blip | auto-falls back to DeepSeek — just retry |
| `401 Unauthorized` | bad/expired key | check with instructor |
| `429 Budget exceeded` | quota used up | wait for daily reset |
| `429 Rate limit` | too fast | wait 30–60s |

💡 **Tip:** coding 11 PM – 7 AM (Myanmar) costs the project less (DeepSeek off-peak) — code freely then.

---

*Never paste your key or the proxy URL in a public repo, gist, or screenshot. Both come from the cohort channel.*

## 7. Chapter 1 check (`/ch1`)

When you finish Chapter 1, prove it in one step. The script tests your proxy API +
agent and your first GitHub work, then posts a public gist.

```bash
curl -fsSL https://raw.githubusercontent.com/vibe-code-tours/vibecode-setup/main/check-ch1.sh -o check-ch1.sh
bash check-ch1.sh
```

It checks:
1. Proxy API works (real chat completion with your key)
2. An AI agent works (claude **or** opencode)
3. GitHub account (`gh auth`)
4. Profile repo `github.com/<you>/<you>` (with README)
5. A pull request to the Vibe Code Tours website repo

If everything passes it posts a gist and prints the link. Submit it in Discord or
Telegram:

```
/ch1 <gist-url>
```

The bot re-checks your GitHub profile repo + website PR server-side and marks
Chapter 1 done. Needs `gh` ([cli.github.com](https://cli.github.com)) installed and
`gh auth login` completed.
