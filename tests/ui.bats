#!/usr/bin/env bats
# tests/ui.bats — public API behaviour in no-colour ASCII mode.
#
# Every human-output function is checked for: exact text on stderr, nothing on
# stdout, and its documented exit code.

bats_require_minimum_version 1.5.0

setup() {
  export NO_COLOR=1
  export UI_ASCII=1
  export UI_KV_WIDTH=14
  unset UI_QUIET UI_VERBOSE UI_YES UI_TIMESTAMPS UI_BACKEND CI UI_APP_NAME
  # shellcheck disable=SC1091
  source "$BATS_TEST_DIRNAME/../ui.sh"
}

# capture <command…> — run a command with stdout and stderr captured to files.
# Sets CAP_STATUS, CAP_OUT and CAP_ERR. Files keep leading spaces, which bats'
# own stderr capture strips from the first line.
capture() {
  local out="$BATS_TEST_TMPDIR/out"
  local err="$BATS_TEST_TMPDIR/err"
  : >"$out"
  : >"$err"
  CAP_STATUS=0
  "$@" >"$out" 2>"$err" || CAP_STATUS=$?
  CAP_OUT=$(cat "$out")
  CAP_ERR=$(cat "$err")
}

@test "UI_VERSION matches the VERSION file" {
  run cat "$BATS_TEST_DIRNAME/../VERSION"
  [ "$status" -eq 0 ]
  [ "$UI_VERSION" = "$output" ]
}

@test "sourcing twice is a no-op" {
  run bash -c 'source "$1"; source "$1"; ui_ok once' _ "$BATS_TEST_DIRNAME/../ui.sh"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = "[OK] once" ]
}

@test "ui_ok writes one line to stderr and nothing to stdout" {
  capture ui_ok "done"
  [ "$CAP_STATUS" -eq 0 ]
  [ "$CAP_OUT" = "" ]
  [ "$CAP_ERR" = "[OK] done" ]
}

@test "ui_warn writes one line to stderr and nothing to stdout" {
  capture ui_warn "careful"
  [ "$CAP_STATUS" -eq 0 ]
  [ "$CAP_OUT" = "" ]
  [ "$CAP_ERR" = "[!!] careful" ]
}

@test "ui_err writes one line to stderr and nothing to stdout" {
  capture ui_err "broke"
  [ "$CAP_STATUS" -eq 0 ]
  [ "$CAP_OUT" = "" ]
  [ "$CAP_ERR" = "[XX] broke" ]
}

@test "ui_step writes one line to stderr and nothing to stdout" {
  capture ui_step "starting"
  [ "$CAP_STATUS" -eq 0 ]
  [ "$CAP_OUT" = "" ]
  [ "$CAP_ERR" = "> starting" ]
}

@test "ui_info writes one line to stderr and nothing to stdout" {
  capture ui_info "note"
  [ "$CAP_STATUS" -eq 0 ]
  [ "$CAP_OUT" = "" ]
  [ "$CAP_ERR" = "[i] note" ]
}

@test "ui_debug is silent unless UI_VERBOSE=1" {
  capture ui_debug "detail"
  [ "$CAP_STATUS" -eq 0 ]
  [ "$CAP_ERR" = "" ]

  UI_VERBOSE=1 capture ui_debug "detail"
  [ "$CAP_ERR" = ". detail" ]
}

@test "ui_header shows the title, subtitle, script name and version" {
  UI_APP_NAME="demo.sh" capture ui_header "Demo" "Sub"
  [ "$CAP_STATUS" -eq 0 ]
  [ "$CAP_OUT" = "" ]
  [[ $CAP_ERR == *"Demo"* ]]
  [[ $CAP_ERR == *"Sub"* ]]
  [[ $CAP_ERR == *"demo.sh - bash-ui $UI_VERSION"* ]]
}

@test "ui_section starts with a ruled heading" {
  capture ui_section "Check"
  [ "$CAP_STATUS" -eq 0 ]
  [ "$CAP_OUT" = "" ]
  [[ $CAP_ERR == "-- Check ---"* ]]
}

@test "ui_hr spans the terminal width with ASCII rules" {
  capture ui_hr
  [ "$CAP_STATUS" -eq 0 ]
  [ "$CAP_OUT" = "" ]
  [ "${#CAP_ERR}" -eq 80 ]
  [[ $CAP_ERR =~ ^-+$ ]]
}

@test "ui_kv pads keys to UI_KV_WIDTH on stderr" {
  local expected
  printf -v expected '  %-14s%s' "Key" "Value"
  capture ui_kv "Key" "Value"
  [ "$CAP_STATUS" -eq 0 ]
  [ "$CAP_OUT" = "" ]
  [ "$CAP_ERR" = "$expected" ]
}

