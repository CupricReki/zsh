#!/bin/bash

# zsh
# zsh setup script
# Update 12/23/23
# Requires zsh, git, curl, fzf, git

# Arch
# powerline-fonts
# noto-fonts-emoji

zshdir=$HOME/.config/zsh

deb_install () {
	sudo apt install $1 -y
}

dep_check () { # Checks for zsh, git, curl, fzf

	type zsh >/dev/null 2>&1 || { deb_install "zsh"; }
	type git >/dev/null 2>&1 || { deb_install "git"; }
	type curl >/dev/null 2>&1 || { deb_install "curl"; }
	type go >/dev/null 2>&1 || { deb_install "go"; }
	type osc >/dev/null 2>&1 || { go install -v github.com/theimpostor/osc@latest; }
}

get_zsh () {
	echo "Getting zsh configs from gitlab.ogbase.net/cupric/zsh.git"
    mkdir -p $zshdir
	git clone https://gitlab.ogbase.net/cupric/zsh.git $zshdir
	rm -f $HOME/.zshrc
	ln -s $zshdir/zshrc $HOME/.zshrc
   	ln -s $zshdir/zshenv $HOME/.zshenv
}

install_antibody () {
	echo "Getting antigen plugin manager from git.io/antibody"
	curl -sfL git.io/antibody | sudo sh -s - -b /usr/local/bin
}

check_zsh () {
    # Change shell if zsh was installed
    type zsh >/dev/null 2>&1 || { chsh "-s /bin/zsh"; }
}

directory_clean () {
	echo "removing zsh and any files matchin '.z*' "
	rm -fdr $HOME/.z*
	rm -fdr $zshdir
}

if [ "$1" = "clean" ]; then
	directory_clean
fi

sudo apt update
dep_check
get_zsh
install_antibody
check_zsh
zsh
