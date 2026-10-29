#!/usr/bin/env bats
# tests/cli.bats — the vendoring tool, driven against a local release directory.

bats_require_minimum_version 1.5.0

setup() {
  REPO="$BATS_TEST_DIRNAME/.."
  CLI="$REPO/scripts/bash-ui.sh"
  TMP="$BATS_TEST_TMPDIR"
  REL="$TMP/release"
  mkdir -p "$REL" "$TMP/proj"
  cp "$REPO/ui.sh" "$REL/ui.sh"
  (cd "$REL" && sha256sum ui.sh >ui.sh.sha256)
  CURRENT=$(sed -n 's/^UI_VERSION="\(.*\)"$/\1/p' "$REPO/ui.sh")
  NEW="${CURRENT%.*}.$((${CURRENT##*.} + 1))"
  export BASH_UI_SOURCE="$REL"
  cd "$TMP/proj" || return 1
  git init -q
}

# restage <version> — rewrite the staged release at a given version.
restage() {
  sed -i "s/^UI_VERSION=.*/UI_VERSION=\"$1\"/" "$REL/ui.sh"
  (cd "$REL" && sha256sum ui.sh >ui.sh.sha256)
}

# stage_version <version> — add a v<version>/ directory to the release mirror.
stage_version() {
  mkdir -p "$REL/v$1"
  sed "s/^UI_VERSION=.*/UI_VERSION=\"$1\"/" "$REPO/ui.sh" >"$REL/v$1/ui.sh"
  (cd "$REL/v$1" && sha256sum ui.sh >ui.sh.sha256)
}

@test "help lists the four commands and no install command" {
  run bash "$CLI" --help
  [ "$status" -eq 0 ]
  [[ $output == *"init"* ]]
  [[ $output == *"check"* ]]
  [[ $output == *"update"* ]]
  [[ $output == *"inline"* ]]
  [[ $output != *"install-timer"* ]]
  [[ $output != *"install.sh"* ]]
}

@test "an unknown command exits 1" {
  run bash "$CLI" nope
  [ "$status" -eq 1 ]
  [[ $output == *"unknown command"* ]]
}

@test "init vendors the library and its checksum" {
  run bash "$CLI" init --path vendor/bash-ui/ui.sh
  [ "$status" -eq 0 ]
  [ -f vendor/bash-ui/ui.sh ]
  [ -f vendor/bash-ui/ui.sh.sha256 ]
  grep -q "^UI_VERSION=\"$CURRENT\"$" vendor/bash-ui/ui.sh

  run bash "$CLI" check
  [ "$status" -eq 0 ]
  [[ $output == *"is current"* ]]
}

@test "init --ci writes the workflow with the vendored path" {
  run bash "$CLI" init --path vendor/bash-ui/ui.sh --ci
  [ "$status" -eq 0 ]
  [ -f .github/workflows/bash-ui.yml ]
  grep -q 'vendor/bash-ui/ui.sh' .github/workflows/bash-ui.yml
  grep -q 'sha256sum -c' .github/workflows/bash-ui.yml
}

@test "init refuses a bad checksum and leaves no vendored file" {
  printf '0000000000000000000000000000000000000000000000000000000000000000  ui.sh\n' >"$REL/ui.sh.sha256"
  run bash "$CLI" init --path vendor/bash-ui/ui.sh
  [ "$status" -eq 1 ]
  [[ $output == *"checksum mismatch"* ]]
  [ ! -f vendor/bash-ui/ui.sh ]
}

@test "check fails when the vendored version is stale" {
  bash "$CLI" init --path vendor/bash-ui/ui.sh >/dev/null 2>&1
  restage "$NEW"
  run bash "$CLI" check
  [ "$status" -eq 1 ]
  [[ $output == *"$CURRENT, latest is $NEW"* ]]
}

@test "check fails when the vendored file was edited" {
  bash "$CLI" init --path vendor/bash-ui/ui.sh >/dev/null 2>&1
  printf '\n# local edit\n' >>vendor/bash-ui/ui.sh
  run bash "$CLI" check
  [ "$status" -eq 1 ]
  [[ $output == *"checksum mismatch"* ]]
}

