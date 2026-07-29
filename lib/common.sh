#!/usr/bin/env bash
# Shared library for buzz-desktop-headless (sourced, not executed).
# Portable across Debian/Ubuntu, Fedora/RHEL, Arch (path + package discovery).
# shellcheck shell=bash disable=SC2034

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
: "${BD_DISPLAY:=101}"
: "${BD_GEOMETRY:=1920x1080x24}"
: "${BD_VNC_PORT:=5911}"
: "${BD_NOVNC_PORT:=6180}"
: "${BD_BIND:=127.0.0.1}"
: "${BD_STATE_DIR:=${XDG_STATE_HOME:-$HOME/.local/state}/buzz-desktop-headless}"
: "${BD_BUZZ_CMD:=buzz-desktop}"
: "${BD_VNC_PASSWORD_FILE:=}"
: "${BD_USER_DATA:=${BUZZ_DESKTOP_USER_DATA_DIR:-$HOME/.local/share/xyz.block.buzz.app}}"
: "${BD_NOVNC_WEB:=}"
: "${BD_WM:=}"
: "${BD_WAIT_BUZZ_SEC:=60}"
: "${BD_SKIP_VNC:=0}"
: "${BD_LOG_LEVEL:=info}" # debug|info|warn
# Pointer fidelity for noVNC drag (session tiling). Override with BD_X11VNC_EXTRA.
: "${BD_X11VNC_EXTRA:=}"
: "${BD_POINTER_MODE:=1}"
: "${BD_VNC_DEFER_MS:=1}"
: "${BD_VNC_WAIT_MS:=5}"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
bd_log() {
  local level="$1"; shift
  case "$level" in
    debug) [[ "${BD_LOG_LEVEL}" == debug ]] || return 0 ;;
    info|warn|error) ;;
    *) level=info ;;
  esac
  printf '[%s] %s\n' "$level" "$*" >&2
}

bd_die() { bd_log error "$*"; return 1; }

# ---------------------------------------------------------------------------
# Paths / process helpers
# ---------------------------------------------------------------------------
bd_mkdirs() { mkdir -p "$BD_STATE_DIR"/{logs,run}; }

bd_pidfile() { printf '%s/run/%s.pid\n' "$BD_STATE_DIR" "$1"; }
bd_logfile() { printf '%s/logs/%s.log\n' "$BD_STATE_DIR" "$1"; }

