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
source "$HOME/.local/lib/bash-ui/ui.sh"
```

`examples/template.sh` is the ready-to-copy skeleton: it also looks in
`$BASH_UI` and `/usr/local/lib/bash-ui/`, and falls back to stub functions so a
script never hard-fails when the library is missing. Use it as the starting
point for every new script.

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
| `ui_spin "msg" -- cmd …` | Run a command with a spinner, then report ok/err with its exit code |
| `ui_confirm "Question?" [default]` | y/n prompt; returns 0/1 |
| `ui_table` | Read TSV from stdin, print aligned columns with a bold header |
| `ui_summary` | End-of-run tally of the ok/warn/err counts |
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
| `UI_YES=1` | Answer every `ui_confirm` with yes |
| `UI_BACKEND=gum` | Use gum for `ui_spin`/`ui_confirm` when it is installed |
| `UI_TIMESTAMPS=1` | Prefix lines with `HH:MM:SS` |
| `UI_KV_WIDTH=14` | Key column width for `ui_kv` |
| `UI_APP_NAME` | Name shown by `ui_header` (defaults to the script name) |
| `CI` | Treat the run as non-interactive |

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/jordantrizz/bash-ui/main/install.sh | bash
```

That installs `ui.sh` to `~/.local/lib/bash-ui/` and the `bash-ui` CLI to
`~/.local/bin/` (or under `/usr/local` when run as root). Use
`./install.sh --prefix DIR` for somewhere else.

| Command | What it does |
|---|---|
| `bash-ui version` | Print the installed library version |
| `bash-ui check` | Exit 1 when a newer release exists |
| `bash-ui update [--major]` | Verify the checksum and replace `ui.sh` atomically |
| `bash-ui demo` | Run the bundled demo from a checkout |
| `bash-ui inline <file>` | Sync the `# >>> bash-ui x.y.z >>>` region in a script |
| `bash-ui inline --check <file>` | Exit non-zero when the inlined copy is stale |
| `bash-ui install-timer` | Schedule a daily `update --quiet` (systemd user timer, or cron) |

## Develop

```bash
shellcheck ui.sh examples/*.sh
bats tests/
NO_COLOR=1 bash examples/demo.sh 2>&1 | cat   # eyeball the plain output
bash examples/demo.sh                          # eyeball the coloured output
```

See `AGENTS.md` for the ground rules and `PLAN.md` for the design.
