# buzz-desktop-headless

<p align="center">
  <strong>Buzz Desktop on a server — no monitor required</strong><br/>
  <sub>Xvfb · window manager · x11vnc · noVNC · one CLI</sub>
</p>

<p align="center">
  <a href="VERSION"><img alt="version" src="https://img.shields.io/badge/version-0.1.1-blue" /></a>
  <a href="LICENSE"><img alt="license" src="https://img.shields.io/badge/license-MIT-green" /></a>
  <a href=".github/workflows/ci.yml"><img alt="ci" src="https://github.com/PabloTheThinker/buzz-desktop-headless/actions/workflows/ci.yml/badge.svg" /></a>
  <img alt="platform" src="https://img.shields.io/badge/platform-Linux-lightgrey" />
  <img alt="shell" src="https://img.shields.io/badge/shell-bash-4EAA25" />
</p>

---

Run the **Buzz Desktop** GUI client on any headless Linux box (VPS, bare metal, CI node) and open it from a browser over an SSH tunnel.

| This repo **is** | This repo **is not** |
|------------------|----------------------|
| A portable **headless GUI stack** for the Desktop client | A Buzz **relay / mesh backend** |
| `start` → virtual display → noVNC URL | A package that ships the Desktop binary |
| Safe **localhost** defaults | A multi-tenant hosted desktop product |

