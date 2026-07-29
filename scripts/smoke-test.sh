#!/usr/bin/env bash
# Offline unit checks (no root). Buzz Desktop binary optional unless BD_SMOKE_REQUIRE_BUZZ=1.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"

pass=0; bad=0
ok() { echo "PASS  $*"; pass=$((pass+1)); }
fail() { echo "FAIL  $*"; bad=$((bad+1)); }

if [[ -x "$ROOT/bin/buzz-desktop-headless" ]]; then ok "cli executable"; else fail "cli not executable"; fi

if bd_resolve_novnc_web >/dev/null 2>&1; then
  ok "novnc web: $(bd_resolve_novnc_web)"
else
  fail "novnc web root not found"
fi

if bd_resolve_websockify >/dev/null 2>&1; then
  ok "websockify: $(bd_resolve_websockify)"
else
  fail "websockify missing"
fi

if bd_resolve_wm >/dev/null 2>&1; then
  ok "wm: $(bd_resolve_wm)"
else
  fail "window manager missing"
fi

export BD_BIND=127.0.0.1
if bd_is_loopback_bind; then ok "loopback 127.0.0.1"; else fail "loopback detect"; fi
export BD_BIND=0.0.0.0
if bd_is_loopback_bind; then fail "0.0.0.0 should not be loopback"; else ok "non-loopback 0.0.0.0"; fi

hints="$(bd_package_hints)"
[[ -n "$hints" ]] && ok "package hints non-empty" || fail "package hints empty"

if bd_have buzz-desktop || bd_have /usr/bin/buzz-desktop; then
  if PATH="/usr/bin:$PATH" bd_doctor >/dev/null 2>&1; then
    ok "doctor with buzz-desktop"
  else
    fail "doctor failed with buzz-desktop present"
  fi
elif [[ "${BD_SMOKE_REQUIRE_BUZZ:-0}" == "1" ]]; then
  fail "buzz-desktop required (BD_SMOKE_REQUIRE_BUZZ=1)"
else
  ok "doctor skipped (buzz-desktop not on PATH — OK for shell-only CI)"
fi

BD_STATE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/bd-smoke-XXXXXX")"
mkdir -p "$BD_STATE_DIR/run"
if bd_export_display && [[ -f "$BD_STATE_DIR/run/env.sh" ]]; then
  ok "export display env.sh"
else
  fail "export display"
fi
rm -rf "$BD_STATE_DIR"

echo "--- $pass passed, $bad failed ---"
[[ "$bad" -eq 0 ]]