@test "check fails when nothing is vendored" {
  run bash "$CLI" check
  [ "$status" -eq 1 ]
  [[ $output == *"not found"* ]]
}

@test "check reports stale inline markers" {
  bash "$CLI" init --path vendor/bash-ui/ui.sh >/dev/null 2>&1
  mkdir -p scripts
  printf '# >>> bash-ui 0.0.1 >>>\nold\n# <<< bash-ui <<<\n' >scripts/inl.sh
  run bash "$CLI" check
  [ "$status" -eq 1 ]
  [[ $output == *"scripts/inl.sh: 0.0.1"* ]]
}

@test "update replaces the vendored file and its checksum" {
  bash "$CLI" init --path vendor/bash-ui/ui.sh >/dev/null 2>&1
  restage "$NEW"

  run bash "$CLI" update
  [ "$status" -eq 0 ]
  [[ $output == *"Vendored bash-ui $NEW"* ]]
  grep -q "^UI_VERSION=\"$NEW\"$" vendor/bash-ui/ui.sh
  (cd vendor/bash-ui && sha256sum -c ui.sh.sha256)

  run bash "$CLI" check
  [ "$status" -eq 0 ]
}

@test "update --version pins a specific release" {
  stage_version "$NEW"
  run bash "$CLI" update --version "$NEW"
  [ "$status" -eq 0 ]
  grep -q "^UI_VERSION=\"$NEW\"$" vendor/bash-ui/ui.sh
  (cd vendor/bash-ui && sha256sum -c ui.sh.sha256)
}

@test "update rewrites stale inline markers" {
  bash "$CLI" init --path vendor/bash-ui/ui.sh >/dev/null 2>&1
  mkdir -p scripts
  printf '#!/usr/bin/env bash\necho before\n# >>> bash-ui 0.0.1 >>>\nold\n# <<< bash-ui <<<\necho after\n' >scripts/inl.sh

  run bash "$CLI" update
  [ "$status" -eq 0 ]
  grep -q "^# >>> bash-ui $CURRENT >>>$" scripts/inl.sh
  grep -q '^echo before$' scripts/inl.sh
  grep -q '^echo after$' scripts/inl.sh
  run bash "$CLI" check
  [ "$status" -eq 0 ]
}

@test "inline --check fails on a stale region and passes after inline" {
  bash "$CLI" init --path vendor/bash-ui/ui.sh >/dev/null 2>&1
  printf '# >>> bash-ui 0.0.1 >>>\nold\n# <<< bash-ui <<<\n' >target.sh

  run bash "$CLI" inline --check target.sh
  [ "$status" -eq 1 ]

  run bash "$CLI" inline target.sh
  [ "$status" -eq 0 ]

  run bash "$CLI" inline --check target.sh
  [ "$status" -eq 0 ]
}

@test "inline refuses a file without markers" {
  bash "$CLI" init --path vendor/bash-ui/ui.sh >/dev/null 2>&1
  printf 'echo hi\n' >plain.sh
  run bash "$CLI" inline plain.sh
  [ "$status" -eq 1 ]
  [[ $output == *"no '# >>> bash-ui"* ]]
}

@test "inline refuses an unterminated region" {
  bash "$CLI" init --path vendor/bash-ui/ui.sh >/dev/null 2>&1
  printf '# >>> bash-ui 0.0.1 >>>\nold\n' >open.sh
  run bash "$CLI" inline open.sh
  [ "$status" -eq 1 ]
  [[ $output == *"unterminated"* ]]
}

@test "inline works without a vendored copy" {
  printf '# >>> bash-ui 0.0.1 >>>\nold\n# <<< bash-ui <<<\n' >target.sh

  run bash "$CLI" inline --check target.sh
  [ "$status" -eq 1 ]

  run bash "$CLI" inline target.sh
  [ "$status" -eq 0 ]
  grep -q "^# >>> bash-ui $CURRENT >>>$" target.sh
  grep -q 'UI_VERSION=' target.sh
  [ ! -d vendor ]

  run bash "$CLI" inline --check target.sh
  [ "$status" -eq 0 ]
}
