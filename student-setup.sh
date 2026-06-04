#!/usr/bin/env bash
# Vibe Code Tours — student setup (standalone, self-contained).
# Works on: Linux, macOS, Windows-WSL (Ubuntu). Native Windows: install WSL first.
#
# One-liner for students:
#   curl -fsSL <GIST_RAW_URL> | bash
# Or download then run:
#   bash student-setup.sh
#
# Idempotent — safe to re-run. Installs: nvm+Node 22 LTS, uv+Python 3.12
# (project pin via .python-version), git, Claude Code, opencode CLI. Then verifies.
# System Python 3.12-3.14 all accepted by verify.
# git, Claude Code. Then verifies everything. No repo clone required.
#
# WSL note: if you ALREADY have Claude Code installed on native Windows, this
# script detects it (claude.exe surfaced on the WSL PATH) and does NOT install a
# second copy — api-setup.sh will configure that existing Windows install.

set -u

NODE_TRACK="--lts"          # Node 22 LTS
PY_VER="3.12"

say()  { printf '\n\033[1;33m==> %s\033[0m\n' "$*"; }
ok()   { printf '  \033[32mOK\033[0m  %s\n' "$*"; }
skip() { printf '  \033[36m--\033[0m  %s (already present)\n' "$*"; }
warn() { printf '  \033[33m!!\033[0m  %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---------- OS detect ----------
OS="unknown"
case "$(uname -s)" in
  Linux*)  OS="linux" ;;
  Darwin*) OS="macos" ;;
esac
IS_WSL=0
if [ "$OS" = "linux" ] && grep -qiE "microsoft|wsl" /proc/version 2>/dev/null; then IS_WSL=1; fi

say "Vibe Code Tours setup — OS: $OS$([ "$IS_WSL" = 1 ] && echo ' (WSL)')"
if [ "$OS" = "unknown" ]; then
  warn "Unsupported shell. On native Windows: run 'wsl --install' in PowerShell,"
  warn "reboot, open Ubuntu, then re-run this script inside WSL."
  exit 1
fi
APT=0; [ "$OS" = "linux" ] && have apt && APT=1

# ---------- 1. Node via nvm ----------
say "1/5  Node.js (nvm + Node 22 LTS)"
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ ! -s "$NVM_DIR/nvm.sh" ]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash && ok "nvm installed"
else
  skip "nvm"
fi
# shellcheck disable=SC1090
# nvm's scripts are not `set -u` clean (the auto-use path dereferences unset
# vars when a Node version is already installed), which would abort here.
# Disable nounset around sourcing + nvm calls, then restore it.
set +u
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
if have nvm; then
  nvm install $NODE_TRACK >/dev/null 2>&1 && nvm use $NODE_TRACK >/dev/null 2>&1
  nvm alias default node >/dev/null 2>&1
  ok "Node $(node --version 2>/dev/null)"
else
  warn "nvm not on PATH this shell — CLOSE this terminal, open a new one, re-run."
fi
set -u

# ---------- 2. Python via uv ----------
say "2/5  Python (uv + Python $PY_VER)"
if ! have uv; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
  ok "uv installed"
else
  skip "uv"
fi
if have uv; then
  uv python install "$PY_VER" >/dev/null 2>&1 || true
  ok "Python $PY_VER ready (uv)"
else
  warn "uv not on PATH this shell — restart terminal, re-run."
fi

# ---------- 3. Git ----------
say "3/5  Git"
if ! have git; then
  if [ "$APT" = 1 ]; then sudo apt update -y && sudo apt install -y git && ok "git installed"
  elif [ "$OS" = "macos" ]; then
    if have brew; then brew install git && ok "git installed"
    else warn "Run: xcode-select --install  (provides git on macOS)"; fi
  fi
else
  skip "git $(git --version | awk '{print $3}')"
fi

