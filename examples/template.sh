#!/usr/bin/env bash
# examples/template.sh — copy this file to start a new script.
#
# The load block below finds bash-ui in BASH_UI, the per-user install and the
# system install, and falls back to a minimal stub so the script never
# hard-fails when the library is missing.

set -euo pipefail

# shellcheck source=/dev/null
for _f in "${BASH_UI:-}" "$HOME/.local/lib/bash-ui/ui.sh" /usr/local/lib/bash-ui/ui.sh; do
  if [[ -n $_f && -r $_f ]]; then
    source "$_f"
    break
  fi
done

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
