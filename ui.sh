#!/usr/bin/env bash
# ui.sh — bash-ui: one palette, one set of symbols, one vocabulary of output.
#
# Source this file. It defines ui_* functions and UI_* globals and nothing else.
# Human output goes to stderr; only ui_style, ui_kv --stdout and documented data
# helpers write to stdout. Sourcing it has no side effects: no shell options, no
# traps, no cd, no network.

# Source guard: sourcing twice is a no-op.
if [[ -n ${_UI_LOADED:-} ]]; then
  if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
    return 0
  fi
  exit 0
fi
_UI_LOADED=1

UI_VERSION="1.0.0"

# --- Capability detection (once, at source time) ---------------------------

_UI_TTY=0
if [[ -t 2 ]]; then
  _UI_TTY=1
fi

# Colour: NO_COLOR wins, then UI_COLOR, then a TTY with a colour terminal.
_UI_COLOR=0
if [[ -z ${NO_COLOR+x} && ${UI_COLOR:-auto} != never ]]; then
  if [[ ${UI_COLOR:-auto} == always ]]; then
    _UI_COLOR=1
  elif (( _UI_TTY )); then
    if [[ $(tput colors 2>/dev/null || printf 0) -ge 8 ]]; then
      _UI_COLOR=1
    fi
  fi
fi

_UI_RESET=''
if (( _UI_COLOR )); then
  _UI_RESET=$'\033[0m'
fi

# UTF-8 symbols unless the locale says otherwise or UI_ASCII is set.
_UI_UTF8=0
case ${LC_ALL:-${LC_CTYPE:-${LANG:-}}} in
  *[Uu][Tt][Ff]-8* | *[Uu][Tt][Ff]8*) _UI_UTF8=1 ;;
esac
if [[ -n ${UI_ASCII:-} ]]; then
  _UI_UTF8=0
fi

# Terminal width: COLUMNS, then tput, then 80.
_UI_WIDTH=80
if [[ ${COLUMNS:-} =~ ^[0-9]+$ ]] && (( COLUMNS >= 40 )); then
  _UI_WIDTH=$COLUMNS
elif (( _UI_TTY )); then
  _UI_WIDTH=$(tput cols 2>/dev/null || printf 80)
  if [[ ! ${_UI_WIDTH} =~ ^[0-9]+$ ]] || (( _UI_WIDTH < 40 )); then
    _UI_WIDTH=80
  fi
fi

# gum is optional and only used when explicitly requested.
_UI_HAS_GUM=0
if [[ ${UI_BACKEND:-} == gum ]] && command -v gum >/dev/null 2>&1; then
  _UI_HAS_GUM=1
fi

_UI_TIMESTAMPS=0
if [[ ${UI_TIMESTAMPS:-0} == 1 ]]; then
  _UI_TIMESTAMPS=1
fi

# Status counters, reported by ui_summary.
_UI_N_OK=0
_UI_N_WARN=0
_UI_N_ERR=0

# --- Private helpers -------------------------------------------------------

# _ui_theme <role> — set _UI_SGR for a role. The only place escapes live.
_ui_theme() {
  local role=${1:-}
  _UI_SGR=''
  if (( ! _UI_COLOR )); then
    return 0
  fi
  case $role in
    accent) _UI_SGR=$'\033[36m' ;;
    ok) _UI_SGR=$'\033[32m' ;;
    warn) _UI_SGR=$'\033[33m' ;;
    err) _UI_SGR=$'\033[31m' ;;
    info) _UI_SGR=$'\033[34m' ;;
    dim) _UI_SGR=$'\033[2m' ;;
    bold) _UI_SGR=$'\033[1m' ;;
    *) _UI_SGR='' ;;
  esac
  return 0
}

