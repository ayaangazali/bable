#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d)
T3=$(mktemp -d)
STUB=$(mktemp -d)
trap 'rm -rf "$T" "$T3" "$STUB"' EXIT
CASE=start

fail() {
  echo "FAIL [$CASE]: $*" >&2
  exit 1
}

in_home() {
  local home=$1 path=$2
  shift 2
  env -i HOME="$home" PATH="$path" USER="$USER" LOGNAME="${LOGNAME:-$USER}" TMPDIR="${TMPDIR:-/tmp}" \
    BABLE_NO_SERVICES=1 BABLE_REPO="file://$ROOT" "$@"
}

run_bable() { in_home "$T" "$PATH" "$@"; }

snapshot() {
  find "$T/.local" "$T/.omp" "$T/.acpx" "$T/.no-mistakes" "$T/.config/herdr" "$T/Library/LaunchAgents" "$T/.zprofile" \
    -type f -exec shasum {} + -exec stat -f '%m %N' {} + | sort
}

CASE="fresh install"
mkdir -p "$T/.no-mistakes"
echo 'sentinel: 1' > "$T/.no-mistakes/config.yaml"
cp "$T/.no-mistakes/config.yaml" "$STUB/sentinel"
(cd "$ROOT" && run_bable ./install.sh) > "$STUB/out1" 2>&1 || { cat "$STUB/out1"; fail "install.sh exited non-zero"; }
[ -L "$T/.local/bin/bable" ] || fail "no ~/.local/bin/bable"
[ "$(git -C "$T/firstmate" branch --show-current)" = main ] || fail "firstmate not on main"
[ "$(cat "$T/firstmate/config/backend")" = herdr ] || fail "firstmate backend not herdr"
for f in .omp/agent/config.yml .omp/agent/lsp.json .acpx/config.json .config/herdr/config.toml; do
  [ -f "$T/$f" ] || fail "missing seeded $f"
done
for l in herdr stall-nudge; do
  plutil -lint -s "$T/Library/LaunchAgents/dev.bable.$l.plist" || fail "dev.bable.$l.plist invalid"
done
grep -q 'bable: [0-9]* changed' "$STUB/out1" || fail "no change count"

CASE="first-write"
cmp -s "$STUB/sentinel" "$T/.no-mistakes/config.yaml" || fail "existing config overwritten"
grep -qF '.no-mistakes/config.yaml (left untouched)' "$STUB/out1" || fail "existing config not reported as kept"

CASE="idempotent"
before=$(snapshot)
run_bable "$T/.local/bin/bable" setup > "$STUB/out2" 2>&1 || { cat "$STUB/out2"; fail "second setup exited non-zero"; }
grep -q 'bable: 0 changed' "$STUB/out2" || { cat "$STUB/out2"; fail "second setup changed something"; }
[ "$(snapshot)" = "$before" ] || fail "second setup rewrote files"

CASE="status"
run_bable "$T/.local/bin/bable" status > "$STUB/out3" 2>&1 || { cat "$STUB/out3"; fail "status exited non-zero"; }
grep -q '^  [a-z]* *gh ' "$STUB/out3" || fail "no gh line"
grep -q 'omp sign-in' "$STUB/out3" || fail "no omp sign-in line"
if grep -q '^  miss' "$STUB/out3"; then cat "$STUB/out3"; fail "status reports missing items"; fi

CASE="uninstall"
run_bable "$T/.local/bin/bable" uninstall > "$STUB/out4" 2>&1 || { cat "$STUB/out4"; fail "uninstall exited non-zero"; }
! ls "$T/Library/LaunchAgents"/dev.bable.* >/dev/null 2>&1 || fail "plists left behind"
[ ! -e "$T/.local/bin/bable" ] || fail "bable link left behind"
[ ! -e "$T/.local/bin/treehouse" ] || fail "release tool left behind"
[ ! -e "$T/.omp/agent/config.yml" ] || fail "unmodified seed left behind"
cmp -s "$STUB/sentinel" "$T/.no-mistakes/config.yaml" || fail "user config removed"
[ -d "$T/firstmate/.git" ] || fail "firstmate removed"
[ ! -e "$T/.zprofile" ] || fail "empty .zprofile left behind"
[ ! -e "$T/.omp" ] || fail "empty seed folder left behind"
[ ! -e "$T/Library/Logs/bable" ] || fail "log folder left behind"
run_bable "$ROOT/bin/bable" uninstall > "$STUB/out5" 2>&1 || { cat "$STUB/out5"; fail "second uninstall exited non-zero"; }

CASE="piped install, herdr already on PATH"
cat > "$STUB/herdr" <<'EOF'
#!/bin/sh
[ "$1 $2" = "status server" ] && echo "status: not running"
exit 0
EOF
chmod +x "$STUB/herdr"
(cd "$T3" && in_home "$T3" "$STUB:$PATH" bash < "$ROOT/install.sh") > "$STUB/out6" 2>&1 || { cat "$STUB/out6"; fail "piped install exited non-zero"; }
[ -x "$T3/.local/share/bable/src/bin/bable" ] || fail "no clone in ~/.local/share/bable/src"
herdr=$(plutil -extract ProgramArguments.0 raw "$T3/Library/LaunchAgents/dev.bable.herdr.plist")
[ "$herdr" = "$STUB/herdr" ] || fail "plist uses $herdr, not the herdr already on PATH"
[ ! -e "$T3/.local/bin/herdr" ] || fail "installed a second herdr"
in_home "$T3" "$STUB:$PATH" "$T3/.local/bin/bable" uninstall > "$STUB/out7" 2>&1 || { cat "$STUB/out7"; fail "uninstall exited non-zero"; }
[ ! -e "$T3/.local/share/bable" ] || fail ".local/share/bable left behind"

echo "e2e: all cases passed"
