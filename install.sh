#!/usr/bin/env bash
# install.sh — install bash-ui for the current user or system-wide.
#
#   curl -fsSL https://raw.githubusercontent.com/jordantrizz/bash-ui/main/install.sh | bash
#   ./install.sh --prefix /opt/bash-ui
#
# BASH_UI_SOURCE points at a directory or release URL to install from; it
# exists for mirrors, air-gapped hosts and tests.

set -euo pipefail

BASH_UI_REPO="jordantrizz/bash-ui"
BASH_UI_URL="https://github.com/$BASH_UI_REPO"
PREFIX=""

usage() {
  printf '%s\n' \
    "usage: install.sh [--prefix DIR]" \
    "" \
    "  --prefix DIR   install under DIR (default: /usr/local for root, ~/.local otherwise)" \
    "  -h, --help     show this help" \
    "" \
    "Environment:" \
    "  BASH_UI_SOURCE   directory or release URL to install from"
}

while (( $# )); do
  case $1 in
    --prefix)
      PREFIX=${2:-}
      [[ -n $PREFIX ]] || {
        printf 'install.sh: --prefix needs a directory\n' >&2
        exit 1
      }
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'install.sh: unknown option: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [[ -z $PREFIX ]]; then
  if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
    PREFIX=/usr/local
  else
    PREFIX="$HOME/.local"
  fi
fi

LIB_DIR="$PREFIX/lib/bash-ui"
BIN_DIR="$PREFIX/bin"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

fetch() {
  local name=$1 dest=$2
  if [[ -n ${BASH_UI_SOURCE:-} && -d ${BASH_UI_SOURCE} ]]; then
    cp "$BASH_UI_SOURCE/$name" "$dest"
    return
  fi
  local base=${BASH_UI_SOURCE:-$BASH_UI_URL/releases/latest/download}
  curl -fsSL "$base/$name" -o "$dest"
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    return 1
  fi
}

printf 'Installing bash-ui into %s\n' "$PREFIX" >&2

fetch ui.sh "$tmpdir/ui.sh"
fetch ui.sh.sha256 "$tmpdir/ui.sh.sha256"
fetch bash-ui "$tmpdir/bash-ui"

expected=$(awk '{print $1; exit}' "$tmpdir/ui.sh.sha256")
if actual=$(sha256_of "$tmpdir/ui.sh"); then
  if [[ $expected != "$actual" ]]; then
    printf 'install.sh: checksum mismatch for ui.sh\n' >&2
    exit 1
  fi
else
  printf 'install.sh: no sha256 tool available, skipping verification\n' >&2
fi

mkdir -p "$LIB_DIR" "$BIN_DIR"
install -m 0644 "$tmpdir/ui.sh" "$LIB_DIR/ui.sh"
install -m 0755 "$tmpdir/bash-ui" "$BIN_DIR/bash-ui"

version=$(sed -n 's/^UI_VERSION="\(.*\)"$/\1/p' "$LIB_DIR/ui.sh" | head -1)
printf 'Installed bash-ui %s\n' "$version" >&2
printf '  library: %s\n' "$LIB_DIR/ui.sh" >&2
printf '  CLI:     %s\n' "$BIN_DIR/bash-ui" >&2

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    printf '\nAdd %s to your PATH, for example:\n' "$BIN_DIR" >&2
    # shellcheck disable=SC2016  # $PATH stays literal: it is text for the user to paste.
    printf '  export PATH="%s:$PATH"\n' "$BIN_DIR" >&2
    ;;
esac
