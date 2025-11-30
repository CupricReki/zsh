# ZSH environment variables
# This file is sourced by all instances of zsh (login, non-login, interactive, non-interactive)
# Use for environment variables that should be available everywhere

# XDG Base Directory Specification
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"

# Main ZSH config directory
export ZSH_DIR="$HOME/.config/zsh"

# Customizations folder
export ZSH_CUSTOM="$ZSH_DIR/custom"
export ZCOMPLETION="$ZSH_DIR/completion"

# Cache directory (needed for kubectl, antibody, etc.)
export ZSH_CACHE_DIR="$HOME/.cache/zsh"

# Functions folder
export ZFUNC="$ZSH_DIR/function"
export ZSCRIPTS="$ZSH_DIR/script"
export ZLOCAL="$ZSH_DIR/local"
export ZBIN="$ZSH_DIR/bin"

# Editor configuration (if nvim exists, will be overridden in alias.zsh)
export VISUAL="${VISUAL:-vi}"
export EDITOR="${EDITOR:-vi}"

# Go configuration (if go is installed)
export GOPATH="$HOME/.go"