Install **Buzz Desktop** yourself. Optionally point it at a **separate** `buzz-relay` with `BUZZ_RELAY_URL`.  
Same industry pattern as [hermes-desktop-headless](https://github.com/PabloTheThinker/hermes-desktop-headless) — **no** affiliation with Block, Nous, or any Desktop vendor.

---

## Who is this for?

| You… | Use it? |
|------|---------|
| Run agents / Buzz on a **Linux server with no GPU monitor** | **Yes** — full stack |
| Already use Buzz Desktop on a laptop screen | **No** — use the native app |
| Only need CLI / relay / ACP agents | **No** — you don’t need a GUI shell |
| Want browser access to Desktop from anywhere via SSH | **Yes** |

---

## Quick start

```bash
git clone https://github.com/PabloTheThinker/buzz-desktop-headless.git
cd buzz-desktop-headless
./scripts/install.sh --packages   # OS deps + ~/.local/bin link (sudo)

# Install Buzz Desktop separately, then:
buzz-desktop-headless doctor --install-hints
buzz-desktop-headless start
buzz-desktop-headless url
```

### Open from your laptop

Defaults bind **127.0.0.1 only**:

```bash
ssh -N -L 6180:127.0.0.1:6180 -L 5911:127.0.0.1:5911 user@server
```

Browser:

```text
http://127.0.0.1:6180/vnc.html?autoconnect=1&resize=remote
```

(`url` prints the full query string optimized for pointer accuracy.)

### Optional: remote Buzz relay

```bash
export BUZZ_RELAY_URL=ws://127.0.0.1:3000
export BUZZ_AUTO_CONNECT_DEFAULT_RELAY=1
export BD_BUZZ_CMD=/usr/bin/buzz-desktop   # real binary, not a shell wrapper
buzz-desktop-headless start
```

---

## Examples

Copy-paste recipes. Replace `user@server` with your SSH target. All GUI ports stay on **localhost** unless you deliberately change `BD_BIND`.

### 1) First boot on a fresh Ubuntu VPS

```bash
# on the server
sudo apt-get update
git clone https://github.com/PabloTheThinker/buzz-desktop-headless.git
cd buzz-desktop-headless
./scripts/install.sh --packages

# install Buzz Desktop your usual way, then point at the real binary:
export BD_BUZZ_CMD=/usr/bin/buzz-desktop   # or: $(command -v buzz-desktop)

buzz-desktop-headless doctor --install-hints
buzz-desktop-headless start
buzz-desktop-headless status
buzz-desktop-headless url
```

```bash
# on your laptop
ssh -N -L 6180:127.0.0.1:6180 -L 5911:127.0.0.1:5911 user@server
# browser → http://127.0.0.1:6180/vnc.html?autoconnect=1&resize=remote
```

### 2) Everyday ops (already installed)

```bash
buzz-desktop-headless status          # what’s up?
buzz-desktop-headless url             # tunnel + noVNC hints
buzz-desktop-headless screenshot ~/buzz-desk.png
buzz-desktop-headless restart         # bounce whole stack
buzz-desktop-headless restart-vnc     # only refresh x11vnc flags
buzz-desktop-headless stop
```

### 3) Desktop + local buzz-relay on the same host

Relay is **separate** — start it yourself, then hand the URL to Desktop:

```bash
# terminal A — your relay (example ports; use whatever your relay docs say)
# buzz-relay  # or docker compose up -d
curl -sS http://127.0.0.1:3000/_liveness   # expect ok / 200 when healthy

# terminal B — headless Desktop pointed at that relay
export BD_BUZZ_CMD=/usr/bin/buzz-desktop
export BUZZ_RELAY_URL=ws://127.0.0.1:3000
export BUZZ_RELAY_HTTP=http://127.0.0.1:3000
export BUZZ_AUTO_CONNECT_DEFAULT_RELAY=1
buzz-desktop-headless start
buzz-desktop-headless url
```

### 4) Avoid port clashes (Hermes headless or another stack already on 6080)

Defaults use `:101` / `5911` / `6180` on purpose. To move further:

```bash
export BD_DISPLAY=102
export BD_VNC_PORT=5912
export BD_NOVNC_PORT=6181
export BD_BUZZ_CMD=/usr/bin/buzz-desktop
buzz-desktop-headless start

# laptop tunnel must match the new ports:
# ssh -N -L 6181:127.0.0.1:6181 -L 5912:127.0.0.1:5912 user@server
```

### 5) Shell wrapper vs real binary

If `~/.local/bin/buzz-desktop` is a **script** that only sets env, force the ELF:

```bash
# see what PATH resolves
type -a buzz-desktop
file "$(command -v buzz-desktop)"

# prefer absolute real binary
export BD_BUZZ_CMD=/usr/bin/buzz-desktop
# or
export BUZZ_DESKTOP_CMD=/usr/local/bin/buzz-desktop

buzz-desktop-headless doctor
buzz-desktop-headless start
```

### 6) One-shot env file

```bash
mkdir -p ~/.config/buzz-desktop-headless
cat > ~/.config/buzz-desktop-headless/env <<'EOF'
export BD_BUZZ_CMD=/usr/bin/buzz-desktop
export BD_DISPLAY=101
export BD_VNC_PORT=5911
export BD_NOVNC_PORT=6180
export BD_BIND=127.0.0.1
# optional relay:
# export BUZZ_RELAY_URL=ws://127.0.0.1:3000
# export BUZZ_AUTO_CONNECT_DEFAULT_RELAY=1
EOF

set -a
source ~/.config/buzz-desktop-headless/env
set +a
buzz-desktop-headless start
```

### 7) Prove the install (CI-style / any server)

```bash
cd buzz-desktop-headless

# no Desktop binary required:
./scripts/smoke-test.sh
./scripts/verify-server.sh
# or: make smoke && make verify

# full GUI path (needs packages + Desktop binary):
BD_FUNCTIONAL=1 BD_BUZZ_CMD=/usr/bin/buzz-desktop ./scripts/verify-server.sh
# uses isolated :111 / 5921 / 6190, then stops — safe beside a personal stack
```

### 8) systemd user service

```bash
mkdir -p ~/.config/systemd/user
cp /path/to/buzz-desktop-headless/systemd/buzz-desktop-headless.service \
  ~/.config/systemd/user/

# optional drop-in for binary + relay
mkdir -p ~/.config/systemd/user/buzz-desktop-headless.service.d
cat > ~/.config/systemd/user/buzz-desktop-headless.service.d/override.conf <<'EOF'
[Service]
Environment=BD_BUZZ_CMD=/usr/bin/buzz-desktop
Environment=BD_BIND=127.0.0.1
# Environment=BUZZ_RELAY_URL=ws://127.0.0.1:3000
EOF

systemctl --user daemon-reload
systemctl --user enable --now buzz-desktop-headless.service
systemctl --user status buzz-desktop-headless.service
# linger so it survives logout (optional):
# loginctl enable-linger "$USER"
```

### 9) Password-protected VNC (non-loopback bind only if you must)

Still prefer SSH. If you bind beyond localhost:

```bash
mkdir -p ~/.config/buzz-desktop-headless
x11vnc -storepasswd ~/.config/buzz-desktop-headless/vnc.pass

export BD_VNC_PASSWORD_FILE=~/.config/buzz-desktop-headless/vnc.pass
export BD_BIND=0.0.0.0          # requires password file
export BD_BUZZ_CMD=/usr/bin/buzz-desktop
buzz-desktop-headless start
# firewall + network policy are your responsibility
```

### 10) Screenshot + logs when something looks wrong

```bash
buzz-desktop-headless status
buzz-desktop-headless screenshot /tmp/buzz-headless.png
ls -la "${BD_STATE_DIR:-$HOME/.local/state/buzz-desktop-headless}/logs/"
tail -n 50 "${BD_STATE_DIR:-$HOME/.local/state/buzz-desktop-headless}/logs/buzz-desktop.log"
tail -n 50 "${BD_STATE_DIR:-$HOME/.local/state/buzz-desktop-headless}/logs/x11vnc.log"
```

### 11) Two users on one machine (isolated state)

```bash
# user alice
export BD_STATE_DIR=$HOME/.local/state/buzz-desktop-headless
export BD_DISPLAY=101 BD_VNC_PORT=5911 BD_NOVNC_PORT=6180
buzz-desktop-headless start

# user bob (different ports + state)
export BD_STATE_DIR=$HOME/.local/state/buzz-desktop-headless
export BD_DISPLAY=121 BD_VNC_PORT=5931 BD_NOVNC_PORT=6280
export BD_BUZZ_CMD=/usr/bin/buzz-desktop
buzz-desktop-headless start
```

---

## Architecture

```text
  Laptop browser
        │  SSH tunnel :6180
        ▼
  websockify / noVNC  ──►  x11vnc :5911  ──►  Xvfb :101
                                                    │
                                         fluxbox / openbox / …
                                                    │
                                              Buzz Desktop
                                                    │
                              (optional)  BUZZ_RELAY_URL → buzz-relay
```

| Layer | Default | Role |
|-------|---------|------|
| Xvfb | `:101` | Virtual framebuffer |
| WM | fluxbox → openbox → icewm | Windows for the client |
| Desktop | `buzz-desktop` / `BD_BUZZ_CMD` | GUI client (you install) |
| x11vnc | `127.0.0.1:5911` | RFB |
| noVNC | `127.0.0.1:6180` | Browser |

Ports are chosen to **avoid clashing** with similar headless tools that often use `:99` / `5901` / `6080`.

---

## Commands

| Command | Purpose |
|---------|---------|
| `start [--no-vnc] [--bind ADDR] [--display N]` | Bring stack up |
| `stop` / `restart` | Tear down / bounce |
| `status` | Health + PIDs |
| `url` | noVNC / VNC / SSH hints |
| `screenshot [path.png]` | Capture virtual display |
| `doctor [--install-hints]` | Deps + distro install line |
| `restart-vnc` | Refresh x11vnc flags only |
| `version` / `help` | Meta |

---

## Prove it works (any Linux server)

```bash
# Always safe (no Desktop required):
./scripts/smoke-test.sh
./scripts/verify-server.sh

# Full stack (Desktop binary + packages installed):
BD_FUNCTIONAL=1 ./scripts/verify-server.sh
```

Functional mode uses an **isolated** display/ports (`:111` / `5921` / `6190` by default) so it won’t stomp a personal stack, then **stops** cleanly.

CI runs the offline path on every push: [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

---

## Environment

| Variable | Default | Notes |
|----------|---------|-------|
| `BD_DISPLAY` | `101` | X display |
| `BD_GEOMETRY` | `1920x1080x24` | Xvfb geometry |
| `BD_VNC_PORT` | `5911` | RFB |
| `BD_NOVNC_PORT` | `6180` | Browser |
| `BD_BIND` | `127.0.0.1` | Listen address |
| `BD_STATE_DIR` | `~/.local/state/buzz-desktop-headless` | PIDs + logs |
| `BD_BUZZ_CMD` / `BUZZ_DESKTOP_CMD` | auto / `buzz-desktop` | Prefer **absolute** path to the real binary |
| `BUZZ_RELAY_URL` | _(empty)_ | Optional remote relay for the client |
| `BUZZ_AUTO_CONNECT_DEFAULT_RELAY` | _(empty)_ | Client auto-join when supported |
| `BD_WM` | auto | Prefer a WM |
| `BD_VNC_PASSWORD_FILE` | _(empty)_ | **Required** if bind ≠ loopback |
| `BD_WAIT_BUZZ_SEC` | `60` | Desktop ready timeout |
| `BD_SKIP_VNC` | `0` | Via `start --no-vnc` |

---

## Security

1. **Loopback by default** — nothing public on the WAN  
2. Non-loopback bind **refused** without `BD_VNC_PASSWORD_FILE`  
3. Prefer **SSH tunnel** (or a private mesh VPN you control)

```bash
mkdir -p ~/.config/buzz-desktop-headless
x11vnc -storepasswd ~/.config/buzz-desktop-headless/vnc.pass
export BD_VNC_PASSWORD_FILE=~/.config/buzz-desktop-headless/vnc.pass
```

Details: [SECURITY.md](SECURITY.md).

---

## systemd (user)

```bash
mkdir -p ~/.config/systemd/user
cp systemd/buzz-desktop-headless.service ~/.config/systemd/user/
# edit paths/env if needed
systemctl --user daemon-reload
systemctl --user enable --now buzz-desktop-headless.service
```

Keep `BD_BIND=127.0.0.1` unless you harden deliberately.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Missing X server or $DISPLAY` | Use this stack, not bare `buzz-desktop` |
| Doctor MISS packages | `./scripts/install.sh --packages` |
| Doctor MISS Desktop | Install binary; `export BD_BUZZ_CMD=/usr/bin/buzz-desktop` |
| Wrong binary / shell wrapper | Set absolute `BD_BUZZ_CMD` to the real ELF |
| Port / display busy | `BD_DISPLAY=102 BD_VNC_PORT=5912 BD_NOVNC_PORT=6181 start` |
| noVNC blank | Use URL from `url` (`resize=remote`); `restart-vnc` |
| Stale lock | `stop`; clear Desktop singleton files if still stuck |

Logs: `$BD_STATE_DIR/logs/`.

---

## Development

```bash
make smoke          # offline unit checks
make doctor
./scripts/verify-server.sh
BD_FUNCTIONAL=1 ./scripts/verify-server.sh
```

See [CONTRIBUTING.md](CONTRIBUTING.md) · [ABOUT.md](ABOUT.md).

---

## License

MIT — [LICENSE](LICENSE).

Buzz Desktop and any relay/backend remain under their upstream licenses. This project is only the headless display / VNC wrapper.

## Author

**Pablo Navarro** · [PabloTheThinker](https://github.com/PabloTheThinker)