bd_is_alive() {
  local pf pid
  pf="$(bd_pidfile "$1")"
  [[ -f "$pf" ]] || return 1
  pid="$(<"$pf")"
  [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null
}

bd_read_pid() {
  local pf
  pf="$(bd_pidfile "$1")"
  if [[ -f "$pf" ]]; then
    cat "$pf"
  fi
}

bd_spawn() {
  # bd_spawn <name> <command...>  — run in background, record pid + log
  local name="$1"; shift
  local log; log="$(bd_logfile "$name")"
  bd_log debug "spawn $name: $*"
  nohup "$@" >"$log" 2>&1 &
  echo $! >"$(bd_pidfile "$name")"
}

bd_kill_pidfile() {
  local name="$1" pf pid
  pf="$(bd_pidfile "$name")"
  [[ -f "$pf" ]] || return 0
  pid="$(<"$pf")"
  if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.15
    done
    kill -9 "$pid" 2>/dev/null || true
  fi
  rm -f "$pf"
}

bd_wait_until() {
  # bd_wait_until <seconds> <message> <command...>
  local secs="$1" msg="$2"; shift 2
  local i
  for ((i = 1; i <= secs * 5; i++)); do
    if "$@"; then return 0; fi
    sleep 0.2
  done
  bd_log error "timeout waiting for: $msg"
  return 1
}

bd_have() { command -v "$1" >/dev/null 2>&1; }

# Resolve Desktop binary. Prefer absolute BD_BUZZ_CMD / BUZZ_DESKTOP_CMD.
# Avoid shell wrappers named buzz-desktop when a real binary exists.
bd_resolve_buzz_cmd() {
  local c
  if [[ -n "${BUZZ_DESKTOP_CMD:-}" ]]; then
    c="$BUZZ_DESKTOP_CMD"
  elif [[ -n "${BD_BUZZ_CMD:-}" ]]; then
    c="$BD_BUZZ_CMD"
  else
    c="buzz-desktop"
  fi
  # If bare name, prefer known real binary paths over a PATH wrapper
  if [[ "$c" == "buzz-desktop" ]]; then
    local p
    for p in /usr/bin/buzz-desktop /usr/local/bin/buzz-desktop \
             "${HOME}/.local/share/buzz/buzz-desktop" \
             "${HOME}/.cargo/bin/buzz-desktop"; do
      if [[ -x "$p" && -f "$p" ]]; then
        # skip if it's a shell script wrapper (optional heuristic)
        # Prefer real ELF binary over shell wrappers named buzz-desktop
        if head -c 4 "$p" 2>/dev/null | grep -aq $'\x7fELF'; then
          printf '%s\n' "$p"; return 0
        fi
      fi
    done
  fi
  if [[ "$c" == /* && -x "$c" ]]; then
    printf '%s\n' "$c"; return 0
  fi
  if command -v "$c" >/dev/null 2>&1; then
    command -v "$c"; return 0
  fi
  return 1
}

# PIDs for the Desktop client on our DISPLAY (not this CLI).
bd_buzz_pids_on_display() {
  local pid disp cmd
  for pid in $(pgrep -x buzz-desktop 2>/dev/null || true); do
    disp="$(bd_proc_display "$pid")"
    if [[ "$disp" == ":${BD_DISPLAY}" || "$disp" == "${BD_DISPLAY}" ]]; then
      printf '%s\n' "$pid"
    fi
  done
  # absolute-path launches may show different process name
  for pid in $(pgrep -f '/buzz-desktop( |$)' 2>/dev/null || true); do
    cmd="$(tr '\0' ' ' </proc/$pid/cmdline 2>/dev/null || true)"
    [[ "$cmd" == *buzz-desktop-headless* ]] && continue
    disp="$(bd_proc_display "$pid")"
    if [[ "$disp" == ":${BD_DISPLAY}" || "$disp" == "${BD_DISPLAY}" ]]; then
      printf '%s\n' "$pid"
    fi
  done | sort -u
}


# ---------------------------------------------------------------------------
# Distro / dependency resolution
# ---------------------------------------------------------------------------
bd_os_id() {
  # shellcheck disable=SC1091
  [[ -r /etc/os-release ]] && . /etc/os-release
  printf '%s\n' "${ID:-unknown}"
}

bd_resolve_novnc_web() {
  if [[ -n "${BD_NOVNC_WEB}" && -d "${BD_NOVNC_WEB}" ]]; then
    printf '%s\n' "$BD_NOVNC_WEB"
    return 0
  fi
  local p
  for p in \
    /usr/share/novnc \
    /usr/share/webapps/novnc \
    /usr/local/share/novnc \
    "$HOME/.local/share/novnc"
  do
    if [[ -d "$p" && ( -f "$p/vnc.html" || -f "$p/vnc_lite.html" ) ]]; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  return 1
}

bd_resolve_websockify() {
  if bd_have websockify; then
    printf '%s\n' websockify
    return 0
  fi
  if bd_have python3 && python3 -c 'import websockify' 2>/dev/null; then
    printf '%s\n' 'python3 -m websockify'
    return 0
  fi
  return 1
}

bd_resolve_wm() {
  local preferred="${BD_WM:-}" c
  if [[ -n "$preferred" ]]; then
    bd_have "$preferred" && { printf '%s\n' "$preferred"; return 0; }
  fi
  for c in fluxbox openbox icewm matchbox-window-manager; do
    if bd_have "$c"; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  return 1
}

bd_resolve_screenshot() {
  if bd_have scrot; then printf '%s\n' scrot; return 0; fi
  if bd_have import; then printf '%s\n' import; return 0; fi # ImageMagick
  if bd_have gnome-screenshot; then printf '%s\n' gnome-screenshot; return 0; fi
  return 1
}

bd_package_hints() {
  local id; id="$(bd_os_id)"
  case "$id" in
    ubuntu|debian|linuxmint|pop|raspbian)
      echo "sudo apt-get install -y xvfb x11vnc novnc websockify fluxbox scrot dbus-x11 xdotool"
      ;;
    fedora|rhel|centos|rocky|almalinux)
      echo "sudo dnf install -y xorg-x11-server-Xvfb x11vnc novnc python3-websockify fluxbox scrot dbus-x11 xdotool"
      ;;
    arch|manjaro|endeavouros)
      echo "sudo pacman -S --needed xorg-server-xvfb x11vnc novnc python-websockify fluxbox scrot dbus xdotool"
      ;;
    opensuse*|sles)
      echo "sudo zypper install -y xorg-x11-server-Xvfb x11vnc novnc python3-websockify fluxbox scrot dbus-1-x11 xdotool"
      ;;
    *)
      echo "# Install: Xvfb, x11vnc, noVNC, websockify, a WM (fluxbox/openbox), scrot, dbus-x11, xdotool (for split CLI)"
      ;;
  esac
  echo "# Buzz Desktop binary must be on PATH (package install or release build)."
}

bd_doctor() {
  local hints=0 missing=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --install-hints) hints=1; shift ;;
      *) shift ;;
    esac
  done

  local b
  for b in Xvfb x11vnc; do
    if bd_have "$b"; then
      echo "ok   $b -> $(command -v "$b")"
    else
      echo "MISS $b"
      missing=1
    fi
  done

  if bd_resolve_websockify >/dev/null; then
    echo "ok   websockify -> $(bd_resolve_websockify)"
  else
    echo "MISS websockify (or python3 -m websockify)"
    missing=1
  fi

  if bd_resolve_wm >/dev/null; then
    echo "ok   window manager -> $(bd_resolve_wm)"
  else
    echo "MISS window manager (fluxbox|openbox|icewm)"
    missing=1
  fi

  if novnc_web="$(bd_resolve_novnc_web 2>/dev/null)"; then
    echo "ok   noVNC web -> $novnc_web"
  else
    echo "MISS noVNC web root (expected /usr/share/novnc or set BD_NOVNC_WEB)"
    missing=1
  fi

  if bd_resolve_screenshot >/dev/null; then
    echo "ok   screenshot -> $(bd_resolve_screenshot)"
  else
    echo "WARN screenshot tool missing (scrot|import) - optional"
  fi

  if buzz_bin="$(bd_resolve_buzz_cmd)"; then
    echo "ok   buzz-desktop -> $buzz_bin"
  else
    echo "MISS buzz-desktop binary (set BD_BUZZ_CMD or install on PATH)"
    missing=1
  fi

  if bd_have dbus-launch; then
    echo "ok   dbus-launch -> $(command -v dbus-launch)"
  else
    echo "WARN dbus-launch missing (recommended)"
  fi

  echo "plan display=:${BD_DISPLAY} bind=${BD_BIND} vnc=${BD_VNC_PORT} novnc=${BD_NOVNC_PORT}"
  echo "plan state=${BD_STATE_DIR} os=$(bd_os_id)"

  if [[ "$hints" -eq 1 ]] || [[ "$missing" -ne 0 ]]; then
    echo "--- install hints ---"
    bd_package_hints
  fi
  return "$missing"
}

# ---------------------------------------------------------------------------
# Runtime env
# ---------------------------------------------------------------------------
bd_export_display() {
  export DISPLAY=":${BD_DISPLAY}"
  export XAUTHORITY="${XAUTHORITY:-$BD_STATE_DIR/run/xauth}"
  export WEBKIT_DISABLE_COMPOSITING_MODE="${BUZZ_DESKTOP_DISABLE_GPU:-1}"
  export ELECTRON_OZONE_PLATFORM_HINT="${ELECTRON_OZONE_PLATFORM_HINT:-x11}"
  # Persist for screenshot/status in other shells
  {
    printf 'export DISPLAY=%q\n' "$DISPLAY"
    printf 'export XAUTHORITY=%q\n' "$XAUTHORITY"
    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
      printf 'export DBUS_SESSION_BUS_ADDRESS=%q\n' "$DBUS_SESSION_BUS_ADDRESS"
    fi
  } >"$BD_STATE_DIR/run/env.sh"
}

bd_load_runtime_env() {
  # shellcheck disable=SC1091
  [[ -f "$BD_STATE_DIR/run/env.sh" ]] && . "$BD_STATE_DIR/run/env.sh"
}

bd_is_loopback_bind() {
  case "$BD_BIND" in
    127.0.0.1|localhost|::1) return 0 ;;
    *) return 1 ;;
  esac
}

# ---------------------------------------------------------------------------
# Electron singleton
# ---------------------------------------------------------------------------
bd_clear_singleton() {
  local lock="$BD_USER_DATA/SingletonLock" target pid
  mkdir -p "$BD_USER_DATA"
  if [[ -e "$lock" || -L "$lock" ]]; then
    target="$(readlink "$lock" 2>/dev/null || true)"
    pid="${target##*-}"
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
      bd_log info "Buzz Desktop already running (pid $pid); leaving SingletonLock"
      return 0
    fi
    bd_log info "clearing stale Electron singleton (${target:-unknown})"
    rm -f "$BD_USER_DATA/SingletonLock" \
          "$BD_USER_DATA/SingletonCookie" \
          "$BD_USER_DATA/SingletonSocket"
  fi
}

# Kill only Buzz Desktop processes bound to our DISPLAY (not every Buzz on the host).
bd_proc_display() {
  # best-effort; other users' /proc/*/environ may be unreadable
  local pid envf
  pid="$1"
  envf="/proc/${pid}/environ"
  [[ -r "$envf" ]] || return 0
  tr '\0' '\n' <"$envf" 2>/dev/null | sed -n 's/^DISPLAY=//p' | head -1 || true
}

bd_kill_buzz_on_display() {
  local pid
  for pid in $(bd_buzz_pids_on_display); do
    bd_log debug "stopping buzz-desktop pid $pid on DISPLAY=:${BD_DISPLAY}"
    kill "$pid" 2>/dev/null || true
  done
  sleep 0.3
  for pid in $(bd_buzz_pids_on_display); do
    kill -9 "$pid" 2>/dev/null || true
  done
}

bd_buzz_on_display() {
  local pid
  pid="$(bd_buzz_pids_on_display | head -1)"
  [[ -n "${pid:-}" ]]
}

# ---------------------------------------------------------------------------
# Stack components
# ---------------------------------------------------------------------------
bd_start_xvfb() {
  if bd_is_alive xvfb; then
    bd_log info "Xvfb already up (pid $(bd_read_pid xvfb))"
    return 0
  fi
  if [[ -e "/tmp/.X${BD_DISPLAY}-lock" ]]; then
    if ! pgrep -af "Xvfb :${BD_DISPLAY}" >/dev/null 2>&1; then
      rm -f "/tmp/.X${BD_DISPLAY}-lock" "/tmp/.X11-unix/X${BD_DISPLAY}" 2>/dev/null || true
    else
      bd_die "display :${BD_DISPLAY} already in use"
    fi
  fi
  bd_have Xvfb || bd_die "Xvfb missing"
  bd_spawn xvfb Xvfb ":${BD_DISPLAY}" -screen 0 "$BD_GEOMETRY" -ac -nolisten tcp
  bd_wait_until 5 "Xvfb socket" test -e "/tmp/.X11-unix/X${BD_DISPLAY}" \
    || bd_die "Xvfb failed - see $(bd_logfile xvfb)"
  bd_log info "Xvfb :${BD_DISPLAY} up (pid $(bd_read_pid xvfb))"
}

bd_start_dbus_wm() {
  bd_export_display
  if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]] && bd_have dbus-launch; then
    # shellcheck disable=SC2046
    eval "$(dbus-launch --sh-syntax)"
    printf '%s\n' "$DBUS_SESSION_BUS_ADDRESS" >"$BD_STATE_DIR/run/dbus.address"
    printf '%s\n' "$DBUS_SESSION_BUS_PID" >"$(bd_pidfile dbus)"
    bd_log info "dbus session pid $DBUS_SESSION_BUS_PID"
    bd_export_display
  fi

  if bd_is_alive wm; then
    bd_log info "window manager already up"
    return 0
  fi
  local wm; wm="$(bd_resolve_wm)" || bd_die "no window manager (install fluxbox/openbox/icewm)"
  # matchbox uses a long binary name
  case "$wm" in
    matchbox-window-manager) bd_spawn wm matchbox-window-manager -use_titlebar no ;;
    *) bd_spawn wm "$wm" ;;
  esac
  sleep 0.25
  bd_log info "wm $wm up (pid $(bd_read_pid wm))"
}

