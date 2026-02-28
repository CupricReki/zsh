#!/bin/bash

# zsh
# zsh setup script
# Update 11/30/25
# This script uses the ansible local setup script to configure zsh.
# It first checks for a local ansible directory, then clones if needed.

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
ANSIBLE_PROJECT_REPO="https://gitlab.timepiggy.com/cupric/ansible.git"
LOCAL_ANSIBLE_DIR="$HOME/ansible"
TEMP_DIR="/tmp/ansible_bootstrap_zsh" # Use a system temp directory
trap 'rm -rf "${TEMP_DIR}"' EXIT

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

# Check if the local ansible project is fully present (not just a leftover
# collections/ dir from a previous failed bootstrap run).
_run_sh="${LOCAL_ANSIBLE_DIR}/scripts/setup_zsh_local/run.sh"
if [[ -f "$_run_sh" ]]; then
    log info "Found local Ansible directory at ${LOCAL_ANSIBLE_DIR}"
    log info "Executing the Zsh local setup script..."
    "$_run_sh"
    unset _run_sh
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


