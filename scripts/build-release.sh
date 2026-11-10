#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(sed -n 's/^VERSION="\([0-9.]*\).*/\1/p' "$ROOT/bin/opsec")"
DIST="$ROOT/dist"
FILES="bin lib configs tiers vm crypto keys windows install.sh LICENSE Legal.md README.md"

[ -n "$VERSION" ] || { echo "Could not read the version from bin/opsec" >&2; exit 1; }

export COPYFILE_DISABLE=1

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT

rm -rf "$DIST"
mkdir -p "$DIST" "$stage/opsec"

(cd "$ROOT" && tar -cf - $FILES) | (cd "$stage/opsec" && tar -xf -)
touch "$stage/opsec/.opsec-release"

tar -C "$stage" -czf "$DIST/opsec-$VERSION.tar.gz" opsec
(cd "$stage" && zip -qrX "$DIST/opsec-$VERSION-windows.zip" opsec)

cat "$ROOT/scripts/installer-header.sh" "$DIST/opsec-$VERSION.tar.gz" >"$DIST/opsec-installer.sh"
chmod +x "$DIST/opsec-installer.sh"

cd "$DIST"
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum opsec-* >SHA256SUMS
else
  shasum -a 256 opsec-* >SHA256SUMS
fi

if [ -n "${OPSEC_SIGNING_KEY:-}" ]; then
  rm -f SHA256SUMS.sig
  ssh-keygen -q -Y sign -f "$OPSEC_SIGNING_KEY" -n opsec-release SHA256SUMS
  ssh-keygen -q -Y verify -f "$ROOT/keys/allowed_signers" -I opsec-release -n opsec-release \
    -s SHA256SUMS.sig <SHA256SUMS
  echo "Signed SHA256SUMS, and the signature matches keys/allowed_signers."
else
  echo "WARNING: this build is NOT signed. Set OPSEC_SIGNING_KEY to your release key" >&2
  echo "and build again before publishing. See 'For maintainers' in README.md." >&2
fi

echo "Built OPSEC $VERSION in $DIST:"
ls -1 "$DIST"
