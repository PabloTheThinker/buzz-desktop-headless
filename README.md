# buzz-desktop-headless

**Run Buzz Desktop on any headless Linux box** — VPS, bare metal, CI — without a physical monitor.

Virtual framebuffer + lightweight window manager + VNC + browser client. Defaults to **localhost-only** access via SSH tunnel.

This is a portable headless GUI wrapper for the **Buzz Desktop** client binary. It is **not** a Buzz backend/relay, and it does not ship the Desktop app itself.

[![version](https://img.shields.io/badge/version-0.1.0-blue)](VERSION)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![shell](https://img.shields.io/badge/shell-bash-4EAA25)](bin/buzz-desktop-headless)
[![platform](https://img.shields.io/badge/platform-Linux-lightgrey)](#requirements)

## What this is (and is not)

| This project | Not this project |
|--------------|------------------|
| Starts Xvfb + WM + **Buzz Desktop GUI** + x11vnc + noVNC | A full Buzz mesh / relay server |
| One CLI to bring the GUI stack up and down | A package of the Desktop binary |
| Localhost bind + SSH tunnel by default | A turnkey multi-tenant hosted desktop |

Install **Buzz Desktop** separately (for example `/usr/bin/buzz-desktop`, or any path you set).  
Backend connectivity (if you use one) is a **separate** concern — typically a **buzz-relay** process or remote URL via `BUZZ_RELAY_URL`. This repo only wraps the Desktop GUI client.

The stack pattern is the same industry-standard approach used by tools like [hermes-desktop-headless](https://github.com/PabloTheThinker/hermes-desktop-headless) (Xvfb → x11vnc → noVNC). There is **no** affiliation with Block, Nous Research, or any upstream Desktop vendor implied by that comparison.

## Features

- **One CLI**: `start` / `stop` / `restart` / `status` / `url` / `screenshot` / `doctor` / `version` / `help`
- **Portable deps**: Debian/Ubuntu, Fedora/RHEL, Arch, openSUSE package hints
- **WM auto-pick**: fluxbox → openbox → icewm → matchbox
- **noVNC discovery**: `/usr/share/novnc`, Arch webapps path, overrides
- **websockify**: binary or `python3 -m websockify`
- **Safe process stop**: only Desktop processes on *this* stack’s `DISPLAY`
- **Security default**: loopback bind; password required off-localhost

## Requirements

- Linux (x86_64 or aarch64 with matching packages)
- Bash
- OS packages: **Xvfb**, **x11vnc**, **noVNC**, **websockify**, a light WM (**fluxbox** / **openbox** / **icewm**), **dbus-x11** recommended; **scrot** or ImageMagick for screenshots; **xdotool** optional for split helpers
- **Buzz Desktop binary** installed and on `PATH`, or pointed at via env (see below)

## Quick start

```bash
git clone https://github.com/PabloTheThinker/buzz-desktop-headless.git
cd buzz-desktop-headless
./scripts/install.sh --packages    # sudo: OS packages + ~/.local/bin link
# or without packages:
./scripts/install.sh

# Ensure Buzz Desktop is installed (example):
#   which buzz-desktop || ls /usr/bin/buzz-desktop

buzz-desktop-headless doctor --install-hints
buzz-desktop-headless start
buzz-desktop-headless url
```

### Access from your laptop

Defaults bind **127.0.0.1 only**. Tunnel in over SSH:

```bash
ssh -N -L 6180:127.0.0.1:6180 -L 5911:127.0.0.1:5911 user@server
```

Then open:

```text
http://127.0.0.1:6180/vnc.html?autoconnect=1&resize=remote
```

(`buzz-desktop-headless url` prints the full drag-friendly query string.)

## Architecture

```text
  Browser ──► websockify:6180 (noVNC) ──► x11vnc:5911 ──► Xvfb:101
                                                                │
                                                fluxbox/openbox + Buzz Desktop
                                                                │
                                              (optional) remote buzz-relay URL
```

| Layer | Default | Role |
|-------|---------|------|
| Xvfb | display `:101` | Virtual framebuffer |
| WM | fluxbox / openbox / … | Lightweight window manager |
| Buzz Desktop | `buzz-desktop` (or override) | Tauri/Electron-style GUI client |
| x11vnc | `127.0.0.1:5911` | RFB / VNC |
| noVNC + websockify | `127.0.0.1:6180` | Browser access |

Industry-standard headless GUI pattern (Xvfb + x11vnc + noVNC), specialized for the Buzz Desktop client.

## Commands

| Command | Purpose |
|---------|---------|
| `start [--foreground] [--no-vnc] [--bind ADDR] [--display N]` | Bring stack up |
| `stop` / `restart` | Tear down / bounce |
| `status` | Component health + URLs |
| `url` | Print noVNC / VNC / SSH tunnel hints |
| `screenshot [path.png]` | Capture the virtual display |
| `doctor [--install-hints]` | Dependency check + distro install line |
| `version` | Print package version |
| `help` | Usage |

Optional helpers (when `xdotool` is installed and the Desktop window is up):

| Command | Purpose |
|---------|---------|
| `restart-vnc` | Re-apply pointer-fidelity VNC flags without bouncing Desktop |
| `split [right\|left\|up\|down]` | Drive open-in-split without drag |
| `new-tab` | Send Ctrl+T for a new session tab |

## Environment

| Variable | Default | Notes |
|----------|---------|-------|
| `BD_DISPLAY` | `101` | X display number |
| `BD_GEOMETRY` | `1920x1080x24` | Xvfb screen |
| `BD_VNC_PORT` | `5911` | RFB |
| `BD_NOVNC_PORT` | `6180` | Browser |
| `BD_BIND` | `127.0.0.1` | Listen address |
| `BD_STATE_DIR` | `~/.local/state/buzz-desktop-headless` | PIDs + logs |
| `BD_BUZZ_CMD` / `BUZZ_DESKTOP_CMD` | `buzz-desktop` (typical) | Path/command for the Desktop binary |
| `BUZZ_RELAY_URL` | _(empty)_ | Optional remote relay for the Desktop client (not started by this tool) |
| `BD_WM` | _(auto)_ | Prefer a specific WM |
| `BD_NOVNC_WEB` | _(auto)_ | noVNC static root |
| `BD_VNC_PASSWORD_FILE` | _(empty)_ | **Required** if bind is not loopback |
| `BD_WAIT_HERMES_SEC` | `45` | Desktop ready timeout (seconds) |
| `BD_POINTER_MODE` | `1` | x11vnc pointer mode (drag fidelity) |
| `BD_VNC_DEFER_MS` / `BD_VNC_WAIT_MS` | `1` / `5` | x11vnc latency knobs |
| `BD_X11VNC_EXTRA` | _(empty)_ | Extra raw x11vnc flags |
| `BD_SKIP_VNC` | `0` | Set via `start --no-vnc` |

> **Honesty note:** This repository does **not** install Buzz Desktop or buzz-relay. Point `BD_BUZZ_CMD` / `BUZZ_DESKTOP_CMD` at your installed client. Use a separate relay install if you need mesh/backend features.

## Security

1. **Loopback by default** — VNC/noVNC are not exposed on the public internet  
2. **Non-loopback refused** without `BD_VNC_PASSWORD_FILE` (`x11vnc -storepasswd`)  
3. Prefer an **SSH tunnel** (or a private mesh VPN you control) over opening ports  

```bash
mkdir -p ~/.config/buzz-desktop-headless
x11vnc -storepasswd ~/.config/buzz-desktop-headless/vnc.pass
export BD_VNC_PASSWORD_FILE=~/.config/buzz-desktop-headless/vnc.pass
# still prefer not exposing 0.0.0.0 to the open WAN
```

See [SECURITY.md](SECURITY.md).

## systemd (user)

If you add a user unit (example name `buzz-desktop-headless.service`):

```bash
mkdir -p ~/.config/systemd/user
# copy or write a unit that ExecStart=.../buzz-desktop-headless start --foreground
systemctl --user daemon-reload
systemctl --user enable --now buzz-desktop-headless.service
```

Keep `BD_BIND=127.0.0.1` unless you intentionally harden with a VNC password and network policy.

## Development

```bash
make check    # bash -n + shellcheck (if installed)
make smoke    # offline unit checks (Buzz Desktop optional)
make doctor
./scripts/install.sh [--packages]
```

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Missing X server or $DISPLAY` | Use this tool, not bare `buzz-desktop` on a headless host |
| Doctor MISS packages | `./scripts/install.sh --packages` or `doctor --install-hints` |
| Doctor MISS Desktop binary | Install Buzz Desktop; set `BD_BUZZ_CMD` / `BUZZ_DESKTOP_CMD` |
| Port / display busy | `BD_DISPLAY=102 BD_VNC_PORT=5912 BD_NOVNC_PORT=6181 start` |
| noVNC blank / can’t drag | Use the URL from `url` (`resize=remote`); try `restart-vnc` |
| Singleton / stale lock | `stop`, then clear dead Electron/Tauri singleton files under the Desktop user-data dir if needed |

Logs: `$BD_STATE_DIR/logs/` (`xvfb`, `wm`, `buzz-desktop`, `x11vnc`, `novnc`).

## License

MIT — see [LICENSE](LICENSE).

Buzz Desktop and any related relay/backend software remain under their own upstream licenses. This project only provides the headless display/VNC wrapper.

## Author

**Pablo Navarro** ([PabloTheThinker](https://github.com/PabloTheThinker))
