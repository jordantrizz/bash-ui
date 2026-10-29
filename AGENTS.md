# AGENTS.md — bash-ui

Instructions for AI agents (Claude Code, OpenCode, Copilot, etc.) working in this repo.

## What this repo is

`bash-ui` is a single-file bash library, `ui.sh`, that standardizes terminal output for all of Jordan's (LMT Solutions) scripts. Other repos depend on it by sourcing it or by inlining it. **Treat `ui.sh` as a public API.** See `PLAN.md` for the full design, phases and open questions.

## Ground rules

1. **Don't break callers.**
   - Public names are `ui_*` functions and `UI_*` env vars.
   - Never rename or remove one, or change its arguments or exit codes, without a major version bump. Ask before making any breaking change.
2. **One runtime file.** `ui.sh` must stay self-contained: no sourcing other files and no external commands beyond coreutils and `tput`. `gum` is optional and always behind a fallback.
3. **Human output goes to stderr.** Only explicit data helpers may write to stdout. Every new function needs a test proving it writes nothing to stdout.
4. **Namespace discipline.**
   - Public: `ui_*`. Private: `_ui_*`. Globals: `UI_*` / `_UI_*`.
   - Don't define anything else, don't leak loop variables (use `local`), and don't alias.
5. **No side effects on source.**
   - Don't set shell options (`set -e/-u/-o pipefail`), traps, or `IFS`.
   - Make no network calls, and don't change the caller's working directory.
   - Must work when the caller has `set -euo pipefail` on: guard unset vars with `${VAR:-}`, and make sure no command returns non-zero unexpectedly.
6. **Degrade gracefully.**
   - Honour `NO_COLOR`, `UI_COLOR=auto|always|never`, `UI_ASCII`, `UI_QUIET`, `UI_VERBOSE`, `UI_YES` and `CI`.
   - Non-TTY output must contain no ANSI escapes and no spinner frames.
7. **Compatibility.**
   - Target bash 4.2+.
   - Until the macOS question in PLAN.md is settled, avoid bash-5-only features (`${var@Q}`, `EPOCHREALTIME`, `wait -n -p`) and note in the PR if you add anything bash-4-only.
8. **Theme lives in one place** (`_ui_theme`). Never hard-code escape sequences outside it.

## Code style

- `shellcheck` clean, with no blanket disables. Inline `# shellcheck disable=SCxxxx` is OK only with a reason comment.
- Use `printf`, not `echo -e`.
- 2-space indent, `[[ ]]` for tests, and quote everything.
- Every public function gets a one-line comment header: purpose, args, return code.
- Keep functions small. `ui.sh` should stay readable top to bottom; aim for under about 600 lines.

## Workflow for changes

1. Update or add bats tests in `tests/ui.bats` first:
   - no-color text snapshots
   - stdout-is-empty checks
   - exit codes
2. Implement it in `ui.sh`.
3. If it's user-visible, add it to `examples/demo.sh`.
4. If the public API changed, update `skills/bash-ui/SKILL.md` too. **The skill must always match the library.**
5. Update `CHANGELOG.md` under `## Unreleased`.
6. Run the checks locally:
   ```bash
   shellcheck ui.sh install.sh bin/bash-ui examples/*.sh
   bats tests/
   NO_COLOR=1 bash examples/demo.sh 2>&1 | cat   # eyeball the plain output
   bash examples/demo.sh                          # eyeball the coloured output
   ```

## Releasing (only when asked)

1. Bump `VERSION` and `UI_VERSION` in `ui.sh`. CI checks they match.
2. Move the `Unreleased` CHANGELOG entries under the new version.
3. Tag `vX.Y.Z` and push. `release.yml` builds the assets and checksum and creates the GitHub Release.

Never push tags, create releases, or trigger dispatch to consumer repos unless Jordan explicitly asks.

## Don't

- Don't add dependencies (jq, python, gum as required, etc.).
- Don't add an argument parser, config file handling, or TUI widgets to `ui.sh`. Those are out of scope (see PLAN.md non-goals).
- Don't auto-update or phone home from `ui.sh` at runtime. Update logic lives in `bin/bash-ui` and `install.sh` only.
- Don't commit secrets or tokens. The dispatch PAT lives in GitHub Actions secrets.
