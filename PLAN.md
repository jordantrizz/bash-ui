# bash-ui — Plan

A single sourceable bash library (`ui.sh`) that gives every LMT script the same look: one palette, one set of symbols, one vocabulary of output functions. It ships with an AI skill so agents write scripts that use it, and an update path so installed copies stay current.

> Repo name: `bash-ui`; `ui.sh` stays the file name.

---

## Goals

- **Consistent.** Every script uses the same headers, status lines, colors and symbols.
- **Readable.** Status is obvious at a glance. Data and decoration never get mixed up.
- **Zero dependencies.** Pure bash, so it works on any client server (GridPane, RunCloud, bare Ubuntu/Debian). If `gum` is present, it can use it for richer output.
- **Safe for automation.** It auto-disables color and animation for pipes, cron and CI, and logs stay clean.
- **Stable API.** Scripts written today still work after updates, because the library follows semver.

## Non-goals

- A full TUI framework (windows, mouse, layouts). Use gum or bash-tui-toolkit for that.
- Argument parsing. That may come as a separate optional module later (`args.sh`), or bashly can handle it.
- POSIX `sh` support. The library is bash only.

---

## Phase 1 — `ui.sh` core library

### Repo layout

```
bash-ui/
├── ui.sh                  # the library (single file, the only runtime artifact)
├── VERSION                # semver, e.g. 1.0.0 — source of truth
├── CHANGELOG.md
├── install.sh             # installer / updater (Phase 3)
├── bin/
│   └── bash-ui             # CLI: version, update, check, demo, inline
├── skills/
│   └── bash-ui/SKILL.md    # AI skill (Phase 2)
├── examples/
│   ├── demo.sh            # shows every function (also used for screenshots)
│   └── template.sh        # starter script for new tools
├── tests/
│   └── ui.bats            # bats-core tests
├── .github/workflows/
│   ├── ci.yml
│   └── release.yml
├── AGENTS.md
└── README.md
```

### Design rules

1. **Everything goes to stderr, except `ui_kv` with `--stdout` and explicit data helpers.** `result=$(myscript)` and `myscript | jq` then keep working.
2. **Namespace.** Public functions are `ui_*`, private ones are `_ui_*`, globals are `UI_*`. Nothing else is defined.
3. **Source guard.** Sourcing the library twice is a no-op (`[[ -n ${_UI_LOADED:-} ]] && return 0`).
4. **No side effects on source.** It sets no `set -e`/`-u`, installs no traps, and makes no network calls. It must also work under the caller's `set -euo pipefail`.
5. **Capability detection happens once, at source time.** It checks for a TTY on stderr, color support (`tput colors`), UTF-8 locale, terminal width, and gum availability.
6. **Graceful degradation:**

   | Condition | Behaviour |
   |---|---|
   | `NO_COLOR` set, or `UI_COLOR=never`, or stderr isn't a TTY | No ANSI codes |
   | `UI_COLOR=always` | Force color (e.g. for `less -R`) |
   | Non-UTF-8 locale or `UI_ASCII=1` | ASCII symbols (`[OK]`, `[!!]`, `[XX]`, `>`) |
   | Not a TTY or `CI` set | Spinners become a single "…done" line |
   | `UI_BACKEND=gum` and gum is installed | Spin/confirm/choose/table use gum; otherwise plain bash |

7. **Bash version.** Target bash 4.2+. macOS's bash 3.2 support is an open question (see the end of this file).

### Public API (v1)

| Function | Purpose | Example output |
|---|---|---|
| `ui_header "Title" ["subtitle"]` | Script banner, once at start | Boxed or ruled title with the script name and version |
| `ui_section "Name"` | Major phase of a script | `── Checking PHP ─────────` |
| `ui_step "msg"` | An action about to happen | `› Restarting nginx` |
| `ui_ok "msg"` | Success | `✔ nginx restarted` (green) |
| `ui_warn "msg"` | Non-fatal problem | `⚠ 3 plugins outdated` (yellow) |
| `ui_err "msg"` | Error, keep going | `✖ Can't reach DB` (red) |
| `ui_info "msg"` | Neutral note | `ℹ Using site example.com` (blue) |
| `ui_debug "msg"` | Only when `UI_VERBOSE=1` | dimmed |
| `ui_die "msg" [code]` | `ui_err` + exit (default 1) | |
| `ui_kv "Key" "Value"` | Aligned key/value pairs | `  PHP version   8.2.12` |
| `ui_list "item" …` | Bulleted list | `  • item` |
| `ui_hr` | Horizontal rule, terminal width | |
| `ui_spin "msg" -- cmd args…` | Run a command with a spinner, then print ok/err with its exit code. Shows captured output on failure | |
| `ui_confirm "Question?" [default y\|n]` | y/n prompt. Returns 0/1. Uses the default when non-interactive or `UI_YES=1` | |
| `ui_table` | Read TSV from stdin and print aligned columns with a bold header | |
| `ui_summary` | End-of-run tally of ok/warn/err counts, which the status functions track automatically | `Done: 12 ok · 2 warnings · 0 errors` |
| `ui_style <role> "text"` | Return styled text for inline use (`role` = ok\|warn\|err\|info\|dim\|bold\|accent) | |

