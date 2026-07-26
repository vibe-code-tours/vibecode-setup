#!/usr/bin/env bash
# Vibe Code Tours — chapter doctor / self-check.
#
# Single chapter-aware script. Replaces old ch-0 doctor.sh and check-ch1.sh.
#
# Usage:
#   bash doctor.sh                  # default ch-0 (pre-class setup)
#   bash doctor.sh ch-0             # explicit ch-0
#   bash doctor.sh ch-1             # ch-1 homework (profile repo + PR)
#   bash doctor.sh ch-2             # ch-2 homework (proposal in team repo)
#   bash doctor.sh ch-3             # ch-3 homework (team-repo report + personal repo: mcp+skill+agent, 6×20 slides, ⭐>=3)
#   bash doctor.sh ch-4             # ch-4 homework (team-repo report + personal repo: live/download URL, LICENSE, >=3 screenshots, product-intro slides)
#   bash doctor.sh ch-5             # ch-5 homework (team-repo report + personal repo: Skill + Subagent, tech-stack slides, one feedback file, live URL)
#   bash doctor.sh ch-6             # ch-6 homework (team-repo report + personal repo: closed-issue links, LICENSE, README, analytics, >=3 screenshots, public live URL, gallery slides)
#   bash doctor.sh ch-7             # ch-7 homework (peer feedback: >=3 issues you authored on OTHER teams' repos (open or closed))
#
# Stages (all chapters):
#   1. detect platform (mac | wsl | linux)
#   2. detect claude install (linux | windows | both | none) — ch-0 prompts on conflict
#   3. version checks (node, npm, python, git, gh, claude)
#   4. gh auth + user + read probe
#   5. proxy probe (claude -p OR curl VIBE_PROXY)
#
# Chapter-specific:
#   ch-0: SVG badge card → drop PNG in #ch-0-intro → instructor ✅/👏 → ch-0-done
#   ch-N: posts gist → submit via /submit ch-N <gist-url> (ch-1 also checks profile+PR)
#
# Flags:
#   --non-interactive  default REPLACE on windows-claude conflict (ch-0)
#   --keep|--replace   force conflict resolution (ch-0)
#   --no-post          save report.md only, no gist post (ch-N)
#   --no-update        skip self-update check
#   --plain            no colors (auto when piped or NO_COLOR set) — clean paste
#   --out DIR          output dir (default ~/.vibecode/doctor)
#
# Exit codes:
#   0  all green     1  hard fail     2  soft fail (proxy down)

set -u

# version stamp — bump on every doctor.sh change (helps users + mentors debug which build is running)
DOCTOR_VERSION="2026-07-26a"

# ---------- 0. self-update ----------
# doctor.sh updates itself from main so chapter checks can change mid-cohort.
# Skip with --no-update or DOCTOR_SKIP_UPDATE=1. Best-effort: offline = run as-is.
# DOCTOR_UPDATE_STATUS + REMOTE_VERSION carry across the post-update re-exec so
# the banner can show users/mentors exactly what happened (updated/current/offline/stale).
DOCTOR_URL="https://raw.githubusercontent.com/vibe-code-tours/vibecode-setup/main/doctor.sh"
DOCTOR_UPDATE_STATUS="${DOCTOR_UPDATE_STATUS:-}"
REMOTE_VERSION="${REMOTE_VERSION:-}"
case " $* " in *" --no-update "*) DOCTOR_SKIP_UPDATE=1 ;; esac
if [ "${DOCTOR_SKIP_UPDATE:-0}" != "1" ] && [ -f "$0" ] && grep -q "Vibe Code Tours" "$0" 2>/dev/null; then
  _upd_tmp=$(mktemp 2>/dev/null || echo /tmp/doctor-update.$$)
  if curl -fsSL --max-time 10 "$DOCTOR_URL" -o "$_upd_tmp" 2>/dev/null \
     && grep -q "Vibe Code Tours" "$_upd_tmp" 2>/dev/null \
     && bash -n "$_upd_tmp" 2>/dev/null; then
    REMOTE_VERSION="$(grep -m1 '^DOCTOR_VERSION=' "$_upd_tmp" | cut -d'"' -f2)"
    if ! cmp -s "$_upd_tmp" "$0"; then
      if cp "$_upd_tmp" "$0" 2>/dev/null; then
        rm -f "$_upd_tmp"
        echo "doctor.sh updated from main — re-running..."
        DOCTOR_SKIP_UPDATE=1 DOCTOR_UPDATE_STATUS=updated REMOTE_VERSION="$REMOTE_VERSION" exec bash "$0" "$@"
      else
        DOCTOR_UPDATE_STATUS=stale   # newer build on main but $0 not writable
      fi
    else
      DOCTOR_UPDATE_STATUS=current
    fi
  else
    DOCTOR_UPDATE_STATUS=offline
  fi
  rm -f "$_upd_tmp"
fi
[ -z "$DOCTOR_UPDATE_STATUS" ] && DOCTOR_UPDATE_STATUS=skipped

# ---------- args ----------
CHAPTER="ch-0"
if [ $# -gt 0 ] && [[ "$1" =~ ^ch-[0-9]+$ ]]; then CHAPTER="$1"; shift; fi
NONINT=0; KEEP=0; REPLACE=0; OUTDIR="${HOME}/.vibecode/doctor"; NO_POST=0; PLAIN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --non-interactive) NONINT=1 ;;
    --keep)            KEEP=1 ;;
    --replace)         REPLACE=1 ;;
    --no-post)         NO_POST=1 ;;
    --no-update)       : ;;
    --plain)           PLAIN=1 ;;
    --chapter)         CHAPTER="$2"; shift ;;
    --out)             OUTDIR="$2"; shift ;;
    -h|--help)         sed -n '2,31p' "$0"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done

mkdir -p "$OUTDIR"
TS="$(date +%Y%m%d-%H%M%S)"
JSON="$OUTDIR/${CHAPTER}-results-$TS.json"
MD="$OUTDIR/${CHAPTER}-report-$TS.md"
SVG="$OUTDIR/${CHAPTER}-report-$TS.svg"
PNG="$OUTDIR/${CHAPTER}-report-$TS.png"
TXT="$OUTDIR/${CHAPTER}-report-$TS.txt"
WEBSITE_REPO="vibe-code-tours/vibe-code-tours.github.io"
GH_ORG="vibe-code-tours"
TEMPLATE_URL="https://raw.githubusercontent.com/vibe-code-tours/vibecode-setup/main/card-template.svg"
KEYFILE="${VIBE_KEYFILE:-vibe-key.env}"

# ---------- ui ----------
c_reset=$'\033[0m'; c_dim=$'\033[2m'
c_ok=$'\033[32m'; c_warn=$'\033[33m'; c_err=$'\033[31m'; c_bold=$'\033[1m'
# plain mode: explicit --plain, NO_COLOR env, or output not a terminal (piped/redirected)
if [ "$PLAIN" = 1 ] || [ -n "${NO_COLOR:-}" ] || [ ! -t 1 ]; then
  c_reset=""; c_dim=""; c_ok=""; c_warn=""; c_err=""; c_bold=""
fi
ok()   { printf '  %s✅%s %s\n' "$c_ok"   "$c_reset" "$*"; }
warn() { printf '  %s⚠ %s%s\n'  "$c_warn" "$c_reset" "$*"; }
fail() { printf '  %s❌%s %s\n' "$c_err"  "$c_reset" "$*"; }
hr()   { printf '%s──────────────────────────────────────────────%s\n' "$c_dim" "$c_reset"; }
say()  { printf '%s%s%s\n' "$c_bold" "$*" "$c_reset"; }

# plain-text, copy-paste debug block for mentors (no ANSI, fenced for Discord).
# Called on any failure so students paste ONE block instead of a screenshot.
print_debug_bundle() {
  echo
  say "Debug bundle — copy ALL lines below into #help (mentors read this):"; hr
  echo '```'
  echo "doctor $DOCTOR_VERSION | update:$DOCTOR_UPDATE_STATUS${REMOTE_VERSION:+ (main:$REMOTE_VERSION)} | $(date '+%F %T %Z')"
  echo "chapter:$CHAPTER platform:$PLATFORM claude:${CLAUDE_LOC:-?} user:${GH_USER:-none}"
  echo "checks: node:${NODE_R:-?} npm:${NPM_R:-?} py:${PY_R:-?} git:${GIT_R:-?} gh:${GH_R:-?} claude:${CL_R:-?}"
  echo "net:${NET:-?} auth: gh:${GH_AUTH:-?} proxy:${CL_API:-?}"
  case "$CHAPTER" in
    ch-1) echo "ch1: profile:${CH1_PROFILE:-?} pr:${CH1_PR_STATE:-?}" ;;
    ch-2) echo "ch2: proposal:${CH2_PROPOSAL:-?}" ;;
    ch-3) echo "ch3: report:${CH3_REPORT:-?} author:${CH3_AUTHOR:-?} repo:${CH3_OWNER:-?} mcp:${CH3_MCP:-?} skill:${CH3_SKILL:-?} agent:${CH3_AGENT:-?} slides:${CH3_SLIDES:-?} stars:${CH3_STARS:-?}" ;;
    ch-4) echo "ch4: report:${CH4_REPORT:-?} author:${CH4_AUTHOR:-?} repo:${CH4_OWNER:-?} license:${CH4_LICENSE:-?} live:${CH4_LIVE:-?} shots:${CH4_SHOTS:-?} slides:${CH4_SLIDES:-?}" ;;
    ch-5) echo "ch5: report:${CH5_REPORT:-?} author:${CH5_AUTHOR:-?} repo:${CH5_OWNER:-?} skill:${CH5_SKILL:-?} agent:${CH5_AGENT:-?} slides:${CH5_SLIDES:-?} feedback:${CH5_FEEDBACK:-?} live:${CH5_LIVE:-?}" ;;
    ch-6) echo "ch6: report:${CH6_REPORT:-?} author:${CH6_AUTHOR:-?} repo:${CH6_OWNER:-?} license:${CH6_LICENSE:-?} readme:${CH6_README:-?} shots:${CH6_SHOTS:-?} slides:${CH6_SLIDES:-?} issues:${CH6_ISSUES:-?} live:${CH6_LIVE:-?}" ;;
    ch-7) echo "ch7: peer:${CH7_PEER:-?} count:${CH7_PEER_COUNT:-0} own:${CH7_OWN:-none}" ;;
  esac
  echo "score: ${checks_pass:-0}/${checks_total:-0}  json: ${JSON:-none}"
  echo '```'
}
have() { command -v "$1" >/dev/null 2>&1; }

# ---------- load vibe-key.env (for proxy curl fallback) ----------
# shellcheck source=/dev/null
if [ -f "$KEYFILE" ]; then set -a; . "$KEYFILE" 2>/dev/null; set +a; fi
VIBE_PROXY="${VIBE_PROXY:-}"; VIBE_KEY="${VIBE_KEY:-}"

# ---------- 1. platform ----------
PLATFORM=linux
if [ "$(uname -s)" = "Darwin" ]; then PLATFORM=mac
elif grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then PLATFORM=wsl
fi
say "Vibe Code Doctor — $CHAPTER"; hr
echo "  version:  $DOCTOR_VERSION"
echo "  run at:   $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "  platform: $PLATFORM"
case "$DOCTOR_UPDATE_STATUS" in
  updated) ok   "self-update: updated to latest ($DOCTOR_VERSION)" ;;
  current) ok   "self-update: already on latest" ;;
  offline) warn "self-update: offline — running local build $DOCTOR_VERSION" ;;
  stale)   fail "self-update: FAILED — main has ${REMOTE_VERSION:-a newer build}, you run $DOCTOR_VERSION (re-download doctor.sh)" ;;
  *)       echo "  self-update: skipped (--no-update)" ;;
esac

