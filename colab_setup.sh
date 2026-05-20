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

# ── Progress bar renderer ─────────────────────────────────────────────────────
bar_line() {
  local label="$1" state="$2" tick="${3:-0}"
  local W=24 bar="" i
  local filled=$(( DONE * W / TOTAL ))
  local empty=$(( W - filled ))
  for ((i=0; i<filled; i++)); do bar+="▓"; done
  for ((i=0; i<empty;  i++)); do bar+="░"; done
  if [[ "$state" == "done" ]]; then
    printf "  ${GRN}✓${R}  ${GRAY}%-14s${R}  ${GRN}done${R}\n" "$label"
  else
    local sp=('·  ' '·· ' '···' ' ··' '  ·' '   ')
    printf "\r  ${CYAN}[${bar}]${R}  ${GRAY}%d/%d${R}  ${CYAN}${sp[$((tick%6))]}${R}  %-14s" \
           "$DONE" "$TOTAL" "$label"
  fi
}

# ── Run a step with animated bar ─────────────────────────────────────────────
run_step() {
  local label="$1"; shift
  local tick=0
  bar_line "$label" running 0
  ("$@" >/dev/null 2>&1) &
  local pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    bar_line "$label" running $tick
    tick=$(( tick + 1 ))
    sleep 0.1
  done
  DONE=$(( DONE + 1 ))
  bar_line "$label" done
}

# ── Wrappers for process-substitution installs ───────────────────────────────
_install_nvm()    { bash <(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh); }
_install_webtun() { bash -c "$(curl -fsSL https://raw.githubusercontent.com/unn-Known1/webtun/main/install.sh)"; }

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${PURP}${BOLD}┌──────────────────────────────────────────┐${R}"
echo -e "  ${PURP}${BOLD}│${R}  ${CYAN}${BOLD}COLAB ENV SETUP${R}                           ${PURP}${BOLD}│${R}"
echo -e "  ${PURP}${BOLD}│${R}  ${GRAY}nvm · node · npm · opencode · webtun${R}      ${PURP}${BOLD}│${R}"
echo -e "  ${PURP}${BOLD}└──────────────────────────────────────────┘${R}"
echo ""

# ── Before snapshot ───────────────────────────────────────────────────────────
node_b=$(node --version   2>/dev/null || echo 'n/a')
npm_b=$(npm --version     2>/dev/null || echo 'n/a')
py_b=$(python3 --version  2>/dev/null | awk '{print $2}' || echo 'n/a')
pip_b=$(pip --version     2>/dev/null | awk '{print $2}' || echo 'n/a')

echo -e "  ${GRAY}before${R}"
printf   "  ${GRAY}  node   %-12s npm    %-12s${R}\n" "$node_b" "$npm_b"
printf   "  ${GRAY}  python %-12s pip    %-12s${R}\n" "$py_b"   "$pip_b"
echo ""
echo -e  "  ${GRAY}────────────────────────────────────────${R}"
echo ""

# ── Installs ──────────────────────────────────────────────────────────────────
run_step "nvm"          _install_nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

run_step "node LTS"     nvm install --lts
nvm use --lts >/dev/null 2>&1
nvm alias default 'lts/*' >/dev/null 2>&1

run_step "npm"          npm install -g npm@latest
run_step "opencode-ai"  npm install -g opencode-ai
run_step "pip + tools"  pip install -q --upgrade pip setuptools wheel
run_step "webtun"       _install_webtun

echo ""
echo -e "  ${GRAY}────────────────────────────────────────${R}"
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
printf   "  ${GRAY}  opencode ${R}${GRN}%-12s${R}\n"                                 "$oai_a"
echo ""
echo -e  "  ${PURP}◈${R}  ${BOLD}ready.${R}"
echo ""
