# GEMINI.md: Zsh Configuration

## Directory Overview

This repository contains a comprehensive set of configuration files for the Zsh shell. It aims to provide a modern, feature-rich, and efficient command-line experience. The configuration is modular, with different aspects of the setup split into logical directories.

The setup is automated via an installation script (`init.sh`) and uses `antibody` for plugin management.

## Key Files

*   **`zshrc`**: The main entry point for the Zsh configuration. It sources other configuration files, sets up shell options, and configures plugins.
*   **`zshenv`**: This file is used to set environment variables. It follows the XDG Base Directory Specification to keep the home directory clean.
*   **`init.sh`**: The installation script. It clones the repository, installs dependencies (like `antibody`, `fzf`, etc.), and creates the necessary symlinks.
*   **`custom/`**: This directory contains all the custom configurations, including:
    *   **`alias/`**: Custom command aliases.
    *   **`cupric_gnzh.zsh-theme`**: A custom theme for the prompt.
    *   **`fzf_*.zsh`**: Configuration files for `fzf`, a command-line fuzzy finder.
    *   **`keybindings.zsh`**: Custom keybindings.
*   **`function/`**: This directory holds custom Zsh functions that can be autoloaded.
*   **`script/`**: This directory contains various helper scripts.
*   **`completion/`**: Zsh completion scripts for various commands.

## Usage

This configuration is intended to be used as a complete replacement for the default Zsh setup.

### Installation

The `init.sh` script automates the installation process. It can be run directly from the web:

```bash
wget -O - https://gitlab.timepiggy.com/cupric/zsh/-/raw/master/init.sh | bash
```

Alternatively, you can clone the repository and run the script manually:

```bash
git clone https://gitlab.timepiggy.com/cupric/zsh.git ~/.config/zsh
cd ~/.config/zsh
./init.sh
```

### Customization

To add your own customizations, you can create files in the following directories:

*   **`$ZSH_CUSTOM/alias/`**: For new aliases.
*   **`$ZLOCAL/`**: For local environment variables and settings. This directory is sourced before other configurations, so you can override default settings here.

### Updating

The configuration can be updated by pulling the latest changes from the git repository:

```bash
cd ~/.config/zsh && git pull
```

There is also a custom alias `zgu` for this.
