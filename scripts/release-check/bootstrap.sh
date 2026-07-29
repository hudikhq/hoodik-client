#!/usr/bin/env bash
# Usage: scripts/release-check/bootstrap.sh
#
# Self-contained Playwright-based bootstrap for the Patrol E2E suite.
#
# 1. Ensures the Playwright dependency tree is installed under
#    scripts/release-check/bootstrap/node_modules. First run downloads
#    Playwright + the bundled Chromium (~250MB); subsequent runs are instant.
# 2. Drives the hoodik web /auth/register form to seed the deterministic E2E
#    user (e2e@hoodik.local / e2e-user-password-1234) on the ephemeral hoodik
#    server that scripts/release-check/docker-hoodik-up.sh booted.
#
# Idempotent: re-running against a server that already has the user is a no-op.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOT_DIR="$SCRIPT_DIR/bootstrap"

command -v node >/dev/null 2>&1 || {
  echo "[bootstrap] FAIL: node not on PATH — install via brew install node" >&2
  exit 1
}

# Playwright 1.49 needs Node >=18. macOS systems and older nvm defaults often
# pin to 16. Try sourcing nvm to switch to a compatible version transparently
# rather than making the dev hand-fiddle every time.
node_major() { node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0; }
if [[ "$(node_major)" -lt 18 ]]; then
  if [[ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]]; then
    # shellcheck source=/dev/null
    . "${NVM_DIR:-$HOME/.nvm}/nvm.sh"
    # `nvm version <major>` resolves to the installed patch version (or "N/A").
    # Try newest first so the dev gets the most modern available toolchain.
    for major in 24 22 20 18; do
      v=$(nvm version "$major" 2>/dev/null || true)
      if [[ -n "$v" && "$v" != "N/A" ]]; then
        nvm use "$v" >/dev/null
        break
      fi
    done
    # Still nothing usable installed? Fall back to one-time LTS install.
    if [[ "$(node_major)" -lt 18 ]]; then
      echo "[bootstrap] no Node >=18 installed in nvm — installing LTS…" >&2
      nvm install --lts >/dev/null
      nvm use --lts >/dev/null
    fi
  fi
fi
if [[ "$(node_major)" -lt 18 ]]; then
  echo "[bootstrap] FAIL: Playwright requires Node >=18, found $(node --version)" >&2
  echo "  install via:  nvm install --lts && nvm use --lts" >&2
  exit 1
fi

command -v npm >/dev/null 2>&1 || {
  echo "[bootstrap] FAIL: npm not on PATH — install via brew install node" >&2
  exit 1
}

# One-time install: node_modules + Chromium browser. The marker file makes
# re-runs a single stat() instead of a multi-second npm cache check.
SENTINEL="$BOOT_DIR/.ready"
if [[ ! -f "$SENTINEL" ]]; then
  echo "[bootstrap] installing Playwright (one-time, ~250MB)"
  pushd "$BOOT_DIR" >/dev/null
  npm install --silent --no-audit --no-fund
  npx --yes playwright install --with-deps chromium >/dev/null 2>&1 \
    || npx --yes playwright install chromium
  popd >/dev/null
  touch "$SENTINEL"
fi

cd "$BOOT_DIR" && node register-user.cjs
