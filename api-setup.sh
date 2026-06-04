#!/usr/bin/env bash
# api-setup.sh — point Claude Code + opencode at the bootcamp LLM proxy.
#   ./api-setup.sh <KEY> <PROXY_URL>
#   VIBE_KEY=sk-... VIBE_PROXY=https://<proxy> ./api-setup.sh
#   ./api-setup.sh --restore            # bring previous Claude config back
#   ./api-setup.sh --restore <bak-dir>  # restore a specific snapshot
#
# Cross-platform: Linux, macOS, WSL. If you run inside WSL but Claude Code is a
# NATIVE WINDOWS install (claude.exe surfaced on the WSL PATH), this configures
# THAT install — it writes the proxy config into Windows' .claude/settings.json
# so the same `claude` you already use just works. No second install needed.
#
# TIP: `source api-setup.sh` applies shell env to your CURRENT shell immediately.
set -euo pipefail

have() { command -v "$1" >/dev/null 2>&1; }

# ---------- sourced? (then env exports survive into your shell) ----------
SOURCED=0
if [ -n "${ZSH_EVAL_CONTEXT:-}" ]; then
  case "$ZSH_EVAL_CONTEXT" in *:file) SOURCED=1;; esac
elif [ -n "${BASH_SOURCE:-}" ]; then
  [ "${BASH_SOURCE[0]}" != "$0" ] && SOURCED=1
fi

# ---------- resolve this script's path (run or sourced, bash or zsh) ----------
if [ -n "${BASH_SOURCE:-}" ]; then
  SELF="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  SELF="$(eval 'printf %s "${(%):-%x}"')"
else
  SELF="$0"
fi
case "$SELF" in
  bash|-bash|zsh|-zsh|sh|-sh|"") SELF_CMD="bash api-setup.sh" ;;
  *)                              SELF_CMD="bash $SELF" ;;
esac

