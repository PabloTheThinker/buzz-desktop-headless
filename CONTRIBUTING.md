# Contributing

Thanks for improving **buzz-desktop-headless**.

## Dev loop

```bash
make check    # bash -n + shellcheck (if installed)
make smoke    # offline unit checks (Buzz Desktop optional)
make doctor   # full dependency report
```

Install OS stack packages when you need an end-to-end run:

```bash
./scripts/install.sh --packages
buzz-desktop-headless start
buzz-desktop-headless status
buzz-desktop-headless stop
```

## Guidelines

- Keep the CLI **bash-only** (no Python runtime required for the launcher).
- Prefer **portability**: new deps should resolve on Debian, Fedora, and Arch, or document a fallback.
- Security defaults stay **loopback-only** unless a VNC password file is set.
- Do not commit secrets, private hostnames, mesh/VPN IPs, or personal paths in screenshots/docs.
- Match existing style: small functions (`bd_*`), `set -euo pipefail`, no unnecessary abstraction.
- This project wraps the **Desktop GUI client only**. Do not fold a full buzz-relay implementation into the launcher without a clear design discussion.
- Be honest in docs: Buzz Desktop must be installed separately; this is not a full Buzz stack.

## PR checklist

- [ ] `make check` passes  
- [ ] `make smoke` passes  
- [ ] README updated if UX/env vars/commands change  
- [ ] SECURITY.md updated if bind/auth behavior changes  
- [ ] No sensitive data in commits  
- [ ] No invented screenshots or affiliation claims with upstream Desktop vendors  

## Scope tips

| Good fit | Usually out of scope here |
|----------|---------------------------|
| Distro package discovery | Vendoring Buzz Desktop binaries |
| VNC/noVNC UX defaults | Implementing buzz-relay mesh logic |
| Safer process lifecycle | Hosting/SaaS control planes |
| Docs, doctor, install | Product branding unrelated to headless ops |

## Communication

- Prefer small, focused PRs with a short “why” in the description.
- Link related issues when applicable.
- For security-sensitive findings, follow [SECURITY.md](SECURITY.md) (private advisory), not a public issue.

## License

By contributing, you agree that your contributions are licensed under the MIT License (see [LICENSE](LICENSE)).
