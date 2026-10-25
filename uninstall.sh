#!/usr/bin/env bash
# Remove dirpin. Your bookmarks are kept unless you pass --purge.
# Usage: ./uninstall.sh [--purge] [--rc FILE]
set -euo pipefail

dest="${XDG_DATA_HOME:-$HOME/.local/share}/dirpin"
purge=0
rc=""
while [ $# -gt 0 ]; do
  case "$1" in
    --purge) purge=1 ;;
    --rc) rc="${2:?--rc needs a file}"; shift ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

if [ -z "$rc" ]; then
  case "${SHELL-}" in
    */zsh) rc="$HOME/.zshrc" ;;
    *) rc="$HOME/.bashrc" ;;
  esac
fi

if [ -f "$rc" ]; then
  tmp="$(mktemp "${rc}.tmp.XXXXXX" 2>/dev/null)" || tmp="${rc}.tmp.$$-$RANDOM"
  if awk '
    /^[[:space:]]*# dirpin: directory bookmarks/ { next }
    /^[[:space:]]*(source|\.)[[:space:]].*dirpin\.sh/ { next }
    { print }
  ' "$rc" > "$tmp"; then
    mv -f "$tmp" "$rc"
    echo "removed source line from $rc"
  else
    rm -f "$tmp"
  fi
fi

rm -f "$dest/dirpin.sh"
if [ "$purge" -eq 1 ]; then
  rm -rf "$dest"
  echo "removed $dest (including bookmarks)"
else
  echo "kept bookmarks in $dest (use --purge to delete)"
fi
