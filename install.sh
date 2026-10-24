#!/usr/bin/env bash
set -euo pipefail

die() { echo "bable: $*" >&2; exit 2; }
find_brew() {
  { [ -x /opt/homebrew/bin/brew ] && echo /opt/homebrew/bin/brew; } || { [ -x /usr/local/bin/brew ] && echo /usr/local/bin/brew; } || true
}

main() {
  [ $# -eq 0 ] || die "usage: install.sh (no arguments)"
  [ "$(uname -s)" = Darwin ] || die "macOS only"
  [ "$(sw_vers -productVersion | cut -d. -f1)" -ge 14 ] || die "macOS 14 or newer is required"
  case "$(uname -m)" in arm64|x86_64) ;; *) die "unsupported CPU $(uname -m)" ;; esac
  [ "$(id -u)" != 0 ] || die "run as your normal user, not root"

  local t need=""
  for t in git gh node jq; do command -v "$t" >/dev/null || need=1; done
  if [ -n "$need" ] && ! command -v brew >/dev/null && [ -z "$(find_brew)" ]; then
    echo "bable: installing Homebrew (it asks for your password; needs an admin account)"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty \
      || die "Homebrew did not install (see its message above); install it from https://brew.sh and run this again"
    mkdir -p "$HOME/.local/state/bable"
    echo "brew brew" >> "$HOME/.local/state/bable/manifest"
  fi

  xcode-select -p >/dev/null 2>&1 || die "run: xcode-select --install"

  local src=${BASH_SOURCE[0]:-}
  if [ -n "$src" ] && [ -f "$src" ] && [ -x "$(dirname "$src")/bin/bable" ]; then
    src=$(cd "$(dirname "$src")" && pwd)
  else
    src=$HOME/.local/share/bable/src
    [ -d "$src" ] || git clone --depth 1 https://github.com/ayaangazali/bable.git "$src"
  fi

  mkdir -p "$HOME/.local/bin"
  ln -sfn "$src/bin/bable" "$HOME/.local/bin/bable"
  exec "$src/bin/bable" setup </dev/null
}

main "$@"
