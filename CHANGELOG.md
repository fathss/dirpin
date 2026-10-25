# Changelog

## Unreleased

## 0.3.1 - 2026-10-25

### Changed

- **Auto-reload on update (`dp -u`)**: Automatically sources `$_DIRPIN_SELF` after a successful release update, eliminating need to open a new terminal or manual reload.

### Added

- **Subpath navigation (`dp name/subpath`)**: Jump into subdirectories beneath a bookmark. Supports paths and subpaths with spaces without manual quoting.
- **Subpath printing (`dp -p name/subpath`)**: Resolve and print full subpath for scripts.
- **Tab completion for subpaths**: Auto-complete child directories with trailing slash in both Bash and Zsh, including folders containing spaces (escaped or quoted).
- **Path traversal protection**: Rejects `..` segments to ensure jumps remain inside bookmarked trees.

## 0.2.1 - 2026-10-25

### Fixed

- **Duplicate rc entries in `install.sh`**: Replaces existing `dirpin.sh` source lines and deduplicates multiple occurrences instead of appending duplicate blocks.
- **Robust uninstallation in `uninstall.sh`**: Removes any `dirpin.sh` source lines and comment blocks regardless of install path.

## 0.2.0 - 2026-10-25

### Added

- **Rename bookmark (`dp -r` / `--rename`)**: Rename an existing bookmark to a new name.
- **Stale bookmark cleanup (`dp -c` / `--clean`)**: Clean up bookmarks whose directory no longer exists.
- Tab completion and help text for `-r` and `-c`.

## 0.1.2 - 2026-10-25

### Added

- **Git clone symlinking**: `install.sh` automatically symlinks `dirpin.sh` when run from a clone so `git pull` updates dirpin immediately. Pass `--copy` to create a standalone copy instead.
- **Install version status**: `install.sh` clearly reports whether dirpin was freshly installed, already up to date, or updated.
- **Remote uninstaller**: Documented `curl ... | bash` uninstall in README.

### Fixed

- **Clone detection in `dp -u`**: Resolves symlinks so `dp -u` correctly detects git clones and prompts for `git pull` instead of overwriting the symlink.
- **Atomic install replacement**: Replaced direct `cp` with an atomic temp-and-move in `install.sh` so converting a symlink to `--copy` does not fail.
- **Concurrent save collisions**: Switched temporary files in `_dirpin_drop` to unique `mktemp` handles and made new bookmark saves append directly without rewriting the file.
- **Input validation**: `install.sh` now validates `DIRPIN_REF` and `DIRPIN_REPO` to prevent path traversal and malformed inputs.

## 0.1.1 - 2026-10-24

- Fix Zsh tab completion index offset.
- Fix default release repository and allow `DIRPIN_REPO` override in `install.sh`.

## 0.1.0 - 2026-10-24

- Initial release: save, jump, list, delete and print directory bookmarks.
- Tab completion for bash (zsh via `bashcompinit`).
- Configurable command name (`DIRPIN_CMD`) and data file (`DIRPIN_FILE`).
- Installer and uninstaller.
