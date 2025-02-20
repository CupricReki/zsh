                                                               Overview

The aur-pkgupdate script is a Bash utility designed to simplify the process of updating the package version in Arch User Repository
(AUR) PKGBUILD files. It allows users to easily manage version updates, run makepkg, and commit changes to Git, all while providing
options for dry runs and error handling.


                                                               Features

 • Update Package Version: Automatically updates the pkgver in the PKGBUILD and .SRCINFO files.
 • Run makepkg: Optionally run makepkg to generate the .SRCINFO file.
 • Dry Run Option: Simulate the commit process without making any actual changes.
 • Version Validation: Ensures that the provided version follows semantic versioning (e.g., 1.0.0).
 • Error Handling: Provides informative error messages for file operations and Git commands.
 • Help Option: Displays usage information and available options.


                                                             Prerequisites

 • Bash shell
 • makepkg (part of the pacman package manager)
 • Git


                                                             Installation

 1 Download the Script: Save the script as aur-pkgupdate.sh.
 2 Make the Script Executable:

    chmod +x aur-pkgupdate.sh

 3 Move the Script to a Directory in Your PATH (optional):

    mv aur-pkgupdate.sh /usr/local/bin/aur-pkgupdate



                                                                 Usage

To use the aur-pkgupdate script, run the following command in your terminal:


 ./aur-pkgupdate.sh [options] [new_version]


                                                                Options

 • -d: Perform a dry run without committing changes. This will simulate the commit process and display what would be done.
 • –help: Display help information, including usage and available options.

                                                               Arguments

 • new_version: Specify the new version to set in the PKGBUILD and .SRCINFO. If not provided, the current version will be used.

                                                           Example Commands

 1 Update to a New Version:

    ./aur-pkgupdate.sh 1.2.0

 2 Run a Dry Run:

    ./aur-pkgupdate.sh -d 1.2.0

 3 Display Help Information:

    ./aur-pkgupdate.sh –help



                                                             How It Works

 1 The script checks for the existence and readability of the PKGBUILD and .SRCINFO files.
 2 It validates the provided version format to ensure it follows semantic versioning.
 3 The user is prompted to run makepkg if desired.
 4 The script updates the pkgver in the .SRCINFO file.
 5 The user is prompted to confirm the commit. If the dry run option is selected, the script will simulate the commit without making
   any changes.


                                                            Error Handling

The script includes error handling for various scenarios, including:

 • Missing or unreadable PKGBUILD or .SRCINFO files.
 • Invalid version format.
 • Errors during makepkg execution.
 • Errors during Git commit operations.


                                                                License

This script is released under the MIT License. Feel free to modify and distribute it as needed.
