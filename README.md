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
