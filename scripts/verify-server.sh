#!/usr/bin/env bash
# Verify buzz-desktop-headless is usable on a generic Linux server.
# Offline by default. Set BD_FUNCTIONAL=1 to start/stop the full stack
# (requires Desktop binary + Xvfb stack packages).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:/usr/bin:/usr/local/bin:${PATH:-}"
CLI="$ROOT/bin/buzz-desktop-headless"

pass=0 fail=0
ok()  { echo "PASS  $*"; pass=$((pass+1)); }
bad() { echo "FAIL  $*"; fail=$((fail+1)); }

echo "== buzz-desktop-headless server verify =="
echo "host=$(uname -srm) user=$(id -un) root=$ROOT"

# 1) offline smoke (subprocess — isolated)
if bash "$ROOT/scripts/smoke-test.sh"; then
  ok "offline smoke"
else
  bad "offline smoke"
fi

# 2) CLI surface
if "$CLI" version 2>/dev/null | grep -q 'buzz-desktop-headless'; then
  ok "version"
else
  bad "version"
fi

if "$CLI" help >/dev/null 2>&1; then
  ok "help"
else
  bad "help"
fi

doctor_out="$("$CLI" doctor 2>&1 || true)"
if printf '%s\n' "$doctor_out" | grep -q 'plan display='; then
  ok "doctor plan line"
else
  bad "doctor plan line"
  printf '%s\n' "$doctor_out" | tail -20
fi

# 3) functional stack (optional)
if [[ "${BD_FUNCTIONAL:-0}" == "1" ]]; then
  # isolate state so we don't stomp a running personal stack
  VERIFY_STATE="$(mktemp -d "${TMPDIR:-/tmp}/bd-verify-XXXXXX")"
  export BD_STATE_DIR="$VERIFY_STATE"
  export BD_DISPLAY="${BD_DISPLAY:-111}"
  export BD_VNC_PORT="${BD_VNC_PORT:-5921}"
  export BD_NOVNC_PORT="${BD_NOVNC_PORT:-6190}"
  export BD_BIND=127.0.0.1
  export BD_BUZZ_CMD="${BD_BUZZ_CMD:-/usr/bin/buzz-desktop}"
  if [[ ! -x "$BD_BUZZ_CMD" ]]; then
    if command -v buzz-desktop >/dev/null 2>&1; then
      BD_BUZZ_CMD="$(command -v buzz-desktop)"
    else
      bad "functional requested but buzz-desktop not installed"
      echo "--- $pass passed, $fail failed ---"
      exit 1
    fi
  fi
  echo "functional display=:$BD_DISPLAY vnc=$BD_VNC_PORT novnc=$BD_NOVNC_PORT bin=$BD_BUZZ_CMD state=$BD_STATE_DIR"

  "$CLI" stop >/dev/null 2>&1 || true
  if "$CLI" start; then
    ok "start"
  else
    bad "start"
  fi

  # brief settle for websockify bind
  sleep 1

  status_out="$("$CLI" status 2>&1 || true)"
  printf '%s\n' "$status_out" | sed -n '1,20p'

  if printf '%s\n' "$status_out" | grep -qE '^UP[[:space:]]+xvfb'; then
    ok "status xvfb"
  else
    bad "status xvfb"
  fi
  if printf '%s\n' "$status_out" | grep -qE '^UP[[:space:]]+(desktop|buzz-desktop)'; then
    ok "status desktop"
  else
    bad "status desktop"
  fi

  code="$(curl -sS -m 5 -o /dev/null -w '%{http_code}' "http://127.0.0.1:${BD_NOVNC_PORT}/vnc.html" || echo 000)"
  if [[ "$code" == "200" ]]; then
    ok "noVNC HTTP $code"
  else
    bad "noVNC HTTP $code"
    tail -30 "$BD_STATE_DIR/logs/novnc.log" 2>/dev/null || true
  fi

  shot="$BD_STATE_DIR/verify-shot.png"
  if "$CLI" screenshot "$shot" && [[ -s "$shot" ]]; then
    ok "screenshot ($(wc -c <"$shot") bytes)"
  else
    bad "screenshot"
  fi

  if "$CLI" stop; then
    ok "stop"
  else
    bad "stop"
  fi

  sleep 0.5
  if ss -tln 2>/dev/null | grep -qE ":${BD_NOVNC_PORT}\\b"; then
    bad "novnc still listening after stop"
  else
    ok "novnc released"
  fi

  rm -rf "$VERIFY_STATE" 2>/dev/null || true
else
  echo "SKIP  functional stack (set BD_FUNCTIONAL=1 to run start/stop/noVNC)"
fi

echo "--- $pass passed, $fail failed ---"
[[ "$fail" -eq 0 ]]
