#!/usr/bin/env bash
# scripts/bash-ui.sh — vendor, check and update bash-ui in a project.
#
#   bash scripts/bash-ui.sh init   [--path vendor/bash-ui/ui.sh] [--ci]
#   bash scripts/bash-ui.sh check  [--path P] [--inline GLOB]
#   bash scripts/bash-ui.sh update [--version X] [--path P] [--inline GLOB]
#   bash scripts/bash-ui.sh inline [--check] <file>
#
# This is a developer tool. It is fetched per run and never installed:
#
#   curl -fsSL https://raw.githubusercontent.com/jordantrizz/bash-ui/main/scripts/bash-ui.sh \
#     | bash -s -- update
#
# BASH_UI_SOURCE points at a directory or release URL to fetch from; it exists
# for mirrors, air-gapped hosts and tests.

set -uo pipefail

BASH_UI_REPO="jordantrizz/bash-ui"
BASH_UI_URL="https://github.com/$BASH_UI_REPO"
DEFAULT_PATH="vendor/bash-ui/ui.sh"

die() {
  printf 'bash-ui: %s\n' "$*" >&2
  exit 1
}

note() {
  printf '%s\n' "$*" >&2
}

usage() {
  sed -n '3,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# read_version <ui.sh> — print the UI_VERSION value.
read_version() {
  sed -n 's/^UI_VERSION="\(.*\)"$/\1/p' "$1" | head -1
}

# sha256_of <file> — print the hex digest, using whichever tool exists.
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    return 1
  fi
}

# verify <file> <sumfile> — true when the digest matches.
verify() {
  local file=$1 sumfile=$2 expected actual
  expected=$(awk '{print $1; exit}' "$sumfile")
  actual=$(sha256_of "$file") || return 2
  [[ $expected == "$actual" ]]
}

# latest_version — print the newest published version.
latest_version() {
  if [[ -n ${BASH_UI_SOURCE:-} && -d ${BASH_UI_SOURCE} ]]; then
    read_version "$BASH_UI_SOURCE/ui.sh"
    return
  fi
  local tag
  tag=$(curl -fsSL "https://api.github.com/repos/$BASH_UI_REPO/releases/latest" 2>/dev/null |
    sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -1)
  if [[ -z $tag ]]; then
    return 1
  fi
  printf '%s\n' "$tag"
}

# fetch <name> <dest> [version] — copy one release asset, latest when no version.
# A directory source may hold a v<version>/ subdirectory per release.
fetch() {
  local name=$1 dest=$2 version=${3:-}
  if [[ -n ${BASH_UI_SOURCE:-} && -d ${BASH_UI_SOURCE} ]]; then
    if [[ -n $version && -f "$BASH_UI_SOURCE/v$version/$name" ]]; then
      cp "$BASH_UI_SOURCE/v$version/$name" "$dest"
    else
      cp "$BASH_UI_SOURCE/$name" "$dest"
    fi
    return
  fi
  local base
  if [[ -n $version ]]; then
    base="$BASH_UI_URL/releases/download/v$version"
  else
    base="${BASH_UI_SOURCE:-$BASH_UI_URL/releases/latest/download}"
  fi
  curl -fsSL "$base/$name" -o "$dest"
}

# install_asset <path> [version] — download, verify and place one vendored copy.
install_asset() {
  local path=$1 version=${2:-}
  local dir
  dir=$(dirname "$path")
  mkdir -p "$dir"

  local tmp="$path.new.$$"
  local sumfile="$path.sha256.new.$$"

  if ! fetch ui.sh "$tmp" "$version"; then
    rm -f "$tmp"
    die "could not download ui.sh"
  fi
  if ! fetch ui.sh.sha256 "$sumfile" "$version"; then
    rm -f "$tmp" "$sumfile"
    die "could not download ui.sh.sha256"
  fi

  if ! verify "$tmp" "$sumfile"; then
    rm -f "$tmp" "$sumfile"
    die "checksum mismatch; keeping $path"
  fi

  chmod 0644 "$tmp"
  mv -f "$tmp" "$path"
  cp "$sumfile" "$path.sha256"
  rm -f "$sumfile"
}

# marker_files [glob] — print the files holding an inline region.
marker_files() {
  local glob=${1:-}
  if [[ -n $glob ]]; then
    # shellcheck disable=SC2086  # the caller supplies a glob on purpose.
    grep -l '^# >>> bash-ui ' $glob 2>/dev/null || true
    return
  fi
  grep -rl '^# >>> bash-ui ' --include='*.sh' \
    --exclude-dir=.git --exclude-dir=vendor --exclude-dir=node_modules . 2>/dev/null || true
}

# marker_version <file> — print the version in the file's opening marker.
marker_version() {
  sed -n 's/^# >>> bash-ui \(.*\) >>>$/\1/p' "$1" | head -1
}

# rewrite_markers <ui.sh> <version> <file> — replace the region in one file.
rewrite_markers() {
  local ui=$1 version=$2 file=$3
  local tmp="$file.tmp.$$"
  BASH_UI_VER="$version" BASH_UI_LIB="$ui" awk '
    BEGIN { in_region = 0 }
    /^# >>> bash-ui .* >>>$/ {
      print "# >>> bash-ui " ENVIRON["BASH_UI_VER"] " >>>"
      while ((getline line < ENVIRON["BASH_UI_LIB"]) > 0) {
        print line
      }
      close(ENVIRON["BASH_UI_LIB"])
      in_region = 1
      next
    }
    /^# <<< bash-ui <<<$/ {
      if (in_region) {
        print
        in_region = 0
        next
      }
    }
    in_region { next }
    { print }
    END { if (in_region) exit 3 }
  ' "$file" >"$tmp"
  local rc=$?
  if (( rc != 0 )); then
    rm -f "$tmp"
    die "unterminated bash-ui region in $file"
  fi
  cat "$tmp" >"$file"
  rm -f "$tmp"
}