# ---------- 4. Claude Code ----------
# Two install paths: official installer (curl) first, npm fallback for regions
# where claude.ai is blocked (Myanmar, etc — npm registry is not geo-restricted).
#
# WSL special case: if `claude` already resolves to a native Windows binary
# (path under /mnt/), we do NOT install a Linux copy. A second install would
# cause a split-brain (two configs, two logins). api-setup.sh configures the
# existing Windows install instead.
say "4/5  Claude Code"
CLAUDE_BIN="$(command -v claude 2>/dev/null || true)"
case "$CLAUDE_BIN" in
  /mnt/*)
    ok "Claude Code: native Windows install detected (via WSL)"
    printf '      %s\n' "$CLAUDE_BIN"
    warn "Not installing a Linux copy (avoids a split-brain second config)."
    warn "Next step — api-setup.sh writes the proxy config into THAT install's"
    warn "Windows .claude/settings.json, so your existing 'claude' just works."
    ;;
  "")
    installed=0
    # Path A: official installer
    if curl -fsSL https://claude.ai/install.sh -o /tmp/_claude_install.sh 2>/dev/null \
       && bash /tmp/_claude_install.sh >/dev/null 2>&1; then
      export PATH="$HOME/.local/bin:$PATH"
      hash -r 2>/dev/null || true     # flush bash command-not-found cache
      if have claude || [ -x "$HOME/.local/bin/claude" ]; then
        ok "Claude Code installed (official curl)"; installed=1
      fi
    fi
    # Path B: npm fallback (works when claude.ai is blocked)
    if [ "$installed" = 0 ] && have npm; then
      if npm install -g @anthropic-ai/claude-code >/dev/null 2>&1; then
        hash -r 2>/dev/null || true
        have claude && { ok "Claude Code installed (npm fallback)"; installed=1; }
      fi
    fi
    if [ "$installed" = 0 ]; then
      warn "Claude Code install failed both paths (curl + npm)."
      warn "Likely cause: claude.ai is blocked at your network/country level."
      warn "For Class 1 you can still join — install an alternative CLI:"
      warn "  npm install -g @google/gemini-cli       # generous free tier"
      warn "  npm install -g opencode-ai              # model-agnostic"
      warn "See SETUP.md 'If Claude Code is blocked in your region' for details."
    fi
    rm -f /tmp/_claude_install.sh
    ;;
  *)
    skip "claude $(claude --version 2>/dev/null | head -1)"
    ;;
esac

# ---------- 5. opencode CLI (open-source agent CLI) ----------
# Default install alongside Claude Code. Path A = official installer, Path B = npm.
# Works in blocked regions where claude.ai is unreachable (npm registry is not geo-blocked).
say "5/5  opencode CLI"
if ! have opencode; then
  installed=0
  if curl -fsSL https://opencode.ai/install -o /tmp/_opencode_install.sh 2>/dev/null \
     && bash /tmp/_opencode_install.sh >/dev/null 2>&1; then
    export PATH="$HOME/.opencode/bin:$HOME/.local/bin:$PATH"
    hash -r 2>/dev/null || true     # flush bash command-not-found cache
    if have opencode || [ -x "$HOME/.opencode/bin/opencode" ]; then
      ok "opencode installed (official curl)"; installed=1
    fi
  fi
  if [ "$installed" = 0 ] && have npm; then
    if npm install -g opencode-ai >/dev/null 2>&1; then
      hash -r 2>/dev/null || true
      have opencode && { ok "opencode installed (npm fallback)"; installed=1; }
    fi
  fi
  if [ "$installed" = 0 ]; then
    warn "opencode install failed both paths."
    warn "Try manually: npm install -g opencode-ai"
  fi
  rm -f /tmp/_opencode_install.sh
else
  skip "opencode $(opencode --version 2>/dev/null | head -1)"
fi

# ---------- verify (inline, no external file) ----------
say "Verifying"
PASS=0; FAIL=0
check() { # name cmd regex
  local out
  if out=$($2 2>&1); then
    if echo "$out" | grep -qE "$3"; then ok "$1: $(echo "$out" | head -1)"; PASS=$((PASS+1));
    else warn "$1: got '$(echo "$out" | head -1)' — expected /$3/"; FAIL=$((FAIL+1)); fi
  else warn "$1: not found"; FAIL=$((FAIL+1)); fi
}
check "Node"        "node --version"   "^v(22|23|24)\."
check "npm"         "npm --version"    "^(1[0-9]|2[0-9])\."
check "Python"      "python3 --version" "^Python 3\.(12|13|14)"
check "uv"          "uv --version"     "^uv 0\."
check "Claude Code" "claude --version" "^[2-9]\."
check "git"         "git --version"    "git version 2\.([3-9][0-9]|[1-9][0-9]{2})"
check "opencode"    "opencode --version" "^[0-9]"

say "Result"
echo "  Passed: $PASS   Failed: $FAIL"
if [ "$FAIL" -eq 0 ]; then
  say "All set. You're ready for Chapter 1."
else
  warn "Some checks failed. Most fix with: CLOSE this terminal, open a new one, re-run this script."
  warn "Still stuck? Post the exact output above in the cohort channel (#setup-help)."
  exit 1
fi
