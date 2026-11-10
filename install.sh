#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/RonTheRentalCop/OPSEC.git"
INSTALL_DIR="${OPSEC_HOME:-$HOME/.local/share/opsec}"
BIN_DIR="$HOME/.local/bin"

say()  { printf '%s\n' "$*"; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

main() {
  if [ "$(id -u)" -eq 0 ]; then
    fail "do not run this installer as root or with sudo. It does not need it."
  fi

  command -v git >/dev/null 2>&1 || fail "git is not installed. Install git and try again."

  local script_dir=""
  if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi

  local source_dir
  if [ -n "$script_dir" ] && [ -f "$script_dir/bin/opsec" ]; then
    source_dir="$script_dir"
    say "Using the copy of OPSEC in $source_dir"
  elif [ -d "$INSTALL_DIR/.git" ]; then
    source_dir="$INSTALL_DIR"
    say "Updating OPSEC in $source_dir"
    git -C "$source_dir" pull --ff-only
  elif [ -e "$INSTALL_DIR" ]; then
    fail "$INSTALL_DIR already exists and is not an OPSEC download. Move it and try again."
  else
    source_dir="$INSTALL_DIR"
    say "Downloading OPSEC to $source_dir"
    mkdir -p "$(dirname "$source_dir")"
    git clone --depth 1 "$REPO_URL" "$source_dir"
  fi

  [ -f "$source_dir/bin/opsec" ] || fail "the download looks incomplete (bin/opsec is missing)."
  chmod +x "$source_dir/bin/opsec"

  mkdir -p "$BIN_DIR"
  if [ -e "$BIN_DIR/opsec" ] && [ ! -L "$BIN_DIR/opsec" ]; then
    fail "$BIN_DIR/opsec already exists and was not created by this installer. Move it and try again."
  fi
  ln -sfn "$source_dir/bin/opsec" "$BIN_DIR/opsec"

  say ""
  say "OPSEC is installed. No system settings were changed."
  case ":$PATH:" in
    *":$BIN_DIR:"*)
      say "Try it:  opsec tiers"
      ;;
    *)
      say "One more step: $BIN_DIR is not on your PATH yet."
      say "Add this line to your shell profile (~/.zshrc or ~/.bashrc), then open a new terminal:"
      say ""
      say "  export PATH=\"\$HOME/.local/bin:\$PATH\""
      say ""
      say "Or run it directly:  $BIN_DIR/opsec tiers"
      ;;
  esac
}

main "$@"