bd_start_buzz() {
  bd_export_display
  bd_clear_singleton
  if bd_buzz_on_display; then
    bd_log info "Buzz Desktop already on DISPLAY=:${BD_DISPLAY}"
    return 0
  fi
  local buzz_bin
  buzz_bin="$(bd_resolve_buzz_cmd)" || bd_die "buzz-desktop binary not found (install Desktop or set BD_BUZZ_CMD)"
  BD_BUZZ_CMD="$buzz_bin"

  local log; log="$(bd_logfile buzz-desktop)"
  # shellcheck disable=SC2086
  # Optional remote relay (headless backend pattern)
  local relay_args=()
  [[ -n "${BUZZ_RELAY_URL:-}" ]] && relay_args+=(BUZZ_RELAY_URL="$BUZZ_RELAY_URL")
  [[ -n "${BUZZ_RELAY_HTTP:-}" ]] && relay_args+=(BUZZ_RELAY_HTTP="$BUZZ_RELAY_HTTP")
  [[ -n "${BUZZ_AUTO_CONNECT_DEFAULT_RELAY:-}" ]] && relay_args+=(BUZZ_AUTO_CONNECT_DEFAULT_RELAY="$BUZZ_AUTO_CONNECT_DEFAULT_RELAY")

  # shellcheck disable=SC2086
  nohup env DISPLAY=":$BD_DISPLAY" \
    WEBKIT_DISABLE_COMPOSITING_MODE=1 \
    ELECTRON_OZONE_PLATFORM_HINT=x11 \
    DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}" \
    "${relay_args[@]}" \
    $BD_BUZZ_CMD \
    >"$log" 2>&1 &
  echo $! >"$(bd_pidfile buzz-desktop)"
  bd_log info "buzz-desktop launcher pid $(bd_read_pid buzz-desktop)"

  local i
  for ((i = 1; i <= BD_WAIT_BUZZ_SEC; i++)); do
    if bd_buzz_on_display; then
      bd_log info "Buzz Desktop running on :${BD_DISPLAY}"
      return 0
    fi
    if ! bd_is_alive buzz-desktop && [[ "$i" -gt 5 ]]; then
      bd_log error "launcher exited early - tail $(bd_logfile buzz-desktop):"
      tail -n 40 "$log" >&2 || true
      return 1
    fi
    sleep 1
  done
  bd_log error "timeout waiting for Buzz Desktop - tail $(bd_logfile buzz-desktop):"
  tail -n 60 "$log" >&2 || true
  return 1
}