# ---------- 2. claude location ----------
CLAUDE_LINUX=""; CLAUDE_WIN=""; CLAUDE_LOC=none
if have claude; then
  bin="$(command -v claude)"
  case "$bin" in
    /mnt/c/*|*/AppData/*|*.exe|*.cmd) CLAUDE_WIN="$bin"; CLAUDE_LOC=windows ;;
    *)                                CLAUDE_LINUX="$bin"; CLAUDE_LOC=linux ;;
  esac
fi
if [ "$PLATFORM" = "wsl" ]; then
  for p in "/mnt/c/Users/$USER/AppData/Roaming/npm/claude.cmd" \
           "/mnt/c/Program Files/nodejs/claude.cmd" \
           "$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')\\AppData\\Roaming\\npm\\claude.cmd" 2>/dev/null)"; do
    [ -n "$p" ] && [ -f "$p" ] && { CLAUDE_WIN="$p"; break; }
  done
  if [ -n "$CLAUDE_LINUX" ] && [ -n "$CLAUDE_WIN" ]; then CLAUDE_LOC=both
  elif [ -n "$CLAUDE_WIN" ] && [ -z "$CLAUDE_LINUX" ]; then CLAUDE_LOC=windows
  fi
fi
echo "  claude:   $CLAUDE_LOC${CLAUDE_LINUX:+  linux=$CLAUDE_LINUX}${CLAUDE_WIN:+  win=$CLAUDE_WIN}"
hr

# ---------- 2b. conflict resolution (ch-0 only) ----------
CHOICE=skip
if [ "$CHAPTER" = "ch-0" ] && [ "$CLAUDE_LOC" = "both" ]; then
  warn "windows-native AND wsl claude both installed — config drift risk"
  echo "    cohort recommends WSL-native only"
  if [ "$REPLACE" = "1" ] || [ "$NONINT" = "1" ]; then CHOICE=replace
  elif [ "$KEEP" = "1" ]; then CHOICE=keep
  else
    echo
    echo "    [R] REPLACE — migrate to WSL (backup config, uninstall windows, install WSL) (recommended)"
    echo "    [K] KEEP    — leave windows, route proxy to Windows .claude/"
    echo "    [S] SKIP    — keep both, accept risk"
    printf "    pick [R/K/S] (default R): "
    read -r ans
    case "${ans:-R}" in r|R) CHOICE=replace ;; k|K) CHOICE=keep ;; *) CHOICE=skip ;; esac
  fi
  # safety: REPLACE must reinstall claude in WSL — needs npm. If absent, downgrade to
  # KEEP so we never uninstall windows claude and leave the student with nothing.
  if [ "$CHOICE" = "replace" ] && ! have npm; then
    warn "REPLACE needs npm in WSL to reinstall claude — none found; keeping windows install"
    echo "      install node/npm in WSL, then re-run: doctor.sh ch-0 --replace"
    CHOICE=keep
  fi
  echo "    choice: $CHOICE"
  case "$CHOICE" in
    replace)
      # Safe migration: backup config -> uninstall windows (clears config drift) ->
      # install WSL claude -> verify. Order matters: WSL claude won't load config
      # cleanly while the windows install is still present, so uninstall first.
      _bk=""
      if [ -d "$HOME/.claude" ]; then
        _bk_dst="$HOME/.vibecode/backup/claude-config-$TS"
        if mkdir -p "$_bk_dst" && cp -r "$HOME/.claude/." "$_bk_dst/" 2>/dev/null; then
          ok "backed up ~/.claude -> $_bk_dst"; _bk="$_bk_dst"
        else
          warn "config backup failed (continuing)"
        fi
      fi
      echo "    uninstalling windows-native claude…"
      if have powershell.exe; then
        powershell.exe -NoProfile -Command "npm uninstall -g @anthropic-ai/claude-code" 2>/dev/null || warn "windows uninstall returned non-zero"
      elif have cmd.exe; then
        cmd.exe /c "npm uninstall -g @anthropic-ai/claude-code" 2>/dev/null || warn "windows uninstall returned non-zero"
      else
        warn "no powershell/cmd — uninstall windows claude manually: (in Windows) npm uninstall -g @anthropic-ai/claude-code"
      fi
      echo "    installing claude in WSL (npm install -g @anthropic-ai/claude-code)…"
      if npm install -g @anthropic-ai/claude-code >/dev/null 2>&1; then
        hash -r 2>/dev/null || true
        newbin="$(command -v claude 2>/dev/null)"
        case "$newbin" in
          ""|/mnt/c/*|*.cmd|*.exe)
            CLAUDE_WIN=""; CLAUDE_LOC=none
            warn "claude installed but not resolving to a WSL path yet — open a NEW shell and re-run doctor" ;;
          *)
            CLAUDE_LINUX="$newbin"; CLAUDE_WIN=""; CLAUDE_LOC=linux
            ok "WSL claude installed: $CLAUDE_LINUX" ;;
        esac
      else
        CLAUDE_WIN=""; CLAUDE_LOC=none
        fail "WSL claude install FAILED after windows uninstall — no working claude right now"
        echo "      recover: npm install -g @anthropic-ai/claude-code"
        [ -n "${_bk:-}" ] && echo "      your config backup: $_bk"
      fi ;;
    keep) ok "keeping windows claude (proxy config will target Windows .claude/)" ;;
    skip) warn "skip — both installs left in place" ;;
  esac
fi

# ---------- 3. versions ----------
say "Versions"; hr
checks_pass=0; checks_total=0
record_check() {
  local name="$1" cmd="$2" want="$3"
  local out
  if out="$($cmd 2>&1)" && echo "$out" | grep -qE "$want"; then
    printf '  \033[32m✅\033[0m %s: %s\n' "$name" "$(echo "$out" | head -1)" >&2
    echo "ok"
  else
    printf '  \033[31m❌\033[0m %s: %s\n' "$name" "${out:-<missing>}" >&2
    echo "fail"
  fi
}
score_check() { checks_total=$((checks_total+1)); [ "$1" = "ok" ] && checks_pass=$((checks_pass+1)); }

NODE_R=$(record_check "node"   "node --version"     "^v(22|23|24)\.");           score_check "$NODE_R"
NPM_R=$(record_check  "npm"    "npm --version"      "^(1[0-9]|2[0-9])\.");        score_check "$NPM_R"
PY_R=$(record_check   "python" "python3 --version"  "^Python 3\.(12|13|14)\.");  score_check "$PY_R"
GIT_R=$(record_check  "git"    "git --version"      "git version 2\.");           score_check "$GIT_R"
GH_R=$(record_check   "gh"     "gh --version"       "gh version (2\.[4-9][0-9]|[3-9])"); score_check "$GH_R"
CL_R=$(record_check   "claude" "claude --version"   "^[0-9]");                     score_check "$CL_R"

# ---------- 4. github ----------
say "GitHub"; hr
GH_USER=""; GH_AUTH=fail; GH_PR=fail
if have gh && gh auth status >/dev/null 2>&1; then
  GH_AUTH=ok
  GH_USER="$(gh api user --jq .login 2>/dev/null || true)"
  # lowercased login for filename guidance (GitHub logins are case-insensitive;
  # team.yml + CI use lowercase, so suggest a lowercase proposal filename).
  GH_USER_LC="$(printf '%s' "$GH_USER" | tr '[:upper:]' '[:lower:]')"
  if [ -n "$GH_USER" ]; then ok "auth: $GH_USER"; else warn "auth ok but /user empty"; fi
  if gh pr list --repo cli/cli --limit 1 >/dev/null 2>&1; then GH_PR=ok; ok "pr read probe (cli/cli)"
  else fail "pr read probe — token may lack repo scope"
  fi
else
  fail "gh not logged in (run: gh auth login)"
fi

# ---------- 5. proxy / claude api ----------
say "Proxy / Claude API"; hr
# ch-2/ch-3 run on the ch-2 tier, whose proxy access is intentionally blocked.
# The proxy probe still runs (informational) but must NOT gate submission.
#
# TEMPORARY (2026-07-26): gated OFF for EVERY chapter — both the Claude sub and the
# proxy API check are informational, neither blocks submission. Keys now carry 5h and
# weekly spend windows, so a correctly-configured student can be rate-limited at any
# moment; gating homework on that would fail them for a budget state rather than a
# setup fault. Access also varies by chapter band now, so "no proxy" is normal for some.
# REVERT: set PROXY_GATED=1 and keep the ch-2|ch-3 exemption below.
PROXY_GATED=0
case "$CHAPTER" in ch-2|ch-3) PROXY_GATED=0 ;; esac
# connectivity pre-check — separates "no internet" from "proxy/key is wrong"
NET=down
if curl -fsS --max-time 6 -o /dev/null "$DOCTOR_URL" 2>/dev/null \
   || curl -fsS --max-time 6 -o /dev/null https://github.com 2>/dev/null; then NET=up; fi
[ "$NET" = up ] && ok "network: online" || warn "network: OFFLINE — auth checks will fail until you reconnect (wifi/VPN)"
CL_API=fail; CL_REPLY=""; PROXY_HTTP=""
# two auth paths: own Claude sub (claude -p) OR our proxy key (VIBE_PROXY+VIBE_KEY).
# pass if EITHER works; the unused path is informational (⚠), not a failure.
CL_OWN=fail; CL_OWN_MSG="claude CLI not installed"
CL_PROXY=fail; CL_PROXY_MSG="VIBE_PROXY+VIBE_KEY not set in $KEYFILE"
# path A: own subscription
if have claude; then
  if CL_REPLY="$(claude -p "ping in one word" --output-format text 2>&1)" && [ -n "$CL_REPLY" ] && ! echo "$CL_REPLY" | grep -qiE "error|401|403|fetch failed|ENOTFOUND"; then
    CL_OWN=ok; CL_OWN_MSG="$(echo "$CL_REPLY" | head -1 | cut -c1-60)"
  else
    CL_OWN_MSG="$(echo "$CL_REPLY" | head -1 | cut -c1-100)"
  fi
fi
# path B: our proxy key
if [ -n "$VIBE_PROXY" ] && [ -n "$VIBE_KEY" ]; then
  # bearer goes in a 0600 --config file, never argv — keeps the key out of `ps`.
  # response body discarded (-o /dev/null) so no world-readable /tmp file is left.
  _api_cfg=$(mktemp 2>/dev/null || echo "/tmp/doctor-cfg.$$")
  chmod 600 "$_api_cfg" 2>/dev/null || true
  printf 'header = "Authorization: Bearer %s"\n' "$VIBE_KEY" > "$_api_cfg"
  PROXY_HTTP=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 \
    --config "$_api_cfg" \
    "${VIBE_PROXY%/}/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{"model":"mimo-v2.5","messages":[{"role":"user","content":"say ok"}],"max_tokens":5}' 2>/dev/null)
  rm -f "$_api_cfg"
  case "$PROXY_HTTP" in
    200)
      CL_PROXY=ok; CL_PROXY_MSG="HTTP 200" ;;
    429)
      # 429 means the key AUTHENTICATED and was then refused on a spend window.
      # That proves the setup is correct — reporting it as a failure sends students
      # to re-run api-setup.sh over what is really just a full 5h/weekly budget.
      CL_PROXY=ok
      CL_PROXY_MSG="HTTP 429 — key is fine, spend window full (5h or weekly); retry later" ;;
    *)
      CL_PROXY_MSG="HTTP ${PROXY_HTTP:-no-response} (check VIBE_PROXY/VIBE_KEY)" ;;
  esac
fi
# verdict: either path is enough
if [ "$CL_OWN" = "ok" ] || [ "$CL_PROXY" = "ok" ]; then
  CL_API=ok
  if [ "$CL_OWN" = "ok" ]; then ok "own sub (claude -p): $CL_OWN_MSG"; else warn "own sub (claude -p): $CL_OWN_MSG"; fi
  if [ "$CL_PROXY" = "ok" ]; then ok "our key (proxy): $CL_PROXY_MSG"; else warn "our key (proxy): $CL_PROXY_MSG"; fi
elif [ "$PROXY_GATED" = 0 ]; then
  case "$CHAPTER" in
    ch-2|ch-3) warn "proxy blocked at $CHAPTER tier (expected) — not gating this chapter" ;;
    *)         warn "no working API right now — NOT gating your submission (temporary)"
               warn "you can still submit; for a free fallback see 9Router in class materials" ;;
  esac
  warn "own sub (claude -p): $CL_OWN_MSG"
  warn "our key (proxy): $CL_PROXY_MSG"
else
  [ "$NET" = down ] && fail "ROOT CAUSE likely no internet — reconnect (wifi/VPN), then re-run"
  fail "own sub (claude -p): $CL_OWN_MSG"
  fail "our key (proxy): $CL_PROXY_MSG"
  fail "need ONE working — fix claude login OR set VIBE_PROXY+VIBE_KEY in $KEYFILE"
fi

# ---------- 6. chapter-specific ----------
CH1_PROFILE=fail; CH1_PR=""; CH1_PR_STATE=fail
if [ "$CHAPTER" = "ch-1" ]; then
  say "Chapter 1 — homework"; hr
  if [ -n "$GH_USER" ]; then
    if gh api "repos/$GH_USER/$GH_USER" >/dev/null 2>&1; then
      CH1_PROFILE=ok; ok "profile repo: github.com/$GH_USER/$GH_USER"
    else
      fail "profile repo $GH_USER/$GH_USER not found — create with a README"
    fi
    CH1_PR=$(gh pr list --repo "$WEBSITE_REPO" --author "$GH_USER" --state all --json url --jq '.[0].url' 2>/dev/null)
    if [ -n "$CH1_PR" ]; then
      CH1_PR_STATE=ok; ok "website PR: $CH1_PR"
    else
      fail "no PR to $WEBSITE_REPO by @$GH_USER"
    fi
  else
    fail "skipping profile/PR — gh not authed"
  fi
fi

# ---------- 6b. chapter 2 — proposal in team repo ----------
# ch-2 gate = member-proposals/<you>.md in your team-NN repo. Build-repo
# checks (files, commits) happen in ch-4 — code may stay private for now.
CH2_PROPOSAL=fail; CH2_TEAM_REPO=""
if [ "$CHAPTER" = "ch-2" ]; then
  say "Chapter 2 — team proposal"; hr
  if [ -n "$GH_USER" ]; then
    TEAM_REPOS=$(gh api --paginate "orgs/$GH_ORG/repos?per_page=100" --jq '.[].name' 2>/dev/null | grep -E '^team-[0-9]+$' || true)
    if [ -n "$TEAM_REPOS" ]; then
      for t in $TEAM_REPOS; do
        # case-insensitive filename match (logins case-insensitive, files aren't)
        if gh api "repos/$GH_ORG/$t/contents/member-proposals" --jq '.[].name' 2>/dev/null | grep -Fixq "$GH_USER.md"; then
          CH2_PROPOSAL=ok; CH2_TEAM_REPO="$t"; break
        fi
      done
      if [ "$CH2_PROPOSAL" = "ok" ]; then
        ok "team proposal: $CH2_TEAM_REPO/member-proposals/$GH_USER_LC.md"
      else
        CH2_TEAM_REPO=$(printf '%s\n' "$TEAM_REPOS" | head -1)
        fail "no member-proposals/$GH_USER_LC.md in your team repo — copy member-proposals/_TEMPLATE.md to that lowercase name, fill Gist/Story/Why, push"
      fi
    else
      fail "no team repo visible — run /repo-access in Discord, accept the GitHub invite, retry"
    fi
  else
    fail "skipping ch-2 checks — gh not authed"
  fi
fi

# ---------- 6c. chapter 3 — personal project ----------
# Submission lives in the TEAM repo at ch-3/<you>/report.md; evidence (.mcp/.claude,
# slides) lives in your PERSONAL project repo. doctor fetches both via gh API — run
# from anywhere, no clone needed. Mirrors instructor scripts/check-ch3.mjs.
CH3_MIN_STARS="${CH3_MIN_STARS:-3}"               # distinct stargazers (excl. owner) — anti ghost/self-star
CH3_MIN_SKILL_BYTES="${CH3_MIN_SKILL_BYTES:-200}" # anti-stub SKILL.md
CH3_MIN_AGENT_BYTES="${CH3_MIN_AGENT_BYTES:-100}" # anti-stub agent .md
CH3_REPORT=fail; CH3_OWNER=fail; CH3_AUTHOR=fail; CH3_MCP=fail; CH3_SKILL=fail; CH3_AGENT=fail
CH3_SLIDES=fail; CH3_EVIDENCE=fail; CH3_METHOD=fail; CH3_STARS=fail
CH3_REPO=""; CH3_REPO_URL=""; CH3_SLIDES_URL=""; CH3_SUMMARY=""
CH3_TEAM_REPO=""; CH3_DIR=""; CH3_STAR_COUNT=0
CH3_REPORT_TMP="$OUTDIR/ch-3-report-fetched-$TS.md"
if [ "$CHAPTER" = "ch-3" ]; then
  say "Chapter 3 — personal project"; hr
  if [ -z "$GH_USER" ]; then
    fail "skipping ch-3 checks — gh not authed (run: gh auth login)"
  else
    # 1. locate your team repo + ch-3/<you>/ dir (login match is case-insensitive)
    TEAM_REPOS=$(gh api --paginate "orgs/$GH_ORG/repos?per_page=100" --jq '.[].name' 2>/dev/null | grep -E '^team-[0-9]+$' || true)
    for t in $TEAM_REPOS; do
      d=$(gh api "repos/$GH_ORG/$t/contents/ch-3" --jq '.[].name' 2>/dev/null | grep -ixF "$GH_USER" | head -1 || true)
      if [ -n "$d" ] && gh api "repos/$GH_ORG/$t/contents/ch-3/$d/report.md" >/dev/null 2>&1; then
        CH3_TEAM_REPO="$t"; CH3_DIR="$d"; break
      fi
    done
    if [ -z "$CH3_TEAM_REPO" ]; then
      fail "no ch-3/$GH_USER/report.md in any team repo — copy ch-3/_TEMPLATE.md to ch-3/$GH_USER_LC/report.md, fill it, push (run /repo-access if you have no team repo)"
    elif gh api "repos/$GH_ORG/$CH3_TEAM_REPO/contents/ch-3/$CH3_DIR/report.md" \
           -H "Accept: application/vnd.github.raw" > "$CH3_REPORT_TMP" 2>/dev/null \
         && [ -s "$CH3_REPORT_TMP" ]; then
      CH3_REPORT=ok; ok "report: $CH3_TEAM_REPO/ch-3/$CH3_DIR/report.md"
    else
      fail "could not fetch ch-3/$CH3_DIR/report.md from $CH3_TEAM_REPO"
    fi

    if [ "$CH3_REPORT" = ok ]; then
      tr -d '\r' < "$CH3_REPORT_TMP" > "$CH3_REPORT_TMP.n" && mv "$CH3_REPORT_TMP.n" "$CH3_REPORT_TMP"
      # tolerant field read: optional leading/trailing **, spaces, case-insensitive key
      get_field() { grep -m1 -iE "^[[:space:]*]*$1[[:space:]]*:" "$CH3_REPORT_TMP" | sed -E "s/^[[:space:]*]*$1[[:space:]]*:[[:space:]*]*//; s/[[:space:]*]+\$//"; }
      CH3_REPO_URL=$(get_field personal_repo_url)
      CH3_SLIDES_URL=$(get_field slides_url)
      CH3_SUMMARY=$(get_field project_summary)

      # methodology (canonical, must match lib/ch3-checks.mjs): section minus
      # comment-lines, minus all whitespace; require >= 10 chars.
      meth_chars=$(awk '/^## Methodology/{f=1;next} /^## /{f=0} f' "$CH3_REPORT_TMP" | grep -vE '^[[:space:]]*<!--' | tr -d '[:space:]')
      if [ "${#meth_chars}" -ge 10 ]; then
        CH3_METHOD=ok; ok "methodology written"
      else
        fail "report.md Methodology section too short — write 2-4 sentences"
      fi

      # 1b. report.md must be committed BY YOU (anti-forgery: teammates can write the team repo)
      rep_author=$(gh api "repos/$GH_ORG/$CH3_TEAM_REPO/commits?path=ch-3/$CH3_DIR/report.md&per_page=1" --jq '.[0].author.login // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]')
      if [ -z "$rep_author" ]; then
        CH3_AUTHOR=ok; warn "could not verify report.md commit author (commit email not linked to a GitHub account) — instructor will check"
      elif [ "$rep_author" = "$GH_USER_LC" ]; then
        CH3_AUTHOR=ok; ok "report committed by you (@$rep_author)"
      else
        fail "report.md last committed by @$rep_author, not you (@$GH_USER) — push your own report"
      fi

      # 2. personal repo: owner check + distinct stargazers (excl. owner) for stars gate
      # robust owner/repo: strip host, drop any path/query (/tree/main, ?tab=),
      # keep first two segments, strip trailing .git
      CH3_REPO=$(printf '%s' "$CH3_REPO_URL" \
        | sed -E 's#(git@|https?://)github\.com[:/]##; s/[#?].*$//' \
        | cut -d/ -f1,2 | sed -E 's/\.git$//')
      repo_owner=$(gh api "repos/$CH3_REPO" --jq '.owner.login' 2>/dev/null || true)
      if [ -z "$repo_owner" ]; then
        fail "personal repo not found: ${CH3_REPO:-none} (check personal_repo_url)"
      else
        repo_owner_lc=$(printf '%s' "$repo_owner" | tr '[:upper:]' '[:lower:]')
        if [ "$repo_owner_lc" = "$GH_USER_LC" ]; then
          CH3_OWNER=ok; ok "repo: github.com/$CH3_REPO (owner @$repo_owner)"
        else
          fail "personal_repo_url owner @$repo_owner != you @$GH_USER — submit your own repo"
        fi
        # distinct stargazers excluding the owner — one self-star does not count.
        # Distinguish a fetch failure (throttle/offline) from a genuine 0: on failure
        # soft-pass (the bot re-checks authoritatively at /submit) so a GitHub hiccup
        # never falsely accuses a real repo of ghosting.
        _stg=$(gh api --paginate "repos/$CH3_REPO/stargazers" --jq '.[].login' 2>/dev/null); _stg_rc=$?
        if [ "$_stg_rc" -ne 0 ]; then
          CH3_STARS=ok; CH3_STAR_COUNT="?"
          warn "stars: couldn't reach GitHub (throttle/offline) — not counted against you; the bot verifies at /submit"
        else
          CH3_STAR_COUNT=$(printf '%s\n' "$_stg" \
            | tr '[:upper:]' '[:lower:]' | grep -vxF "$repo_owner_lc" | sort -u | grep -c . || true)
          if [ "${CH3_STAR_COUNT:-0}" -ge "$CH3_MIN_STARS" ]; then
            CH3_STARS=ok; ok "stars: $CH3_STAR_COUNT distinct, excl. you (>= $CH3_MIN_STARS)"
          else
            fail "stars: $CH3_STAR_COUNT distinct (need >= $CH3_MIN_STARS — ask teammates to ⭐; your own star doesn't count)"
          fi
        fi

        # 3. evidence: recursive tree of personal repo → .mcp/.claude + claimed paths
        if [ "$(gh api "repos/$CH3_REPO/git/trees/HEAD?recursive=1" --jq '.truncated' 2>/dev/null)" = "true" ]; then
          warn "repo tree too large — GitHub truncated it; evidence/slide checks may be incomplete, instructor will verify manually"
        fi
        TREE=$(gh api "repos/$CH3_REPO/git/trees/HEAD?recursive=1" --jq '.tree[]|select(.type=="blob")|"\(.size)\t\(.path)"' 2>/dev/null || true)
        TREE_PATHS=$(printf '%s\n' "$TREE" | cut -f2-)
        # mcp: ANY candidate (.mcp.json OR .claude/settings*.json) declares MCP —
        # mcpServers (classic / plugin pluginConfigs), enabledPlugins (plugin-based MCP),
        # or a bare .mcp.json with real server entries. Mirrors lib/ch3-checks.mjs.
        mcp_paths=$(printf '%s\n' "$TREE_PATHS" | grep -iE '^\.mcp\.json$|^\.claude/settings[^/]*\.json$' || true)
        if [ -z "$mcp_paths" ]; then
          fail "no .mcp.json (or .claude/settings*.json) in repo"
        else
          mcp_found=""
          while IFS= read -r mp; do
            [ -z "$mp" ] && continue
            body=$(gh api "repos/$CH3_REPO/contents/$mp" -H "Accept: application/vnd.github.raw" 2>/dev/null || true)
            if printf '%s' "$body" | grep -qiE 'mcp_?servers|enabledplugins'; then mcp_found="$mp"; break; fi
            case "$mp" in
              .mcp.json|.MCP.json) printf '%s' "$body" | grep -qE '"(command|url|type)"[[:space:]]*:' && { mcp_found="$mp"; break; } ;;
            esac
          done <<EOF2
