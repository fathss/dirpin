#!/usr/bin/env bash
# Install dirpin: put dirpin.sh in ~/.local/share/dirpin and source it from your rc file.
#
#   From a clone:  ./install.sh [--rc FILE]
#   Via curl:      curl -fsSL https://raw.githubusercontent.com/fathss/dirpin/main/install.sh | bash
#   Options via curl: ... | bash -s -- --rc ~/.zshrc
#   Pin a version:    ... | DIRPIN_REF=v0.1.0 bash
set -euo pipefail

REPO="fathss/dirpin"
REF="${DIRPIN_REF:-main}"
RAW_URL="https://raw.githubusercontent.com/$REPO/$REF/dirpin.sh"
dest="${XDG_DATA_HOME:-$HOME/.local/share}/dirpin"

rc=""
if [ "${1-}" = "--rc" ]; then
  rc="${2:?--rc needs a file}"
else
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

mkdir -p "$dest"
if [ -n "$script_dir" ] && [ -f "$script_dir/dirpin.sh" ]; then
  cp "$script_dir/dirpin.sh" "$dest/dirpin.sh"
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
if grep -qxF "$line" "$rc"; then
  echo "already configured in $rc"
else
  printf '\n# dirpin: directory bookmarks\n%s\n' "$line" >> "$rc"
  echo "added to $rc"
fi

echo "Installed to $dest"
echo "Open a new terminal, or run: source \"$rc\""
case "$rc" in
  *zshrc) echo "zsh note: the source line must come after 'compinit' in $rc for tab completion." ;;
esac
