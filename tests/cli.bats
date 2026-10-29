#!/usr/bin/env bats
# tests/cli.bats — installer and CLI behaviour, using a local release directory.

bats_require_minimum_version 1.5.0

setup() {
  REPO="$BATS_TEST_DIRNAME/.."
  CLI="$REPO/bin/bash-ui"
  TMP="$BATS_TEST_TMPDIR"
  REL="$TMP/release"
  mkdir -p "$REL"
  cp "$REPO/ui.sh" "$REL/ui.sh"
  cp "$CLI" "$REL/bash-ui"
  (cd "$REL" && sha256sum ui.sh >ui.sh.sha256)
  CURRENT=$(sed -n 's/^UI_VERSION="\(.*\)"$/\1/p' "$REPO/ui.sh")
  NEW="${CURRENT%.*}.$((${CURRENT##*.} + 1))"
}

# restage <version> — rewrite the staged release at a given version.
restage() {
  sed -i "s/^UI_VERSION=.*/UI_VERSION=\"$1\"/" "$REL/ui.sh"
  (cd "$REL" && sha256sum ui.sh >ui.sh.sha256)
}

@test "version prints the library version" {
  run "$CLI" version
  [ "$status" -eq 0 ]
  [ "$output" = "bash-ui $CURRENT" ]
}

@test "help exits 0" {
  run "$CLI" --help
  [ "$status" -eq 0 ]
  [[ $output == *"bash-ui inline"* ]]
}

@test "an unknown command exits 1" {
  run "$CLI" nope
  [ "$status" -eq 1 ]
  [[ $output == *"unknown command"* ]]
}

@test "inline --check fails on a stale region" {
  printf '# >>> bash-ui 0.0.1 >>>\nold\n# <<< bash-ui <<<\n' >"$TMP/target.sh"
  run "$CLI" inline --check "$TMP/target.sh"
  [ "$status" -eq 1 ]
  [[ $output == *"current is $CURRENT"* ]]
}

@test "inline rewrites the region and then passes --check" {
  printf '#!/usr/bin/env bash\necho before\n# >>> bash-ui 0.0.1 >>>\nold\n# <<< bash-ui <<<\necho after\n' >"$TMP/target.sh"
  run "$CLI" inline "$TMP/target.sh"
  [ "$status" -eq 0 ]

  run "$CLI" inline --check "$TMP/target.sh"
  [ "$status" -eq 0 ]

  grep -q "^# >>> bash-ui $CURRENT >>>$" "$TMP/target.sh"
  grep -q 'UI_VERSION=' "$TMP/target.sh"
  grep -q '^echo before$' "$TMP/target.sh"
  grep -q '^echo after$' "$TMP/target.sh"
}

@test "inline refuses a file without markers" {
  printf 'echo hi\n' >"$TMP/plain.sh"
  run "$CLI" inline "$TMP/plain.sh"
  [ "$status" -eq 1 ]
  [[ $output == *"no '# >>> bash-ui"* ]]
}

@test "inline refuses an unterminated region" {
  printf '# >>> bash-ui 0.0.1 >>>\nold\n' >"$TMP/open.sh"
  run "$CLI" inline "$TMP/open.sh"
  [ "$status" -eq 1 ]
  [[ $output == *"unterminated"* ]]
}

@test "check exits 0 when up to date" {
  BASH_UI_SOURCE="$REL" run "$CLI" check
  [ "$status" -eq 0 ]
  [[ $output == *"up to date"* ]]
}

@test "check exits 1 and names both versions when newer" {
  restage "$NEW"
  BASH_UI_SOURCE="$REL" run "$CLI" check
  [ "$status" -eq 1 ]
  [[ $output == *"$CURRENT -> $NEW"* ]]
}

@test "update replaces the library with the verified asset" {
  restage "$NEW"
  mkdir -p "$TMP/lib"
  cp "$REPO/ui.sh" "$TMP/lib/ui.sh"

  BASH_UI="$TMP/lib/ui.sh" BASH_UI_SOURCE="$REL" run "$CLI" update
  [ "$status" -eq 0 ]
  [[ $output == *"$CURRENT -> $NEW"* ]]
  grep -q "^UI_VERSION=\"$NEW\"$" "$TMP/lib/ui.sh"
}

