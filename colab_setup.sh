#!/bin/bash
# ── Colors — theme-safe (Colab light & dark) ─────────────────────────────────
R='\033[0m'
BOLD='\033[1m'
CYAN='\033[38;5;38m'
PURP='\033[38;5;135m'
GRN='\033[38;5;70m'
YLW='\033[38;5;178m'
GRAY='\033[38;5;243m'
RED=$'\033[0;31m'

TOTAL=6
DONE=0

# ── Step counter renderer ─────────────────────────────────────────────────────
bar_line() {
  local label="$1" state="$2" tick="${3:-0}"
  if [[ "$state" == "done" ]]; then
    printf "  ${GRN}✓${R}  ${GRAY}%d/%d${R}  %-18s  ${GRN}done${R}\n" "$DONE" "$TOTAL" "$label"
  elif [[ "$state" == "failed" ]]; then
    printf "  ${RED}✗${R}  ${GRAY}%d/%d${R}  %-18s  ${RED}failed${R}\n" "$DONE" "$TOTAL" "$label"
  else
    local sp=('·  ' '·· ' '···' ' ··' ' · ' '   ')
    printf "\r  ${CYAN}${sp[$((tick%6))]}${R}  ${GRAY}%d/%d${R}  %-18s" \
      "$DONE" "$TOTAL" "$label"
  fi
}

# ── Run a step with animated bar ─────────────────────────────────────────────
FAILED=0
_LOG_DIR=$(mktemp -d)
trap 'rm -rf "$_LOG_DIR"' EXIT

run_step() {
  local label="$1"; shift
  local tick=0
  local log="$_LOG_DIR/$(echo "$label" | tr ' /' '__').log"

  bar_line "$label" running 0
  ("$@" >"$log" 2>&1) &
  local pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    bar_line "$label" running $(( tick % 6 ))
    tick=$(( tick + 1 ))
    sleep 0.1
  done

  wait "$pid"
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    DONE=$(( DONE + 1 ))
    bar_line "$label" done
  else
    FAILED=$(( FAILED + 1 ))
    bar_line "$label" failed
    if [[ -s "$log" ]]; then
      while IFS= read -r line; do
        printf "      ${RED}%s${R}\n" "$line"
      done < "$log"
    fi
  fi

  return $exit_code
}

# ── nvm install wrapper ───────────────────────────────────────────────────────
_install_nvm() {
  bash <(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh);
}

# ── webtun: clone + deps + server + tunnel → capture URL ─────────────────────
run_webtun() {
  local PORT=3000
  local DIR="$HOME/webtun"
  local CF_LOG="/tmp/cf_tunnel.log"
  local tick=0

  bar_line "webtun install" running 0

  # ── Phase 1: clone + npm install + cloudflared ──────────────────────────────
  (
    # Clone or update
    if [ -d "$DIR" ]; then
      git -C "$DIR" pull -q 2>/dev/null || true
    else
      git clone -q https://github.com/unn-Known1/webtun.git "$DIR" 2>/dev/null
    fi

    # Write .env — bypasses all interactive prompts in setup.sh
    cat > "$DIR/.env" << EOFPORT
PORT=$PORT
HOST=0.0.0.0
PIN=
EOFPORT

    # npm deps — fully silent (suppress postinstall, funding, audit logs)
    cd "$DIR"
    npm install --silent --unsafe-perm --omit=optional 2>/dev/null

    # cloudflared
    if ! command -v cloudflared &>/dev/null; then
      curl -fsSL \
        "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" \
        -o /tmp/cloudflared 2>/dev/null
      chmod +x /tmp/cloudflared
      sudo mv /tmp/cloudflared /usr/local/bin/cloudflared 2>/dev/null \
        || mv /tmp/cloudflared "$HOME/.local/bin/cloudflared" 2>/dev/null || true
    fi
  ) &
  local pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    bar_line "webtun install" running $tick
    tick=$(( tick + 1 ))
    sleep 0.1
  done
  bar_line "webtun install" done
  DONE=$(( DONE + 1 ))

  # ── Phase 2: start server ───────────────────────────────────────────────────
  pkill -f "node.*server.js" 2>/dev/null || true
  sleep 0.3
  cd "$DIR"
  nohup node "$DIR/server.js" > "$DIR/webterm.log" 2>&1 &

  # Wait for server ready (up to 10s)
  for i in {1..20}; do
    sleep 0.5
    curl -sf "http://localhost:$PORT/api/auth/required" &>/dev/null && break
  done

  # ── Phase 3: start tunnel + capture URL ────────────────────────────────────
  pkill -f "cloudflared tunnel" 2>/dev/null || true
  sleep 0.3
  rm -f "$CF_LOG"
  cloudflared tunnel --url "http://localhost:$PORT" > "$CF_LOG" 2>&1 &

  # Animate while waiting for URL (up to 40s)
  local URL=""
  tick=0
  printf "  ${CYAN}[${R}${GRAY}waiting for tunnel url${R}${CYAN}]${R}\n"
  for i in {1..40}; do
    sleep 1
    URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$CF_LOG" 2>/dev/null | head -1)
    [ -n "$URL" ] && break
    printf "\r  ${CYAN}·${R}  ${GRAY}tunnel starting%-*s${R}" $(( i % 4 )) "..."
  done

  # Print result
  printf "\r%-60s\r" " "  # clear line
  if [ -n "$URL" ]; then
    printf "  ${GRN}✓${R}  ${GRAY}%d/%d${R}  %-18s  ${GRN}${BOLD}%s${R}\n" "$DONE" "$TOTAL" "tunnel" "$URL"
  else
    printf "  ${YLW}⚠${R}  ${GRAY}%d/%d${R}  %-18s  URL not found — check ${R}${CYAN}$CF_LOG${R}\n" "$DONE" "$TOTAL" "tunnel"
  fi
}

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${PURP}${BOLD}┌──────────────────────────────────────────┐${R}"
echo -e "  ${PURP}${BOLD}│${R}  ${CYAN}${BOLD}COLAB ENV SETUP${R}                           ${PURP}${BOLD}│${R}"
echo -e "  ${PURP}${BOLD}│${R}  ${GRAY}nvm · node · npm · opencode · webtun${R}      ${PURP}${BOLD}│${R}"
echo -e "  ${PURP}${BOLD}└──────────────────────────────────────────┘${R}"
echo ""

