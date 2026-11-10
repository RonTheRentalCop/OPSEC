#!/usr/bin/env bash

set -euo pipefail

INSTALL_DIR="${OPSEC_HOME:-$HOME/.local/share/opsec}"

TMP_DIR=""
trap '[ -z "$TMP_DIR" ] || rm -rf "$TMP_DIR"' EXIT

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

main() {
  if [ "$(id -u)" -eq 0 ]; then
    fail "do not run this installer as root or with sudo. It does not need it."
  fi
  if [ -d "$INSTALL_DIR/.git" ]; then
    fail "OPSEC in $INSTALL_DIR was installed with git. Update it by running $INSTALL_DIR/install.sh instead."
  fi
  if [ -e "$INSTALL_DIR" ] && [ ! -f "$INSTALL_DIR/.opsec-release" ]; then
    fail "$INSTALL_DIR already exists and is not an OPSEC install. Move it and try again."
  fi

  local line
  TMP_DIR="$(mktemp -d)"

  line="$(awk '/^__OPSEC_ARCHIVE__$/ { print NR + 1; exit }' "$0")"
  [ -n "$line" ] || fail "this installer file is damaged. Download it again."
  tail -n +"$line" "$0" | tar -xzf - -C "$TMP_DIR" || fail "this installer file is damaged. Download it again."
  [ -f "$TMP_DIR/opsec/bin/opsec" ] || fail "this installer file is incomplete. Download it again."

  rm -rf "$INSTALL_DIR"
  mkdir -p "$(dirname "$INSTALL_DIR")"
  mv "$TMP_DIR/opsec" "$INSTALL_DIR"

  "$INSTALL_DIR/install.sh"
}

main "$@"
exit 0
__OPSEC_ARCHIVE__
