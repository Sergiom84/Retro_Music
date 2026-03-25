#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen not found. Install with: brew install xcodegen"
  exit 1
fi

xcodegen generate
echo "Generated: ${ROOT_DIR}/RetroMusic.xcodeproj"
