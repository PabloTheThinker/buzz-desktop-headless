#!/usr/bin/env bash
# Cross-distro install for buzz-desktop-headless (CLI only).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

say() { printf '==> %s\n' "$*"; }

install_packages() {
  # shellcheck disable=SC1091
  [[ -r /etc/os-release ]] && . /etc/os-release
  local id="${ID:-unknown}"
  say "os=$id"
  case "$id" in
    ubuntu|debian|linuxmint|pop|raspbian)
      sudo apt-get update -qq
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
        xvfb x11vnc novnc websockify fluxbox scrot dbus-x11 xdotool
      ;;
    fedora|rhel|centos|rocky|almalinux)
      sudo dnf install -y \
        xorg-x11-server-Xvfb x11vnc novnc python3-websockify fluxbox scrot dbus-x11 xdotool || \
      sudo dnf install -y xorg-x11-server-Xvfb x11vnc python3-websockify fluxbox ImageMagick dbus-x11 xdotool
      ;;
    arch|manjaro|endeavouros)
      sudo pacman -S --needed --noconfirm \
        xorg-server-xvfb x11vnc novnc python-websockify fluxbox scrot dbus xdotool
      ;;
    opensuse*|sles)
      sudo zypper --non-interactive install \
        xorg-x11-server-Xvfb x11vnc novnc python3-websockify fluxbox scrot dbus-1-x11 xdotool
      ;;
    *)
      say "unknown distro - install manually: Xvfb x11vnc noVNC websockify fluxbox scrot dbus-x11 xdotool"
      ;;
  esac
}

link_cli() {
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$ROOT/bin/buzz-desktop-headless" "$HOME/.local/bin/buzz-desktop-headless"
  ln -sfn "$ROOT/bin/buzz-desktop-headless-stop" "$HOME/.local/bin/buzz-desktop-headless-stop"
  chmod +x "$ROOT/bin/buzz-desktop-headless" "$ROOT/bin/buzz-desktop-headless-stop" 2>/dev/null || true
  say "linked: buzz-desktop-headless"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) say "add to PATH: export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
  esac
}

main() {
  local with_pkgs=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --packages) with_pkgs=1; shift ;;
      -h|--help)
        echo "Usage: $0 [--packages]"
        echo "  --packages  also install OS packages (needs sudo)"
        echo "Installs the headless CLI. Buzz Desktop binary is separate."
        exit 0
        ;;
      *) echo "unknown: $1" >&2; exit 1 ;;
    esac
  done
  if [[ "$with_pkgs" -eq 1 ]]; then
    install_packages
  fi
  link_cli
  say "done. next:"
  say "  # install Buzz Desktop binary on PATH (system package or release)"
  say "  buzz-desktop-headless doctor --install-hints"
  say "  buzz-desktop-headless start"
  say "  buzz-desktop-headless url"
}

main "$@"
