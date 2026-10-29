# bash-ui

A single sourceable bash library that gives every script the same look: one
palette, one set of symbols, one vocabulary of output functions.

- **Zero dependencies.** Pure bash 4.2+, using only coreutils and `tput`.
- **Safe for automation.** Colour, animation and prompts switch themselves off
  for pipes, cron and CI, so logs stay clean.
- **Stable API.** Public names are `ui_*` functions and `UI_*` environment
  variables, versioned with semver.
- **Human output on stderr.** `result=$(myscript)` and `myscript | jq` keep
  working.

## Load it

```bash
# shellcheck source=/dev/null
for _f in "${BASH_UI:-}" "$HOME/.local/lib/bash-ui/ui.sh" /usr/local/lib/bash-ui/ui.sh; do
  [[ -n $_f && -r $_f ]] && { source "$_f"; break; }
done
command -v ui_ok >/dev/null 2>&1 || {   # minimal fallback so scripts never hard-fail
  ui_ok(){ echo "OK: $*" >&2; }; ui_warn(){ echo "WARN: $*" >&2; }
  ui_err(){ echo "ERR: $*" >&2; }; ui_die(){ echo "ERR: $*" >&2; exit "${2:-1}"; }
  ui_step(){ echo "> $*" >&2; }; ui_info(){ echo "$*" >&2; }; ui_section(){ echo "== $* ==" >&2; }
  ui_header(){ echo "== $* ==" >&2; }; ui_kv(){ printf '  %-14s %s\n' "$1" "$2" >&2; }
  ui_debug(){ :; }; ui_summary(){ :; }
}
```

`examples/template.sh` is a ready-to-copy script skeleton that uses it.

## API

| Function | Purpose |
|---|---|
| `ui_header "Title" ["subtitle"]` | Script banner with the script name and library version |
| `ui_section "Name"` | Major phase of a script |
| `ui_step "msg"` | An action about to happen |
| `ui_ok "msg"` | Success |
| `ui_warn "msg"` | Non-fatal problem |
| `ui_err "msg"` | Error, keep going |
| `ui_info "msg"` | Neutral note |
| `ui_debug "msg"` | Only when `UI_VERBOSE=1` |
| `ui_die "msg" [code]` | `ui_err` then exit (default 1) |
| `ui_kv "Key" "Value"` | Aligned key/value pair; `--stdout` writes to stdout |
| `ui_list "item" …` | Bulleted list |
| `ui_hr` | Horizontal rule across the terminal width |
| `ui_style <role> "text"` | Styled text on stdout for inline use |

Roles for `ui_style`: `accent`, `ok`, `warn`, `err`, `info`, `dim`, `bold`.

## Environment

| Variable | Effect |
|---|---|
| `NO_COLOR` | Set to anything to disable colour |
| `UI_COLOR=auto\|always\|never` | Force or forbid colour (`auto` is the default) |
| `UI_ASCII=1` | ASCII symbols instead of UTF-8 |
| `UI_QUIET=1` | Suppress step/info/ok lines; warnings and errors always show |
| `UI_VERBOSE=1` | Enable `ui_debug` |
| `UI_TIMESTAMPS=1` | Prefix lines with `HH:MM:SS` |
| `UI_KV_WIDTH=14` | Key column width for `ui_kv` |
| `UI_APP_NAME` | Name shown by `ui_header` (defaults to the script name) |
| `CI` | Treat the run as non-interactive |

## Develop

```bash
shellcheck ui.sh examples/*.sh
bats tests/
NO_COLOR=1 bash examples/demo.sh 2>&1 | cat   # eyeball the plain output
bash examples/demo.sh                          # eyeball the coloured output
```

See `AGENTS.md` for the ground rules and `PLAN.md` for the design.