bd_start_vnc() {
  [[ "$BD_SKIP_VNC" == "1" ]] && { bd_log info "skip VNC"; return 0; }
  if bd_is_alive x11vnc; then
    bd_log info "x11vnc already up"
    return 0
  fi
  bd_have x11vnc || bd_die "x11vnc missing"
  bd_export_display

  local auth_args=()
  if [[ -n "$BD_VNC_PASSWORD_FILE" && -f "$BD_VNC_PASSWORD_FILE" ]]; then
    auth_args=(-rfbauth "$BD_VNC_PASSWORD_FILE")
  else
    bd_is_loopback_bind || bd_die "non-localhost bind requires BD_VNC_PASSWORD_FILE"
    auth_args=(-nopw)
  fi

  # Pointer path tuned for noVNC drag (session tiles / Open-in-split gestures):
  # -always_inject  : deliver clicks even when dx=dy=0 (menu clicks, slow drags)
  # -pointer_mode 1 : smoother motion sampling (less "stuck" drags)
  # -cursor most    : real X cursors so targets are visible over VNC
  # -defer 1 -wait 5: low latency updates so drop targets track the pointer
  # -wait_ui 0.5    : poll faster while UI input is active
  # shellcheck disable=SC2086
  bd_spawn x11vnc x11vnc \
    -display ":$BD_DISPLAY" \
    -rfbport "$BD_VNC_PORT" \
    -listen "$BD_BIND" \
    -forever -shared -noxdamage -repeat \
    -always_inject \
    -pointer_mode "$BD_POINTER_MODE" \
    -cursor most \
    -defer "$BD_VNC_DEFER_MS" \
    -wait "$BD_VNC_WAIT_MS" \
    -wait_ui 0.5 \
    "${auth_args[@]}" \
    $BD_X11VNC_EXTRA

  bd_wait_until 5 "x11vnc" bd_is_alive x11vnc \
    || { tail -n 30 "$(bd_logfile x11vnc)" >&2; bd_die "x11vnc failed"; }
  bd_log info "x11vnc ${BD_BIND}:${BD_VNC_PORT} (pid $(bd_read_pid x11vnc)) [pointer-fidelity]"
}

