#!/bin/bash

# zsh
# zsh setup script
# Update 12/23/23
# Requires zsh, git, curl, fzf, git

# Arch
# powerline-fonts
# noto-fonts-emoji

deb_install () {
	sudo apt install $1 -y
}

dep_check () { # Checks for zsh, git, curl, fzf

	type zsh >/dev/null 2>&1 || { deb_install "zsh"; }
	type git >/dev/null 2>&1 || { deb_install "git"; }
	type curl >/dev/null 2>&1 || { deb_install "curl"; }
}

get_zsh () {
	echo "Getting zsh configs from gitlab.ogbase.net/cupric/zsh.git"
	git clone https://gitlab.ogbase.net/cupric/zsh.git $HOME/zsh
	mv $HOME/zsh $HOME/.zsh
	rm -f $HOME/.zshrc
	ln -s $HOME/.zsh/.zshrc $HOME/.zshrc
    ln -s $HOME/.zsh/.zshenv $HOME/.zshenv
}

install_antibody () {
	echo "Getting antigen plugin manager from git.io/antibody"
	#mkdir ~/.zsh/antibody
	curl -sfL git.io/antibody | sudo sh -s - -b /usr/local/bin
}

check_zsh () {
    # Change shell if zsh was installed
    type zsh >/dev/null 2>&1 || { chsh "-s /bin/zsh"; }
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
install_antibody
check_zsh
zsh
