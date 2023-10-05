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

dep_check () { # Checks for zsh, git, curl, fzf

	type zsh >/dev/null 2>&1 || { deb_install "zsh"; }
	type git >/dev/null 2>&1 || { deb_install "git"; }
	type curl >/dev/null 2>&1 || { deb_install "curl"; }
	type fzf >/dev/null 2>&1 || { deb_install "fzf"; }
}

get_zsh () {
	echo "Getting zsh configs from gitlab.ogbase.net/cupric/zsh.git"
	git clone https://gitlab.ogbase.net/cupric/zsh.git $HOME
	mv $HOME/zsh $HOME/.zsh
	rm -f $HOME/.zshrc
	ln -s $HOME/.zsh/.zshrc $HOME/.zshrc
}

install_antibody () {
	echo "Getting antigen plugin manager from git.io/antibody"
	#mkdir ~/.zsh/antibody
	curl -sfL git.io/antibody | sudo sh -s - -b /usr/local/bin
}

install_starship () {
    echo "Getting spaceship from https://starship.rs/install.sh"
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
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
install_starship
check_zsh
zsh
echo 'reload shell or run exec zsh'
