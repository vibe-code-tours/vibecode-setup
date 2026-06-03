#!/usr/bin/env bash
# Vibe Code Tours — Chapter 1 self-check.
#
# Verifies your setup + first GitHub work, then posts a public gist.
# Submit the gist in Discord/Telegram with:  /ch1 <gist-url>
#
# Checks:
#   1. Proxy API works (real chat completion with your key)
#   2. An AI coding agent works (claude OR opencode)
#   3. GitHub account (gh auth)
#   4. Profile repo  github.com/<you>/<you>  (with README)
#   5. A pull request to the Vibe Code Tours website repo
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/vibe-code-tours/vibecode-setup/main/check-ch1.sh -o check-ch1.sh
#   bash check-ch1.sh
#
# Reads VIBE_PROXY + VIBE_KEY from ./vibe-key.env (or current env).
set -uo pipefail

WEBSITE_REPO="vibe-code-tours/vibe-code-tours.github.io"
KEYFILE="${VIBE_KEYFILE:-vibe-key.env}"
PASS="✅"; FAIL="❌"; WARN="⚠️"
report=""
add() { report+="$1"$'\n'; printf '%b\n' "$1"; }
fail=0

add "# Chapter 1 check — $(date -u '+%Y-%m-%d %H:%M UTC')"
add ""

# --- load proxy key ---
if [ -f "$KEYFILE" ]; then
  set -a; . "$KEYFILE" 2>/dev/null; set +a
fi
VIBE_PROXY="${VIBE_PROXY:-}"; VIBE_KEY="${VIBE_KEY:-}"

# --- 1. proxy API (real call) ---
if [ -n "$VIBE_PROXY" ] && [ -n "$VIBE_KEY" ]; then
  code=$(curl -s -o /tmp/ch1_api.json -w '%{http_code}' --max-time 30 \
    "${VIBE_PROXY%/}/v1/chat/completions" \
    -H "Authorization: Bearer $VIBE_KEY" \
    -H "Content-Type: application/json" \
    -d '{"model":"mimo-v2.5","messages":[{"role":"user","content":"say ok"}],"max_tokens":5}' 2>/dev/null)
  if [ "$code" = "200" ]; then
    add "$PASS Proxy API — chat completion returned 200"
  else
    add "$FAIL Proxy API — HTTP ${code:-no-response} (check VIBE_PROXY / VIBE_KEY)"; fail=1
  fi
else
  add "$FAIL Proxy API — VIBE_PROXY/VIBE_KEY not set (need $KEYFILE)"; fail=1
fi

# --- 2. AI agent (claude OR opencode) ---
agent=0
if command -v claude >/dev/null 2>&1; then
  add "$PASS claude CLI — $(claude --version 2>/dev/null | head -1)"; agent=1
else
  add "$WARN claude CLI — not found"
fi
if command -v opencode >/dev/null 2>&1; then
  add "$PASS opencode — $(opencode --version 2>/dev/null | head -1)"; agent=1
else
  add "$WARN opencode — not found"
fi
[ "$agent" -eq 0 ] && { add "$FAIL No AI agent — install claude or opencode"; fail=1; }

# --- 3. GitHub auth ---
GH_USER=""
if ! command -v gh >/dev/null 2>&1; then
  add "$FAIL gh CLI not installed — https://cli.github.com"; fail=1
elif gh auth status >/dev/null 2>&1; then
  GH_USER=$(gh api user -q .login 2>/dev/null)
  add "$PASS GitHub auth — @${GH_USER:-?}"
else
  add "$FAIL GitHub — run: gh auth login"; fail=1
fi

# --- 4. profile repo + 5. website PR ---
PR_URL=""
if [ -n "$GH_USER" ]; then
  if gh api "repos/$GH_USER/$GH_USER" >/dev/null 2>&1; then
    add "$PASS Profile repo — github.com/$GH_USER/$GH_USER"
  else
    add "$FAIL Profile repo $GH_USER/$GH_USER not found — create it with a README"; fail=1
  fi
  PR_URL=$(gh pr list --repo "$WEBSITE_REPO" --author "$GH_USER" --state all \
    --json url --jq '.[0].url' 2>/dev/null)
  if [ -n "$PR_URL" ]; then
    add "$PASS Website PR — $PR_URL"
  else
    add "$FAIL No PR to $WEBSITE_REPO by @$GH_USER yet"; fail=1
  fi
fi

# --- machine-readable footer (the bot parses these) ---
add ""
add "---"
add "github_username: ${GH_USER:-none}"
add "website_pr: ${PR_URL:-none}"
add "result: $([ "$fail" -eq 0 ] && echo PASS || echo INCOMPLETE)"

# --- save + post gist ---
f="ch1-report.md"
printf '%s' "$report" > "$f"
echo
if [ "$fail" -ne 0 ]; then
  printf '%b\n' "$WARN Some checks failed — fix the $FAIL lines above and re-run. Gist not posted."
  exit 1
fi
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  url=$(gh gist create --public -d "Vibe Code Tours — Chapter 1 — @$GH_USER" "$f" 2>/dev/null | tail -1)
  if [ -n "$url" ]; then
    printf '%b\n' "$PASS Gist posted: $url"
    echo
    echo "Submit it now (Discord or Telegram):"
    echo "    /ch1 $url"
  else
    printf '%b\n' "$WARN Could not post gist. Create manually: gh gist create --public $f"
  fi
else
  echo "Report saved to $f — create a gist: gh gist create --public $f"
fi