# ---------- detect Claude install: nix (Linux/macOS) | windows (via WSL) ----------
# Sets: CLAUDE_KIND, CLAUDE_DIR (holds settings.json/.credentials.json),
#       CLAUDE_JSON (the .claude.json login/config file).
detect_claude() {
  local bin; bin="$(command -v claude 2>/dev/null || true)"
  CLAUDE_KIND="nix"
  case "$bin" in
    /mnt/*) CLAUDE_KIND="windows" ;;   # a Windows binary leaked into WSL PATH
  esac
  if [ "$CLAUDE_KIND" = "windows" ]; then
    local up="" wh=""
    up="$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r' || true)"
    [ -n "$up" ] && wh="$(wslpath "$up" 2>/dev/null || true)"
    if [ -z "$wh" ] || [ ! -d "$wh" ]; then
      # fallback: carve /mnt/<drive>/Users/<name> out of the binary path
      wh="$(printf '%s' "$bin" | sed -E 's#(/mnt/[a-z]/Users/[^/]+).*#\1#')"
    fi
    # Guard: if the Windows home still doesn't resolve to a real directory
    # (cmd.exe unavailable, localized/non-standard profile path, or a false
    # /mnt match), DON'T fall through to "$wh/.claude" — an empty $wh would
    # target the root filesystem. Fall back to the Linux config instead.
    if [ -n "$wh" ] && [ -d "$wh" ]; then
      CLAUDE_DIR="$wh/.claude"
      CLAUDE_JSON="$wh/.claude.json"
      echo "Detected Claude Code: native Windows install (via WSL) — home: $wh"
    else
      echo "WARN: a Windows claude ($bin) is on PATH but its Windows home could not" >&2
      echo "      be resolved — using the Linux config (~/.claude) instead. If your" >&2
      echo "      Windows claude ignores the proxy, configure it manually (see README)." >&2
      CLAUDE_KIND="nix"
      CLAUDE_DIR="$HOME/.claude"
      CLAUDE_JSON="$HOME/.claude.json"
    fi
  else
    CLAUDE_DIR="$HOME/.claude"
    CLAUDE_JSON="$HOME/.claude.json"
  fi
}

# ---------- full timestamped backup of the previous Claude config ----------
# Snapshots .claude.json + .credentials.json + settings.json to
# ~/.claude-backup-<ts>/ (always on the Linux/macOS side) with a manifest that
# records each file's origin path so --restore can put them back exactly.
backup_claude() {
  local ts bak f
  ts="$(date +%Y%m%d-%H%M%S)"
  bak="$HOME/.claude-backup-$ts"
  mkdir -p "$bak"
  : > "$bak/manifest.tsv"
  for f in "$CLAUDE_JSON" "$CLAUDE_DIR/.credentials.json" "$CLAUDE_DIR/settings.json"; do
    if [ -f "$f" ]; then
      cp -p "$f" "$bak/$(basename "$f")"
      printf '%s\t%s\n' "$f" "$(basename "$f")" >> "$bak/manifest.tsv"
    fi
  done
  if [ -s "$bak/manifest.tsv" ]; then
    printf '%s\n' "$bak" > "$HOME/.claude-backup-latest"
    echo "Backed up previous Claude config -> $bak"
    echo "  (restore later: $SELF_CMD --restore)"
  else
    rmdir "$bak" 2>/dev/null || true
  fi
}

# ---------- restore ----------
if [ "${1:-}" = "--restore" ]; then
  detect_claude
  BAK="${2:-}"
  [ -z "$BAK" ] && BAK="$(cat "$HOME/.claude-backup-latest" 2>/dev/null || true)"
  if [ -n "$BAK" ] && [ -f "$BAK/manifest.tsv" ]; then
    while IFS=$'\t' read -r origin base; do
      [ -f "$BAK/$base" ] || continue
      mkdir -p "$(dirname "$origin")"
      cp -p "$BAK/$base" "$origin" && echo "  restored $origin"
    done < "$BAK/manifest.tsv"
    echo "Restored previous Claude config from $BAK"
  else
    # legacy fallback (older api-setup only backed up credentials)
    CRED="$CLAUDE_DIR/.credentials.json"; CRED_BAK="$CRED.vibe-bak"
    if [ -f "$CRED_BAK" ]; then
      mv "$CRED_BAK" "$CRED"; echo "Restored personal Claude login (legacy backup)."
    else
      echo "No backup found (looked for ~/.claude-backup-* and $CRED_BAK)." >&2
    fi
  fi
  # drop the proxy env block from settings.json so the personal login takes over
  if have node && [ -f "$CLAUDE_DIR/settings.json" ]; then
    node -e '
      const fs=require("fs"),f=process.argv[1];
      let j={};try{j=JSON.parse(fs.readFileSync(f,"utf8"))}catch(e){}
      if(j.env){for(const k of ["ANTHROPIC_BASE_URL","ANTHROPIC_AUTH_TOKEN","ANTHROPIC_API_KEY","ANTHROPIC_MODEL","ANTHROPIC_SMALL_FAST_MODEL","CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY"]) delete j.env[k];
       if(Object.keys(j.env).length===0) delete j.env;}
      fs.writeFileSync(f,JSON.stringify(j,null,2));
    ' "$CLAUDE_DIR/settings.json" 2>/dev/null || true
  fi
  echo "Also remove the '# >>> vibe-code-tours >>>' block from your shell profile to fully revert."
  exit 0
fi

# ---------- load a key file (beginner path: edit vibe-key.env, run) ----------
SELF_DIR="$(cd "$(dirname "$SELF")" 2>/dev/null && pwd || echo .)"
for KF in "$SELF_DIR/vibe-key.env" "./vibe-key.env"; do
  if [ -f "$KF" ]; then
    # shellcheck disable=SC1090
    set -a; . "$KF"; set +a
    echo "Loaded key file: $KF"; break
  fi
done

KEY="${1:-${VIBE_KEY:-}}"
PROXY="${2:-${VIBE_PROXY:-}}"

[ -n "$PROXY" ] || { echo "ERROR: proxy URL not set. ./api-setup.sh <KEY> <PROXY_URL>" >&2; exit 1; }
case "$PROXY" in https://*) : ;; *) echo "ERROR: PROXY must start https://" >&2; exit 1;; esac
PROXY="${PROXY%/}"; PROXY="${PROXY%/v1}"   # strip trailing slash + accidental /v1

if [ -z "$KEY" ]; then printf "Paste your key (sk-...): "; read -r KEY; fi
case "$KEY" in sk-*) : ;; *) echo "ERROR: key must start sk-" >&2; exit 1;; esac

# ---------- locate + back up the Claude install ----------
detect_claude
backup_claude

# 1. remove stored Claude login (a saved login overrides our env/settings)
CRED="$CLAUDE_DIR/.credentials.json"
if [ -f "$CRED" ]; then
  rm -f "$CRED"
  echo "Cleared stored Claude login (backed up above; restore: $SELF_CMD --restore)"
fi

# 2. write proxy config into Claude's settings.json env block.
#    This is the cross-platform anchor: Claude Code reads its OWN settings.json
#    regardless of shell — so a native Windows claude.exe launched from WSL
#    picks it up too (a shell-profile export alone would NOT reach it).
mkdir -p "$CLAUDE_DIR"
SF="$CLAUDE_DIR/settings.json"
[ -f "$SF" ] || printf '{}\n' > "$SF"
if have node; then
  VIBE_KEY_V="$KEY" VIBE_PROXY_V="$PROXY" node -e '
    const fs=require("fs"),f=process.argv[1];
    let j={};try{j=JSON.parse(fs.readFileSync(f,"utf8"))}catch(e){}
    j.env=Object.assign({},j.env,{
      ANTHROPIC_BASE_URL:process.env.VIBE_PROXY_V,
      ANTHROPIC_AUTH_TOKEN:process.env.VIBE_KEY_V,
      ANTHROPIC_API_KEY:process.env.VIBE_KEY_V,
      ANTHROPIC_MODEL:"mimo-v2.5-pro",
      ANTHROPIC_SMALL_FAST_MODEL:"mimo-v2.5",
      CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY:"1"
    });
    fs.writeFileSync(f,JSON.stringify(j,null,2));
  ' "$SF"
  echo "Claude proxy config -> $SF (env block)"
else
  echo "WARN: node not found — could not patch settings.json." >&2
  echo "      Shell env (below) still configures a Linux claude, but a Windows" >&2
  echo "      claude.exe needs node to apply. Install Node, re-run." >&2
fi

# 3. shell profile (Linux/macOS claude + opencode convenience)
case "${SHELL##*/}" in
  zsh)  PROFILE="$HOME/.zshrc" ;;
  bash) PROFILE="$HOME/.bashrc" ;;
  *)    PROFILE="$HOME/.profile" ;;
