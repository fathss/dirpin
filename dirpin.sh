# shellcheck shell=bash
# dirpin - named directory bookmarks for bash and zsh.
# Source this file from your rc file; do not execute it.
#
#   dp              list bookmarks
#   dp name         jump to a bookmark
#   dp -s [name]    save the current directory
#   dp -d name      delete a bookmark
#   dp -p name      print a bookmark's path (for scripts)
#   dp -u           update to the latest release

(return 0 2>/dev/null) || {
  echo "dirpin: source this file instead of running it: source ${0}" >&2
  exit 1
}

DIRPIN_VERSION="0.1.1"
: "${DIRPIN_FILE:=${XDG_DATA_HOME:-$HOME/.local/share}/dirpin/bookmarks}"
: "${DIRPIN_CMD:=dp}"
: "${DIRPIN_REPO:=fathss/dirpin}"

# Remember where this file lives, so the updater knows what to replace.
if [ -n "${ZSH_VERSION-}" ]; then
  eval '_DIRPIN_SELF=${(%):-%x}'
else
  _DIRPIN_SELF="${BASH_SOURCE[0]}"
fi

# --- internals -------------------------------------------------------------

# Print the path stored for bookmark $1; fail if there is none.
_dirpin_get() {
  [ -f "$DIRPIN_FILE" ] || return 1
  N="$1" awk -F'\t' '$1 == ENVIRON["N"] { print $2; found = 1; exit } END { exit !found }' "$DIRPIN_FILE"
}

# Remove bookmark $1 from the file (no error if absent).
_dirpin_drop() {
  [ -f "$DIRPIN_FILE" ] || return 0
  local tmp="$DIRPIN_FILE.tmp.$$"
  N="$1" awk -F'\t' '$1 != ENVIRON["N"]' "$DIRPIN_FILE" > "$tmp" && mv -- "$tmp" "$DIRPIN_FILE"
}