bd_novnc_query() {
  # Optimal noVNC client params for drag/drop tiling:
  # resize=remote  — 1:1 coords (scale mode breaks drop geometry)
  # quality=9 compression=0 — fewer smear/ghost frames during drag
  # show_dot=1 — local cursor for hit-testing
  printf 'autoconnect=1&resize=remote&quality=9&compression=0&show_dot=1'
}

bd_novnc_url() {
  printf 'http://%s:%s/vnc.html?%s\n' "$BD_BIND" "$BD_NOVNC_PORT" "$(bd_novnc_query)"
}

bd_start_novnc() {
  [[ "$BD_SKIP_VNC" == "1" ]] && return 0
  if bd_is_alive novnc; then
    bd_log info "noVNC already up"
    return 0
  fi
  local wscmd web
  wscmd="$(bd_resolve_websockify)" || bd_die "websockify missing"
  web="$(bd_resolve_novnc_web)" || bd_die "noVNC web root missing"

  # shellcheck disable=SC2086
  bd_spawn novnc $wscmd --web="$web" \
    "${BD_BIND}:${BD_NOVNC_PORT}" \
    "127.0.0.1:${BD_VNC_PORT}"

  bd_wait_until 5 "noVNC" bd_is_alive novnc \
    || { tail -n 30 "$(bd_logfile novnc)" >&2; bd_die "noVNC/websockify failed"; }
  bd_log info "noVNC $(bd_novnc_url) (pid $(bd_read_pid novnc))"
}

