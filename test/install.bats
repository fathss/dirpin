#!/usr/bin/env bats

load test_helper

setup() {
  setup_env
  export XDG_DATA_HOME="$BATS_TEST_TMPDIR/data"
  export FAKE_RC="$BATS_TEST_TMPDIR/fake_rc"
  touch "$FAKE_RC"
}

@test "install.sh auto-symlinks when run from a git clone" {
  mkdir -p "$BATS_TEST_TMPDIR/repo/.git"
  cp "$BATS_TEST_DIRNAME/../install.sh" "$BATS_TEST_DIRNAME/../dirpin.sh" "$BATS_TEST_TMPDIR/repo/"
  run bash "$BATS_TEST_TMPDIR/repo/install.sh" --rc "$FAKE_RC"
  [ "$status" -eq 0 ]
  [ -L "$XDG_DATA_HOME/dirpin/dirpin.sh" ]
  [ "$(readlink "$XDG_DATA_HOME/dirpin/dirpin.sh")" = "$BATS_TEST_TMPDIR/repo/dirpin.sh" ]
}

@test "install.sh --copy forces file copy even with .git" {
  mkdir -p "$BATS_TEST_TMPDIR/repo/.git"
  cp "$BATS_TEST_DIRNAME/../install.sh" "$BATS_TEST_DIRNAME/../dirpin.sh" "$BATS_TEST_TMPDIR/repo/"
  run bash "$BATS_TEST_TMPDIR/repo/install.sh" --copy --rc "$FAKE_RC"
  [ "$status" -eq 0 ]
  [ -f "$XDG_DATA_HOME/dirpin/dirpin.sh" ]
  [ ! -L "$XDG_DATA_HOME/dirpin/dirpin.sh" ]
}

@test "install.sh --copy cleanly replaces an existing symlink" {
  mkdir -p "$BATS_TEST_TMPDIR/repo/.git"
  cp "$BATS_TEST_DIRNAME/../install.sh" "$BATS_TEST_DIRNAME/../dirpin.sh" "$BATS_TEST_TMPDIR/repo/"
  # First install as symlink
  run bash "$BATS_TEST_TMPDIR/repo/install.sh" --rc "$FAKE_RC"
  [ "$status" -eq 0 ]
  [ -L "$XDG_DATA_HOME/dirpin/dirpin.sh" ]

  # Second install as copy over the existing symlink
  run bash "$BATS_TEST_TMPDIR/repo/install.sh" --copy --rc "$FAKE_RC"
  [ "$status" -eq 0 ]
  [ -f "$XDG_DATA_HOME/dirpin/dirpin.sh" ]
  [ ! -L "$XDG_DATA_HOME/dirpin/dirpin.sh" ]
  [ ! -e "$XDG_DATA_HOME/dirpin/dirpin.sh.tmp" ]
}

@test "install.sh reports fresh install, up to date, and update" {
  mkdir -p "$BATS_TEST_TMPDIR/repo"
  cp "$BATS_TEST_DIRNAME/../install.sh" "$BATS_TEST_TMPDIR/repo/"
  sed 's/^DIRPIN_VERSION=.*/DIRPIN_VERSION="0.1.0"/' "$BATS_TEST_DIRNAME/../dirpin.sh" > "$BATS_TEST_TMPDIR/repo/dirpin.sh"

  # 1. Fresh install
  run bash "$BATS_TEST_TMPDIR/repo/install.sh" --copy --rc "$FAKE_RC"
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed dirpin 0.1.0"* ]]

  # 2. Re-install same version
  run bash "$BATS_TEST_TMPDIR/repo/install.sh" --copy --rc "$FAKE_RC"
  [ "$status" -eq 0 ]
  [[ "$output" == *"dirpin 0.1.0 is already up to date"* ]]

  # 3. Upgrade version
  sed -i.bak 's/^DIRPIN_VERSION=.*/DIRPIN_VERSION="0.2.0"/' "$BATS_TEST_TMPDIR/repo/dirpin.sh"
  run bash "$BATS_TEST_TMPDIR/repo/install.sh" --copy --rc "$FAKE_RC"
  [ "$status" -eq 0 ]
  [[ "$output" == *"updated dirpin 0.1.0 -> 0.2.0"* ]]
}

