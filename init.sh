#!/bin/bash

# zsh
# zsh setup script
# Update 5/2/21
# Requires zsh, git, curl, fzy

# Arch
# for spacship-prompt theme
# powerline-fonts
# noto-fonts-emoji

install_deb () {
	sudo apt install $1 -y
}

dep_check () {
# Checks for zsh, git, curl, fzy, and antibody

	type zsh >/dev/null 2>&1 || { deb_install "zsh"; }
	type git >/dev/null 2>&1 || { deb_install "git"; }
	type curl >/dev/null 2>&1 || { deb_install "curl"; }
	type fzy >/dev/null 2>&1 || { deb_install "fzy"; }
	type antibody >/dev/null 2>&1 || { install_antibody; }
}

get_zsh () {
	echo "Getting zsh configs from gitlab.ogbase.net/cupric/zsh.git"
	cd ~
	git clone https://gitlab.ogbase.net/cupric/zsh.git
	mv zsh .zsh
	rm .zshrc
	ln -s .zsh/.zshrc .zshrc
}

install_antibody () {
	echo "Getting antigen plugin manager from git.io/antibody"
	#mkdir ~/.zsh/antibody
	curl -sfL git.io/antibody | sudo sh -s - -b /usr/local/bin
}

dep_check
get_zsh

cd ~
#chsh -s /bin/zsh
exec zsh