**Verbosity:** `UI_QUIET=1` suppresses step/info/ok; warnings and errors always show. `UI_VERBOSE=1` enables debug.

**Optional timestamps:** `UI_TIMESTAMPS=1` prefixes `HH:MM:SS`. This is useful for long migrations and cron logs.

### Theme

There is one palette, defined in one place (`_ui_theme`):

- accent = cyan (headers, sections)
- ok = green, warn = yellow, err = red, info = blue
- dim = grey (debug, secondary detail)
- bold for keys in `ui_kv` and table headers

It uses the 16-colour ANSI set only, so it looks right in any terminal and over SSH. A `UI_THEME` hook can come later; don't build it in v1.

### Phase 1 done when

- [ ] Every v1 function is implemented in `ui.sh`
- [ ] `examples/demo.sh` exercises every function
- [ ] Output looks right in a colour TTY, with `NO_COLOR=1`, piped to a file, and with `UI_ASCII=1`
- [ ] bats tests cover each function in no-color mode (snapshot the text) and check that nothing goes to stdout
- [ ] shellcheck passes clean
- [ ] `examples/template.sh` is a ready-to-copy script skeleton

---

## Phase 2 — AI skill

`skills/bash-ui/SKILL.md` lives in this repo, so the skill is versioned with the library it describes.

**Trigger:** writing a new bash script, refactoring an existing one, or "make this script's output consistent/nicer".

**Content:**
1. How to load the library (the standard snippet below).
2. The function vocabulary, with when to use each one: section vs step vs info, and when to `ui_die` vs `ui_err`.
3. Rules:
   - Never write raw `echo -e "\033[…"` or `tput` colour calls.
   - Data goes to stdout with plain `printf`; everything human-facing goes through `ui_*`.
   - Wrap long-running commands in `ui_spin`.
   - End multi-step scripts with `ui_summary`.
   - Any prompt must work non-interactively (`UI_YES`).
4. A refactor checklist for converting old scripts: find echo/printf with escapes, map them to `ui_*`, remove local colour variables, and check stdout is data only.
5. A before/after example.

**Standard load snippet** (in the template and the skill):

```bash
# shellcheck source=/dev/null
for _f in "${BASH_UI:-}" "$HOME/.local/lib/bash-ui/ui.sh" /usr/local/lib/bash-ui/ui.sh; do
  [[ -n $_f && -r $_f ]] && { source "$_f"; break; }
done
command -v ui_ok >/dev/null 2>&1 || {   # minimal fallback so scripts never hard-fail
  ui_ok(){ echo "OK: $*" >&2; }; ui_warn(){ echo "WARN: $*" >&2; }
  ui_err(){ echo "ERR: $*" >&2; }; ui_die(){ echo "ERR: $*" >&2; exit "${2:-1}"; }
  ui_step(){ echo "> $*" >&2; }; ui_info(){ echo "$*" >&2; }; ui_section(){ echo "== $* ==" >&2; }
  ui_header(){ echo "== $* ==" >&2; }; ui_kv(){ printf '  %-16s %s\n' "$1" "$2" >&2; }
  ui_debug(){ :; }; ui_summary(){ :; }
}
```

**Distribution:**
- Copy or sync it into the `lmt-skills` repo; `agentsync` can handle this if it already manages skills across repos.
- Optionally upload it to Claude as a skill so claude.ai sessions use it too.

### Phase 2 done when

- [ ] SKILL.md written and tested: ask an agent to refactor a real messy script and check the result follows the rules
- [ ] Synced into lmt-skills

---

## Phase 3 — Versioning, releases and updates

There are two kinds of consumers, so there are two update paths.

