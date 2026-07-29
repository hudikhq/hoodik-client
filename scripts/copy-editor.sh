#!/bin/bash
# Copy the built editor standalone bundle from the hoodik repo into Flutter assets.
# Run this after building the editor package: cd ../hoodik/editor && yarn build
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets/editor
cp ../hoodik/editor/dist/standalone/index.html assets/editor/editor.html
echo "Copied editor.html ($(wc -c < assets/editor/editor.html) bytes)"