bd_print_urls() {
  local url
  url="$(bd_novnc_url)"
  cat <<EOF
Display   : :${BD_DISPLAY}
VNC       : ${BD_BIND}:${BD_VNC_PORT}
noVNC     : ${url}
SSH tunnel:
  ssh -N -L ${BD_NOVNC_PORT}:127.0.0.1:${BD_NOVNC_PORT} -L ${BD_VNC_PORT}:127.0.0.1:${BD_VNC_PORT} user@host
Then open (drag-friendly params already in the URL):
  http://127.0.0.1:${BD_NOVNC_PORT}/vnc.html?$(bd_novnc_query)

Tip: use the noVNC URL above (resize=remote) for accurate clicks.
EOF
}

# Restart only the VNC layer (apply pointer-fidelity flags without bouncing Desktop).
bd_restart_vnc() {
  bd_mkdirs
  bd_kill_pidfile novnc
  bd_kill_pidfile x11vnc
  sleep 0.3
  bd_start_vnc
  bd_start_novnc
  bd_print_urls
}

# ---------------------------------------------------------------------------
# Split / tile helpers (no drag required — for noVNC and automation)
# ---------------------------------------------------------------------------
bd_buzz_window() {
  local w
  for w in $(xdotool search --onlyvisible --name 'Buzz' 2>/dev/null || true); do
    echo "$w"; return 0
  done
  for w in $(xdotool search --class buzz-desktop 2>/dev/null || true); do
    echo "$w"; return 0
  done
  for w in $(xdotool search --name '' 2>/dev/null || true); do
    # last resort: any mapped window on our display owned by buzz
    echo "$w"; return 0
  done
  return 1
}

