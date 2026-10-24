#!/usr/bin/env bats

load test_helper

@test "list with no bookmarks prints a hint" {
  run dp
  [ "$status" -eq 0 ]
  [[ "$output" == *"no bookmarks yet"* ]]
}

@test "save uses the folder name by default" {
  cd proj
  run dp -s
  [ "$status" -eq 0 ]
  [[ "$output" == "saved: proj -> $PWD" ]]
  [ "$(dp -p proj)" = "$PWD" ]
}

@test "save with an explicit name and jump from elsewhere" {
  cd proj/deep/nested
  dp -s api
  cd /
  dp api
  [ "$PWD" = "$BATS_TEST_TMPDIR/proj/deep/nested" ]
}

@test "saving an existing name updates it" {
  cd proj
  dp -s x
  cd deep
  run dp -s x
  [[ "$output" == updated:* ]]
  [ "$(dp -p x)" = "$BATS_TEST_TMPDIR/proj/deep" ]
  [ "$(grep -c '^x	' "$DIRPIN_FILE")" -eq 1 ]
}

@test "delete removes a bookmark" {
  cd proj
  dp -s api
  run dp -d api
  [ "$status" -eq 0 ]
  run dp -p api
  [ "$status" -eq 1 ]
}

@test "delete of a missing bookmark fails" {
  run dp -d nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"no bookmark 'nope'"* ]]
}

@test "deleting one bookmark leaves others alone" {
  cd proj; dp -s a
  cd deep; dp -s ab
  dp -d a
  [ "$(dp -p ab)" = "$BATS_TEST_TMPDIR/proj/deep" ]
}

@test "jump to an unknown bookmark fails" {
  run dp nope
  [ "$status" -eq 1 ]
}

@test "paths with spaces work" {
  cd "with space"
  dp -s sp
  cd /
  dp sp
  [ "$PWD" = "$BATS_TEST_TMPDIR/with space" ]
}

@test "-p is usable in command substitution" {
  cd proj
  dp -s p1
  cd "$BATS_TEST_TMPDIR"
  [ "$(dp -p p1)" = "$BATS_TEST_TMPDIR/proj" ]
}

@test "invalid names are rejected" {
  for bad in "-x" "a b" "a/b" 'a\b'; do
    run dp -s "$bad"
    [ "$status" -eq 1 ]
  done
  [ ! -s "$DIRPIN_FILE" ]
}

@test "jumping to a deleted directory fails with a clear message" {
  mkdir gone && cd gone
  dp -s gone
  cd .. && rmdir gone
  run dp gone
  [ "$status" -eq 1 ]
  [[ "$output" == *"no longer exists"* ]]
}

@test "list flags missing directories and sorts by name" {
  mkdir gone && cd gone && dp -s zeta
  cd ../proj && dp -s alpha
  cd .. && rmdir gone
  run dp
  [[ "${lines[0]}" == alpha* ]]
  [[ "${lines[1]}" == zeta*"(missing)" ]]
}

@test "unknown option fails" {
  run dp -z
  [ "$status" -eq 1 ]
}

@test "help and version" {
  run dp -h
  [[ "$output" == *"dp -s [name]"* ]]
  run dp -V
  [[ "$output" == "dirpin $DIRPIN_VERSION" ]]
}

@test "a bookmark named like a subcommand still jumps" {
  cd proj
  dp -s help
  cd /
  dp help
  [ "$PWD" = "$BATS_TEST_TMPDIR/proj" ]
}

@test "completion suggests bookmark names" {
  cd proj; dp -s alpha
  cd deep; dp -s beta
  COMP_WORDS=(dp a); COMP_CWORD=1
  _dirpin_complete
  [ "${COMPREPLY[*]}" = "alpha" ]
  COMP_WORDS=(dp -d ""); COMP_CWORD=2
  _dirpin_complete
  [ "${#COMPREPLY[@]}" -eq 2 ]
}

@test "completion offers flags and nothing after -s" {
  COMP_WORDS=(dp -); COMP_CWORD=1
  _dirpin_complete
  [[ " ${COMPREPLY[*]} " == *" -s "* ]]
  COMP_WORDS=(dp -s ""); COMP_CWORD=2
  _dirpin_complete
  [ "${#COMPREPLY[@]}" -eq 0 ]
}

@test "DIRPIN_CMD renames the command" {
  export DIRPIN_CMD=jj
  source "$BATS_TEST_DIRNAME/../dirpin.sh"
  run jj -V
  [ "$status" -eq 0 ]
}

@test "existing commands are not shadowed" {
  export DIRPIN_CMD=ls
  run bash -c 'source "$1" 2>&1' _ "$BATS_TEST_DIRNAME/../dirpin.sh"
  [[ "$output" == *"already exists"* ]]
}

@test "executing the file instead of sourcing it is refused" {
  run bash "$BATS_TEST_DIRNAME/../dirpin.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"source this file"* ]]
}
