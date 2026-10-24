# Contributing to dirpin

Thanks for considering a contribution. dirpin is deliberately small. One sourced shell file, no dependencies. Changes that keep it that way are the easiest to accept.

## Before you start

- **Bugs and small fixes:** open a pull request directly.
- **New features:** open an issue first, so we can agree on the approach before you write code.
- **Questions:** an issue is fine.

A feature is more likely to be accepted if it works without extra dependencies, behaves the same in bash and zsh, and doesn't add a command or flag for a rare case.

## Making a change

1. Fork the repo and create a branch from `main`.
2. Make your change, with a test for it (see below).
3. Run `make lint` and `make test`.
4. Add a line under an "Unreleased" heading at the top of `CHANGELOG.md`, if the change is visible to users (a new feature or a bug fix).
5. Open a pull request that says what changed and why. Keep it focused, since one change per pull request is easier to review.

## Tests

- Tests live in `test/` and use bats. `test/test_helper.bash` isolates every test in a temp directory with its own `HOME` and bookmarks file, so tests never touch your real bookmarks.
- Add a test for each new behavior and each bug you fix. For a bug, write the failing test first.
- **Updater tests run on a copy of `dirpin.sh`**, not the repo file, because `dp -u` rewrites the file it was loaded from. Don't change them to source the repo file directly.

## Code guidelines

dirpin has to run in bash and zsh, on Linux and macOS, so a few habits matter:

- **Quote everything**, and keep paths with spaces working.
- **Prefix internals with `_dirpin_`** so they don't clash with the user's shell functions. The only public name is the command (`dp` by default).
- **Don't print to stdout from functions meant for command substitution** unless it's the value. Messages go to stderr.
- **Fix shellcheck warnings** rather than disabling them. If a disable is truly needed, explain it in a comment.
- **Don't change the bookmarks file format** without a migration plan. People keep it in dotfiles repos.

## Reporting bugs

Please include:

- The output of `dp -V`
- Your shell and version (`bash --version` or `zsh --version`) and your OS
- The steps to reproduce, and what you expected to happen

## Releases

Maintainers publish releases by pushing a version tag, and the release workflow does the rest. You don't need to bump `DIRPIN_VERSION` in your pull request. See [Releasing](README.md#releasing) for the process.

## License

By contributing, you agree that your contribution is licensed under the [MIT License](LICENSE).
