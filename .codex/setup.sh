#!/usr/bin/env bash
set -euo pipefail

# Pipe App Codex cloud bootstrap.
# Run this as the Codex Environment setup script while network access is available.

FLUTTER_VERSION="3.44.6"
FIREBASE_TOOLS_VERSION="15.25.0"
FLUTTER_HOME="${HOME}/.local/flutter-${FLUTTER_VERSION}"

mkdir -p "${HOME}/.local"

if [[ ! -x "${FLUTTER_HOME}/bin/flutter" ]]; then
  git clone \
    --depth 1 \
    --branch "${FLUTTER_VERSION}" \
    https://github.com/flutter/flutter.git \
    "${FLUTTER_HOME}"
fi

export PATH="${FLUTTER_HOME}/bin:${PATH}"

echo "export PATH=\"${FLUTTER_HOME}/bin:\$PATH\"" >> "${HOME}/.bashrc"

flutter config --no-analytics
flutter precache --web
flutter --version

# Prefer the repository's release runtime when nvm is available in the image.
if [[ -s "${HOME}/.nvm/nvm.sh" ]]; then
  # shellcheck disable=SC1090
  source "${HOME}/.nvm/nvm.sh"
  nvm install 22
  nvm use 22
fi

node --version
npm --version

npm install --global "firebase-tools@${FIREBASE_TOOLS_VERSION}"
firebase --version

flutter pub get
npm ci --prefix firebase/functions
npm ci --prefix firebase/agent-functions
npm ci --prefix firebase/rules-tests

# Codex should test against Firebase emulators by default. Do not authenticate
# this environment to production Firebase and do not place production secrets here.
echo "Pipe App Codex environment ready. Use Firebase emulators for development; use GitHub Actions for controlled live deployment."
