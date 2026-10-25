#!/usr/bin/env bash
# Install dirpin: put dirpin.sh in ~/.local/share/dirpin and source it from your rc file.
#
#   From a clone:  ./install.sh [--copy] [--rc FILE]
#   Via curl:      curl -fsSL https://raw.githubusercontent.com/fathss/dirpin/main/install.sh | bash
#   Options via curl: ... | bash -s -- --rc ~/.zshrc
#   Pin a version:    ... | DIRPIN_REF=v0.1.0 bash
set -euo pipefail

REPO="${DIRPIN_REPO:-fathss/dirpin}"
REF="${DIRPIN_REF:-main}"

case "$REF" in
  "" | *[!a-zA-Z0-9._/-]* | *".."*)
    echo "error: invalid DIRPIN_REF '$REF'" >&2
    exit 1
    ;;
esac

case "$REPO" in
  "" | *[!a-zA-Z0-9._/-]* | *".."*)
    echo "error: invalid DIRPIN_REPO '$REPO'" >&2
    exit 1
    ;;
esac

RAW_URL="https://raw.githubusercontent.com/$REPO/$REF/dirpin.sh"
dest="${XDG_DATA_HOME:-$HOME/.local/share}/dirpin"

copy=0
rc=""
while [ $# -gt 0 ]; do
  case "$1" in
    --copy) copy=1 ;;
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

# Local clone next to this script? Use it. Otherwise (curl | bash) download.
script_dir=""
if [ -n "${BASH_SOURCE[0]-}" ]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

is_clone=0
if [ -n "$script_dir" ] && [ -f "$script_dir/dirpin.sh" ] && [ -e "$script_dir/.git" ]; then
  is_clone=1
fi

old_ver=""
if [ -f "$dest/dirpin.sh" ]; then
  old_ver="$(sed -n 's/^DIRPIN_VERSION="\([^"]*\)"/\1/p' "$dest/dirpin.sh" 2>/dev/null || true)"
fi

mkdir -p "$dest"
if [ "$copy" -eq 0 ] && [ "$is_clone" -eq 1 ]; then
  ln -sf "$script_dir/dirpin.sh" "$dest/dirpin.sh"
  echo "linked $dest/dirpin.sh -> $script_dir/dirpin.sh"
elif [ -n "$script_dir" ] && [ -f "$script_dir/dirpin.sh" ]; then
  cp "$script_dir/dirpin.sh" "$dest/dirpin.sh.tmp"
  mv -f "$dest/dirpin.sh.tmp" "$dest/dirpin.sh"
else
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  echo "downloading $RAW_URL"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$RAW_URL" -o "$tmp"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$tmp" "$RAW_URL"
  else
    echo "error: need curl or wget" >&2
    exit 1
  fi
  if ! grep -q '^DIRPIN_VERSION=' "$tmp"; then
    echo "error: downloaded file doesn't look like dirpin.sh" >&2
    exit 1
  fi
  mv "$tmp" "$dest/dirpin.sh"
  chmod 644 "$dest/dirpin.sh"
fi

line="source \"$dest/dirpin.sh\""
touch "$rc"
matches=$(grep -c -E '^[[:space:]]*(source|\.)[[:space:]].*dirpin\.sh' "$rc" || true)

if [ "$matches" -eq 1 ] && grep -qxF "$line" "$rc"; then
  echo "already configured in $rc"
elif [ "$matches" -gt 0 ]; then
  tmp="$(mktemp "${rc}.tmp.XXXXXX" 2>/dev/null)" || tmp="${rc}.tmp.$$-$RANDOM"
  if awk -v new="$line" '
    /^[[:space:]]*# dirpin: directory bookmarks/ {
      if (saw_comment) next
      saw_comment = 1
    }
    /^[[:space:]]*(source|\.)[[:space:]].*dirpin\.sh/ {
      if (!done) { print new; done = 1 }
      next
    }
    { print }
  ' "$rc" > "$tmp"; then
    mv -f "$tmp" "$rc"
    echo "updated in $rc"
  else
    rm -f "$tmp"
  fi
else
  printf '\n# dirpin: directory bookmarks\n%s\n' "$line" >> "$rc"
  echo "added to $rc"
fi

new_ver="$(sed -n 's/^DIRPIN_VERSION="\([^"]*\)"/\1/p' "$dest/dirpin.sh" 2>/dev/null || true)"
if [ -z "$old_ver" ]; then
  echo "installed dirpin ${new_ver:+$new_ver }to $dest"
elif [ "$old_ver" = "$new_ver" ]; then
  echo "dirpin $new_ver is already up to date in $dest"
else
  echo "updated dirpin $old_ver -> $new_ver in $dest"
fi
echo "Open a new terminal, or run: source \"$rc\""
case "$rc" in
  *zshrc) echo "zsh note: the source line must come after 'compinit' in $rc for tab completion." ;;
esac
