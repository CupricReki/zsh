#!/bin/bash

# zsh
# zsh setup script
# Update 5/2/21
# Requires zsh, git, curl, fzy

# Arch
# for spacship-prompt theme
# powerline-fonts
# noto-fonts-emoji

deb_install () {
	sudo apt install $1 -y
}

dep_check () { # Checks for zsh, git, curl, fzy, and antibody

	type zsh >/dev/null 2>&1 || { deb_install "zsh"; }
	type git >/dev/null 2>&1 || { deb_install "git"; }
	type curl >/dev/null 2>&1 || { deb_install "curl"; }
	type fzy >/dev/null 2>&1 || { deb_install "fzy"; }
	type antibody >/dev/null 2>&1 || { install_antibody; }
}

get_zsh () {
	echo "Getting zsh configs from gitlab.ogbase.net/cupric/zsh.git"
	cd $HOME
	git clone https://gitlab.ogbase.net/cupric/zsh.git
	mv zsh .zsh
	rm -f .zshrc
	ln -s .zsh/.zshrc .zshrc
}

install_antibody () {
	echo "Getting antigen plugin manager from git.io/antibody"
	#mkdir ~/.zsh/antibody
	curl -sfL git.io/antibody | sudo sh -s - -b /usr/local/bin
}

check_zsh () {
    # Change shell if zsh was installed
    type zsh >/dev/null 2>&1 || { chsh -s /bin/zsh }
}

directory_clean () {
	echo "removing zsh and any files matchin '.z*' "
	rm -fdr .z*
	rm -fdr zsh
}

if [ "$1" = "clean" ]; then
	directory_clean
fi

dep_check
get_zsh
check_zsh
zsh
echo 'reload shell or run exec zsh'