# Drive "New session → Open in split → <dir>" via xdotool.
# dir: right|left|up|down (default right). Requires xdotool.
bd_split() {
  local dir="${1:-right}"
  export DISPLAY=":${BD_DISPLAY}"
  bd_have xdotool || bd_die "xdotool required for 'split' (sudo apt-get install -y xdotool)"
  bd_buzz_on_display || pgrep -f 'buzz-desktop' >/dev/null \
    || bd_die "Buzz Desktop is not running — start first"

  local wid
  wid="$(bd_buzz_window)" || bd_die "could not find Buzz window on :${BD_DISPLAY}"
  xdotool windowactivate --sync "$wid"
  sleep 0.25
  xdotool key --window "$wid" Escape Escape
  sleep 0.2

  # Geometry relative clicks: "New session" is top-left of the content chrome.
  local x y w h
  eval "$(xdotool getwindowgeometry --shell "$wid")"
  x=$X; y=$Y; w=$WIDTH; h=$HEIGHT

  # New session row (~ left rail, first item under titlebar)
  local nx ny
  nx=$((x + 90))
  ny=$((y + 70))
  xdotool mousemove --sync "$nx" "$ny"
  sleep 0.15
  xdotool click 3
  sleep 0.55

  # "Open in split" sits just below New session in the context menu
  xdotool mousemove --sync $((nx + 40)) $((ny + 20))
  sleep 0.35

  # Submenu directions: Right first (default), then Down, Left, Up
  local sx sy
  case "$dir" in
    right|r)  sx=$((nx + 130)); sy=$((ny + 28)) ;;
    down|d|bottom) sx=$((nx + 130)); sy=$((ny + 48)) ;;
    left|l)   sx=$((nx + 130)); sy=$((ny + 68)) ;;
    up|u|top) sx=$((nx + 130)); sy=$((ny + 88)) ;;
    *) bd_die "split dir must be right|left|up|down (got: $dir)" ;;
  esac

  # Open submenu by hovering Open in split, then click direction
  xdotool mousemove --sync $((nx + 50)) $((ny + 22))
  sleep 0.45
  xdotool mousemove --sync "$sx" "$sy"
  sleep 0.25
  xdotool click 1
  sleep 0.8

  bd_log info "split requested: $dir (window $wid)"
  echo "split $dir — if the layout did not change, use right-click New session → Open in split in the UI"
}

