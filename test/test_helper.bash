# Shared test setup.

# Isolate state in a temp dir. Used by every test file.
setup_env() {
  export HOME="$BATS_TEST_TMPDIR/home"
  export DIRPIN_FILE="$BATS_TEST_TMPDIR/bookmarks"
  export DIRPIN_CMD=dp
  mkdir -p "$HOME"
  unset -f dp 2>/dev/null || true
}

# Default setup: load the repo's dirpin.sh directly and add some directories to jump to.
setup() {
  setup_env
  mkdir -p "$BATS_TEST_TMPDIR/proj/deep/nested" "$BATS_TEST_TMPDIR/with space"
  # shellcheck source=../dirpin.sh
  source "$BATS_TEST_DIRNAME/../dirpin.sh"
  cd "$BATS_TEST_TMPDIR" || return 1
}