# _ui_symbol <kind> — set _UI_SYM to the UTF-8 or ASCII symbol for a message kind.
_ui_symbol() {
  local kind=${1:-}
  if (( _UI_UTF8 )); then
    case $kind in
      ok) _UI_SYM='✔' ;;
      warn) _UI_SYM='⚠' ;;
      err) _UI_SYM='✖' ;;
      info) _UI_SYM='ℹ' ;;
      step) _UI_SYM='›' ;;
      list) _UI_SYM='•' ;;
      *) _UI_SYM='·' ;;
    esac
  else
    case $kind in
      ok) _UI_SYM='[OK]' ;;
      warn) _UI_SYM='[!!]' ;;
      err) _UI_SYM='[XX]' ;;
      info) _UI_SYM='[i]' ;;
      step) _UI_SYM='>' ;;
      list) _UI_SYM='-' ;;
      *) _UI_SYM='.' ;;
    esac
  fi
  return 0
}

# _ui_prefix — set _UI_PREFIX to the HH:MM:SS prefix when UI_TIMESTAMPS=1.
_ui_prefix() {
  _UI_PREFIX=''
  if (( _UI_TIMESTAMPS )); then
    printf -v _UI_PREFIX '[%(%H:%M:%S)T] ' -1
  fi
  return 0
}