# A valid name is non-empty, doesn't start with "-", and has no whitespace,
# slashes or backslashes.
_dirpin_valid_name() {
  case "$1" in
    "" | -* | *[[:space:]]* | */* | *\\*) return 1 ;;
  esac
  return 0
}

_dirpin_names() {
  [ -f "$DIRPIN_FILE" ] && cut -f1 "$DIRPIN_FILE"
}

_dirpin_list() {
  if [ ! -s "$DIRPIN_FILE" ]; then
    echo "no bookmarks yet. cd somewhere and run: $DIRPIN_CMD -s [name]"
    return 0
  fi
  sort -t "$(printf '\t')" -k1,1 "$DIRPIN_FILE" | while IFS="$(printf '\t')" read -r n p; do
    if [ -d "$p" ]; then
      printf '%-16s %s\n' "$n" "$p"
    else
      printf '%-16s %s  (missing)\n' "$n" "$p"
    fi
  done
}

_dirpin_save() {
  local name="${1:-$(basename "$PWD")}"
  if ! _dirpin_valid_name "$name"; then
    echo "dirpin: invalid name '$name' (no spaces, slashes or leading '-')" >&2
    return 1
  fi
  local tab=$'\t' nl=$'\n'
  case "$PWD" in
    *"$tab"* | *"$nl"*)
      echo "dirpin: cannot save a path containing tabs or newlines" >&2
      return 1
      ;;
  esac
  local verb="saved"
  _dirpin_get "$name" >/dev/null && verb="updated"
  mkdir -p -- "$(dirname "$DIRPIN_FILE")" || return 1
  _dirpin_drop "$name" || return 1
  printf '%s\t%s\n' "$name" "$PWD" >> "$DIRPIN_FILE"
  echo "$verb: $name -> $PWD"
}

_dirpin_delete() {
  if [ -z "${1-}" ]; then
    echo "usage: $DIRPIN_CMD -d name" >&2
    return 1
  fi
  if ! _dirpin_get "$1" >/dev/null; then
    echo "dirpin: no bookmark '$1'" >&2
    return 1
  fi
  _dirpin_drop "$1"
  echo "deleted: $1"
}

_dirpin_path() {
  if [ -z "${1-}" ]; then
    echo "usage: $DIRPIN_CMD -p name" >&2
    return 1
  fi
  _dirpin_get "$1" || {
    echo "dirpin: no bookmark '$1'" >&2
    return 1
  }
}

_dirpin_jump() {
  local dir
  dir=$(_dirpin_get "$1") || {
    echo "dirpin: no bookmark '$1'" >&2
    return 1
  }
  if [ ! -d "$dir" ]; then
    echo "dirpin: directory no longer exists: $dir" >&2
    return 1
  fi
  cd -- "$dir" || return 1
}

# Print the contents of URL $1.
_dirpin_fetch() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --max-time 15 "$1"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- -T 15 "$1"
  else
    echo "dirpin: need curl or wget" >&2
    return 1
  fi
}

# Replace this file with the latest GitHub release's dirpin.sh.
_dirpin_update() {
  local dir latest tmp newest
  dir="$(cd "$(dirname "$_DIRPIN_SELF")" && pwd)"
  if [ -d "$dir/.git" ]; then
    echo "dirpin: running from a git clone; update with: git -C \"$dir\" pull" >&2
    return 1
  fi
  if [ ! -w "$_DIRPIN_SELF" ]; then
    echo "dirpin: $_DIRPIN_SELF is not writable" >&2
    return 1
  fi

  latest=$(_dirpin_fetch "https://api.github.com/repos/$DIRPIN_REPO/releases/latest" |
    sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -n 1)
  case "$latest" in
    "" | *[!0-9.]*)
      echo "dirpin: couldn't determine the latest version" >&2
      return 1
      ;;
  esac

  newest=$(printf '%s\n%s\n' "$DIRPIN_VERSION" "$latest" |
    sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)
  if [ "$newest" = "$DIRPIN_VERSION" ]; then
    echo "dirpin $DIRPIN_VERSION is up to date"
    return 0
  fi

  tmp=$(mktemp) || return 1
  if ! _dirpin_fetch "https://raw.githubusercontent.com/$DIRPIN_REPO/v$latest/dirpin.sh" > "$tmp" ||
    ! grep -q "^DIRPIN_VERSION=\"$latest\"" "$tmp" ||
    { command -v bash >/dev/null 2>&1 && ! bash -n "$tmp" 2>/dev/null; }; then
    rm -f "$tmp"
    echo "dirpin: download failed or file looks wrong; nothing changed" >&2
    return 1
  fi
  # Copy next to the target, then move over it, so a failure can't leave a half-written file.
  if cp "$tmp" "$_DIRPIN_SELF.new" && mv -- "$_DIRPIN_SELF.new" "$_DIRPIN_SELF"; then
    rm -f "$tmp"
    echo "updated $DIRPIN_VERSION -> $latest; open a new terminal or run: source \"$_DIRPIN_SELF\""
  else
    rm -f "$tmp" "$_DIRPIN_SELF.new"
    echo "dirpin: could not replace $_DIRPIN_SELF" >&2
    return 1
  fi
}

_dirpin_help() {
  cat <<HELP
dirpin $DIRPIN_VERSION - named directory bookmarks

  $DIRPIN_CMD              list bookmarks
  $DIRPIN_CMD name         jump to a bookmark
  $DIRPIN_CMD -s [name]    save the current directory (default name: folder name)
  $DIRPIN_CMD -d name      delete a bookmark
  $DIRPIN_CMD -p name      print a bookmark's path, e.g. cp file "\$($DIRPIN_CMD -p name)"
  $DIRPIN_CMD -u           update to the latest release
  $DIRPIN_CMD -h           show this help
  $DIRPIN_CMD -V           show the version

Bookmarks are stored in: $DIRPIN_FILE
HELP
}

_dirpin() {
  case "${1-}" in
    "" | -l | --list) _dirpin_list ;;
    -s | --save) _dirpin_save "${2-}" ;;
    -d | --delete) _dirpin_delete "${2-}" ;;
    -p | --path) _dirpin_path "${2-}" ;;
    -u | --update) _dirpin_update ;;
    -h | --help) _dirpin_help ;;
    -V | --version) echo "dirpin $DIRPIN_VERSION" ;;
    -*)
      echo "dirpin: unknown option '$1' (try $DIRPIN_CMD -h)" >&2
      return 1
      ;;
    *) _dirpin_jump "$1" ;;
  esac
}

# --- tab completion --------------------------------------------------------

# Fill COMPREPLY with the words in $1 that start with $2 (works on bash 3.2).
_dirpin_reply() {
  local w
  COMPREPLY=()
  while IFS= read -r w; do
    [ -n "$w" ] && COMPREPLY+=("$w")
  done < <(compgen -W "$1" -- "$2")
}

_dirpin_complete() {
  [ -n "${ZSH_VERSION-}" ] && setopt localoptions ksharrays
  local cur="${COMP_WORDS[COMP_CWORD]}" prev="${COMP_WORDS[COMP_CWORD - 1]}"
  case "$prev" in
    -s | --save) COMPREPLY=() ;; # a new name: nothing to suggest
    -d | --delete | -p | --path)
      _dirpin_reply "$(_dirpin_names)" "$cur"
      ;;
    *)
      if [[ "$cur" == -* ]]; then
        _dirpin_reply "-s -d -p -l -u -h -V" "$cur"
      else
        _dirpin_reply "$(_dirpin_names)" "$cur"
      fi
      ;;
  esac
}

# --- define the user-facing command ----------------------------------------

case "$DIRPIN_CMD" in
  "" | *[!A-Za-z0-9_-]*)
    echo "dirpin: invalid DIRPIN_CMD '$DIRPIN_CMD'; command not defined" >&2
    ;;
  *)
    # Don't shadow an existing command or alias (re-sourcing our own function is fine).
    if command -v "$DIRPIN_CMD" >/dev/null 2>&1 && ! typeset -f "$DIRPIN_CMD" >/dev/null 2>&1; then
      echo "dirpin: '$DIRPIN_CMD' already exists; set DIRPIN_CMD to another name" >&2
    else
      eval "$DIRPIN_CMD() { _dirpin \"\$@\"; }"
      if [ -n "${ZSH_VERSION-}" ]; then
        autoload -U +X bashcompinit 2>/dev/null && bashcompinit 2>/dev/null
      fi
      if command -v complete >/dev/null 2>&1; then
        complete -F _dirpin_complete "$DIRPIN_CMD" 2>/dev/null || true
      fi
    fi
    ;;
esac