### A. Installed copy (workstations, homelab, servers you control)

**Install:**
```bash
curl -fsSL https://raw.githubusercontent.com/<owner>/bash-ui/main/install.sh | bash
```
- Per-user installs go to `~/.local/lib/bash-ui/`, and root installs go to `/usr/local/lib/bash-ui/`.
- It also installs the `bash-ui` CLI to `~/.local/bin` or `/usr/local/bin`.

**Update mechanism:**
- `bash-ui update` fetches the latest GitHub Release, downloads `ui.sh` and `ui.sh.sha256`, verifies the checksum, and replaces the file atomically (write to temp, then `mv`).
- It refuses major-version jumps unless `--major` is passed.
- `bash-ui check` reports whether an update is available without changing anything.

**Automatic updates (opt-in):**
- `bash-ui install-timer` adds a systemd user timer, or cron where there's no systemd, that runs `bash-ui update --quiet` daily.
- Where you'd rather pull than poll, the same command can run from your existing config tooling.

**Runtime check (optional, off by default):**
- If `UI_UPDATE_CHECK=1`, sourcing `ui.sh` checks a cached timestamp. At most once per day, it backgrounds a `bash-ui check` and shows one dim line next run if an update exists.
- It never blocks a script and never updates during a script run.

### B. Inlined copy (single-file scripts shipped to client servers)

Some scripts must be one file, e.g. scp'd to a client box. For those:
- Mark the library region in the consuming script:
  ```bash
  # >>> bash-ui 1.2.0 >>>
  …inlined ui.sh…
  # <<< bash-ui <<<
  ```
- `bash-ui inline script.sh` replaces the region with the current `ui.sh` (and the version in the marker).
- `bash-ui inline --check script.sh` exits non-zero if the inlined copy is stale. This is used in CI.

**Automatic updates for inlined copies, via GitHub Actions in each consuming repo:**
- Add a reusable workflow, `bash-ui/.github/workflows/sync-inline.yml` (`workflow_call`).
- Consuming repos call it on a weekly `schedule` plus `workflow_dispatch`.
- It finds files with the marker, runs `bash-ui inline`, and opens a PR if anything changed. The PR is titled "Update bash-ui to X.Y.Z" and includes the changelog excerpt.
- Optional push model: `release.yml` in this repo sends a `repository_dispatch` to a list of consumer repos, so they update right after a release instead of waiting for the schedule. This needs a fine-grained PAT stored as a secret.

### This repo's workflows

**`ci.yml`** (push and PR):
- shellcheck on `ui.sh`, `install.sh`, `bin/bash-ui` and the examples
- bats tests on ubuntu-latest (bash 5); add a bash 4.2 container job
- check that `VERSION` matches `UI_VERSION` inside `ui.sh`
- check that CHANGELOG has an entry for `VERSION`

**`release.yml`** (on a `v*` tag push):
- check that the tag matches `VERSION`
- build release assets: `ui.sh`, `ui.sh.sha256`, `bash-ui`, `install.sh`
- create a GitHub Release with notes from the CHANGELOG
- optionally send `repository_dispatch` to consumers

**Versioning:**
- Semver applies to the public `ui_*` API and `UI_*` env vars.
- Patch = fixes and visual tweaks.
- Minor = new functions or options.
- Major = renamed or removed functions, or behaviour changes that break callers.

### Phase 3 done when

- [ ] `install.sh`, `bash-ui update/check/inline` work and are tested
- [ ] Release workflow produces a checksummed release from a tag
- [ ] Reusable sync workflow opens a PR in one real consumer repo
- [ ] Timer install tested on a homelab host

---

## Phase 4 — Rollout

1. Use `template.sh` for every new script from now on.
2. Refactor the highest-traffic scripts first (wp-audit-site, migration helpers, GridPane tooling), using the skill.
3. Add `bash-ui inline --check` to CI in repos with inlined copies.
4. Post a write-up and screenshots on managingwp.io once it's stable (optional).

---

## Open questions

- **Repo name and visibility:** `bash-ui` public or private? Public makes `curl | bash` installs and client-server use simpler. Private needs a token for installs and updates.
- **macOS:** do any scripts run on the system bash 3.2? If yes, avoid associative arrays and `${var,,}` in `ui.sh`.
- **Gum backend:** include it in v1, or ship plain bash first and add gum in v1.1?
- **Push vs pull for inlined copies:** a weekly scheduled PR is simpler; dispatch is faster but needs a PAT.
