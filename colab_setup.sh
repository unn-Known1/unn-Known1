#!/bin/bash
# ── Colors ───────────────────────────────────────────────────────────────────
R='\033[0m'
CYAN='\033[38;5;51m'
BLUE='\033[38;5;39m'
PURP='\033[38;5;141m'
GRN='\033[38;5;82m'
YLW='\033[38;5;220m'
GRAY='\033[38;5;240m'
WHT='\033[38;5;255m'
DIM='\033[38;5;238m'
BOLD='\033[1m'

# ── Spinner ───────────────────────────────────────────────────────────────────
spinner() {
  local pid=$1 label=$2
  local frames=('·  ' '·· ' '···' ' ··' '  ·' '   ')
  local cols=("$CYAN" "$BLUE" "$PURP" "$CYAN" "$BLUE" "$PURP")
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${cols[i]}${frames[i]}${R}  ${WHT}%-16s${R}${GRAY} installing...${R}" "$label"
    i=$(( (i+1) % ${#frames[@]} ))
    sleep 0.1
  done
  printf "\r  ${GRN}▸▸▸${R}  ${GRAY}%-16s${R}${GRN} done${R}              \n" "$label"
}

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${PURP}${BOLD}┌───────────────────────────────────┐${R}"
echo -e "  ${PURP}${BOLD}│${R}  ${CYAN}${BOLD}COLAB ENV SETUP${R}                  ${PURP}${BOLD}│${R}"
echo -e "  ${PURP}${BOLD}│${R}  ${DIM}node  npm  python  pip${R}           ${PURP}${BOLD}│${R}"
echo -e "  ${PURP}${BOLD}└───────────────────────────────────┘${R}"
echo ""
# ── Before snapshot ───────────────────────────────────────────────────────────
node_b=$(node --version 2>/dev/null || echo 'n/a')
npm_b=$(npm --version 2>/dev/null || echo 'n/a')
py_b=$(python3 --version 2>/dev/null | awk '{print $2}' || echo 'n/a')
pip_b=$(pip --version 2>/dev/null | awk '{print $2}' || echo 'n/a')

echo -e "  ${DIM}╔═══════════════════ before ═════╗${R}"
printf "  ${DIM}║${R}  ${GRAY}%-8s${R}  ${YLW}%-16s${R}${DIM}    ║${R}\n" "node"   "$node_b"
printf "  ${DIM}║${R}  ${GRAY}%-8s${R}  ${YLW}%-16s${R}${DIM}    ║${R}\n" "npm"    "$npm_b"
printf "  ${DIM}║${R}  ${GRAY}%-8s${R}  ${YLW}%-16s${R}${DIM}    ║${R}\n" "python" "$py_b"
printf "  ${DIM}║${R}  ${GRAY}%-8s${R}  ${YLW}%-16s${R}${DIM}    ║${R}\n" "pip"    "$pip_b"
echo -e "  ${DIM}╚════════════════════════════════╝${R}"
echo ""
echo -e "  ${DIM}────────────────────────────────────────${R}"

# ── Install nvm ───────────────────────────────────────────────────────────────
( bash <(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh) > /dev/null 2>&1 ) &
spinner $! "nvm"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# ── Install Node LTS ──────────────────────────────────────────────────────────
( nvm install --lts > /dev/null 2>&1 ) &
spinner $! "node LTS"
nvm use --lts > /dev/null 2>&1
nvm alias default 'lts/*' > /dev/null 2>&1

# ── Update npm ────────────────────────────────────────────────────────────────
( npm install -g npm@latest > /dev/null 2>&1 ) &
spinner $! "npm"

# ── Install opencode-ai ───────────────────────────────────────────────────────
( npm install -g opencode-ai > /dev/null 2>&1 ) &
spinner $! "opencode-ai"

# ── Update pip ────────────────────────────────────────────────────────────────
( pip install -q --upgrade pip setuptools wheel > /dev/null 2>&1 ) &
spinner $! "pip + tools"

echo -e "  ${DIM}────────────────────────────────────────${R}"
echo ""

# ── After snapshot ────────────────────────────────────────────────────────────
node_a=$(node --version 2>/dev/null || echo 'n/a')
npm_a=$(npm --version 2>/dev/null || echo 'n/a')
py_a=$(python3 --version 2>/dev/null | awk '{print $2}' || echo 'n/a')
pip_a=$(pip --version 2>/dev/null | awk '{print $2}' || echo 'n/a')
oai_a=$(opencode --version 2>/dev/null || echo 'n/a')

echo -e "  ${CYAN}╔═══════════════════ after  ═════╗${R}"
printf "  ${CYAN}║${R}  ${GRAY}%-10s${R}  ${GRN}%-16s${R}${CYAN}  ║${R}\n" "node"       "$node_a"
printf "  ${CYAN}║${R}  ${GRAY}%-10s${R}  ${GRN}%-16s${R}${CYAN}  ║${R}\n" "npm"        "$npm_a"
printf "  ${CYAN}║${R}  ${GRAY}%-10s${R}  ${GRN}%-16s${R}${CYAN}  ║${R}\n" "python"     "$py_a"
printf "  ${CYAN}║${R}  ${GRAY}%-10s${R}  ${GRN}%-16s${R}${CYAN}  ║${R}\n" "pip"        "$pip_a"
printf "  ${CYAN}║${R}  ${GRAY}%-10s${R}  ${GRN}%-16s${R}${CYAN}  ║${R}\n" "opencode"   "$oai_a"
echo -e "  ${CYAN}╚════════════════════════════════╝${R}"
echo ""

# ── Optional: webtun ─────────────────────────────────────────────────────────
echo -e "  ${PURP}◈${R}  ${WHT}${BOLD}Optional:${R}  ${GRAY}install webtun tunnel?${R}"
echo -e "  ${DIM}  run this to install:${R}"
echo ""
echo -e "  ${YLW}  bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/unn-Known1/webtun/main/install.sh)\"${R}"
echo ""
printf "  ${WHT}Install webtun now? [y/N]:${R} "
read -r webtun_ans < /dev/tty
if [[ "$webtun_ans" =~ ^[Yy]$ ]]; then
  echo ""
  ( bash -c "$(curl -fsSL https://raw.githubusercontent.com/unn-Known1/webtun/main/install.sh)" > /dev/null 2>&1 ) &
  spinner $! "webtun"
else
  echo -e "\n  ${GRAY}skipped webtun.${R}"
fi

echo ""
echo -e "  ${PURP}◈${R}  ${GRAY}${BOLD}ready.${R}"
echo ""
