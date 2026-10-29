# Changelog

All notable changes to this project are documented in this file. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) from
1.0.0 onwards. While the version is `0.x`, a **minor** bump may rename or
remove a `ui_*` function or a `UI_*` variable, so pin the version you vendor.

## Unreleased

## 0.2.0 — 2026-10-29

### Changed

- **Delivery model.** `bash-ui` is vendored per project instead of installed:
  `vendor/bash-ui/ui.sh` plus `ui.sh.sha256`, committed and reviewed in pull
  requests. The updater is fetched per run and never installed.
- The CLI moved from `bin/bash-ui` to `scripts/bash-ui.sh` and gained `init`
  and `check`; `check` verifies the committed checksum and every inline marker.
- `examples/template.sh` and the skill locate the vendored copy by walking up to
  `vendor/bash-ui/ui.sh`, with `$BASH_UI` as an override.

### Removed

- `install.sh`, the global `~/.local/lib` and `/usr/local/lib` install paths,
  `install-timer` (systemd and cron), `demo`, and the `version` subcommand.

### Migration from 0.1.0

Copy your installed `ui.sh` to `vendor/bash-ui/ui.sh`, write its checksum with
`sha256sum ui.sh > ui.sh.sha256`, and delete any `bash-ui` timer or cron entry.
Installed copies keep working; only the update path changes.

## 0.1.0 — 2026-10-29

### Added

- `ui.sh`, a single sourceable bash library with one palette, one set of
  symbols and one vocabulary of output functions.
- Message helpers: `ui_header`, `ui_section`, `ui_step`, `ui_ok`, `ui_warn`,
  `ui_err`, `ui_info`, `ui_debug`, `ui_die`, `ui_hr`, `ui_list`, `ui_kv`,
  `ui_style`.
- Interaction and data helpers: `ui_spin`, `ui_confirm`, `ui_table`,
  `ui_summary`.
- Graceful degradation for `NO_COLOR`, `UI_COLOR`, `UI_ASCII`, `UI_QUIET`,
  `UI_VERBOSE`, `UI_YES`, `UI_TIMESTAMPS`, `CI` and an optional gum backend.
- `examples/demo.sh`, `examples/template.sh` and bats coverage in
  `tests/ui.bats`.
- `install.sh`, with per-user (`~/.local`) and system-wide (`/usr/local`)
  prefixes, checksum verification and a `BASH_UI_SOURCE` override.
- `bin/bash-ui` CLI: `version`, `check`, `update`, `demo`, `inline`,
  `inline --check` and `install-timer`, with tests in `tests/cli.bats`.
- `skills/bash-ui/SKILL.md`, the agent skill that teaches the library's
  vocabulary and refactor workflow. Synced to the `lmt-skills` repo.
- GitHub Actions: `ci.yml` (shellcheck, bats, version and changelog gates, plus
  a bash 4.2 smoke test), `release.yml` and the reusable `sync-inline.yml`.
