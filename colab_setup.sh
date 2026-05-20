#!/bin/bash
# ── Colors — theme-safe (Colab light & dark) ─────────────────────────────────
R='\033[0m'
BOLD='\033[1m'
CYAN='\033[38;5;38m'
PURP='\033[38;5;135m'
GRN='\033[38;5;70m'
YLW='\033[38;5;178m'
GRAY='\033[38;5;243m'

TOTAL=6
DONE=0

# ── Run a step — synchronous, one line output ─────────────────────────────────
run_step() {
  local label="$1"; shift
  "$@" >/dev/null 2>&1
  DONE=$(( DONE + 1 ))
  printf "  ${GRN}✓${R}  ${GRAY}%d/%d${R}  %-18s  ${GRN}done${R}\n" "$DONE" "$TOTAL" "$label"
}

# ── nvm wrapper ───────────────────────────────────────────────────────────────
_install_nvm() { bash <(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh); }

# ── webtun: clone + deps + server + tunnel → print URL ───────────────────────
run_webtun() {
  local PORT=3000
  local DIR="$HOME/webtun"
  local CF_LOG="/tmp/cf_tunnel.log"

  printf "  ${GRAY}·  %d/%d${R}  %-18s  ${GRAY}installing...${R}\n" "$DONE" "$TOTAL" "webtun"

  # Clone or update
  if [ -d "$DIR" ]; then
    git -C "$DIR" pull -q 2>/dev/null || true
  else
    git clone -q https://github.com/unn-Known1/webtun.git "$DIR" 2>/dev/null
  fi

  # Write .env — skips all interactive prompts
  printf "PORT=%s\nHOST=0.0.0.0\nPIN=\n" "$PORT" > "$DIR/.env"

  # npm install — fully suppressed
  cd "$DIR"
  npm install --loglevel=silent >/dev/null 2>&1 || true

  # cloudflared
  if ! command -v cloudflared &>/dev/null; then
    curl -fsSL \
      "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" \
      -o /tmp/cloudflared 2>/dev/null
    chmod +x /tmp/cloudflared
    sudo mv /tmp/cloudflared /usr/local/bin/cloudflared 2>/dev/null || \
      mv /tmp/cloudflared "$HOME/.local/bin/cloudflared" 2>/dev/null || true
  fi

  DONE=$(( DONE + 1 ))
  printf "  ${GRN}✓${R}  ${GRAY}%d/%d${R}  %-18s  ${GRN}done${R}\n" "$DONE" "$TOTAL" "webtun"

  # Start server
  pkill -f "node.*server.js" 2>/dev/null || true
  sleep 0.3
  nohup node "$DIR/server.js" > "$DIR/webterm.log" 2>&1 &
  echo $! > "$DIR/webterm.pid"

  # Wait for server ready (up to 10s)
  for i in {1..20}; do
    sleep 0.5
    curl -sf "http://localhost:$PORT/api/auth/required" &>/dev/null && break
  done

  # Start tunnel
  pkill -f "cloudflared tunnel" 2>/dev/null || true
  sleep 0.3
  rm -f "$CF_LOG"
  cloudflared tunnel --url "http://localhost:$PORT" > "$CF_LOG" 2>&1 &
  echo $! > "$DIR/tunnel.pid"

  # Wait for URL (up to 40s)
  printf "  ${GRAY}·  %d/%d  %-18s  starting...${R}\n" "$DONE" "$TOTAL" "tunnel"
  local URL=""
  for i in {1..40}; do
    sleep 1
    URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$CF_LOG" 2>/dev/null | head -1)
    [ -n "$URL" ] && break
  done

  if [ -n "$URL" ]; then
    printf "  ${GRN}✓  %d/%d  %-18s  ${BOLD}%s${R}\n" "$DONE" "$TOTAL" "tunnel" "$URL"
  else
    printf "  ${YLW}⚠  %d/%d  %-18s  URL not found — check %s${R}\n" "$DONE" "$TOTAL" "tunnel" "$CF_LOG"
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
# ensure opencode is reachable regardless of nvm path state
OPENCODE_BIN=$(find "$NVM_DIR" -name "opencode" -type f 2>/dev/null | head -1)
if [ -n "$OPENCODE_BIN" ]; then
  ln -sf "$OPENCODE_BIN" /usr/local/bin/opencode 2>/dev/null ||   ln -sf "$OPENCODE_BIN" "$HOME/.local/bin/opencode" 2>/dev/null || true
fi
run_step "pip + tools" pip install -q --upgrade pip setuptools wheel

echo ""
run_webtun

echo ""
echo -e  "  ${GRAY}────────────────────────────────────────${R}"
echo ""

# ── After snapshot ────────────────────────────────────────────────────────────
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
