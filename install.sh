#!/usr/bin/env bash
set -euo pipefail

die() { echo "bable: $*" >&2; exit 2; }
find_brew() {
  { [ -x /opt/homebrew/bin/brew ] && echo /opt/homebrew/bin/brew; } || { [ -x /usr/local/bin/brew ] && echo /usr/local/bin/brew; } || true
}

main() {
  [ "$(uname -s)" = Darwin ] || die "macOS only"
  [ "$(sw_vers -productVersion | cut -d. -f1)" -ge 14 ] || die "macOS 14 or newer is required"
  case "$(uname -m)" in arm64|x86_64) ;; *) die "unsupported CPU $(uname -m)" ;; esac
  [ "$(id -u)" != 0 ] || die "run as your normal user, not root"

  if ! command -v brew >/dev/null; then
    local brew state=$HOME/.local/state/bable
    brew=$(find_brew)
    if [ -z "$brew" ]; then
      echo "bable: installing Homebrew"
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty \
        || die "Homebrew needs an admin account; run from an admin user or install Homebrew first"
      brew=$(find_brew)
      mkdir -p "$state"
      echo "brew brew" >> "$state/manifest"
    fi
    eval "$("$brew" shellenv bash)"
  fi

  xcode-select -p >/dev/null 2>&1 || die "run: xcode-select --install"

  local src=${BASH_SOURCE[0]:-}
  if [ -n "$src" ] && [ -f "$src" ] && [ -x "$(dirname "$src")/bin/bable" ]; then
    src=$(cd "$(dirname "$src")" && pwd)
  else
    src=$HOME/.local/share/bable/src
    [ -d "$src" ] || git clone --depth 1 "${BABLE_REPO:-https://github.com/ayaangazali/bable.git}" "$src"
  fi

  mkdir -p "$HOME/.local/bin"
  ln -sfn "$src/bin/bable" "$HOME/.local/bin/bable"
  exec "$src/bin/bable" setup </dev/null
}

main "$@"
