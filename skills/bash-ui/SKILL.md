---
name: bash-ui
description: Use when writing or refactoring a bash script that needs consistent output — headers, status lines, spinners, prompts or tables. Covers loading bash-ui, choosing the right ui_* call, keeping stdout clean for data, and replacing raw colour codes.
---

# bash-ui

`ui.sh` is a single sourceable bash library that gives every script the same
look: one palette, one set of symbols, one vocabulary of output functions.
Human output goes to **stderr**; only data helpers write to stdout.

## Load it

Use this block at the top of the script. It finds a per-user or system install
and falls back to stubs so the script never hard-fails when the library is
missing.

```bash
# shellcheck source=/dev/null
for _f in "${BASH_UI:-}" "$HOME/.local/lib/bash-ui/ui.sh" /usr/local/lib/bash-ui/ui.sh; do
  if [[ -n $_f && -r $_f ]]; then
    source "$_f"
    break
  fi
done
command -v ui_ok >/dev/null 2>&1 || {
  ui_ok(){ printf 'OK: %s\n' "$*" >&2; }; ui_warn(){ printf 'WARN: %s\n' "$*" >&2; }
  ui_err(){ printf 'ERR: %s\n' "$*" >&2; }; ui_die(){ printf 'ERR: %s\n' "$*" >&2; exit "${2:-1}"; }
  ui_step(){ printf '> %s\n' "$*" >&2; }; ui_info(){ printf '%s\n' "$*" >&2; }
  ui_section(){ printf '== %s ==\n' "$*" >&2; }; ui_header(){ printf '== %s ==\n' "${1:-}" >&2; }
  ui_kv(){ printf '  %-14s %s\n' "${1:-}" "${2:-}" >&2; }; ui_list(){ printf '  - %s\n' "$@" >&2; }
  ui_hr(){ printf '%s\n' '----------------------------------------' >&2; }
  ui_style(){ shift; printf '%s' "$*"; }
  ui_confirm(){ if [[ ${UI_YES:-0} == 1 || ${2:-n} == y ]]; then return 0; fi; return 1; }
  ui_spin(){ local _m=${1:-}; shift; if [[ ${1:-} == -- ]]; then shift; fi
    if "$@" >&2; then ui_ok "$_m"; else local _rc=$?; ui_err "$_m (exit $_rc)"; return "$_rc"; fi; }
  ui_table(){ cat >&2; }
  ui_debug(){ :; }; ui_summary(){ :; }
}
```

`examples/template.sh` in the bash-ui repo is the ready-to-copy skeleton.

## Vocabulary

| Call | Use it for |
|---|---|
| `ui_header "Title" ["subtitle"]` | Once, at the very start of the script |
| `ui_section "Name"` | A major phase — "Check", "Migrate", "Report" |
| `ui_step "msg"` | An action about to happen, present continuous |
| `ui_ok "msg"` | The action succeeded, past tense |
| `ui_warn "msg"` | Something is off but the script continues |
| `ui_err "msg"` | A failure that is recorded but not fatal |
| `ui_info "msg"` | A neutral fact the user needs |
| `ui_debug "msg"` | Detail for `UI_VERBOSE=1` only |
| `ui_die "msg" [code]` | Fatal — prints an error and exits (default 1) |
| `ui_kv "Key" "Value"` | Aligned facts; add `--stdout` to emit data |
| `ui_list "item" …` | A short bulleted list |
| `ui_hr` | A rule between blocks |
| `ui_style <role> "text"` | Styled text on stdout for inline use |
| `ui_spin "msg" -- cmd …` | Any command that takes more than a moment |
| `ui_confirm "Question?" [y\|n]` | A yes/no decision |
| `ui_table` | TSV on stdin, aligned columns, bold header |
| `ui_summary` | Once, at the end, after multi-step work |

### section vs step vs info

- A **section** changes subject. There are usually three to six in a script.
- A **step** is one action inside a section, and it reads as "about to".
- **info** explains something the user did not ask for but needs: a path, a
  version, a decision the script made.
- If a line has no verb, it is probably `ui_info` or `ui_kv`, not `ui_step`.

### die vs err

- `ui_die` stops the script. Use it when continuing would make things worse:
  missing dependency, unwritable target, failed pre-flight check.
- `ui_err` records a failure and continues. Use it inside loops over sites,
  files or plugins, so one failure does not hide the rest.
- Both increment the error counter that `ui_summary` reports.

## Rules

1. **Never write raw escapes.** No `echo -e "\033[…"`, no `tput setaf`. The
   palette lives in `_ui_theme`; `ui_style` is the only public way to colour
   inline text.
2. **Data goes to stdout, everything human goes through `ui_*`.** A script that
   prints results with `printf` on stdout stays pipeable; status chatter on
   stderr never pollutes `result=$(script)` or `script | jq`.
3. **Wrap anything slow in `ui_spin`.** It captures output, prints it only on
   failure, and returns the command's exit status.
4. **End multi-step scripts with `ui_summary`.**
5. **Every prompt must work unattended.** `ui_confirm` already answers with its
   default when stdin is not a terminal; callers should also honour `UI_YES=1`.

## Refactor checklist

Converting an existing script:

1. Find every `echo -e`, `printf` with `\033`, and `tput` colour call.
2. Map each one to a `ui_*` call using the vocabulary table above.
3. Delete the local colour variables (`RED=`, `GREEN=`, `NC=`) — the library
   owns them now.
4. Check that the script's real output is still plain `printf` on stdout, and
   that nothing human-facing is on stdout.
5. Replace the banner with `ui_header` and the closing tally with `ui_summary`.
6. Wrap long `curl`/`rsync`/`mysqldump` calls in `ui_spin`.
7. Replace `read -rp "Continue? [y/N]"` with `ui_confirm`.
8. Run it four ways: a colour terminal, `NO_COLOR=1`, piped to a file, and
   `UI_ASCII=1`.

## Before and after

Before:

```bash
#!/usr/bin/env bash
RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
echo -e "\033[1m== Backing up example.com ==\033[0m"
echo "Checking disk space..."
if ! df -h / | tail -1 | awk '{print $5}' | grep -q '^[0-9]%$'; then
  echo -e "${RED}disk check failed${NC}" >&2
  exit 1
fi
echo -e "${GREEN}disk ok${NC}"
read -rp "Continue? [y/N] " a
[[ $a == y ]] || exit 0
mysqldump example > /tmp/example.sql 2>/dev/null
echo -e "${GREEN}backup written${NC}"
```

After:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$HOME/.local/lib/bash-ui/ui.sh"

ui_header "Backup" "example.com"
ui_section "Pre-flight"
ui_step "Checking disk space"
if df -h / | tail -1 | awk '{print $5}' | grep -q '^[0-9]%$'; then
  ui_ok "Disk space available"
else
  ui_die "Not enough disk space"
fi
ui_confirm "Continue?" y || { ui_info "Aborted by user"; exit 0; }
ui_spin "Dumping database" -- sh -c 'mysqldump example > /tmp/example.sql'
ui_summary
```

The after version has no colour variables, no raw escapes, one banner, one
prompt that survives a cron run, and a summary the operator can read at a
glance.
