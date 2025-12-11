#!/bin/bash

# zsh
# zsh setup script
# Update 11/30/25
# This script uses the ansible local setup script to configure zsh.
# It first checks for a local ansible directory, then clones if needed.

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
ANSIBLE_PROJECT_REPO="https://gitlab.ogbase.net/cupric/ansible.git"
LOCAL_ANSIBLE_DIR="$HOME/ansible"
TEMP_DIR="/tmp/ansible_bootstrap_zsh" # Use a system temp directory
ZSH_CONFIG_DIR="$HOME/.config/zsh"

# --- Logging Function (bash-compatible) ---
# Unified logging function for consistent colored output
# Usage: log <level> <message>
log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        success)
            echo -e "\033[0;32m${message}\033[0m" >&2
            ;;
        error)
            echo -e "\033[0;31m[X]\033[0m ${message}" >&2
            ;;
        warning)
            echo -e "\033[0;33m[!]\033[0m ${message}" >&2
            ;;
        info)
            echo -e "\033[0;34m[i]\033[0m ${message}" >&2
            ;;
        debug)
            [[ -n "${DEBUG:-}" ]] && echo -e "\033[0;90m[DEBUG]\033[0m ${message}" >&2
            ;;
        notice)
            echo -e "\033[0;36m[~]\033[0m ${message}" >&2
            ;;
        *)
            echo "$message" >&2
            ;;
    esac
}

# --- Main Script ---
echo "--- Starting Zsh Local Bootstrap via Ansible ---"

# --- Preflight: Ensure sheldon is installed ---
echo ""
echo "Preflight: Checking dependencies..."

if ! command -v sheldon &> /dev/null; then
    log warning "sheldon is not installed"
    echo "Installing sheldon (required for plugin management)..."
    
    if [[ -x "$ZSH_CONFIG_DIR/script/ensure-sheldon" ]]; then
        "$ZSH_CONFIG_DIR/script/ensure-sheldon"
    else
        log error "ensure-sheldon script not found at $ZSH_CONFIG_DIR/script/ensure-sheldon"
        echo "Please install sheldon manually:"
        echo "  cargo install sheldon"
        echo "  OR"
        echo "  yay -S sheldon"
        exit 1
    fi
else
    log success "sheldon is installed ($(sheldon --version))"
fi

echo ""

# Check if local ansible directory exists
if [[ -d "$LOCAL_ANSIBLE_DIR" ]]; then
    log info "Found local Ansible directory at ${LOCAL_ANSIBLE_DIR}"
    log info "Executing the Zsh local setup script..."
    "${LOCAL_ANSIBLE_DIR}/scripts/setup_zsh_local/run.sh"
else
    log info "Local Ansible directory not found, cloning from ${ANSIBLE_PROJECT_REPO}..."
    
    # 1. Clean up any previous temporary directory
    rm -rf "${TEMP_DIR}"

    # 2. Clone the Ansible project
    log info "Cloning Ansible project to ${TEMP_DIR}..."
    git clone "${ANSIBLE_PROJECT_REPO}" "${TEMP_DIR}"

    # 3. Execute the local bootstrap script from the cloned repository
    log info "Executing the Zsh local setup script..."
    "${TEMP_DIR}/scripts/setup_zsh_local/run.sh"

    # 4. Cleanup
    log info "Cleaning up temporary directory..."
    rm -rf "${TEMP_DIR}"
fi

echo ""
log success "Zsh Bootstrap Complete!"


