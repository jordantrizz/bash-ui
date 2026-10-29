#!/usr/bin/env bash
# examples/template.sh — copy this file to start a new script.
#
# It loads the vendored copy at vendor/bash-ui/ui.sh (or $BASH_UI) and falls
# back to a minimal stub so the script never hard-fails when the library is
# missing. Vendor it first with:
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/jordantrizz/bash-ui/main/scripts/bash-ui.sh) init

set -euo pipefail

# Locate the vendored library: $BASH_UI wins, otherwise the nearest
# vendor/bash-ui/ui.sh at or above this script's directory.
_ui_lib=${BASH_UI:-}
if [[ -z $_ui_lib ]]; then
  _ui_dir=$(dirname "${BASH_SOURCE[0]}")
  while [[ $_ui_dir != '/' && $_ui_dir != '.' ]]; do
    if [[ -r $_ui_dir/vendor/bash-ui/ui.sh ]]; then
      _ui_lib=$_ui_dir/vendor/bash-ui/ui.sh
      break
    fi
    _ui_dir=$(dirname "$_ui_dir")
  done
  if [[ -z $_ui_lib && -r ./vendor/bash-ui/ui.sh ]]; then
    _ui_lib=./vendor/bash-ui/ui.sh
  fi
fi

# shellcheck source=/dev/null
if [[ -n $_ui_lib ]]; then
  source "$_ui_lib"
fi

if ! command -v ui_ok >/dev/null 2>&1; then
  ui_ok() { printf 'OK: %s\n' "$*" >&2; }
  ui_warn() { printf 'WARN: %s\n' "$*" >&2; }
  ui_err() { printf 'ERR: %s\n' "$*" >&2; }
  ui_die() { printf 'ERR: %s\n' "$*" >&2; exit "${2:-1}"; }
  ui_step() { printf '> %s\n' "$*" >&2; }
  ui_info() { printf '%s\n' "$*" >&2; }
  ui_section() { printf '== %s ==\n' "$*" >&2; }
  ui_header() { printf '== %s ==\n' "${1:-}" >&2; }
  ui_kv() { printf '  %-14s %s\n' "${1:-}" "${2:-}" >&2; }
  ui_list() { printf '  - %s\n' "$@" >&2; }
  ui_hr() { printf '%s\n' '----------------------------------------' >&2; }
  ui_style() { shift; printf '%s' "$*"; }
  ui_confirm() { if [[ ${UI_YES:-0} == 1 || ${2:-n} == y ]]; then return 0; fi; return 1; }
  ui_spin() {
    local _m=${1:-}
    shift
    if [[ ${1:-} == -- ]]; then shift; fi
    if "$@" >&2; then
      ui_ok "$_m"
    else
      local _rc=$?
      ui_err "$_m (exit $_rc)"
      return "$_rc"
    fi
  }
  ui_table() { cat >&2; }
  ui_debug() { :; }
  ui_summary() { :; }
fi

main() {
  ui_header "my-script" "One line about what this script does"

  ui_section "Check"
  ui_step "Looking at the environment"
  if [[ -r /etc/os-release ]]; then
    ui_ok "Found /etc/os-release"
  else
    ui_warn "No /etc/os-release on this host"
  fi

  ui_section "Result"
  ui_kv "Host" "$(hostname 2>/dev/null || printf 'unknown')"
  ui_list "Data goes to stdout with plain printf" "Everything human-facing goes through ui_*"
  ui_summary
}

main "$@"