$mcp_paths
EOF2
          if [ -n "$mcp_found" ]; then
            CH3_MCP=ok; ok "$mcp_found declares MCP (mcpServers / enabledPlugins)"
          else
            fail "MCP file(s) present but no mcpServers / enabledPlugins / server entry"
          fi
        fi
        # skill: present AND not a stub (size >= threshold)
        skill_sz=$(printf '%s\n' "$TREE" | awk -F'\t' 'tolower($2) ~ "^\\.claude/skills/[^/]+/skill\\.md$" {print $1; exit}')
        if [ -z "$skill_sz" ]; then fail "no .claude/skills/<name>/SKILL.md on your default branch (is .claude/ in .gitignore? un-ignore it and push)"
        elif [ "$skill_sz" -ge "$CH3_MIN_SKILL_BYTES" ]; then CH3_SKILL=ok; ok ".claude/skills SKILL.md present (${skill_sz}b)"
        else fail "SKILL.md too small (${skill_sz}b < ${CH3_MIN_SKILL_BYTES}b — looks like a stub)"; fi
        # agent: present AND not a stub
        agent_sz=$(printf '%s\n' "$TREE" | awk -F'\t' 'tolower($2) ~ "^\\.claude/agents/[^/]+\\.md$" {print $1; exit}')
        if [ -z "$agent_sz" ]; then fail "no .claude/agents/<name>.md on your default branch (is .claude/ in .gitignore? un-ignore it and push)"
        elif [ "$agent_sz" -ge "$CH3_MIN_AGENT_BYTES" ]; then CH3_AGENT=ok; ok ".claude/agents agent present (${agent_sz}b)"
        else fail "agent .md too small (${agent_sz}b < ${CH3_MIN_AGENT_BYTES}b — looks like a stub)"; fi

        CH3_EVIDENCE=ok; ev_paths=$(grep -E '^- *path:' "$CH3_REPORT_TMP" | sed 's/^- *path:[[:space:]]*//')
        if [ -n "$ev_paths" ]; then
          while IFS= read -r p; do
            [ -z "$p" ] && continue
            case "$p" in '<'*'>') continue;; esac
            printf '%s\n' "$TREE_PATHS" | grep -qxF "$p" || { CH3_EVIDENCE=fail; fail "evidence path not on default branch: $p (is .claude/ gitignored? push it to your default branch)"; }
          done <<EOF2
