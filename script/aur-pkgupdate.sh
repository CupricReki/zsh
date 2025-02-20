#!/bin/bash

# Script Name: aur-pkgupdate.sh
# Description: This script manages version updates for a PKGBUILD and .SRCINFO file.
#              It allows for a dry run, validates version formats, and commits changes to git.
# Author: Skyler Ogden
# Revision Date: 2023-10-05

# Function to display help information
show_help() {
    echo "Usage: $0 [-d] [new_version]"
    echo
    echo "Options:"
    echo "  -d            Perform a dry run without committing changes."
    echo "  new_version   Specify the new version to set in the PKGBUILD and .SRCINFO."
    echo "                If not provided, the current version will be used."
    echo "  --help        Display this help message."
    exit 0
}

# Function to check if a file exists and is readable
check_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "Error: $file not found."
        exit 1
    elif [[ ! -r "$file" ]]; then
        echo "Error: $file is not readable."
        exit 1
    fi
}

# Function to validate the version format
validate_version() {
    local version="$1"
    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Error: Invalid version format. Use semantic versioning (e.g., 1.0.0)."
        exit 1
    fi
}

# Function to get the current pkgver from PKGBUILD
get_current_version() {
    check_file "PKGBUILD"  # Check if the file exists and is readable
    local version
    version=$(grep -E '^pkgver=' PKGBUILD | cut -d'=' -f2 | xargs)
    if [[ -z "$version" ]]; then
        echo "Error: pkgver not found in PKGBUILD."
        exit 1
    fi
    echo "$version"
}

# Function to update pkgver in .SRCINFO
update_pkgver() {
    local new_ver="$1"
    check_file ".SRCINFO"  # Check if the file exists and is readable
    sed -i -E "s#(pkgver\s*=\s*).*#\1$new_ver#" .SRCINFO
    echo "Updated pkgver to $new_ver in .SRCINFO"
}

# Function to run makepkg
run_makepkg() {
    echo "Running makepkg..."
    if ! makepkg --printsrcinfo; then
        echo "Error: makepkg failed."
        exit 1
    fi
}

# Main script logic
dry_run=false

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -d)
            dry_run=true
            shift
            ;;
        --help)
            show_help
            ;;
        *)
            if [[ -z "$new_ver" ]]; then
                new_ver="$1"
            else
                echo "Error: Too many arguments."
                show_help
            fi
            shift
            ;;
    esac
done

if [[ -n "$new_ver" ]]; then
    validate_version "$new_ver"  # Validate the provided version
else
    new_ver=$(get_current_version)
    echo "No version argument provided. Using current version: $new_ver"
fi

# Ask if makepkg should be run first
read -p "Do you want to run makepkg first? (Y/n): " run_makepkg_first
run_makepkg_first=${run_makepkg_first:-Y}  # Default to 'Y'
if [[ "$run_makepkg_first" =~ ^[Yy]$ ]]; then
    run_makepkg
fi

# Update the pkgver in .SRCINFO
update_pkgver "$new_ver"

# Confirm the version before committing
read -p "Are you sure you want to commit the changes with version '$new_ver'? (Y/n): " confirm_commit
confirm_commit=${confirm_commit:-Y}  # Default to 'Y'
if [[ "$confirm_commit" =~ ^[Yy]$ ]]; then
    if $dry_run; then
        echo "Dry run: Changes would be committed with version '$new_ver'."
        echo "Files to be added: PKGBUILD, .SRCINFO"
    else
        # Add only PKGBUILD and .SRCINFO to the git commit
        git add PKGBUILD .SRCINFO
        
        # Commit the changes using git
        if git commit -m "Update to $new_ver"; then
            echo "Changes committed to git."
        else
            echo "Error: Git commit failed."
            exit 1
        fi
    fi
else
    echo "Commit aborted."
fi

# End of script