# ── Before snapshot ───────────────────────────────────────────────────────────
node_b=$(node --version  2>/dev/null || echo 'n/a')
npm_b=$(npm --version    2>/dev/null || echo 'n/a')
py_b=$(python3 --version 2>/dev/null | awk '{print $2}' || echo 'n/a')
pip_b=$(pip --version    2>/dev/null | awk '{print $2}' || echo 'n/a')

echo -e "  ${GRAY}before${R}"
printf   "  ${GRAY}  node   %-12s npm    %-12s${R}\n" "$node_b" "$npm_b"
printf   "  ${GRAY}  python %-12s pip    %-12s${R}\n" "$py_b"   "$pip_b"
echo ""
echo -e  "  ${GRAY}────────────────────────────────────────${R}"
echo ""

# ── Installs ──────────────────────────────────────────────────────────────────
run_step "nvm"         _install_nvm

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

run_step "node LTS"    nvm install --lts
nvm use --lts >/dev/null 2>&1
nvm alias default 'lts/*' >/dev/null 2>&1

run_step "npm"         npm install -g npm@latest
run_step "opencode-ai" npm install -g opencode-ai
run_step "pip + tools" pip install -q --upgrade pip setuptools wheel

echo ""
echo -e  "  ${GRAY}────────────────────────────────────────${R}"
echo ""

run_webtun

echo ""
echo -e  "  ${GRAY}────────────────────────────────────────${R}"
echo ""

# ── After snapshot ───────────────────────────────────────────────────────────
node_a=$(node --version   2>/dev/null || echo 'n/a')
npm_a=$(npm --version     2>/dev/null || echo 'n/a')
py_a=$(python3 --version  2>/dev/null | awk '{print $2}' || echo 'n/a')
pip_a=$(pip --version     2>/dev/null | awk '{print $2}' || echo 'n/a')
oai_a=$(opencode --version 2>/dev/null || echo 'n/a')

echo -e "  ${CYAN}after${R}"
printf   "  ${GRAY}  node   ${R}${GRN}%-12s${R}${GRAY} npm    ${R}${GRN}%-12s${R}\n" "$node_a" "$npm_a"
printf   "  ${GRAY}  python ${R}${GRN}%-12s${R}${GRAY} pip    ${R}${GRN}%-12s${R}\n" "$py_a"   "$pip_a"
printf   "  ${GRAY}  opencode${R} ${GRN}%-12s${R}\n"                                 "$oai_a"
echo ""
echo -e  "  ${PURP}◈${R}  ${BOLD}ready.${R}"
echo ""
