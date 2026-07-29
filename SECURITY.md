# Security policy

## Supported versions

| Version | Supported |
|---------|-----------|
| 0.1.x   | Yes |
| < 0.1   | Best-effort |

## Reporting a vulnerability

Open a **private** GitHub security advisory on
[PabloTheThinker/buzz-desktop-headless](https://github.com/PabloTheThinker/buzz-desktop-headless)
or contact the maintainer via GitHub. Do **not** file a public issue with
exploit details for auth/bind mistakes.

## Hardening defaults

- Binds **127.0.0.1** only unless you override `BD_BIND`
- Non-loopback bind **requires** `BD_VNC_PASSWORD_FILE`
- Prefer SSH tunnel or a private mesh VPN over public exposure of noVNC
- VNC without a password on a public interface is **unsafe**
- This tool does **not** start or secure a Buzz relay; treat `BUZZ_RELAY_URL` and Desktop credentials as separate secrets

### Recommended access path

```bash
# On the server: keep BD_BIND=127.0.0.1 (default)
buzz-desktop-headless start

# On your client:
ssh -N -L 6180:127.0.0.1:6180 -L 5911:127.0.0.1:5911 user@server
# open http://127.0.0.1:6180/vnc.html?...
```

### If you must bind non-loopback

```bash
mkdir -p ~/.config/buzz-desktop-headless
x11vnc -storepasswd ~/.config/buzz-desktop-headless/vnc.pass
export BD_VNC_PASSWORD_FILE=~/.config/buzz-desktop-headless/vnc.pass
export BD_BIND=0.0.0.0   # still pair with firewall / private network
```

Do not publish VNC or noVNC ports to the open internet without authentication, TLS termination you control, and network policy.

## Trust boundary

| Component | Trust notes |
|-----------|-------------|
| Xvfb + WM | Local processes; anyone with shell on the host can often attach |
| x11vnc / noVNC | Full interactive control of the Desktop session — treat like a remote keyboard |
| Buzz Desktop binary | Third-party app; keep it updated via its own upstream |
| buzz-relay (external) | Out of scope for this repo; harden and authenticate separately |

## What not to commit

- Secrets, API tokens, `.env`, VNC password files
- Personal home paths, private hostnames, mesh/VPN addresses
- Unredacted Desktop screenshots (session titles, `cwd`, project paths, account UI)

Run before every push:

```bash
gitleaks detect --source . --no-git
git grep -nE '/home/|BEGIN .*PRIVATE|vnc\.pass|API_KEY|SECRET' -- .
```

## Scope

Security reports for **this repository** (launcher scripts, bind/password guards, install docs) are in scope.

Issues solely in Buzz Desktop, buzz-relay, Xvfb, x11vnc, or noVNC should go to those upstream projects unless this wrapper mishandles them (for example forcing insecure defaults).
