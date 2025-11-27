#!/bin/bash

# zsh
# zsh setup script
# Update 11/26/25
# This script uses the ansible local setup script to configure zsh by cloning the ansible repo.

set -e # Exit immediately if a command exits with a non-zero status.

# --- Configuration ---
ANSIBLE_PROJECT_REPO="https://gitlab.ogbase.net/cupric/ansible.git"
TEMP_DIR="/tmp/ansible_bootstrap_zsh" # Use a system temp directory

# --- Main Script ---
echo "--- Starting Zsh Local Bootstrap via Ansible Clone ---"

# 1. Clean up any previous temporary directory
rm -rf "${TEMP_DIR}"

# 2. Clone the Ansible project
echo "STEP 1: Cloning Ansible project from ${ANSIBLE_PROJECT_REPO} to ${TEMP_DIR}..."
git clone "${ANSIBLE_PROJECT_REPO}" "${TEMP_DIR}"

# 3. Execute the local bootstrap script from the cloned repository
echo "STEP 2: Executing the Zsh local setup script..."
"${TEMP_DIR}/scripts/setup_zsh_local/run.sh"

# 4. Cleanup
echo "STEP 3: Cleaning up temporary directory..."
rm -rf "${TEMP_DIR}"

echo ""
echo "--- Zsh Bootstrap Complete! ---"