$ev_paths
EOF2
          [ "$CH3_EVIDENCE" = ok ] && ok "evidence paths exist in repo"
        else
          CH3_EVIDENCE=fail; fail "no evidence '- path:' lines in report.md"
        fi

        # 4. slides: slides_url is a repo-relative path (normalize blob/raw URLs),
        #    fetch raw from the personal repo, require Marp 6 slides + auto-advance:20
        sp="$CH3_SLIDES_URL"
        case "$sp" in
          http*://github.com/*/blob/*)         sp="${sp#*://github.com/*/blob/}"; sp="${sp#*/}" ;;
          http*://raw.githubusercontent.com/*) sp="${sp#*://raw.githubusercontent.com/}"; sp="${sp#*/}"; sp="${sp#*/}"; sp="${sp#*/}" ;;
        esac
        if [ -z "$sp" ]; then
          fail "slides_url empty in report.md"
        elif gh api "repos/$CH3_REPO/contents/$sp" -H "Accept: application/vnd.github.raw" > "$OUTDIR/ch3-slides-$TS.md" 2>/dev/null && [ -s "$OUTDIR/ch3-slides-$TS.md" ]; then
          slf="$OUTDIR/ch3-slides-$TS.md"
          tr -d '\r' < "$slf" > "$slf.n" && mv "$slf.n" "$slf"
          fm=$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f{print}' "$slf")
          sl_count=$(awk 'NR==1&&$0=="---"{infm=1;next} infm&&$0=="---"{infm=0;body=1;prev="";next} infm{next} {if($0 ~ /^---[ \t]*$/ && prev==""){s++} prev=$0} END{if(body)print s+1; else print 0}' "$slf")
          if printf '%s\n' "$fm" | grep -qE '^[[:space:]]*marp:[[:space:]]*true' && [ "${sl_count:-0}" -eq 6 ] && printf '%s\n' "$fm" | grep -qE '^[[:space:]]*auto-advance:[[:space:]]*20'; then
            CH3_SLIDES=ok; ok "slides: 6×20 Marp ($sp)"
          else
            fail "slides must be Marp (marp: true) with 6 slides + 'auto-advance: 20' (found ${sl_count:-0} slides at $sp)"
          fi
        else
          fail "slides not found in repo at: ${sp:-none} (slides_url must be a repo-relative path)"
        fi
      fi
    fi
  fi
fi

# ---------- 6d. chapter 4 — make the winner real (personal project, shipped) ----------
# Submission: TEAM repo ch-4/<you>/report.md. Evidence: PERSONAL repo (LICENSE,
# screenshots, product-intro slides) + a live/download URL. Fetched via gh API —
# run from anywhere, no clone needed. Mirrors instructor scripts/check-ch4.mjs.
CH4_MIN_SHOTS="${CH4_MIN_SHOTS:-3}"               # screenshots referenced in report that exist in repo
CH4_REPORT=fail; CH4_AUTHOR=fail; CH4_OWNER=fail; CH4_LICENSE=fail
CH4_LIVE=fail; CH4_SHOTS=fail; CH4_SLIDES=fail
CH4_REPO=""; CH4_REPO_URL=""; CH4_LIVE_URL=""; CH4_LICENSE_NAME=""
CH4_SLIDES_PATH=""; CH4_SUMMARY=""; CH4_TEAM_REPO=""; CH4_DIR=""; CH4_SHOT_COUNT=0
CH4_REPORT_TMP="$OUTDIR/ch-4-report-fetched-$TS.md"
if [ "$CHAPTER" = "ch-4" ]; then
  say "Chapter 4 — personal project (shipped + licensed)"; hr
  if [ -z "$GH_USER" ]; then
    fail "skipping ch-4 checks — gh not authed (run: gh auth login)"
  else
    # 1. locate your team repo + ch-4/<you>/ dir (login match is case-insensitive)
    TEAM_REPOS=$(gh api --paginate "orgs/$GH_ORG/repos?per_page=100" --jq '.[].name' 2>/dev/null | grep -E '^team-[0-9]+$' || true)
    for t in $TEAM_REPOS; do
      d=$(gh api "repos/$GH_ORG/$t/contents/ch-4" --jq '.[].name' 2>/dev/null | grep -ixF "$GH_USER" | head -1 || true)
      if [ -n "$d" ] && gh api "repos/$GH_ORG/$t/contents/ch-4/$d/report.md" >/dev/null 2>&1; then
        CH4_TEAM_REPO="$t"; CH4_DIR="$d"; break
      fi
    done
    if [ -z "$CH4_TEAM_REPO" ]; then
      fail "no ch-4/$GH_USER/report.md in any team repo — copy ch-4/_TEMPLATE.md to ch-4/$GH_USER_LC/report.md, fill it, push (run /repo-access if you have no team repo)"
    elif gh api "repos/$GH_ORG/$CH4_TEAM_REPO/contents/ch-4/$CH4_DIR/report.md" \
           -H "Accept: application/vnd.github.raw" > "$CH4_REPORT_TMP" 2>/dev/null \
         && [ -s "$CH4_REPORT_TMP" ]; then
      CH4_REPORT=ok; ok "report: $CH4_TEAM_REPO/ch-4/$CH4_DIR/report.md"
    else
      fail "could not fetch ch-4/$CH4_DIR/report.md from $CH4_TEAM_REPO"
    fi

    if [ "$CH4_REPORT" = ok ]; then
      tr -d '\r' < "$CH4_REPORT_TMP" > "$CH4_REPORT_TMP.n" && mv "$CH4_REPORT_TMP.n" "$CH4_REPORT_TMP"
      # tolerant markdown field read (case-insensitive): strips leading "- ", "**",
      # spaces around the key; $1 is a lowercase ERE key. awk/tolower keeps it portable.
      get4() {
        awk -v k="$1" '
        {
          line=$0
          sub(/^[[:space:]]*[-*[:space:]]*/, "", line)   # strip "- ** " prefix
          low=tolower(line)
          if (match(low, "^" k "[[:space:]]*:")) {
            v=substr(line, RLENGTH+1)                     # value after the colon
            sub(/^[[:space:]*]*/, "", v)                  # strip leading ** / spaces
            sub(/[[:space:]*]+$/, "", v)                  # strip trailing
            print v; exit
          }
        }' "$CH4_REPORT_TMP"
      }
      is_ph() { case "$1" in ""|*"<"*|*">"*) return 0;; *) return 1;; esac; }   # empty or <placeholder>
      CH4_REPO_URL=$(get4 'repo url')
      CH4_LIVE_URL=$(get4 'live[^:]*url')
      CH4_LICENSE_NAME=$(get4 'license')
      CH4_SLIDES_PATH=$(get4 'slides[[:space:]]*path')
      CH4_SUMMARY=$(get4 'one-line summary')

      # report.md must be committed BY YOU (anti-forgery: teammates can write the team repo)
      rep_author=$(gh api "repos/$GH_ORG/$CH4_TEAM_REPO/commits?path=ch-4/$CH4_DIR/report.md&per_page=1" --jq '.[0].author.login // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]')
      if [ -z "$rep_author" ]; then
        CH4_AUTHOR=ok; warn "could not verify report.md commit author (commit email not linked to a GitHub account) — instructor will check"
      elif [ "$rep_author" = "$GH_USER_LC" ]; then
        CH4_AUTHOR=ok; ok "report committed by you (@$rep_author)"
      else
        fail "report.md last committed by @$rep_author, not you (@$GH_USER) — push your own report"
      fi

      # personal repo: owner == you
      CH4_REPO=$(printf '%s' "$CH4_REPO_URL" | sed -E 's#(git@|https?://)github.com[:/]##; s/#.*$//; s/\.git$//; s#/+$##')
      if is_ph "$CH4_REPO_URL"; then
        fail "Repo URL line empty/placeholder — paste your own repo link"
      else
        repo_owner=$(gh api "repos/$CH4_REPO" --jq '.owner.login' 2>/dev/null || true)
        if [ -z "$repo_owner" ]; then
          fail "personal repo not found: ${CH4_REPO:-none} (check the Repo URL line)"
        else
          repo_owner_lc=$(printf '%s' "$repo_owner" | tr '[:upper:]' '[:lower:]')
          if [ "$repo_owner_lc" = "$GH_USER_LC" ]; then
            CH4_OWNER=ok; ok "repo: github.com/$CH4_REPO (owner @$repo_owner)"
          else
            fail "Repo URL owner @$repo_owner != you @$GH_USER — submit your own repo"
          fi

          # repo tree (LICENSE, screenshots, slides path)
          if [ "$(gh api "repos/$CH4_REPO/git/trees/HEAD?recursive=1" --jq '.truncated' 2>/dev/null)" = "true" ]; then
            warn "repo tree too large — GitHub truncated it; checks may be incomplete, instructor will verify"
          fi
          TREE_PATHS=$(gh api "repos/$CH4_REPO/git/trees/HEAD?recursive=1" --jq '.tree[]|select(.type=="blob")|.path' 2>/dev/null || true)

          # license: LICENSE file in repo root + a non-placeholder license name in report
          lic_file=$(printf '%s\n' "$TREE_PATHS" | grep -iE '^license(\.md|\.txt)?$' | head -1 || true)
          if [ -z "$lic_file" ]; then
            fail "no LICENSE file in repo root (add one — MIT is a fine default)"
          elif is_ph "$CH4_LICENSE_NAME"; then
            fail "License line in report empty/placeholder — write the license name (e.g. MIT)"
          else
            CH4_LICENSE=ok; ok "license: $CH4_LICENSE_NAME ($lic_file)"
          fi

          # screenshots: >= N markdown image links whose paths exist in the repo
          shots=$(grep -oE '!\[[^]]*\]\([^)]+\)' "$CH4_REPORT_TMP" | sed -E 's/^!\[[^]]*\]\(([^)]+)\)$/\1/' || true)
          CH4_SHOT_COUNT=0
          if [ -n "$shots" ]; then
            while IFS= read -r sp; do
              [ -z "$sp" ] && continue
              is_ph "$sp" && continue
              case "$sp" in http*://*) continue;; esac   # must live in the repo, not hotlinked
              if printf '%s\n' "$TREE_PATHS" | grep -qxF "$sp"; then
                CH4_SHOT_COUNT=$((CH4_SHOT_COUNT+1))
              else
                warn "screenshot path not in repo: $sp"
              fi
            done <<EOF4
$shots
EOF4
          fi
          if [ "$CH4_SHOT_COUNT" -ge "$CH4_MIN_SHOTS" ]; then
            CH4_SHOTS=ok; ok "screenshots: $CH4_SHOT_COUNT in repo (>= $CH4_MIN_SHOTS)"
          else
            fail "screenshots: $CH4_SHOT_COUNT in repo (need >= $CH4_MIN_SHOTS — add image files + ![](path) links)"
          fi

          # slides: product-intro slide file exists in repo (path may be a blob/raw URL)
          sp4="$CH4_SLIDES_PATH"
          case "$sp4" in
            http*://github.com/*/blob/*)         sp4="${sp4#*://github.com/*/blob/}"; sp4="${sp4#*/}" ;;
            http*://raw.githubusercontent.com/*) sp4="${sp4#*://raw.githubusercontent.com/}"; sp4="${sp4#*/}"; sp4="${sp4#*/}"; sp4="${sp4#*/}" ;;
          esac
          if is_ph "$sp4"; then
            fail "Slides path empty/placeholder — add product-intro slides (e.g. slides/intro.md)"
          elif printf '%s\n' "$TREE_PATHS" | grep -qxF "$sp4"; then
            CH4_SLIDES=ok; ok "slides: $sp4"
          else
            fail "slides not found in repo at: $sp4 (Slides path must be a repo-relative path)"
          fi
        fi
      fi

      # live / download URL present + non-placeholder (reachability is a soft check)
      if is_ph "$CH4_LIVE_URL"; then
        fail "Live / download URL empty/placeholder — ship it and paste the link"
      else
        CH4_LIVE=ok; ok "live/download url: $CH4_LIVE_URL"
        if have curl; then
          code=$(curl -A 'vibe-doctor' -m 12 -s -o /dev/null -w '%{http_code}' -L "$CH4_LIVE_URL" 2>/dev/null || true)
          case "$code" in
            2??|3??) ok "live url reachable (HTTP $code)" ;;
            000|"")  warn "live url not reachable from here (network/blocked) — instructor will open it" ;;
            *)       warn "live url returned HTTP $code — make sure it opens" ;;
          esac
        fi
      fi
    fi
  fi
