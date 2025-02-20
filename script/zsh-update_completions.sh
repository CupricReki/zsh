#!/bin/bash

# Description: This script downloads the latest Zsh completion script for Docker
#              from the official GitHub repository and saves it to the specified
#              Zsh completions directory.
# Author: Skyler Ogden
# Revision Date: 2023-10-05

# Generate updated completions
wget "https://github.com/docker/cli/raw/master/contrib/completion/zsh/_docker" -O "$ZSH_DIR/completion/_docker"

# End of script
