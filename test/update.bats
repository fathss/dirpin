#!/usr/bin/env bats
# Tests for `dp -u`, using a fake curl so nothing touches the network.

load test_helper

# Overrides the helper's setup(): the updater rewrites the file it was loaded from,
# so these tests must run against a copy, never the repo's own dirpin.sh.
setup() {
  setup_env
  export DIRPIN_REPO="someone/dirpin"
  mkdir -p "$BATS_TEST_TMPDIR/install" "$BATS_TEST_TMPDIR/stub"

  # Work on a copy so the updater never touches the real repo file (CI checkouts have .git).
  INSTALLED="$BATS_TEST_TMPDIR/install/dirpin.sh"
  cp "$BATS_TEST_DIRNAME/../dirpin.sh" "$INSTALLED"
  cp "$INSTALLED" "$BATS_TEST_TMPDIR/original.sh"

  # Fake curl: answers the release-API URL and the raw-file URL from env vars.
  cat > "$BATS_TEST_TMPDIR/stub/curl" <<'STUB'
#!/usr/bin/env bash
url="${*: -1}"
echo "$url" >> "$STUB_LOG"
case "$url" in
  *api.github.com*releases/latest)
    [ -n "${STUB_API_FAIL-}" ] && exit 22
    printf '{\n  "tag_name": "%s",\n  "name": "x"\n}\n' "$STUB_TAG"
    ;;
  *raw.githubusercontent.com*)
    [ -n "${STUB_RAW_FAIL-}" ] && exit 22
    cat "$STUB_RAW_FILE"
    ;;
  *) exit 1 ;;
esac
STUB
  chmod +x "$BATS_TEST_TMPDIR/stub/curl"
  export PATH="$BATS_TEST_TMPDIR/stub:$PATH"
  export STUB_LOG="$BATS_TEST_TMPDIR/requests.log"
  : > "$STUB_LOG"

  # shellcheck source=../dirpin.sh
  source "$INSTALLED"

  # A "new release" file: the real script with a higher version.
  NEWER="$BATS_TEST_TMPDIR/newer.sh"
  sed 's/^DIRPIN_VERSION=.*/DIRPIN_VERSION="9.9.9"/' "$INSTALLED" > "$NEWER"
  export STUB_RAW_FILE="$NEWER"
}

@test "up to date when the latest release matches" {
  export STUB_TAG="v$DIRPIN_VERSION"
  run dp -u
  [ "$status" -eq 0 ]
  [[ "$output" == *"up to date"* ]]
  ! grep -q raw.githubusercontent.com "$STUB_LOG"
}

@test "up to date when the remote version is older" {
  export STUB_TAG="v0.0.1"
  run dp -u
  [ "$status" -eq 0 ]
  [[ "$output" == *"up to date"* ]]
}

@test "update replaces the file with the new release" {
  export STUB_TAG="v9.9.9"
  run dp -u
  [ "$status" -eq 0 ]
  [[ "$output" == *"updated $DIRPIN_VERSION -> 9.9.9"* ]]
  grep -q '^DIRPIN_VERSION="9.9.9"' "$INSTALLED"
  [ ! -e "$INSTALLED.new" ]
  grep -q "raw.githubusercontent.com/someone/dirpin/v9.9.9/dirpin.sh" "$STUB_LOG"
}

@test "multi-digit versions compare numerically (0.10.0 > 0.9.0)" {
  sed -i.bak 's/^DIRPIN_VERSION=.*/DIRPIN_VERSION="0.9.0"/' "$INSTALLED" && rm -f "$INSTALLED.bak"
  source "$INSTALLED"
  export STUB_TAG="v0.10.0"
  sed 's/^DIRPIN_VERSION=.*/DIRPIN_VERSION="0.10.0"/' "$INSTALLED" > "$NEWER"
  run dp -u
  [[ "$output" == *"updated 0.9.0 -> 0.10.0"* ]]
}

@test "refuses to update a git clone" {
  mkdir "$BATS_TEST_TMPDIR/install/.git"
  export STUB_TAG="v9.9.9"
  run dp -u
  [ "$status" -eq 1 ]
  [[ "$output" == *"git clone"* ]]
  cmp "$INSTALLED" "$BATS_TEST_TMPDIR/original.sh"
}

@test "fails cleanly when the release lookup fails" {
  export STUB_API_FAIL=1
  run dp -u
  [ "$status" -eq 1 ]
  [[ "$output" == *"couldn't determine"* ]]
  cmp "$INSTALLED" "$BATS_TEST_TMPDIR/original.sh"
}

@test "rejects a malformed tag before building a URL from it" {
  export STUB_TAG="v1.0.0/../../evil"
  run dp -u
  [ "$status" -eq 1 ]
  ! grep -q raw.githubusercontent.com "$STUB_LOG"
}

@test "failed download leaves the installed file untouched" {
  export STUB_TAG="v9.9.9" STUB_RAW_FAIL=1
  run dp -u
  [ "$status" -eq 1 ]
  [[ "$output" == *"nothing changed"* ]]
  cmp "$INSTALLED" "$BATS_TEST_TMPDIR/original.sh"
}

@test "an error page instead of a script is rejected" {
  export STUB_TAG="v9.9.9"
  echo "<html>404: Not Found</html>" > "$NEWER"
  run dp -u
  [ "$status" -eq 1 ]
  cmp "$INSTALLED" "$BATS_TEST_TMPDIR/original.sh"
}

@test "a file whose version doesn't match the release is rejected" {
  export STUB_TAG="v9.9.9"
  sed 's/^DIRPIN_VERSION=.*/DIRPIN_VERSION="1.0.0"/' "$INSTALLED" > "$NEWER"
  run dp -u
  [ "$status" -eq 1 ]
  cmp "$INSTALLED" "$BATS_TEST_TMPDIR/original.sh"
}

@test "a file with a syntax error is rejected" {
  export STUB_TAG="v9.9.9"
  { echo 'DIRPIN_VERSION="9.9.9"'; echo 'if then fi ('; } > "$NEWER"
  run dp -u
  [ "$status" -eq 1 ]
  cmp "$INSTALLED" "$BATS_TEST_TMPDIR/original.sh"
}

@test "-u is listed in completion and help" {
  COMP_WORDS=(dp -); COMP_CWORD=1
  _dirpin_complete
  [[ " ${COMPREPLY[*]} " == *" -u "* ]]
  run dp -h
  [[ "$output" == *"-u"* ]]
}