esac
touch "$PROFILE"
MS="# >>> vibe-code-tours >>>"; ME="# <<< vibe-code-tours <<<"
if grep -q "$MS" "$PROFILE" 2>/dev/null; then
  tmp=$(mktemp); sed "/$MS/,/$ME/d" "$PROFILE" > "$tmp" && mv "$tmp" "$PROFILE"
fi
cat >> "$PROFILE" <<EOF
$MS
# Vibe Code Tours LLM proxy
export VIBE_PROXY="$PROXY"
# Claude Code (Anthropic-compatible) — base has NO /v1
export ANTHROPIC_BASE_URL="\$VIBE_PROXY"
export ANTHROPIC_AUTH_TOKEN="$KEY"
export ANTHROPIC_API_KEY="$KEY"
# force proxy models so Claude Code never requests claude-opus-* (403)
export ANTHROPIC_MODEL="mimo-v2.5-pro"
export ANTHROPIC_SMALL_FAST_MODEL="mimo-v2.5"
# let /model picker list proxy models
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY="1"
# opencode / OpenAI-compatible — base HAS /v1
export OPENAI_BASE_URL="\$VIBE_PROXY/v1"
export OPENAI_API_KEY="$KEY"
vibe-model() { export OPENAI_MODEL="\$1"; echo "model: \$1"; }
$ME
EOF

# 4. opencode config file (env alone is unreliable for opencode)
OC="$HOME/.config/opencode"; mkdir -p "$OC"
cat > "$OC/opencode.json" <<OCJSON
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "vibe": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Vibe Code Tours",
      "options": { "baseURL": "$PROXY/v1", "apiKey": "$KEY" },
      "models": {
        "mimo-v2.5": { "name": "MiMo v2.5 (fast)" },
        "mimo-v2.5-pro": { "name": "MiMo v2.5 Pro (reasoning)" },
        "deepseek-flash": { "name": "DeepSeek Flash (backup)" }
      }
    }
  },
  "model": "vibe/mimo-v2.5"
}
OCJSON
echo "opencode config -> $OC/opencode.json"

# 5. live test (Anthropic /v1/messages — what Claude Code calls)
echo ""; echo "Testing key ..."
code=$(curl -s -o /tmp/vibe_t.json -w "%{http_code}" "$PROXY/v1/messages" \
  -H "x-api-key: $KEY" -H "anthropic-version: 2023-06-01" -H "Content-Type: application/json" \
  -d '{"model":"mimo-v2.5","max_tokens":10,"messages":[{"role":"user","content":"ok"}]}' || true)
case "$code" in
  200) echo "OK Key works." ;;
  401) echo "FAIL Key rejected (401)." >&2; exit 1 ;;
  429) echo "WARN budget/rate cap (429) — key valid." ;;
  *)   echo "WARN HTTP $code — see /tmp/vibe_t.json" ;;
esac
rm -f /tmp/vibe_t.json 2>/dev/null || true

echo ""
echo "Done."
echo "  Claude settings : $SF"
echo "  Shell profile   : $PROFILE"
echo "Models: mimo-v2.5 (fast) · mimo-v2.5-pro (reasoning) · deepseek-flash"
echo "Switch: Claude Code  /model mimo-v2.5-pro   ·   opencode  --model vibe/mimo-v2.5-pro"
echo "Restore previous Claude config:  $SELF_CMD --restore"
echo ""
if [ "$SOURCED" = "1" ]; then
  # shellcheck disable=SC1090
  . "$PROFILE"
  echo "✅ Active in THIS shell. Run:  claude   (or)   opencode"
else
  echo "Activate now — copy-paste this line:"
  echo ""
  echo "    source $PROFILE"
  echo ""
  echo "(Claude Code also reads its settings.json, so a fresh terminal works too.)"
  echo "Then run:  claude   (or)   opencode"
fi
