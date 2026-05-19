#!/bin/bash

set -e



echo "==> Updating Node via nvm..."

curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash

export NVM_DIR="$HOME/.nvm"

source "$NVM_DIR/nvm.sh"

nvm install --lts --silent

nvm use --lts

nvm alias default 'lts/*'



echo "==> Updating pip & Python tools..."

pip install -q --upgrade pip setuptools wheel



echo "==> Updating npm..."

npm install -g npm@latest --silent



echo ""

echo "✅ Done!"

python3 --version

node --version

npm --version

npx --version

pip --version
