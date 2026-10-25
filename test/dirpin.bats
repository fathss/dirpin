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

@test "rename changes bookmark name and preserves path" {
  cd proj
  dp -s old
  run dp -r old new
  [ "$status" -eq 0 ]
  [[ "$output" == "renamed: old -> new" ]]
  run dp -p old
  [ "$status" -eq 1 ]
  [ "$(dp -p new)" = "$BATS_TEST_TMPDIR/proj" ]
}

@test "rename requires two arguments" {
  run dp -r
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage:"* ]]
  run dp -r one
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage:"* ]]
}

@test "rename of a missing bookmark fails" {
  run dp -r nope new
  [ "$status" -eq 1 ]
  [[ "$output" == *"no bookmark 'nope'"* ]]
}

@test "rename to invalid name fails" {
  cd proj
  dp -s api
  run dp -r api "bad name"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid name"* ]]
}

@test "rename to existing bookmark fails" {
  cd proj; dp -s a
  cd deep; dp -s b
  run dp -r a b
  [ "$status" -eq 1 ]
  [[ "$output" == *"already exists"* ]]
  [ "$(dp -p a)" = "$BATS_TEST_TMPDIR/proj" ]
}

@test "rename to same name succeeds" {
  cd proj; dp -s a
  run dp -r a a
  [ "$status" -eq 0 ]
  [[ "$output" == "renamed: a -> a" ]]
  [ "$(dp -p a)" = "$BATS_TEST_TMPDIR/proj" ]
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

@test "clean removes stale bookmarks and leaves valid ones" {
  mkdir valid && cd valid && dp -s ok
  mkdir gone && cd gone && dp -s dead
  cd .. && rmdir gone
  run dp -c
  [ "$status" -eq 0 ]
  [[ "$output" == *"cleaned: dead ->"* ]]
  run dp -p dead
  [ "$status" -eq 1 ]
  [ "$(dp -p ok)" = "$BATS_TEST_TMPDIR/valid" ]
}

@test "clean reports when no stale bookmarks exist" {
  cd proj && dp -s p1
  run dp -c
  [ "$status" -eq 0 ]
  [[ "$output" == "no stale bookmarks" ]]
  [ "$(dp -p p1)" = "$BATS_TEST_TMPDIR/proj" ]
}

@test "clean on empty or missing bookmark file" {
  run dp -c
  [ "$status" -eq 0 ]
  [[ "$output" == "no stale bookmarks" ]]
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
  COMP_WORDS=(dp -r ""); COMP_CWORD=2
  _dirpin_complete
  [ "${#COMPREPLY[@]}" -eq 2 ]
  COMP_WORDS=(dp -r alpha ""); COMP_CWORD=3
  _dirpin_complete
  [ "${#COMPREPLY[@]}" -eq 0 ]
}

@test "completion offers flags and nothing after -s or -c" {
  COMP_WORDS=(dp -); COMP_CWORD=1
  _dirpin_complete
  [[ " ${COMPREPLY[*]} " == *" -s "* ]]
  [[ " ${COMPREPLY[*]} " == *" -c "* ]]
  [[ " ${COMPREPLY[*]} " == *" -r "* ]]
  COMP_WORDS=(dp -s ""); COMP_CWORD=2
  _dirpin_complete
  [ "${#COMPREPLY[@]}" -eq 0 ]
  COMP_WORDS=(dp -c ""); COMP_CWORD=2
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

@test "jump to bookmark subpath" {
  cd proj
  dp -s root
  cd /
  dp root/deep/nested
  [ "$PWD" = "$BATS_TEST_TMPDIR/proj/deep/nested" ]
}

@test "jump to non-existent subpath fails and stays in place" {
  cd proj
  dp -s root
  cd /
  run dp root/does/not/exist
  [ "$status" -eq 1 ]
  [[ "$output" == *"path does not exist"* ]]
  [ "$PWD" = "/" ]
}

@test "jump to subpath that is a regular file fails" {
  cd proj
  touch somefile
  dp -s root
  cd /
  run dp root/somefile
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a directory"* ]]
  [ "$PWD" = "/" ]
}

@test "jump to subpath with .. is rejected" {
  cd proj
  dp -s root
  cd /
  run dp root/../proj
  [ "$status" -eq 1 ]
  [[ "$output" == *"subpath cannot contain '..'"* ]]
  run dp root/deep/../../etc
  [ "$status" -eq 1 ]
  [[ "$output" == *"subpath cannot contain '..'"* ]]
}

@test "-p prints bookmark subpath" {
  cd proj
  dp -s root
  [ "$(dp -p root/deep)" = "$BATS_TEST_TMPDIR/proj/deep" ]
  [ "$(dp -p root/deep/nested)" = "$BATS_TEST_TMPDIR/proj/deep/nested" ]
}

@test "-p with non-existent subpath fails" {
  cd proj
  dp -s root
  run dp -p root/nope
  [ "$status" -eq 1 ]
  [[ "$output" == *"path does not exist"* ]]
}

@test "-p rejects .. in subpath" {
  cd proj
  dp -s root
  run dp -p root/..
  [ "$status" -eq 1 ]
  [[ "$output" == *"subpath cannot contain '..'"* ]]
}

@test "subpaths with spaces work for jump and -p" {
  mkdir -p "$BATS_TEST_TMPDIR/proj/sub dir"
  cd proj
  dp -s root
  cd /
  dp "root/sub dir"
  [ "$PWD" = "$BATS_TEST_TMPDIR/proj/sub dir" ]
  [ "$(dp -p "root/sub dir")" = "$BATS_TEST_TMPDIR/proj/sub dir" ]
  cd /
  dp root/sub dir
  [ "$PWD" = "$BATS_TEST_TMPDIR/proj/sub dir" ]
  [ "$(dp -p root/sub dir)" = "$BATS_TEST_TMPDIR/proj/sub dir" ]
}

@test "completion suggests subdirectories with trailing slash (unsplit cur)" {
  cd proj; dp -s root
  COMP_WORDS=(dp root/); COMP_CWORD=1
  _dirpin_complete
  [ "${COMPREPLY[*]}" = "root/deep/" ]
  COMP_WORDS=(dp root/d); COMP_CWORD=1
  _dirpin_complete
  [ "${COMPREPLY[*]}" = "root/deep/" ]
  COMP_WORDS=(dp root/deep/); COMP_CWORD=1
  _dirpin_complete
  [ "${COMPREPLY[*]}" = "root/deep/nested/" ]
}

@test "completion suggests subdirectories in bash split wordbreaks" {
  cd proj; dp -s root
  COMP_WORDS=(dp root / ""); COMP_CWORD=3
  _dirpin_complete
  [ "${COMPREPLY[*]}" = "deep/" ]
  COMP_WORDS=(dp root / d); COMP_CWORD=3
  _dirpin_complete
  [ "${COMPREPLY[*]}" = "deep/" ]
  COMP_WORDS=(dp root / deep / ""); COMP_CWORD=5
  _dirpin_complete
  [ "${COMPREPLY[*]}" = "nested/" ]
}

@test "completion for -p suggests subdirectories" {
  cd proj; dp -s root
  COMP_WORDS=(dp -p root/); COMP_CWORD=2
  _dirpin_complete
  [ "${COMPREPLY[*]}" = "root/deep/" ]
  COMP_WORDS=(dp -p root / ""); COMP_CWORD=4
  _dirpin_complete
  [ "${COMPREPLY[*]}" = "deep/" ]
}

@test "completion suggests subdirectories with spaces" {
  mkdir -p "$BATS_TEST_TMPDIR/proj/dir with space/nested"
  cd proj; dp -s root
  COMP_WORDS=(dp root/dir); COMP_CWORD=1
  _dirpin_complete
  [ "${COMPREPLY[*]}" = "root/dir\\ with\\ space/" ]

  COMP_WORDS=(dp "root/dir\\ with\\ space/"); COMP_CWORD=1
  _dirpin_complete
  [ "${COMPREPLY[*]}" = "root/dir\\ with\\ space/nested/" ]

  COMP_WORDS=(dp root / "dir\\ with\\ space" / ""); COMP_CWORD=5
  _dirpin_complete
  [ "${COMPREPLY[*]}" = "nested/" ]
}

@test "completion does not suggest subpaths for -d" {
  cd proj; dp -s root
  COMP_WORDS=(dp -d root / ""); COMP_CWORD=4
  _dirpin_complete
  [ "${#COMPREPLY[@]}" -eq 0 ]
}