# _ui_fill <width> — set _UI_FILL to a horizontal rule of the given width.
_ui_fill() {
  local width=${1:-0}
  local char='─'
  if (( ! _UI_UTF8 )); then
    char='-'
  fi
  local blanks=''
  printf -v blanks '%*s' "$width" ''
  _UI_FILL=${blanks// /$char}
  return 0
}

# _ui_msg <role> <kind> <message…> — print one symbol-prefixed line to stderr.
_ui_msg() {
  local role=${1:-}
  local kind=${2:-}
  shift 2
  _ui_theme "$role"
  _ui_symbol "$kind"
  _ui_prefix
  printf '%s%s%s%s %s\n' "$_UI_PREFIX" "$_UI_SGR" "$_UI_SYM" "$_UI_RESET" "$*" >&2
  return 0
}

# _ui_rule — print a dim full-width rule to stderr.
_ui_rule() {
  _ui_theme dim
  _ui_fill "$_UI_WIDTH"
  printf '%s%s%s\n' "$_UI_SGR" "$_UI_FILL" "$_UI_RESET" >&2
  return 0
}

# --- Public API ------------------------------------------------------------

# ui_header "Title" ["subtitle"] — script banner: rule, title, subtitle, script
# name and library version. Returns 0.
ui_header() {
  local title=${1:-}
  local subtitle=${2:-}
  local name=${UI_APP_NAME:-${0##*/}}
  local bold='' dim=''
  local sep='·'
  if (( ! _UI_UTF8 )); then
    sep='-'
  fi
  _ui_theme bold
  bold=$_UI_SGR
  _ui_theme dim
  dim=$_UI_SGR
  _ui_rule
  printf ' %s%s%s\n' "$bold" "$title" "$_UI_RESET" >&2
  if [[ -n $subtitle ]]; then
    printf ' %s%s%s\n' "$dim" "$subtitle" "$_UI_RESET" >&2
  fi
  printf ' %s%s %s bash-ui %s%s\n' "$dim" "$name" "$sep" "$UI_VERSION" "$_UI_RESET" >&2
  _ui_rule
  return 0
}

# ui_section "Name" — major phase heading: "── Name ────". Returns 0.
ui_section() {
  local name=${1:-}
  local lead='──'
  if (( ! _UI_UTF8 )); then
    lead='--'
  fi
  local pad=$(( _UI_WIDTH - 4 - ${#name} ))
  if (( pad < 3 )); then
    pad=3
  fi
  _ui_theme accent
  _ui_fill "$pad"
  printf '%s%s %s %s%s\n' "$_UI_SGR" "$lead" "$name" "$_UI_FILL" "$_UI_RESET" >&2
  return 0
}

# ui_step "msg" — an action about to happen. Suppressed by UI_QUIET=1. Returns 0.
ui_step() {
  if [[ ${UI_QUIET:-0} == 1 ]]; then
    return 0
  fi
  _ui_msg accent step "$@"
  return 0
}

# ui_ok "msg" — success line, counted for ui_summary. Suppressed by UI_QUIET=1.
ui_ok() {
  _UI_N_OK=$(( _UI_N_OK + 1 ))
  if [[ ${UI_QUIET:-0} == 1 ]]; then
    return 0
  fi
  _ui_msg ok ok "$@"
  return 0
}

# ui_warn "msg" — non-fatal warning, counted for ui_summary. Never suppressed.
ui_warn() {
  _UI_N_WARN=$(( _UI_N_WARN + 1 ))
  _ui_msg warn warn "$@"
  return 0
}

# ui_err "msg" — error, keep going, counted for ui_summary. Never suppressed.
ui_err() {
  _UI_N_ERR=$(( _UI_N_ERR + 1 ))
  _ui_msg err err "$@"
  return 0
}

# ui_info "msg" — neutral note. Suppressed by UI_QUIET=1. Returns 0.
ui_info() {
  if [[ ${UI_QUIET:-0} == 1 ]]; then
    return 0
  fi
  _ui_msg info info "$@"
  return 0
}

# ui_debug "msg" — dim note, only when UI_VERBOSE=1. Returns 0.
ui_debug() {
  if [[ ${UI_VERBOSE:-0} != 1 ]]; then
    return 0
  fi
  _ui_msg dim debug "$@"
  return 0
}

# ui_die "msg" [code] — print an error and exit (default code 1). Never returns.
ui_die() {
  local msg=${1:-}
  local code=${2:-1}
  ui_err "$msg"
  exit "$code"
}

# ui_kv "Key" "Value" / ui_kv --stdout "Key" "Value" — aligned key/value pair.
# Writes to stderr, or to stdout with --stdout. Returns 0.
ui_kv() {
  local to_stdout=0
  if [[ ${1:-} == --stdout ]]; then
    to_stdout=1
    shift
  fi
  local key=${1:-}
  local value=${2:-}
  local width=${UI_KV_WIDTH:-14}
  local pad=$(( width - ${#key} ))
  if (( pad < 1 )); then
    pad=1
  fi
  local bold=''
  _ui_theme bold
  bold=$_UI_SGR
  _ui_prefix
  if (( to_stdout )); then
    printf '  %s%s%s%*s%s\n' "$bold" "$key" "$_UI_RESET" "$pad" '' "$value"
  else
    printf '%s  %s%s%s%*s%s\n' "$_UI_PREFIX" "$bold" "$key" "$_UI_RESET" "$pad" '' "$value" >&2
  fi
  return 0
}

# ui_list "item" … — bulleted list on stderr. Returns 0.
ui_list() {
  local item
  _ui_symbol list
  _ui_theme dim
  for item in "$@"; do
    printf '  %s%s%s %s\n' "$_UI_SGR" "$_UI_SYM" "$_UI_RESET" "$item" >&2
  done
  return 0
}

# ui_hr — horizontal rule across the terminal width, on stderr. Returns 0.
ui_hr() {
  _ui_rule
  return 0
}

# ui_style <role> "text" — print styled text to stdout for inline use. Returns 0.
# Roles: accent, ok, warn, err, info, dim, bold.
ui_style() {
  local role=${1:-}
  shift || true
  _ui_theme "$role"
  printf '%s%s%s' "$_UI_SGR" "$*" "$_UI_RESET"
  return 0
}

# ui_summary — end-of-run tally of ok/warn/err counts, on stderr. Returns 0.
ui_summary() {
  local sep='·'
  if (( ! _UI_UTF8 )); then
    sep='-'
  fi
  local bold='' ok_sgr='' warn_sgr='' err_sgr=''
  _ui_theme bold
  bold=$_UI_SGR
  _ui_theme ok
  ok_sgr=$_UI_SGR
  _ui_theme warn
  warn_sgr=$_UI_SGR
  _ui_theme err
  err_sgr=$_UI_SGR
  _ui_prefix
  printf '%s%sDone:%s %s%d ok%s %s %s%d warnings%s %s %s%d errors%s\n' \
    "$_UI_PREFIX" "$bold" "$_UI_RESET" \
    "$ok_sgr" "$_UI_N_OK" "$_UI_RESET" "$sep" \
    "$warn_sgr" "$_UI_N_WARN" "$_UI_RESET" "$sep" \
    "$err_sgr" "$_UI_N_ERR" "$_UI_RESET" >&2
  return 0
}