@test "ui_kv --stdout writes the pair to stdout" {
  local expected
  printf -v expected '  %-14s%s' "Key" "Value"
  capture ui_kv --stdout "Key" "Value"
  [ "$CAP_STATUS" -eq 0 ]
  [ "$CAP_ERR" = "" ]
  [ "$CAP_OUT" = "$expected" ]
}

@test "ui_list writes one bulleted line per item" {
  capture ui_list "a" "b"
  [ "$CAP_STATUS" -eq 0 ]
  [ "$CAP_OUT" = "" ]
  [ "$CAP_ERR" = "  - a
  - b" ]
}

@test "ui_style returns plain text on stdout in no-colour mode" {
  capture ui_style ok "fine"
  [ "$CAP_STATUS" -eq 0 ]
  [ "$CAP_ERR" = "" ]
  [ "$CAP_OUT" = "fine" ]
}

@test "ui_summary reports the ok, warn and err counters" {
  ui_ok "a"
  ui_warn "b"
  ui_err "c"
  capture ui_summary
  [ "$CAP_STATUS" -eq 0 ]
  [ "$CAP_OUT" = "" ]
  [ "$CAP_ERR" = "Done: 1 ok - 1 warnings - 1 errors" ]
}

@test "ui_die prints an error and exits with the given code" {
  run --separate-stderr bash -c 'source "$1"; ui_die "fatal" 3' _ "$BATS_TEST_DIRNAME/../ui.sh"
  [ "$status" -eq 3 ]
  [[ $stderr == *"[XX] fatal"* ]]
}

@test "ui_confirm uses the default when non-interactive" {
  run ui_confirm "ok?" y
  [ "$status" -eq 0 ]
  run ui_confirm "ok?" n
  [ "$status" -eq 1 ]
}

@test "UI_YES=1 answers ui_confirm with yes" {
  UI_YES=1 run ui_confirm "ok?" n
  [ "$status" -eq 0 ]
}

@test "ui_spin reports success with the command's exit code" {
  run --separate-stderr ui_spin "waiting" -- true
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
  [ "$stderr" = "[OK] waiting" ]
}

@test "ui_spin reports failure, shows output and keeps the exit code" {
  run --separate-stderr ui_spin "failing" -- bash -c 'printf "boom\n"; exit 4'
  [ "$status" -eq 4 ]
  [[ $stderr == *"boom"* ]]
  [[ $stderr == *"[XX] failing (exit 4)"* ]]
}

@test "ui_table aligns columns from TSV and writes nothing to stdout" {
  capture bash -c 'source "$1"; printf "NAME\tV\nnginx\t1\n" | ui_table' _ "$BATS_TEST_DIRNAME/../ui.sh"
  [ "$CAP_STATUS" -eq 0 ]
  [ "$CAP_OUT" = "" ]
  [[ $CAP_ERR == *"  NAME   V"* ]]
  [[ $CAP_ERR == *"  nginx  1"* ]]
}

@test "UI_QUIET=1 hides step, info and ok but keeps warn and err" {
  UI_QUIET=1 capture bash -c \
    'source "$1"; ui_step s; ui_info i; ui_ok o; ui_warn w; ui_err e' _ "$BATS_TEST_DIRNAME/../ui.sh"
  [ "$CAP_ERR" = "[!!] w
[XX] e" ]
}

@test "UI_TIMESTAMPS=1 prefixes each line with HH:MM:SS" {
  UI_TIMESTAMPS=1 capture ui_ok "done"
  [[ $CAP_ERR =~ ^\[[0-9]{2}:[0-9]{2}:[0-9]{2}\]\ \[OK\]\ done$ ]]
}

@test "no ANSI escapes appear in no-colour mode" {
  capture bash -c \
    'source "$1"; ui_header T; ui_section S; ui_step s; ui_ok o; ui_warn w; ui_err e; ui_info i; ui_kv k v; ui_list a; ui_hr; ui_summary' \
    _ "$BATS_TEST_DIRNAME/../ui.sh"
  [ "$CAP_STATUS" -eq 0 ]
  [[ $CAP_ERR != *$'\033'* ]]
}

@test "the library works under set -euo pipefail" {
  run bash -c \
    'set -euo pipefail; source "$1"; ui_ok x; ui_kv k v; ui_confirm q y; printf "A\tB\n1\t2\n" | ui_table; ui_spin s -- true; ui_summary' \
    _ "$BATS_TEST_DIRNAME/../ui.sh"
  [ "$status" -eq 0 ]
}