@test "update refuses a major jump without --major" {
  restage "99.0.0"
  mkdir -p "$TMP/lib"
  cp "$REPO/ui.sh" "$TMP/lib/ui.sh"

  BASH_UI="$TMP/lib/ui.sh" BASH_UI_SOURCE="$REL" run "$CLI" update
  [ "$status" -eq 1 ]
  [[ $output == *"refusing major jump"* ]]
  grep -q "^UI_VERSION=\"$CURRENT\"$" "$TMP/lib/ui.sh"
}

@test "update accepts a major jump with --major" {
  restage "99.0.0"
  mkdir -p "$TMP/lib"
  cp "$REPO/ui.sh" "$TMP/lib/ui.sh"

  BASH_UI="$TMP/lib/ui.sh" BASH_UI_SOURCE="$REL" run "$CLI" update --major
  [ "$status" -eq 0 ]
  grep -q '^UI_VERSION="99.0.0"$' "$TMP/lib/ui.sh"
}

@test "update refuses a bad checksum and keeps the library" {
  restage "$NEW"
  printf '0000000000000000000000000000000000000000000000000000000000000000  ui.sh\n' >"$REL/ui.sh.sha256"
  mkdir -p "$TMP/lib"
  cp "$REPO/ui.sh" "$TMP/lib/ui.sh"

  BASH_UI="$TMP/lib/ui.sh" BASH_UI_SOURCE="$REL" run "$CLI" update
  [ "$status" -eq 1 ]
  [[ $output == *"checksum mismatch"* ]]
  grep -q "^UI_VERSION=\"$CURRENT\"$" "$TMP/lib/ui.sh"
}

@test "install.sh installs a working prefix" {
  run env BASH_UI_SOURCE="$REL" bash "$REPO/install.sh" --prefix "$TMP/pfx"
  [ "$status" -eq 0 ]
  [ -f "$TMP/pfx/lib/bash-ui/ui.sh" ]
  [ -x "$TMP/pfx/bin/bash-ui" ]

  run "$TMP/pfx/bin/bash-ui" version
  [ "$status" -eq 0 ]
  [ "$output" = "bash-ui $CURRENT" ]
}

@test "install.sh rejects a checksum mismatch" {
  printf '0000000000000000000000000000000000000000000000000000000000000000  ui.sh\n' >"$REL/ui.sh.sha256"
  run env BASH_UI_SOURCE="$REL" bash "$REPO/install.sh" --prefix "$TMP/pfx"
  [ "$status" -eq 1 ]
  [[ $output == *"checksum mismatch"* ]]
  [ ! -f "$TMP/pfx/lib/bash-ui/ui.sh" ]
}

@test "install-timer writes systemd user units" {
  mkdir -p "$TMP/bin" "$TMP/home"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$TMP/bin/systemctl"
  chmod +x "$TMP/bin/systemctl"

  HOME="$TMP/home" PATH="$TMP/bin:$PATH" run "$CLI" install-timer
  [ "$status" -eq 0 ]
  [ -f "$TMP/home/.config/systemd/user/bash-ui-update.timer" ]
  [ -f "$TMP/home/.config/systemd/user/bash-ui-update.service" ]
  grep -q 'OnCalendar=daily' "$TMP/home/.config/systemd/user/bash-ui-update.timer"
  grep -q 'update --quiet' "$TMP/home/.config/systemd/user/bash-ui-update.service"
}

@test "install-timer falls back to cron without systemd" {
  mkdir -p "$TMP/bin" "$TMP/home"
  printf '#!/usr/bin/env bash\nexit 1\n' >"$TMP/bin/systemctl"
  cat >"$TMP/bin/crontab" <<EOF
#!/usr/bin/env bash
if [[ \${1:-} == -l ]]; then exit 1; fi
cat > "$TMP/crontab.out"
EOF
  chmod +x "$TMP/bin/systemctl" "$TMP/bin/crontab"

  HOME="$TMP/home" PATH="$TMP/bin:$PATH" run "$CLI" install-timer
  [ "$status" -eq 0 ]
  grep -q 'update --quiet' "$TMP/crontab.out"
}
