#!/bin/bash

# zsh
# zsh setup script
# Update 5/2/21
# Requires zsh, git, curl, fzy

# Arch
# for spacship-prompt theme
# powerline-fonts
# noto-fonts-emoji

type zsh >/dev/null 2>&1 || { echo >&2 "This script requires zsh, git and curl but at least zsh is not installed.  Aborting."; exit 2; }

type git >/dev/null 2>&1 || { echo >&2 "This script requires zsh, git and curl but at least git is not installed.  Aborting."; exit 2; }

type curl >/dev/null 2>&1 || { echo >&2 "This script requires zsh, git and curl but at least curl is not installed.  Aborting."; exit 2; }

type fzy >/dev/null 2>&1 || { echo >&2 "This script requires zsh, git and curl but at least fzy is not installed.  Aborting."; exit 2; }

cd ~
git clone https://gitlab.ogbase.net/cupric/zsh.git
mv zsh .zsh
rm .zshrc
ln -s .zsh/.zshrc .zshrc
# ln -s .zsh/.zlogin

# Antigen
mkdir ~/.zsh/antigen
cd ~/.zsh/antigen
curl -L git.io/antigen > antigen.zsh

exec zsh
