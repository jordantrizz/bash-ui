# bash-ui

A single sourceable bash library that gives every script the same look: one
palette, one set of symbols, one vocabulary of output functions.

- **Zero dependencies.** Pure bash 4.2+, using only coreutils and `tput`.
- **Vendored, not installed.** A project commits one file and its checksum, so
  the version is visible in every pull request and CI can prove it is current.
- **Safe for automation.** Colour, animation and prompts switch themselves off
  for pipes, cron and CI, so logs stay clean.
- **Human output on stderr.** `result=$(myscript)` and `myscript | jq` keep
  working.
- **Stable API.** Public names are `ui_*` functions and `UI_*` environment
  variables, versioned with semver. While the version is `0.x` a minor bump may
  break callers, so pin what you vendor.

## Add it to a project

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jordantrizz/bash-ui/main/scripts/bash-ui.sh) init
```

That writes two files:

```
vendor/bash-ui/ui.sh          # the library, pinned
vendor/bash-ui/ui.sh.sha256   # proves it matches the published release
```

Commit both, then source it:

```bash
source "$(dirname "${BASH_SOURCE[0]}")/../vendor/bash-ui/ui.sh"
```

`examples/template.sh` is the ready-to-copy skeleton: it also honours `$BASH_UI`
and falls back to stub functions so a script never hard-fails when the library
is missing.

### Keep it current

```bash
curl -fsSL https://raw.githubusercontent.com/jordantrizz/bash-ui/main/scripts/bash-ui.sh | bash -s -- check
curl -fsSL https://raw.githubusercontent.com/jordantrizz/bash-ui/main/scripts/bash-ui.sh | bash -s -- update
```

`update` downloads the latest release, verifies the checksum, replaces the file
atomically and rewrites any inline regions it finds. Pin a specific release with
`--version 0.2.0`, or point at a mirror with `BASH_UI_SOURCE`.

### Check it in CI

No tool required — the file states its own version:

```yaml
- name: bash-ui is current
  run: |
    pinned=$(sed -n 's/^UI_VERSION="\(.*\)"$/\1/p' vendor/bash-ui/ui.sh)
    latest=$(curl -fsSL https://api.github.com/repos/jordantrizz/bash-ui/releases/latest \
      | sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p')
    if [ "$pinned" != "$latest" ]; then
      echo "vendor/bash-ui is $pinned, latest is $latest — run the updater"
      exit 1
    fi
    cd vendor/bash-ui && sha256sum -c ui.sh.sha256
```

`init --ci` writes that workflow for you.

### Shellcheck

Vendored code is linted by your project's own shellcheck run. Either exclude it:

```bash
shellcheck $(git ls-files '*.sh' ':!:vendor/')
```

or list `vendor/` in `source-path` in `.shellcheckrc`.

### Single-file scripts

Scripts shipped as one file keep the library inline. Mark the region once:

```bash
# >>> bash-ui 0.2.0 >>>
…the library…
# <<< bash-ui <<<
```

Then `bash scripts/bash-ui.sh inline script.sh` rewrites it, and
`inline --check` exits non-zero when it goes stale:

```yaml
- name: Check inlined bash-ui
  run: |
    curl -fsSL https://raw.githubusercontent.com/jordantrizz/bash-ui/main/scripts/bash-ui.sh \
      | bash -s -- inline --check path/to/script.sh
```

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

## Rollout

1. **Add the library to the project.** `init` vendors it and prints the source
   line; commit `vendor/bash-ui/`.
2. **Start every new script from `examples/template.sh`.**
3. **Refactor existing scripts with the skill.** `skills/bash-ui/SKILL.md` has
   the vocabulary table, the five rules and a refactor checklist.
   Highest-traffic scripts first.
4. **Single-file scripts use the inline markers**, checked in CI with
   `inline --check`.
5. **Optionally let a release open the PR for you.** Call the reusable workflow
   from the consumer repo:

   ```yaml
   jobs:
     bash-ui:
       uses: jordantrizz/bash-ui/.github/workflows/sync-inline.yml@main
       permissions:
         contents: write
         pull-requests: write
   ```

## Develop

```bash
shellcheck ui.sh scripts/bash-ui.sh examples/*.sh
bats tests/
NO_COLOR=1 bash examples/demo.sh 2>&1 | cat   # eyeball the plain output
bash examples/demo.sh                          # eyeball the coloured output
```

See `AGENTS.md` for the ground rules and `PLAN.md` for the design.
