# dirpin

Named directory bookmarks in a single, dependency-free shell file.

`cd` into a deeply nested folder once, give it a name, and jump back from any terminal with `dp name`. Names are yours, so they always resolve to the same place.

```console
$ cd ~/work/clients/acme/backend/services/api
$ dp -s api
saved: api -> /home/you/work/clients/acme/backend/services/api

$ cd /            # anywhere, any terminal
$ dp api          # back in one step
$ dp              # list bookmarks
api              /home/you/work/clients/acme/backend/services/api
```

## Install

### Quick install

```bash
curl -fsSL https://raw.githubusercontent.com/fathss/dirpin/main/install.sh | bash
```

Piping a script into your shell means trusting it, so [read it first](install.sh) if you like. To pin a release instead of `main`:

```bash
curl -fsSL https://raw.githubusercontent.com/fathss/dirpin/v0.1.0/install.sh | DIRPIN_REF=v0.1.0 bash
```

### From a clone

```bash
git clone https://github.com/fathss/dirpin.git
cd dirpin
./install.sh
```

Both methods copy `dirpin.sh` to `~/.local/share/dirpin/` and add one `source` line to your `~/.bashrc` (or `~/.zshrc` if your shell is zsh). Open a new terminal afterwards. To use a different file, run `./install.sh --rc ~/.bash_profile` (or `bash -s -- --rc ~/.bash_profile` after the curl pipe).

### By hand

Put `dirpin.sh` anywhere and add `source /path/to/dirpin.sh` to your rc file. It has to be sourced, not executed, because a child process can't change your shell's directory.

### Uninstall

From a clone: `./uninstall.sh` (add `--purge` to delete your bookmarks too).

Without a clone: remove the `source` line and the `# dirpin` comment from your rc file, then `rm -rf ~/.local/share/dirpin`. That last command also deletes your bookmarks.

## Usage

| Command           | What it does                                               |
| ----------------- | ---------------------------------------------------------- |
| `dp`              | List bookmarks (missing directories are flagged)           |
| `dp name`         | Jump to a bookmark                                         |
| `dp -s [name]`    | Save the current directory (defaults to the folder's name) |
| `dp -d name`      | Delete a bookmark                                          |
| `dp -p name`      | Print the path, for scripts: `cp file "$(dp -p api)"`      |
| `dp -u`           | Update to the latest release                               |
| `dp -h` / `dp -V` | Help / version                                             |

Tab completion works for bookmark names and flags.

Bookmark names can't contain whitespace or slashes, or start with `-`.

## Configuration

Set these before the `source` line in your rc file.

| Variable      | Default                           | Purpose                                                                                          |
| ------------- | --------------------------------- | ------------------------------------------------------------------------------------------------ |
| `DIRPIN_CMD`  | `dp`                              | Name of the command. dirpin refuses to shadow an existing command, so set this if `dp` is taken. |
| `DIRPIN_FILE` | `~/.local/share/dirpin/bookmarks` | Where bookmarks are stored                                                                       |
| `DIRPIN_REPO` | `YOUR_USERNAME/dirpin`            | Repository that `dp -u` checks for releases. Set it if you run a fork.                           |
|               |

Bookmarks live in a plain tab-separated text file, so they're easy to back up or keep in a dotfiles repo.

## Updating

```bash
dp -u
```

This checks the latest GitHub release and replaces `dirpin.sh` if there's a newer version. If you installed from a git clone, update with `git pull` instead. Open a new terminal afterwards to load the new version.

## Development

```bash
make lint   # shellcheck
make test   # bats
```

Requires [bats-core](https://github.com/bats-core/bats-core) and [shellcheck](https://www.shellcheck.net/).

## Releasing

1. Bump `DIRPIN_VERSION` in `dirpin.sh` and add a `## X.Y.Z` section to `CHANGELOG.md`.
2. Commit, push, and wait for CI to pass.
3. Tag and push the tag:

   ```bash
   git tag vX.Y.Z && git push --tags
   ``
   ```

## Roadmap

- `dp -r old new` to rename
- `dp -c` to clean up bookmarks whose directory no longer exists
- Subpath jumping: `dp api/src/controllers`
- Project-local bookmark files that teammates share through the repo
- zsh and more Linux distributions in CI

## License

MIT
