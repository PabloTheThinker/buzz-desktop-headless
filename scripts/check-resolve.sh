#!/usr/bin/env bash
# Soft portability checks for unknown PATH layouts (no stack start).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"

echo "resolve test..."
# With no binary, may fail — OK
if BD_BUZZ_CMD=/usr/bin/buzz-desktop bd_resolve_buzz_cmd 2>/dev/null; then
  echo "resolved: $(BD_BUZZ_CMD=/usr/bin/buzz-desktop bd_resolve_buzz_cmd)"
fi
echo "ok"