fi

# ---------- 6e. chapter 5 — workflow + capability (personal project) ----------
# Submission: TEAM repo ch-5/<you>/report.md. Evidence: PERSONAL repo (a Skill +
# a Subagent), a tech-stack slide deck, and ONE feedback file (interview / feedback /
# issues). Mirrors instructor scripts/check-ch5.mjs.
CH5_MIN_SKILL_BYTES="${CH5_MIN_SKILL_BYTES:-200}"
CH5_MIN_AGENT_BYTES="${CH5_MIN_AGENT_BYTES:-100}"
CH5_REPORT=fail; CH5_AUTHOR=fail; CH5_OWNER=fail; CH5_SKILL=fail; CH5_AGENT=fail
CH5_SLIDES=fail; CH5_FEEDBACK=fail; CH5_LIVE=fail
CH5_REPO=""; CH5_REPO_URL=""; CH5_LIVE_URL=""; CH5_SLIDES_PATH=""; CH5_FEEDBACK_PATH=""
CH5_TEAM_REPO=""; CH5_DIR=""
CH5_REPORT_TMP="$OUTDIR/ch-5-report-fetched-$TS.md"
if [ "$CHAPTER" = "ch-5" ]; then
  say "Chapter 5 — workflow + capability"; hr
  if [ -z "$GH_USER" ]; then
    fail "skipping ch-5 checks — gh not authed (run: gh auth login)"
  else
    TEAM_REPOS=$(gh api --paginate "orgs/$GH_ORG/repos?per_page=100" --jq '.[].name' 2>/dev/null | grep -E '^team-[0-9]+$' || true)
    for t in $TEAM_REPOS; do
      d=$(gh api "repos/$GH_ORG/$t/contents/ch-5" --jq '.[].name' 2>/dev/null | grep -ixF "$GH_USER" | head -1 || true)
      if [ -n "$d" ] && gh api "repos/$GH_ORG/$t/contents/ch-5/$d/report.md" >/dev/null 2>&1; then
        CH5_TEAM_REPO="$t"; CH5_DIR="$d"; break
      fi
    done
    if [ -z "$CH5_TEAM_REPO" ]; then
      fail "no ch-5/$GH_USER/report.md in any team repo — copy ch-5/_TEMPLATE.md to ch-5/$GH_USER_LC/report.md, fill it, push"
    elif gh api "repos/$GH_ORG/$CH5_TEAM_REPO/contents/ch-5/$CH5_DIR/report.md" \
           -H "Accept: application/vnd.github.raw" > "$CH5_REPORT_TMP" 2>/dev/null \
         && [ -s "$CH5_REPORT_TMP" ]; then
      CH5_REPORT=ok; ok "report: $CH5_TEAM_REPO/ch-5/$CH5_DIR/report.md"
    else
      fail "could not fetch ch-5/$CH5_DIR/report.md from $CH5_TEAM_REPO"
    fi

    if [ "$CH5_REPORT" = ok ]; then
      tr -d '\r' < "$CH5_REPORT_TMP" > "$CH5_REPORT_TMP.n" && mv "$CH5_REPORT_TMP.n" "$CH5_REPORT_TMP"
      get5() {
        awk -v k="$1" '{ line=$0; sub(/^[[:space:]]*[-*[:space:]]*/,"",line); low=tolower(line)
          if (match(low,"^" k "[[:space:]]*:")) { v=substr(line,RLENGTH+1); sub(/^[[:space:]*]*/,"",v); sub(/[[:space:]*]+$/,"",v); print v; exit } }' "$CH5_REPORT_TMP"
      }
      is_ph() { case "$1" in ""|*"<"*|*">"*) return 0;; *) return 1;; esac; }
      CH5_REPO_URL=$(get5 'repo url')
      CH5_LIVE_URL=$(get5 'live[^:]*')
      CH5_SLIDES_PATH=$(get5 'slides[ \t]*path')
      CH5_FEEDBACK_PATH=$(get5 'feedback[^:]*path')

      rep_author=$(gh api "repos/$GH_ORG/$CH5_TEAM_REPO/commits?path=ch-5/$CH5_DIR/report.md&per_page=1" --jq '.[0].author.login // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]')
      if [ -z "$rep_author" ]; then CH5_AUTHOR=ok; warn "could not verify report.md commit author — instructor will check"
      elif [ "$rep_author" = "$GH_USER_LC" ]; then CH5_AUTHOR=ok; ok "report committed by you (@$rep_author)"
      else fail "report.md last committed by @$rep_author, not you (@$GH_USER) — push your own report"; fi

      # live URL carried from ch-4 — must still be present
      if is_ph "$CH5_LIVE_URL"; then fail "Live / download URL empty/placeholder in report"
      else CH5_LIVE=ok; ok "live/download url: $CH5_LIVE_URL"; fi

      CH5_REPO=$(printf '%s' "$CH5_REPO_URL" | sed -E 's#(git@|https?://)github.com[:/]##; s/#.*$//; s/\.git$//; s#/+$##')
      if is_ph "$CH5_REPO_URL"; then
        fail "Repo URL line empty/placeholder"
      else
        repo_owner=$(gh api "repos/$CH5_REPO" --jq '.owner.login' 2>/dev/null || true)
        if [ -z "$repo_owner" ]; then fail "personal repo not found: ${CH5_REPO:-none}"
        else
          repo_owner_lc=$(printf '%s' "$repo_owner" | tr '[:upper:]' '[:lower:]')
          if [ "$repo_owner_lc" = "$GH_USER_LC" ]; then CH5_OWNER=ok; ok "repo: github.com/$CH5_REPO (owner @$repo_owner)"
          else fail "Repo URL owner @$repo_owner != you @$GH_USER"; fi

          TREE=$(gh api "repos/$CH5_REPO/git/trees/HEAD?recursive=1" --jq '.tree[]|select(.type=="blob")|"\(.size)\t\(.path)"' 2>/dev/null || true)
          TREE_PATHS=$(printf '%s\n' "$TREE" | cut -f2-)

          # Skill — present + not a stub
          skill_sz=$(printf '%s\n' "$TREE" | awk -F'\t' 'tolower($2) ~ "^\\.claude/skills/[^/]+/skill\\.md$" {print $1; exit}')
          if [ -z "$skill_sz" ]; then fail "no .claude/skills/<name>/SKILL.md on your default branch (is .claude/ gitignored?)"
          elif [ "$skill_sz" -ge "$CH5_MIN_SKILL_BYTES" ]; then CH5_SKILL=ok; ok ".claude/skills SKILL.md present (${skill_sz}b)"
          else fail "SKILL.md too small (${skill_sz}b < ${CH5_MIN_SKILL_BYTES}b — stub)"; fi
          # Subagent — present + not a stub
          agent_sz=$(printf '%s\n' "$TREE" | awk -F'\t' 'tolower($2) ~ "^\\.claude/agents/[^/]+\\.md$" {print $1; exit}')
          if [ -z "$agent_sz" ]; then fail "no .claude/agents/<name>.md on your default branch (is .claude/ gitignored?)"
          elif [ "$agent_sz" -ge "$CH5_MIN_AGENT_BYTES" ]; then CH5_AGENT=ok; ok ".claude/agents agent present (${agent_sz}b)"
          else fail "agent .md too small (${agent_sz}b < ${CH5_MIN_AGENT_BYTES}b — stub)"; fi

          # tech-stack slides
          sp5="$CH5_SLIDES_PATH"
          case "$sp5" in
            http*://github.com/*/blob/*)         sp5="${sp5#*://github.com/*/blob/}"; sp5="${sp5#*/}" ;;
            http*://raw.githubusercontent.com/*) sp5="${sp5#*://raw.githubusercontent.com/}"; sp5="${sp5#*/}"; sp5="${sp5#*/}"; sp5="${sp5#*/}" ;;
          esac
          if is_ph "$sp5"; then fail "Slides path empty/placeholder — add a tech-stack deck (e.g. slides/tech-stack.md)"
          elif printf '%s\n' "$TREE_PATHS" | grep -qxF "$sp5"; then CH5_SLIDES=ok; ok "tech-stack slides: $sp5"
          else fail "slides not found in repo at: $sp5"; fi

          # feedback file (one of interview / feedback / issues) — path must exist in repo
          fp5="$CH5_FEEDBACK_PATH"
          if is_ph "$fp5"; then fail "Feedback file path empty/placeholder — pick ONE of interview/feedback/issues, fill it, link it"
          elif printf '%s\n' "$TREE_PATHS" | grep -qxF "$fp5"; then CH5_FEEDBACK=ok; ok "feedback file: $fp5"
          else fail "feedback file not found in repo at: $fp5"; fi
        fi
      fi
    fi
  fi
fi

