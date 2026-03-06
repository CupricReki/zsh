## Learned User Preferences

- Only commit files that were intentionally changed for the current request; avoid including unrelated staged or modified files in commits.

## Learned Workspace Facts

- This workspace is a zsh dotfiles repo: zshenv, zshrc, custom/, migrations/, script/.
- Go and Cargo use XDG-style paths: `~/.local/share/go` and `~/.local/share/cargo/bin` (see migrations and zshenv).
- For zsh config migrations: signal failure with `return 1` so run-migrations retries; wrap the body in a function so `local` variables are scoped (sourced files ignore `local` at top level).
- When configuring login shell for users (e.g. FreeIPA or new hosts), use `/bin/bash` until zsh is installed; setting shell to zsh when zsh is not installed causes login to fail.
