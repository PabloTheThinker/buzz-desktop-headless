# About buzz-desktop-headless

<p align="center">
  <strong>A small, honest tool</strong><br/>
  <sub>Put Buzz Desktop on a headless Linux server and open it in a browser.</sub>
</p>

---

## One sentence

**buzz-desktop-headless** starts a virtual display, a window manager, the Buzz Desktop GUI client, and a localhost VNC/noVNC path so you can use Desktop from any machine with SSH + a browser.

## Why it exists

Servers that run agents often have **no monitor**. The Buzz Desktop app still expects a graphical session.  
Instead of shipping a one-off Xvfb script per host, this repo packages the **standard** stack:

```text
Xvfb → WM → Buzz Desktop → x11vnc → noVNC
```

…behind a single CLI with safe defaults.

### Benefits in plain language

- **Use the real Desktop UI** on a headless box — not a degraded CLI-only substitute  
- **Open it in a browser** after an SSH tunnel — works from café Wi‑Fi to office laptop  
- **Keep secrets on the server** — tunnel in; don’t copy agent keys to every personal machine  
- **Stay boring and safe** — localhost bind, optional password if you leave loopback  
- **Ship with confidence** — smoke + functional verify scripts match what CI runs  

## Boundaries (important)

| In scope | Out of scope |
|----------|--------------|
| Virtual display + VNC access to **Desktop** | Installing or distributing Buzz Desktop |
| Optional env pass-through (`BUZZ_RELAY_URL`, …) | Running or bundling **buzz-relay** / ACP agents |
| Portable bash on common Linux distros | macOS / Windows native GUI hosts |
| Localhost bind + SSH tunnel docs | Public internet exposure by default |

If you only need relay + agents, you do **not** need this project.

## Design principles

1. **Safe by default** — bind `127.0.0.1`; password required off-loopback  
2. **One command** — `start` / `stop` / `status` / `url` / `doctor`  
3. **Portable** — Debian/Ubuntu, Fedora, Arch, openSUSE package hints  
4. **Isolated verify** — `BD_FUNCTIONAL=1 ./scripts/verify-server.sh` uses alternate ports  
5. **No cosplay** — clear non-affiliation with upstream Desktop vendors  
6. **Honest docs** — Desktop binary is your responsibility  

## Defaults

| | |
|--|--|
| Display | `:101` |
| VNC | `127.0.0.1:5911` |
| noVNC | `127.0.0.1:6180` |
| State | `~/.local/state/buzz-desktop-headless` |

Chosen to reduce collisions with other headless GUI stacks that often use `:99` / `5901` / `6080`.

## Related

- Sibling pattern: [hermes-desktop-headless](https://github.com/PabloTheThinker/hermes-desktop-headless)  
- Buzz ecosystem (Desktop / relay / agents): install from upstream Buzz sources separately  

## Author

**Pablo Navarro** ([@PabloTheThinker](https://github.com/PabloTheThinker))  
MIT licensed — see [LICENSE](LICENSE).
