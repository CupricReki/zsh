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

# --- Main Script ---
echo "--- Starting Zsh Local Bootstrap via Ansible ---"

# Check if local ansible directory exists
if [[ -d "$LOCAL_ANSIBLE_DIR" ]]; then
    echo "STEP 1: Found local Ansible directory at ${LOCAL_ANSIBLE_DIR}"
    echo "STEP 2: Executing the Zsh local setup script..."
    "${LOCAL_ANSIBLE_DIR}/scripts/setup_zsh_local/run.sh"
else
    echo "STEP 1: Local Ansible directory not found, cloning from ${ANSIBLE_PROJECT_REPO}..."
    
    # 1. Clean up any previous temporary directory
    rm -rf "${TEMP_DIR}"

    # 2. Clone the Ansible project
    echo "STEP 2: Cloning Ansible project to ${TEMP_DIR}..."
    git clone "${ANSIBLE_PROJECT_REPO}" "${TEMP_DIR}"

    # 3. Execute the local bootstrap script from the cloned repository
    echo "STEP 3: Executing the Zsh local setup script..."
    "${TEMP_DIR}/scripts/setup_zsh_local/run.sh"

    # 4. Cleanup
    echo "STEP 4: Cleaning up temporary directory..."
    rm -rf "${TEMP_DIR}"
fi

echo ""
echo "--- Zsh Bootstrap Complete! ---"


