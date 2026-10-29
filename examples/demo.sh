#!/usr/bin/env bash
# examples/demo.sh — exercises every public bash-ui function.
#
#   bash examples/demo.sh              # coloured, interactive
#   NO_COLOR=1 bash examples/demo.sh   # plain
#   UI_ASCII=1 bash examples/demo.sh   # ASCII symbols
#   UI_VERBOSE=1 bash examples/demo.sh # show ui_debug

set -uo pipefail

# The library sits one directory up; the path is resolved at runtime.
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/../ui.sh"

ui_header "bash-ui demo" "Every public function in one script"

ui_section "Messages"
ui_step "A step describes an action that is about to happen"
ui_ok "A success line, counted by the summary"
ui_warn "A warning that does not stop the script"
ui_err "An error that does not stop the script either"
ui_info "A neutral note"
ui_debug "Only visible when UI_VERBOSE=1"

ui_section "Layout"
ui_kv "Library" "bash-ui $UI_VERSION"
ui_kv "Shell" "bash ${BASH_VERSION%%(*}"
ui_kv "Colour" "$([[ $_UI_COLOR == 1 ]] && printf on || printf off)"
ui_kv "Symbols" "$([[ $_UI_UTF8 == 1 ]] && printf utf-8 || printf ascii)"
ui_list "First bullet" "Second bullet" "Third bullet"
ui_hr

ui_section "Table"
printf 'SITE\tPHP\tSTATUS\nexample.com\t8.2\tok\nstaging.example.com\t8.1\twarn\n' | ui_table

ui_section "Interaction"
ui_spin "Waiting 0.3s" -- sleep 0.3
if ui_confirm "Proceed with the demo?" y; then
  ui_ok "Confirmed"
else
  ui_warn "Declined (a non-interactive run uses the default)"
fi

ui_section "Inline styling"
ui_info "Status: $(ui_style ok 'all good') / $(ui_style warn 'degraded') / $(ui_style err 'failed')"

ui_section "Summary"
ui_summary

exit 0