# ---------- 6f. chapter 6 — polish + deployment (personal project) ----------
# Submission: TEAM repo ch-6/<you>/report.md. Evidence: PERSONAL repo, now polished —
# closed issues (links), LICENSE, README, analytics, >=3 updated screenshots, a public
# live URL, gallery-card slides. Mirrors instructor scripts/check-ch6.mjs.
CH6_MIN_SHOTS="${CH6_MIN_SHOTS:-3}"
CH6_REPORT=fail; CH6_AUTHOR=fail; CH6_OWNER=fail; CH6_LIVE=fail; CH6_LICENSE=fail
CH6_README=fail; CH6_SHOTS=fail; CH6_SLIDES=fail; CH6_ISSUES=fail
CH6_REPO=""; CH6_REPO_URL=""; CH6_LIVE_URL=""; CH6_LICENSE_NAME=""; CH6_SLIDES_PATH=""
CH6_ANALYTICS=""; CH6_TEAM_REPO=""; CH6_DIR=""; CH6_SHOT_COUNT=0; CH6_ISSUE_COUNT=0
CH6_REPORT_TMP="$OUTDIR/ch-6-report-fetched-$TS.md"
if [ "$CHAPTER" = "ch-6" ]; then
  say "Chapter 6 — polish + deployment"; hr
  if [ -z "$GH_USER" ]; then
    fail "skipping ch-6 checks — gh not authed (run: gh auth login)"
  else
    TEAM_REPOS=$(gh api --paginate "orgs/$GH_ORG/repos?per_page=100" --jq '.[].name' 2>/dev/null | grep -E '^team-[0-9]+$' || true)
    for t in $TEAM_REPOS; do
      d=$(gh api "repos/$GH_ORG/$t/contents/ch-6" --jq '.[].name' 2>/dev/null | grep -ixF "$GH_USER" | head -1 || true)
      if [ -n "$d" ] && gh api "repos/$GH_ORG/$t/contents/ch-6/$d/report.md" >/dev/null 2>&1; then
        CH6_TEAM_REPO="$t"; CH6_DIR="$d"; break
      fi
    done
    if [ -z "$CH6_TEAM_REPO" ]; then
      fail "no ch-6/$GH_USER/report.md in any team repo — copy ch-6/_TEMPLATE.md to ch-6/$GH_USER_LC/report.md, fill it, push"
    elif gh api "repos/$GH_ORG/$CH6_TEAM_REPO/contents/ch-6/$CH6_DIR/report.md" \
           -H "Accept: application/vnd.github.raw" > "$CH6_REPORT_TMP" 2>/dev/null \
         && [ -s "$CH6_REPORT_TMP" ]; then
      CH6_REPORT=ok; ok "report: $CH6_TEAM_REPO/ch-6/$CH6_DIR/report.md"
    else
      fail "could not fetch ch-6/$CH6_DIR/report.md from $CH6_TEAM_REPO"
    fi

    if [ "$CH6_REPORT" = ok ]; then
      tr -d '\r' < "$CH6_REPORT_TMP" > "$CH6_REPORT_TMP.n" && mv "$CH6_REPORT_TMP.n" "$CH6_REPORT_TMP"
      get6() {
        awk -v k="$1" '{ line=$0; sub(/^[[:space:]]*[-*[:space:]]*/,"",line); low=tolower(line)
          if (match(low,"^" k "[[:space:]]*:")) { v=substr(line,RLENGTH+1); sub(/^[[:space:]*]*/,"",v); sub(/[[:space:]*]+$/,"",v); print v; exit } }' "$CH6_REPORT_TMP"
      }
      is_ph() { case "$1" in ""|*"<"*|*">"*) return 0;; *) return 1;; esac; }
      CH6_REPO_URL=$(get6 'repo url')
      CH6_LIVE_URL=$(get6 'live[^:]*')
      CH6_LICENSE_NAME=$(get6 'license')
      CH6_SLIDES_PATH=$(get6 'slides[ \t]*path')
      CH6_ANALYTICS=$(get6 'analytics[^:]*')

      rep_author=$(gh api "repos/$GH_ORG/$CH6_TEAM_REPO/commits?path=ch-6/$CH6_DIR/report.md&per_page=1" --jq '.[0].author.login // ""' 2>/dev/null | tr '[:upper:]' '[:lower:]')
      if [ -z "$rep_author" ]; then CH6_AUTHOR=ok; warn "could not verify report.md commit author — instructor will check"
      elif [ "$rep_author" = "$GH_USER_LC" ]; then CH6_AUTHOR=ok; ok "report committed by you (@$rep_author)"
      else fail "report.md last committed by @$rep_author, not you (@$GH_USER) — push your own report"; fi

      # public live URL
      if is_ph "$CH6_LIVE_URL"; then fail "Live URL empty/placeholder — deploy public and paste the link"
      else
        CH6_LIVE=ok; ok "live url: $CH6_LIVE_URL"
        if have curl; then
          code=$(curl -A 'vibe-doctor' -m 12 -s -o /dev/null -w '%{http_code}' -L "$CH6_LIVE_URL" 2>/dev/null || true)
          case "$code" in 2??|3??) ok "live url reachable (HTTP $code)";; 000|"") warn "live url not reachable from here — instructor will open it";; *) warn "live url returned HTTP $code";; esac
        fi
      fi

      # issues closed — at least one GitHub issue link in the report (Ch-5 feedback → fixed)
      CH6_ISSUE_COUNT=$(grep -oiE 'https://github\.com/[^/]+/[^/]+/issues/[0-9]+' "$CH6_REPORT_TMP" | sort -u | grep -c . || true)
      if [ "${CH6_ISSUE_COUNT:-0}" -ge 1 ]; then CH6_ISSUES=ok; ok "issues closed: $CH6_ISSUE_COUNT issue link(s) in report"
      else fail "no GitHub issue links in report — close your Ch-5 issues and link them"; fi

      # analytics — soft (report field present); warn only
      if is_ph "$CH6_ANALYTICS"; then warn "Analytics line empty — add a simple analytics tool (Plausible/GoatCounter/GA) and name it"
      else ok "analytics: $CH6_ANALYTICS"; fi

      CH6_REPO=$(printf '%s' "$CH6_REPO_URL" | sed -E 's#(git@|https?://)github.com[:/]##; s/#.*$//; s/\.git$//; s#/+$##')
      if is_ph "$CH6_REPO_URL"; then
        fail "Repo URL line empty/placeholder"
      else
        repo_owner=$(gh api "repos/$CH6_REPO" --jq '.owner.login' 2>/dev/null || true)
        if [ -z "$repo_owner" ]; then fail "personal repo not found: ${CH6_REPO:-none}"
        else
          repo_owner_lc=$(printf '%s' "$repo_owner" | tr '[:upper:]' '[:lower:]')
          if [ "$repo_owner_lc" = "$GH_USER_LC" ]; then CH6_OWNER=ok; ok "repo: github.com/$CH6_REPO (owner @$repo_owner)"
          else fail "Repo URL owner @$repo_owner != you @$GH_USER"; fi

          if [ "$(gh api "repos/$CH6_REPO/git/trees/HEAD?recursive=1" --jq '.truncated' 2>/dev/null)" = "true" ]; then
            warn "repo tree too large — GitHub truncated it; checks may be incomplete"
          fi
          TREE_PATHS=$(gh api "repos/$CH6_REPO/git/trees/HEAD?recursive=1" --jq '.tree[]|select(.type=="blob")|.path' 2>/dev/null || true)

          # LICENSE
          lic_file=$(printf '%s\n' "$TREE_PATHS" | grep -iE '^license(\.md|\.txt)?$' | head -1 || true)
          if [ -z "$lic_file" ]; then fail "no LICENSE file in repo root"
          elif is_ph "$CH6_LICENSE_NAME"; then fail "License line in report empty/placeholder"
          else CH6_LICENSE=ok; ok "license: $CH6_LICENSE_NAME ($lic_file)"; fi

          # README (polished — presence + non-trivial size)
          readme_path=$(printf '%s\n' "$TREE_PATHS" | grep -iE '^readme(\.md|\.markdown|\.txt)?$' | head -1 || true)
          if [ -z "$readme_path" ]; then fail "no README in repo root"
          else
            rm_sz=$(gh api "repos/$CH6_REPO/contents/$readme_path" --jq '.size' 2>/dev/null || echo 0)
            if [ "${rm_sz:-0}" -ge 300 ]; then CH6_README=ok; ok "README present ($readme_path, ${rm_sz}b)"
            else fail "README too small (${rm_sz}b) — make it a real front door"; fi
          fi

          # updated screenshots: >= N image links existing in repo
          shots=$(grep -oE '!\[[^]]*\]\([^)]+\)' "$CH6_REPORT_TMP" | sed -E 's/^!\[[^]]*\]\(([^)]+)\)$/\1/' || true)
          CH6_SHOT_COUNT=0
          if [ -n "$shots" ]; then
            while IFS= read -r sp; do
              [ -z "$sp" ] && continue; is_ph "$sp" && continue
              case "$sp" in http*://*) continue;; esac
              printf '%s\n' "$TREE_PATHS" | grep -qxF "$sp" && CH6_SHOT_COUNT=$((CH6_SHOT_COUNT+1))
            done <<EOF6
$shots
EOF6
          fi
          if [ "$CH6_SHOT_COUNT" -ge "$CH6_MIN_SHOTS" ]; then CH6_SHOTS=ok; ok "screenshots: $CH6_SHOT_COUNT in repo (>= $CH6_MIN_SHOTS)"
          else fail "screenshots: $CH6_SHOT_COUNT in repo (need >= $CH6_MIN_SHOTS)"; fi

          # gallery-card slides
          sp6="$CH6_SLIDES_PATH"
          case "$sp6" in
            http*://github.com/*/blob/*)         sp6="${sp6#*://github.com/*/blob/}"; sp6="${sp6#*/}" ;;
            http*://raw.githubusercontent.com/*) sp6="${sp6#*://raw.githubusercontent.com/}"; sp6="${sp6#*/}"; sp6="${sp6#*/}"; sp6="${sp6#*/}" ;;
          esac
          if is_ph "$sp6"; then fail "Slides path empty/placeholder"
          elif printf '%s\n' "$TREE_PATHS" | grep -qxF "$sp6"; then CH6_SLIDES=ok; ok "slides: $sp6"
          else fail "slides not found in repo at: $sp6"; fi
        fi
      fi
    fi
  fi
fi

# ---------- 6g. chapter 7 — team demo-ready sprint ----------
# ch-7 gate = PEER FEEDBACK ONLY: >=PF_MIN issues you authored (open or closed) across OTHER team
# repos. Your own team (detected via collaborator membership) is excluded.
# Mirrors instructor scripts/check-ch7.mjs.
CH7_PEER=fail; CH7_PEER_COUNT=0; CH7_OWN=""; CH7_PEER_URLS=""; PF_MIN=3
if [ "$CHAPTER" = "ch-7" ]; then
  say "Chapter 7 — peer feedback"; hr
  if [ -z "$GH_USER" ]; then
    fail "skipping ch-7 checks — gh not authed (run: gh auth login)"
  else
    # Repo list kept in parity with roster/team-repos.tsv + channels scripts/check-ch7.mjs.
    PF_REPOS="vibe-code-tours/team-01-app vibe-code-tours/team-02-app pyone-cho/pwe vibe-code-tours/team-04-app vibe-code-tours/team-05-app vibe-code-tours/team-06-app vibecode-team7/ARGUS vibe-code-tours/team-08-app vibe-code-tours/team-09-app vibe-code-tours/team-10-app team11-hub-coder/personal-analytics SiThuTun-mdy/Dr-Note vibe-code-tours/team-13-app vibe-code-tours/team-14-app vibe-code-tours/team-15-app vibe-code-tours/team-16-app vibe-code-tours/team-17-app swan1792/Fraud_Awareness_Hub vibe-code-tours/team-19-app vibe-code-tours/team-20-app"
    for r in $PF_REPOS; do
      # own team? collaborator membership => skip. gh api exits 0 on 2xx (204=collaborator),
      # non-zero on 403/404 (no push access / not a collaborator) => counted as "other".
      if gh api "repos/$r/collaborators/$GH_USER" >/dev/null 2>&1; then
        CH7_OWN="${CH7_OWN:+$CH7_OWN }$r"; continue
      fi
      urls=$(gh api "repos/$r/issues?state=all&creator=$GH_USER&per_page=100" --jq '.[]|select(.pull_request==null)|"\(.html_url) [\(.state)]"' 2>/dev/null || true)
      [ -z "$urls" ] && continue
      n=$(printf '%s\n' "$urls" | grep -c .)
      CH7_PEER_COUNT=$((CH7_PEER_COUNT + n))
      CH7_PEER_URLS="${CH7_PEER_URLS:+$CH7_PEER_URLS
}$urls"
    done
    [ -n "$CH7_OWN" ] && ok "own team (excluded from peer count): $CH7_OWN"
    if [ "$CH7_PEER_COUNT" -ge "$PF_MIN" ]; then CH7_PEER=ok; ok "peer feedback: $CH7_PEER_COUNT issue(s) authored on other teams, open or closed (need $PF_MIN)"
    else fail "peer feedback: only $CH7_PEER_COUNT/$PF_MIN — review other teams' demos and file issues"; fi
    if [ -n "$CH7_PEER_URLS" ]; then
      say "  issues you filed:"
      printf '%s\n' "$CH7_PEER_URLS" | while IFS= read -r u; do [ -n "$u" ] && echo "    - $u"; done
    fi
  fi
fi

# ---------- 7. results JSON ----------
# ch1 block only when actually run (ch-1); keeps it off the ch-0 card
CH1_JSON=""
if [ "$CHAPTER" = "ch-1" ]; then
  CH1_JSON="  \"ch1\": { \"profile\": \"$CH1_PROFILE\", \"pr_url\": \"$CH1_PR\", \"pr_state\": \"$CH1_PR_STATE\" },
"
fi
CH2_JSON=""
if [ "$CHAPTER" = "ch-2" ]; then
  CH2_JSON="  \"ch2\": { \"proposal\": \"$CH2_PROPOSAL\", \"team_repo\": \"$CH2_TEAM_REPO\" },
"
fi
CH3_JSON=""
if [ "$CHAPTER" = "ch-3" ]; then
  CH3_JSON="  \"ch3\": { \"team_repo\": \"$CH3_TEAM_REPO\", \"repo\": \"$CH3_REPO\", \"owner\": \"$CH3_OWNER\", \"stars\": \"$CH3_STAR_COUNT\", \"min_stars\": \"$CH3_MIN_STARS\", \"mcp\": \"$CH3_MCP\", \"skill\": \"$CH3_SKILL\", \"agent\": \"$CH3_AGENT\", \"slides\": \"$CH3_SLIDES\", \"evidence\": \"$CH3_EVIDENCE\", \"methodology\": \"$CH3_METHOD\" },
"
fi
CH4_JSON=""
if [ "$CHAPTER" = "ch-4" ]; then
  CH4_JSON="  \"ch4\": { \"team_repo\": \"$CH4_TEAM_REPO\", \"repo\": \"$CH4_REPO\", \"owner\": \"$CH4_OWNER\", \"author\": \"$CH4_AUTHOR\", \"license\": \"$CH4_LICENSE\", \"live\": \"$CH4_LIVE\", \"screenshots\": \"$CH4_SHOT_COUNT\", \"min_screenshots\": \"$CH4_MIN_SHOTS\", \"shots\": \"$CH4_SHOTS\", \"slides\": \"$CH4_SLIDES\" },
"
fi
CH5_JSON=""
if [ "$CHAPTER" = "ch-5" ]; then
  CH5_JSON="  \"ch5\": { \"team_repo\": \"$CH5_TEAM_REPO\", \"repo\": \"$CH5_REPO\", \"owner\": \"$CH5_OWNER\", \"author\": \"$CH5_AUTHOR\", \"skill\": \"$CH5_SKILL\", \"agent\": \"$CH5_AGENT\", \"slides\": \"$CH5_SLIDES\", \"feedback\": \"$CH5_FEEDBACK\", \"live\": \"$CH5_LIVE\" },
"
fi
CH6_JSON=""
if [ "$CHAPTER" = "ch-6" ]; then
  CH6_JSON="  \"ch6\": { \"team_repo\": \"$CH6_TEAM_REPO\", \"repo\": \"$CH6_REPO\", \"owner\": \"$CH6_OWNER\", \"author\": \"$CH6_AUTHOR\", \"license\": \"$CH6_LICENSE\", \"readme\": \"$CH6_README\", \"screenshots\": \"$CH6_SHOT_COUNT\", \"min_screenshots\": \"$CH6_MIN_SHOTS\", \"shots\": \"$CH6_SHOTS\", \"slides\": \"$CH6_SLIDES\", \"issues\": \"$CH6_ISSUES\", \"issue_links\": \"$CH6_ISSUE_COUNT\", \"live\": \"$CH6_LIVE\" },