# Ctrl+T new session tab (stacked, not split).
bd_new_tab() {
  export DISPLAY=":${BD_DISPLAY}"
  bd_have xdotool || bd_die "xdotool required"
  local wid
  wid="$(bd_buzz_window)" || bd_die "Buzz window not found"
  xdotool windowactivate --sync "$wid"
  sleep 0.2
  xdotool key --window "$wid" ctrl+t
  bd_log info "sent Ctrl+T (new session tab)"
}

# ---------------------------------------------------------------------------
# Public commands
# ---------------------------------------------------------------------------
bd_start() {
  local foreground=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --foreground) foreground=1; shift ;;
      --no-vnc) BD_SKIP_VNC=1; shift ;;
      --bind) BD_BIND="$2"; shift 2 ;;
      --display) BD_DISPLAY="$2"; shift 2 ;;
      *) bd_die "unknown start flag: $1" ;;
    esac
  done

  bd_mkdirs
  if ! bd_doctor >/dev/null; then
    bd_log error "doctor failed - missing dependencies"
    bd_doctor --install-hints || true
    return 1
  fi

  bd_start_xvfb
  bd_start_dbus_wm
  bd_start_buzz
  bd_start_vnc
  bd_start_novnc
  bd_print_urls
  date -u +"%Y-%m-%dT%H:%M:%SZ started" >>"$BD_STATE_DIR/logs/lifecycle.log"

  if [[ "$foreground" -eq 1 ]]; then
    bd_log info "foreground mode - Ctrl-C stops the stack"
    trap 'bd_stop' INT TERM
    while bd_is_alive xvfb; do sleep 2; done
  fi
}

bd_stop() {
  bd_mkdirs
  bd_kill_pidfile buzz-desktop
  bd_kill_buzz_on_display
  bd_kill_pidfile novnc
  bd_kill_pidfile x11vnc
  bd_kill_pidfile wm
  # legacy name from v0.1
  bd_kill_pidfile fluxbox
  bd_kill_pidfile dbus
  bd_kill_pidfile xvfb
  pkill -f "Xvfb :${BD_DISPLAY}" 2>/dev/null || true
  rm -f "/tmp/.X${BD_DISPLAY}-lock" 2>/dev/null || true
  bd_clear_singleton || true
  date -u +"%Y-%m-%dT%H:%M:%SZ stopped" >>"$BD_STATE_DIR/logs/lifecycle.log"
  bd_log info "stopped"
  echo "stopped"
}

bd_status() {
  bd_mkdirs
  local n
  for n in xvfb dbus wm buzz-desktop x11vnc novnc; do
    if bd_is_alive "$n"; then
      echo "UP   $n pid=$(bd_read_pid "$n")"
    else
      # compat: old fluxbox pidfile
      if [[ "$n" == wm ]] && bd_is_alive fluxbox; then
        echo "UP   wm(fluxbox) pid=$(bd_read_pid fluxbox)"
      else
        echo "DOWN $n"
      fi
    fi
  done
  if bd_buzz_on_display; then
    echo "UP   desktop DISPLAY=:${BD_DISPLAY}"
    bd_buzz_pids_on_display | head -5 | while read -r _p; do ps -p "$_p" -o pid=,args= 2>/dev/null; done || true
  else
    echo "DOWN desktop"
  fi
  if [[ -e "/tmp/.X11-unix/X${BD_DISPLAY}" ]]; then
    echo "X socket :$BD_DISPLAY present"
  else
    echo "X socket :$BD_DISPLAY missing"
  fi
  bd_print_urls
}

bd_screenshot() {
  bd_load_runtime_env
  bd_export_display
  local tool out
  tool="$(bd_resolve_screenshot)" || bd_die "need scrot or ImageMagick import"
  out="${1:-$BD_STATE_DIR/logs/screenshot-$(date -u +%Y%m%dT%H%M%SZ).png}"
  mkdir -p "$(dirname "$out")"
  case "$tool" in
    scrot) scrot -o "$out" ;;
    import) import -window root "$out" ;;
    gnome-screenshot) gnome-screenshot -f "$out" ;;
  esac
  echo "$out"
}