cmd_init() {
  local path=$DEFAULT_PATH ci=0
  while (( $# )); do
    case $1 in
      --path) path=${2:-}; shift 2 ;;
      --ci) ci=1; shift ;;
      *) die "unknown option: $1" ;;
    esac
  done

  local latest
  latest=$(latest_version) || die "cannot determine the latest release"
  install_asset "$path" "$latest"

  note "Vendored bash-ui $latest into $path"
  note ""
  note "Source it from a script:"
  note "  source \"\$(dirname \"\${BASH_SOURCE[0]}\")/../$path\""
  note ""
  note "Check it in CI:"
  note "  bash scripts/bash-ui.sh check"

  if (( ci )); then
    local wf=".github/workflows/bash-ui.yml"
    mkdir -p "$(dirname "$wf")"
    cat >"$wf" <<EOF
name: bash-ui

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: bash-ui is current
        run: |
          pinned=\$(sed -n 's/^UI_VERSION="\\(.*\\)"\$/\\1/p' $path)
          latest=\$(curl -fsSL https://api.github.com/repos/$BASH_UI_REPO/releases/latest \\
            | sed -n 's/.*"tag_name": *"v\\([^"]*\\)".*/\\1/p')
          if [ "\$pinned" != "\$latest" ]; then
            echo "$path is \$pinned, latest is \$latest - run the updater"
            exit 1
          fi
          cd \$(dirname $path) && sha256sum -c \$(basename $path).sha256
EOF
    note ""
    note "Wrote $wf"
  fi
}

cmd_check() {
  local path=$DEFAULT_PATH glob=''
  while (( $# )); do
    case $1 in
      --path) path=${2:-}; shift 2 ;;
      --inline) glob=${2:-}; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done

  local latest failed=0
  latest=$(latest_version) || die "cannot determine the latest release"

  if [[ -f $path ]]; then
    local pinned
    pinned=$(read_version "$path")
    if [[ $pinned != "$latest" ]]; then
      note "$path: $pinned, latest is $latest"
      failed=1
    fi
    if [[ -f "$path.sha256" ]]; then
      if ! verify "$path" "$path.sha256"; then
        note "$path: checksum mismatch"
        failed=1
      fi
    else
      note "$path: no $path.sha256 (rerun init to add one)"
      failed=1
    fi
  else
    note "$path: not found"
    failed=1
  fi

  local file version
  while IFS= read -r file; do
    [[ -n $file ]] || continue
    version=$(marker_version "$file")
    if [[ $version != "$latest" ]]; then
      note "$file: $version, latest is $latest"
      failed=1
    fi
  done < <(marker_files "$glob")

  if (( failed == 0 )); then
    note "bash-ui $latest is current"
  fi
  return "$failed"
}

cmd_update() {
  local path=$DEFAULT_PATH glob='' target=''
  while (( $# )); do
    case $1 in
      --path) path=${2:-}; shift 2 ;;
      --inline) glob=${2:-}; shift 2 ;;
      --version) target=${2:-}; shift 2 ;;
      *) die "unknown option: $1" ;;
    esac
  done

  local version
  if [[ -n $target ]]; then
    version=$target
  else
    version=$(latest_version) || die "cannot determine the latest release"
  fi

  install_asset "$path" "$version"
  note "Vendored bash-ui $version into $path"

  local file
  while IFS= read -r file; do
    [[ -n $file ]] || continue
    rewrite_markers "$path" "$version" "$file"
    note "Inlined bash-ui $version into $file"
  done < <(marker_files "$glob")
}

cmd_inline() {
  local check=0 file=''
  while (( $# )); do
    case $1 in
      --check) check=1; shift ;;
      *) file=$1; shift ;;
    esac
  done
  [[ -n $file ]] || die "usage: bash-ui inline [--check] <file>"
  [[ -f $file ]] || die "no such file: $file"

  if ! grep -q '^# >>> bash-ui ' "$file"; then
    die "no '# >>> bash-ui <version> >>>' marker in $file"
  fi

  local version
  if [[ -f $DEFAULT_PATH ]]; then
    version=$(read_version "$DEFAULT_PATH")
  else
    version=$(latest_version) || die "cannot determine the latest release"
  fi

  if (( check )); then
    local embedded
    embedded=$(marker_version "$file")
    if [[ $embedded == "$version" ]]; then
      return 0
    fi
    note "$file: inlined bash-ui $embedded, current is $version"
    return 1
  fi

  local ui=$DEFAULT_PATH
  local tmp=''
  if [[ ! -f $ui ]]; then
    tmp=$(mktemp)
    if ! fetch ui.sh "$tmp" "$version"; then
      rm -f "$tmp"
      die "could not download ui.sh"
    fi
    ui=$tmp
  fi

  rewrite_markers "$ui" "$version" "$file"
  if [[ -n $tmp ]]; then
    rm -f "$tmp"
  fi
  note "Inlined bash-ui $version into $file"
}

main() {
  local cmd=${1:-}
  case $cmd in
    init) shift; cmd_init "$@" ;;
    check) shift; cmd_check "$@" ;;
    update) shift; cmd_update "$@" ;;
    inline) shift; cmd_inline "$@" ;;
    -h | --help | help | '') usage ;;
    *) die "unknown command: $cmd (try --help)" ;;
  esac
}

main "$@"