"
fi
CH7_JSON=""
if [ "$CHAPTER" = "ch-7" ]; then
  CH7_JSON="  \"ch7\": { \"peer\": \"$CH7_PEER\", \"peer_count\": \"$CH7_PEER_COUNT\", \"own\": \"$CH7_OWN\" },
"
fi
cat > "$JSON" <<EOF
{
  "version": "$DOCTOR_VERSION",
  "ts": "$TS",
  "chapter": "$CHAPTER",
  "platform": "$PLATFORM",
  "claude_loc": "$CLAUDE_LOC",
  "claude_choice": "$CHOICE",
  "gh_user": "$GH_USER",
  "checks": {
    "node": "$NODE_R", "npm": "$NPM_R", "python": "$PY_R",
    "git": "$GIT_R", "gh": "$GH_R", "claude": "$CL_R"
  },
  "gh": { "auth": "$GH_AUTH", "pr_probe": "$GH_PR" },
  "proxy_api": "$CL_API",
${CH1_JSON}${CH2_JSON}${CH3_JSON}${CH4_JSON}${CH5_JSON}${CH6_JSON}${CH7_JSON}  "score": "$checks_pass/$checks_total"
}
EOF
ok "results json: $JSON"

# ---------- 8. card by chapter ----------
if [ "$CHAPTER" = "ch-0" ]; then
  render_static_svg() {
    local user="${GH_USER:-anonymous}"
    local hdr_date; hdr_date="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
    local r pass_n=0 fail_n=0 bg mk
    for r in "$NODE_R" "$NPM_R" "$PY_R" "$GIT_R" "$GH_R" "$CL_R" "$GH_AUTH" "$GH_PR" "$CL_API"; do
      if [ "$r" = "ok" ]; then pass_n=$((pass_n+1)); else fail_n=$((fail_n+1)); fi
    done
    if [ "$CHAPTER" = "ch-1" ]; then
      for r in "$CH1_PROFILE" "$CH1_PR_STATE"; do
        if [ "$r" = "ok" ]; then pass_n=$((pass_n+1)); else fail_n=$((fail_n+1)); fi
      done
    fi

    # system-check pills
    local pills="" px=40 pair lbl st w
    for pair in "node:$NODE_R:64" "npm:$NPM_R:58" "python:$PY_R:84" "git:$GIT_R:56" "gh:$GH_R:52" "claude:$CL_R:84"; do
      lbl=${pair%%:*}; w=${pair##*:}; st=${pair#*:}; st=${st%%:*}
      if [ "$st" = "ok" ]; then bg="#16a34a"; mk="\xe2\x9c\x93"; else bg="#dc2626"; mk="\xe2\x9c\x97"; fi
      pills="$pills<g transform=\"translate($px,194)\"><rect width=\"$w\" height=\"26\" rx=\"13\" fill=\"$bg\"/><circle cx=\"16\" cy=\"13\" r=\"8\" fill=\"#ffffff\"/><text x=\"16\" y=\"17.5\" font-size=\"12\" text-anchor=\"middle\" fill=\"$bg\">$mk</text><text x=\"31\" y=\"17.5\" font-size=\"13\" fill=\"#ffffff\">$lbl</text></g>"
      px=$((px + w + 8))
    done

    # services rows
    local IFSO="$IFS" i nm vv
    local names="GH Auth|GH PR Probe|Proxy API" vals="$GH_AUTH|$GH_PR|$CL_API"
    IFS='|'
    # shellcheck disable=SC2206
    local -a NA=($names) VA=($vals)
    IFS="$IFSO"
    local rows="" sy=262
    for i in "${!NA[@]}"; do
      nm="${NA[$i]}"; vv="${VA[$i]}"
      if [ "$vv" = "ok" ]; then bg="#16a34a"; mk="\xe2\x9c\x93"; else bg="#dc2626"; mk="\xe2\x9c\x97"; fi
      rows="$rows<text x=\"52\" y=\"$((sy+16))\" font-size=\"15\" fill=\"#3f2a14\">$nm</text><g transform=\"translate(250,$sy)\"><rect width=\"62\" height=\"24\" rx=\"12\" fill=\"$bg\"/><circle cx=\"14\" cy=\"12\" r=\"7.5\" fill=\"#ffffff\"/><text x=\"14\" y=\"16\" font-size=\"11\" text-anchor=\"middle\" fill=\"$bg\">$mk</text><text x=\"28\" y=\"16\" font-size=\"12\" fill=\"#ffffff\">$vv</text></g>"
      sy=$((sy+30))
    done

    # chapter-1 section (ch-1 only)
    local ch1svg="" cy cn cv
    if [ "$CHAPTER" = "ch-1" ]; then
      cy=$((sy+8))
      ch1svg="<text x=\"40\" y=\"$((cy+12))\" font-size=\"13\" font-weight=\"700\" letter-spacing=\"1\" fill=\"#b45309\">CHAPTER 1</text><line x1=\"40\" y1=\"$((cy+18))\" x2=\"300\" y2=\"$((cy+18))\" stroke=\"#e6b27a\" stroke-width=\"1\"/>"
      cy=$((cy+24))
      IFS='|'; local -a CN=("Profile" "PR State") CV=("$CH1_PROFILE" "$CH1_PR_STATE"); IFS="$IFSO"
      for i in "${!CN[@]}"; do
        cn="${CN[$i]}"; cv="${CV[$i]}"
        if [ "$cv" = "ok" ]; then bg="#16a34a"; mk="\xe2\x9c\x93"; else bg="#dc2626"; mk="\xe2\x9c\x97"; fi
        ch1svg="$ch1svg<text x=\"52\" y=\"$((cy+16))\" font-size=\"15\" fill=\"#3f2a14\">$cn</text><g transform=\"translate(250,$cy)\"><rect width=\"62\" height=\"24\" rx=\"12\" fill=\"$bg\"/><circle cx=\"14\" cy=\"12\" r=\"7.5\" fill=\"#ffffff\"/><text x=\"14\" y=\"16\" font-size=\"11\" text-anchor=\"middle\" fill=\"$bg\">$mk</text><text x=\"28\" y=\"16\" font-size=\"12\" fill=\"#ffffff\">$cv</text></g>"
        cy=$((cy+28))
      done
    fi

    local ready="#d97706"
    [ "$pass_n" -gt 0 ] && [ "$fail_n" -eq 0 ] && ready="#16a34a"

    # --- resolve template: local file -> cached -> download -> embedded fallback ---
    local tpl="" cache="$OUTDIR/card-template.svg"
    if [ -f "./card-template.svg" ]; then tpl="$(cat ./card-template.svg)"
    elif [ -f "$cache" ]; then tpl="$(cat "$cache")"
    elif have curl && curl -fsSL "$TEMPLATE_URL" -o "$cache" 2>/dev/null && [ -s "$cache" ]; then tpl="$(cat "$cache")"
    fi
    if [ -z "$tpl" ]; then
      tpl="$(cat <<'TPL'
<svg xmlns="http://www.w3.org/2000/svg" width="800" height="450" viewBox="0 0 800 450" font-family="ui-monospace,SFMono-Regular,Menlo,monospace">
  <!-- Vibe Code Doctor card template. Double-underscore tokens (CHAPTER, PILLS,
       ROWS, CH1, SCORE, PASS, FAIL, READY, ...) are filled in by doctor.sh.
       Safe to redesign; keep the injection-point tokens intact. -->
  <defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fef3e2"/><stop offset="1" stop-color="#fde2c4"/></linearGradient></defs>
  <rect width="800" height="450" fill="url(#bg)"/>
  <rect x="12" y="12" width="776" height="426" fill="none" stroke="#d97706" stroke-width="3" rx="16"/>
  <rect x="34" y="26" width="60" height="26" rx="13" fill="#d97706"/>
  <text x="64" y="44" font-size="14" font-weight="700" text-anchor="middle" fill="#ffffff">__CHAPTER__</text>
  <text x="110" y="44" font-size="13" fill="#a16207">__HDR_DATE__  &#183;  __PLATFORM__  &#183;  claude:__CHOICE__</text>
  <text x="766" y="44" font-size="16" font-weight="700" text-anchor="end" fill="#9a3412">@__USER__</text>
  <text x="40" y="80" font-size="13" font-weight="700" letter-spacing="1" fill="#b45309">ENVIRONMENT</text>
  <line x1="40" y1="86" x2="300" y2="86" stroke="#e6b27a" stroke-width="1"/>
  <text x="52" y="112" font-size="15" fill="#3f2a14">Platform</text>
  <rect x="210" y="97" width="90" height="22" rx="6" fill="none" stroke="#d9a066"/><text x="222" y="112" font-size="13" fill="#7c2d12">__PLATFORM__</text>
  <text x="52" y="140" font-size="15" fill="#3f2a14">Claude Loc</text>
  <rect x="210" y="125" width="90" height="22" rx="6" fill="none" stroke="#d9a066"/><text x="222" y="140" font-size="13" fill="#7c2d12">__CLAUDE_LOC__</text>
  <text x="52" y="168" font-size="15" fill="#3f2a14">Choice</text>
  <rect x="210" y="153" width="90" height="22" rx="6" fill="none" stroke="#d9a066"/><text x="222" y="168" font-size="13" fill="#7c2d12">__CHOICE__</text>
  <text x="40" y="184" font-size="13" font-weight="700" letter-spacing="1" fill="#b45309">SYSTEM CHECKS</text>
  __PILLS__
  <text x="40" y="252" font-size="13" font-weight="700" letter-spacing="1" fill="#b45309">SERVICES</text>
  <line x1="40" y1="258" x2="300" y2="258" stroke="#e6b27a" stroke-width="1"/>
  __ROWS__
  __CH1__
  <rect x="566" y="58" width="200" height="306" rx="14" fill="#fff7ec" stroke="#e6b27a"/>
  <rect x="596" y="70" width="72" height="22" rx="11" fill="none" stroke="#d9a066"/>
  <text x="632" y="85" font-size="12" font-weight="700" letter-spacing="1" text-anchor="middle" fill="#9a3412">SCORE</text>
  <circle cx="666" cy="158" r="56" fill="none" stroke="#f0d2a8" stroke-width="10"/>
  <text x="666" y="178" font-size="58" font-weight="700" text-anchor="middle" fill="#c2410c">__SCORE__</text>
  <text x="666" y="214" font-size="13" text-anchor="middle" fill="#9a3412">checkpoints passed</text>
  <rect x="586" y="240" width="160" height="22" rx="6" fill="#fde7cf"/>
  <text x="596" y="255" font-size="13" font-weight="700" fill="#7c2d12">PASS</text>
  <text x="736" y="255" font-size="13" font-weight="700" text-anchor="end" fill="#16a34a">__PASS__</text>
  <text x="596" y="281" font-size="13" font-weight="700" fill="#7c2d12">FAIL</text>
  <text x="736" y="281" font-size="13" font-weight="700" text-anchor="end" fill="#dc2626">__FAIL__</text>
  <text x="586" y="308" font-size="11" fill="#a16207">CHAPTER</text><text x="746" y="308" font-size="11" text-anchor="end" fill="#7c2d12">__CHAPTER__</text>
  <text x="586" y="326" font-size="11" fill="#a16207">PLATFORM</text><text x="746" y="326" font-size="11" text-anchor="end" fill="#7c2d12">__PLATFORM__</text>
  <text x="586" y="344" font-size="11" fill="#a16207">CLAUDE</text><text x="746" y="344" font-size="11" text-anchor="end" fill="#7c2d12">__CLAUDE_LOC__</text>
  <rect x="320" y="418" width="170" height="22" rx="11" fill="none" stroke="__READY__"/>
  <text x="405" y="433" font-size="12" text-anchor="middle" fill="#a16207">vibecode.tours</text>
</svg>
TPL
)"
    fi

    tpl="${tpl//__CHAPTER__/$CHAPTER}"
    tpl="${tpl//__HDR_DATE__/$hdr_date}"
    tpl="${tpl//__PLATFORM__/$PLATFORM}"
    tpl="${tpl//__CLAUDE_LOC__/$CLAUDE_LOC}"
    tpl="${tpl//__CHOICE__/$CHOICE}"
    tpl="${tpl//__USER__/$user}"
    tpl="${tpl//__PILLS__/$pills}"
    tpl="${tpl//__ROWS__/$rows}"
    tpl="${tpl//__CH1__/$ch1svg}"
    tpl="${tpl//__SCORE__/$checks_pass/$checks_total}"
    tpl="${tpl//__PASS__/$pass_n}"
    tpl="${tpl//__FAIL__/$fail_n}"
    tpl="${tpl//__READY__/$ready}"
    printf '%s\n' "$tpl" > "$SVG"
  }
  say "Card"; hr
  render_static_svg; ok "static svg: $SVG"
  make_png() {
    if have rsvg-convert; then rsvg-convert "$SVG" -o "$PNG" 2>/dev/null && return 0; fi
    if have convert;       then convert "$SVG" "$PNG" 2>/dev/null && return 0; fi
    if have chromium;      then chromium --headless --no-sandbox --disable-gpu --screenshot="$PNG" --window-size=800,450 "file://$SVG" >/dev/null 2>&1 && return 0; fi
    if have google-chrome; then google-chrome --headless --no-sandbox --disable-gpu --screenshot="$PNG" --window-size=800,450 "file://$SVG" >/dev/null 2>&1 && return 0; fi
    return 1
  }
  if make_png; then ok "png: $PNG"
  else warn "no svg→png tool (install: librsvg2-bin OR imagemagick)"
  fi
  {
    echo "┌─ Vibe Code Doctor ──────────────┐"
    echo "│ user:     ${GH_USER:-anonymous}"
    echo "│ platform: $PLATFORM"
    echo "│ claude:   $CLAUDE_LOC ($CHOICE)"
    echo "│ checks:   ${NODE_R}/node ${NPM_R}/npm ${PY_R}/py ${GIT_R}/git ${GH_R}/gh ${CL_R}/claude"
    echo "│ proxy:    $CL_API"
    echo "│ score:    $checks_pass/$checks_total"
    echo "└──────────────────────────────────┘"
  } > "$TXT"
  echo
  say "Drop one of these in #ch-0-intro"; hr
  [ -f "$PNG" ] && echo "  image: $PNG"
  [ -f "$SVG" ] && echo "  svg:   $SVG  (fallback if no PNG)"
  echo "  text:  $TXT  (copy/paste fallback)"
  echo "  json:  $JSON"
  echo
  echo "  Wait for instructor ✅/👏 → ch-0-done role → #ch-1 unlocks."

