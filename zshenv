# ZSH environment variables
# This file is sourced by all instances of zsh (login, non-login, interactive, non-interactive)
# Use for environment variables that should be available everywhere

# ================================================
# Helper Functions
# ================================================
# Helper: check command exists without invoking it
command_exists() { command -v "$1" >/dev/null 2>&1 }

# Helper: check if directory exists
dir_exists() { [[ -d "$1" ]] }

# Helper: check if file exists
file_exists() { [[ -f "$1" ]] }

# ================================================
# Logging Function
# ================================================
# Unified logging function for consistent colored output
# Usage: log <level> <message>
#   Levels: success, error, warning, info, debug, notice
# Examples:
#   log success "Installation complete"
#   log error "Failed to install package"
#   log warning "Deprecated feature detected"
#   log info "Checking dependencies..."
log() {
  local level="$1"
  shift
  local message="$*"
  
  # Load colors if not already loaded
  [[ -z "${fg[green]:-}" ]] && autoload -U colors && colors
  
  case "$level" in
    success)
      echo "$fg[green]$message$reset_color" >&2
      ;;
    error)
      echo "$fg[red][X]$reset_color $message" >&2
      ;;
    warning)
      echo "$fg[yellow][!]$reset_color $message" >&2
      ;;
    info)
      echo "$fg[blue][i]$reset_color $message" >&2
      ;;
    debug)
      # Only show if DEBUG is set
      [[ -n "${DEBUG:-}" ]] && echo "$fg[grey][DEBUG]$reset_color $message" >&2
      ;;
    notice)
      echo "$fg[cyan][~]$reset_color $message" >&2
      ;;
    *)
      # Unknown level, just print the message
      echo "$message" >&2
      ;;
  esac
}

# XDG Base Directory Specification
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_CACHE_HOME="${HOME}/.cache"
export XDG_DATA_HOME="${HOME}/.local/share"

# Main ZSH config directory
export ZSH_DIR="${HOME}/.config/zsh"

# Customizations folder
export ZSH_CUSTOM="${ZSH_DIR}/custom"
export ZCOMPLETION="${ZSH_DIR}/completion"

# Cache directory (needed for kubectl, antibody, etc.)
export ZSH_CACHE_DIR="${XDG_CACHE_HOME}/zsh"

# Sheldon config directory
export SHELDON_CONFIG_DIR="${ZSH_DIR}/sheldon"

# Sheldon plugin manager data directory (stores cloned plugins)
export SHELDON_DATA_DIR="${ZSH_CACHE_DIR}/sheldon"

# Functions folder
export ZFUNC="${ZSH_DIR}/function"
export ZSCRIPTS="${ZSH_DIR}/script"
export ZLOCAL="${ZSH_DIR}/local"
export ZBIN="${ZSH_DIR}/bin"

# Local bin directory for user-installed binaries
export LOCAL_BIN="${HOME}/.local/bin"

# Editor configuration (if nvim exists, will be overridden in alias.zsh)
export VISUAL="${VISUAL:-vi}"
export EDITOR="${EDITOR:-vi}"

# Go configuration (if go is installed)
export GOPATH="/usr/local/go-packages"

# ================================================
# PATH Configuration
# ================================================
# PATH should be set in zshenv to be available to all shells (including non-interactive)
# This ensures scripts and non-interactive shells have access to the same tools

# Initialize path array (removes duplicates automatically)
typeset -U path

# System and user paths (standard locations)
path=(
    /usr/local/sbin
    /usr/local/bin
    /usr/sbin
    /usr/bin
    /sbin
    /bin
    /usr/games
    /usr/local/games
    "$HOME/bin"
    "$HOME/.local/bin"
    $path  # Preserve any existing paths
)

# Conditional paths (only add if directories exist)
# Rust/Cargo: user-installed crates
dir_exists "$HOME/.cargo/bin" && path=("$HOME/.cargo/bin" $path)

# Node.js/npm: user-installed global packages
dir_exists "$HOME/.npm-global/bin" && path=("$HOME/.npm-global/bin" $path)

# Go binaries
dir_exists "$HOME/.go/bin" && path=("$HOME/.go/bin" $path)


# ZSH config specific paths (only if ZSH_DIR is set)
if [[ -n "$ZSH_DIR" ]]; then
    dir_exists "$ZSH_DIR/bin" && path=("$ZSH_DIR/bin" $path)
    [[ -n "$ZSCRIPTS" ]] && dir_exists "$ZSCRIPTS" && path=("$ZSCRIPTS" $path)
fi

# Android SDK (if installed)
dir_exists "/opt/android-sdk/platform-tools" && path=("/opt/android-sdk/platform-tools" $path)

export PATH

# ================================================
# FPATH Configuration (interactive shells only)
# ================================================
# FPATH: Directories zsh searches for functions and completions
# Adding these directories makes:
#   - Custom functions in $ZFUNC available for autoload
#   - Custom completions in $ZCOMPLETION automatically discovered by compinit
#   - Local overrides in $ZLOCAL take priority
# Only set for interactive shells to avoid "function definition file not found" errors
# in non-interactive shells (e.g., cursor-agent, scripts)
if [[ -o interactive ]]; then
    export FPATH="$ZCOMPLETION:$ZFUNC:$ZLOCAL:$FPATH"
fi

# ================================================
# Rustup Environment Setup
# ================================================
# Source rustup environment if available
if file_exists "$HOME/.cargo/env"; then
  source "$HOME/.cargo/env"
fi