@test "uninstall.sh removes script and rc line, keeping bookmarks unless --purge" {
  mkdir -p "$XDG_DATA_HOME/dirpin"
  touch "$XDG_DATA_HOME/dirpin/dirpin.sh" "$XDG_DATA_HOME/dirpin/bookmarks"
  printf '# dirpin: directory bookmarks\nsource "%s/dirpin/dirpin.sh"\n' "$XDG_DATA_HOME" > "$FAKE_RC"

  # Without --purge
  run bash "$BATS_TEST_DIRNAME/../uninstall.sh" --rc "$FAKE_RC"
  [ "$status" -eq 0 ]
  [ ! -e "$XDG_DATA_HOME/dirpin/dirpin.sh" ]
  [ -f "$XDG_DATA_HOME/dirpin/bookmarks" ]
  ! grep -q "dirpin" "$FAKE_RC"

  # With --purge
  run bash "$BATS_TEST_DIRNAME/../uninstall.sh" --purge --rc "$FAKE_RC"
  [ "$status" -eq 0 ]
  [ ! -d "$XDG_DATA_HOME/dirpin" ]
}

@test "install.sh replaces existing dirpin line instead of appending duplicate" {
  mkdir -p "$BATS_TEST_TMPDIR/repo"
  cp "$BATS_TEST_DIRNAME/../install.sh" "$BATS_TEST_DIRNAME/../dirpin.sh" "$BATS_TEST_TMPDIR/repo/"
  printf '# dirpin: directory bookmarks\nsource "/custom/path/dirpin.sh"\n' > "$FAKE_RC"

  run bash "$BATS_TEST_TMPDIR/repo/install.sh" --copy --rc "$FAKE_RC"
  [ "$status" -eq 0 ]
  [[ "$output" == *"updated in $FAKE_RC"* ]]
  [ "$(grep -c 'dirpin\.sh' "$FAKE_RC")" -eq 1 ]
  grep -qxF "source \"$XDG_DATA_HOME/dirpin/dirpin.sh\"" "$FAKE_RC"
}

@test "install.sh deduplicates multiple existing dirpin lines" {
  mkdir -p "$BATS_TEST_TMPDIR/repo"
  cp "$BATS_TEST_DIRNAME/../install.sh" "$BATS_TEST_DIRNAME/../dirpin.sh" "$BATS_TEST_TMPDIR/repo/"
  cat << 'EOF' > "$FAKE_RC"
# dirpin: directory bookmarks
source "/first/path/dirpin.sh"

# dirpin: directory bookmarks
source "/second/path/dirpin.sh"
EOF

  run bash "$BATS_TEST_TMPDIR/repo/install.sh" --copy --rc "$FAKE_RC"
  [ "$status" -eq 0 ]
  [[ "$output" == *"updated in $FAKE_RC"* ]]
  [ "$(grep -c 'dirpin\.sh' "$FAKE_RC")" -eq 1 ]
  [ "$(grep -c 'dirpin: directory bookmarks' "$FAKE_RC")" -eq 1 ]
  grep -qxF "source \"$XDG_DATA_HOME/dirpin/dirpin.sh\"" "$FAKE_RC"
}

@test "uninstall.sh removes varied dirpin source lines" {
  cat << 'EOF' > "$FAKE_RC"
export PATH=/bin
# dirpin: directory bookmarks
source "/custom/path/dirpin.sh"
. "/another/dirpin.sh"
export FOO=bar
EOF

  run bash "$BATS_TEST_DIRNAME/../uninstall.sh" --rc "$FAKE_RC"
  [ "$status" -eq 0 ]
  ! grep -q "dirpin" "$FAKE_RC"
  grep -qxF "export PATH=/bin" "$FAKE_RC"
  grep -qxF "export FOO=bar" "$FAKE_RC"
}

@test "install.sh rejects invalid DIRPIN_REF and DIRPIN_REPO formats" {
  for bad_ref in "v1.0; rm -rf /" "v1.0/../../evil" "v1.0 space" "v1.0*bad" "v1.0\bad"; do
    DIRPIN_REF="$bad_ref" run bash "$BATS_TEST_DIRNAME/../install.sh" --rc "$FAKE_RC"
    [ "$status" -eq 1 ]
    [[ "$output" == *"error: invalid DIRPIN_REF"* ]]
  done

  for bad_repo in "evil;repo" "owner/../../evil" "repo space" "bad*repo" "bad\repo"; do
    DIRPIN_REPO="$bad_repo" run bash "$BATS_TEST_DIRNAME/../install.sh" --rc "$FAKE_RC"
    [ "$status" -eq 1 ]
    [[ "$output" == *"error: invalid DIRPIN_REPO"* ]]
  done
}