else
  # any homework chapter (ch-1, ch-2, ...). Base: proxy + gh auth.
  # ch-1 also needs profile repo + website PR; others rely on mentor 👏 review.
  ch_fail=0
  [ "$PROXY_GATED" = 1 ] && [ "$CL_API" != "ok" ] && ch_fail=1
  [ "$GH_AUTH" != "ok" ] && ch_fail=1
  if [ "$CHAPTER" = "ch-1" ]; then
    [ "$CH1_PROFILE"  != "ok" ] && ch_fail=1
    [ "$CH1_PR_STATE" != "ok" ] && ch_fail=1
  fi
  if [ "$CHAPTER" = "ch-2" ]; then
    [ "$CH2_PROPOSAL" != "ok" ] && ch_fail=1
  fi
  if [ "$CHAPTER" = "ch-3" ]; then
    for v in "$CH3_REPORT" "$CH3_OWNER" "$CH3_AUTHOR" "$CH3_MCP" "$CH3_SKILL" "$CH3_AGENT" "$CH3_SLIDES" "$CH3_EVIDENCE" "$CH3_METHOD" "$CH3_STARS"; do
      [ "$v" != "ok" ] && ch_fail=1
    done
  fi
  if [ "$CHAPTER" = "ch-4" ]; then
    for v in "$CH4_REPORT" "$CH4_OWNER" "$CH4_AUTHOR" "$CH4_LICENSE" "$CH4_LIVE" "$CH4_SHOTS" "$CH4_SLIDES"; do
      [ "$v" != "ok" ] && ch_fail=1
    done
  fi
  if [ "$CHAPTER" = "ch-5" ]; then
    for v in "$CH5_REPORT" "$CH5_OWNER" "$CH5_AUTHOR" "$CH5_SKILL" "$CH5_AGENT" "$CH5_SLIDES" "$CH5_FEEDBACK" "$CH5_LIVE"; do
      [ "$v" != "ok" ] && ch_fail=1
    done
  fi
  if [ "$CHAPTER" = "ch-6" ]; then
    for v in "$CH6_REPORT" "$CH6_OWNER" "$CH6_AUTHOR" "$CH6_LICENSE" "$CH6_README" "$CH6_SHOTS" "$CH6_SLIDES" "$CH6_ISSUES" "$CH6_LIVE"; do
      [ "$v" != "ok" ] && ch_fail=1
    done
  fi
  if [ "$CHAPTER" = "ch-7" ]; then
    [ "$CH7_PEER" != "ok" ] && ch_fail=1
  fi
  {
    echo "# ${CHAPTER} check — $(date -u '+%Y-%m-%d %H:%M UTC')"
    echo
    echo "- proxy api: $CL_API"
    echo "- gh auth: $GH_AUTH ($GH_USER)"
    if [ "$CHAPTER" = "ch-1" ]; then
      echo "- profile repo: $CH1_PROFILE"
      echo "- website pr: ${CH1_PR:-none}"
    fi
    if [ "$CHAPTER" = "ch-2" ]; then
      echo "- team proposal: $CH2_PROPOSAL (${CH2_TEAM_REPO:-no-team-repo})"
    fi
    if [ "$CHAPTER" = "ch-3" ]; then
      echo "- team repo: ${CH3_TEAM_REPO:-none} (ch-3/$CH3_DIR/report.md)"
      echo "- report author: $CH3_AUTHOR"
      echo "- repo: $CH3_REPO (owner: $CH3_OWNER)"
      echo "- stars: $CH3_STAR_COUNT distinct (need >= $CH3_MIN_STARS: $CH3_STARS)"
      echo "- mcp/skill/agent: $CH3_MCP/$CH3_SKILL/$CH3_AGENT"
      echo "- slides: $CH3_SLIDES ($CH3_SLIDES_URL)"
    fi
    if [ "$CHAPTER" = "ch-4" ]; then
      echo "- team repo: ${CH4_TEAM_REPO:-none} (ch-4/$CH4_DIR/report.md)"
      echo "- report author: $CH4_AUTHOR"
      echo "- repo: $CH4_REPO (owner: $CH4_OWNER)"
      echo "- license: $CH4_LICENSE ($CH4_LICENSE_NAME)"
      echo "- live/download url: $CH4_LIVE ($CH4_LIVE_URL)"
      echo "- screenshots: $CH4_SHOT_COUNT in repo (need >= $CH4_MIN_SHOTS: $CH4_SHOTS)"
      echo "- slides: $CH4_SLIDES ($CH4_SLIDES_PATH)"
    fi
    if [ "$CHAPTER" = "ch-5" ]; then
      echo "- team repo: ${CH5_TEAM_REPO:-none} (ch-5/$CH5_DIR/report.md)"
      echo "- report author: $CH5_AUTHOR"
      echo "- repo: $CH5_REPO (owner: $CH5_OWNER)"
      echo "- skill/agent: $CH5_SKILL/$CH5_AGENT"
      echo "- tech-stack slides: $CH5_SLIDES ($CH5_SLIDES_PATH)"
      echo "- feedback file: $CH5_FEEDBACK ($CH5_FEEDBACK_PATH)"
      echo "- live/download url: $CH5_LIVE ($CH5_LIVE_URL)"
    fi
    if [ "$CHAPTER" = "ch-6" ]; then
      echo "- team repo: ${CH6_TEAM_REPO:-none} (ch-6/$CH6_DIR/report.md)"
      echo "- report author: $CH6_AUTHOR"
      echo "- repo: $CH6_REPO (owner: $CH6_OWNER)"
      echo "- license: $CH6_LICENSE ($CH6_LICENSE_NAME)"
      echo "- readme: $CH6_README"
      echo "- analytics: ${CH6_ANALYTICS:-none}"
      echo "- issues closed: $CH6_ISSUES ($CH6_ISSUE_COUNT link(s))"
      echo "- screenshots: $CH6_SHOT_COUNT in repo (need >= $CH6_MIN_SHOTS: $CH6_SHOTS)"
      echo "- slides: $CH6_SLIDES ($CH6_SLIDES_PATH)"
      echo "- live url: $CH6_LIVE ($CH6_LIVE_URL)"
    fi
    if [ "$CHAPTER" = "ch-7" ]; then
      CH7_OWN_DISP="${CH7_OWN:-none}"
      echo "- own team(s): $CH7_OWN_DISP"
      echo "- peer issues authored: $CH7_PEER_COUNT (need >= $PF_MIN: $CH7_PEER)"
      if [ -n "$CH7_PEER_URLS" ]; then
        printf '%s\n' "$CH7_PEER_URLS" | while IFS= read -r u; do [ -n "$u" ] && echo "  - $u"; done
      fi
    fi
    echo
    echo "---"
    echo "chapter: $CHAPTER"
    echo "github_username: ${GH_USER:-none}"
    [ "$CHAPTER" = "ch-1" ] && echo "website_pr: ${CH1_PR:-none}"
    if [ "$CHAPTER" = "ch-3" ]; then
      echo "personal_repo_url: $CH3_REPO_URL"
      echo "slides_url: $CH3_SLIDES_URL"
      echo "stars: $CH3_STAR_COUNT"
      echo "project_summary: $CH3_SUMMARY"
      echo
      echo "## Methodology"
      awk '/^## Methodology/{f=1;next} /^## /{f=0} f' "$CH3_REPORT_TMP"
      echo
      echo "## Evidence"
      grep -E '^- *path:' "$CH3_REPORT_TMP"
    fi
    if [ "$CHAPTER" = "ch-4" ]; then
      echo "repo_url: $CH4_REPO_URL"
      echo "live_url: $CH4_LIVE_URL"
      echo "license: $CH4_LICENSE_NAME"
      echo "slides_path: $CH4_SLIDES_PATH"
      echo "screenshots: $CH4_SHOT_COUNT"
      echo "project_summary: $CH4_SUMMARY"
    fi
    if [ "$CHAPTER" = "ch-5" ]; then
      echo "repo_url: $CH5_REPO_URL"
      echo "live_url: $CH5_LIVE_URL"
      echo "slides_path: $CH5_SLIDES_PATH"
      echo "feedback_path: $CH5_FEEDBACK_PATH"
    fi
    if [ "$CHAPTER" = "ch-6" ]; then
      echo "repo_url: $CH6_REPO_URL"
      echo "live_url: $CH6_LIVE_URL"
      echo "license: $CH6_LICENSE_NAME"
      echo "slides_path: $CH6_SLIDES_PATH"
      echo "analytics: $CH6_ANALYTICS"
      echo "issue_links: $CH6_ISSUE_COUNT"
      echo "screenshots: $CH6_SHOT_COUNT"
    fi
    echo "result: $([ "$ch_fail" -eq 0 ] && echo PASS || echo INCOMPLETE)"
  } > "$MD"
  say "${CHAPTER} report"; hr
  echo "  md: $MD"
  if [ "$ch_fail" -ne 0 ]; then
    warn "checks failed — fix the ❌ rows above and re-run. Gist not posted."
    print_debug_bundle
    exit 1
  fi
  if [ "$NO_POST" = "1" ]; then
    echo "  --no-post — skipping gist. Manual: gh gist create --public $MD"
  elif have gh && gh auth status >/dev/null 2>&1; then
    url=$(gh gist create --public -d "Vibe Code Tours — ${CHAPTER} — @$GH_USER" "$MD" 2>/dev/null | tail -1)
    if [ -n "$url" ]; then
      ok "gist posted: $url"
      echo
      say "Submit (Discord):"; hr
      echo "    Paste this gist link in #${CHAPTER} — the bot checks it, a mentor 👏 approves:"
      echo "    $url"
      echo "    (or run the /submit command and paste the link)"
    else
      warn "gist post failed. Manual: gh gist create --public $MD"
    fi
  else
    echo "  gh not authed — manual gist: gh gist create --public $MD"
  fi
fi

# ---------- 9. debug bundle + recovery on any fail ----------
echo
say "Exit codes"; hr
echo "  0 = all green    1 = hard fail (setup/homework incomplete)    2 = soft fail (proxy/API down)"
if [ "$checks_pass" != "$checks_total" ] || { [ "$PROXY_GATED" = 1 ] && [ "$CL_API" = "fail" ]; }; then
  print_debug_bundle
fi
if [ "$PROXY_GATED" = 1 ] && [ "$CL_API" = "fail" ]; then
  echo
  say "Proxy/API failed — recovery options:"; hr
  echo "  1. gemini  — free tier (gemini.google.com or 'gemini' CLI)"
  echo "  2. ollama  — offline (ollama run qwen2.5-coder:7b)"
  echo "  3. #help   — tag @instructor for manual /unlock"
  exit 2
fi

[ "$checks_pass" = "$checks_total" ] && exit 0 || exit 2
