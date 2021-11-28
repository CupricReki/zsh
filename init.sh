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

dep_check () {
	# Checks for zsh, git, curl, fzy, and antibody

	type zsh >/dev/null 2>&1 || { deb_install "zsh"; }
	type git >/dev/null 2>&1 || { deb_install "git"; }
	type curl >/dev/null 2>&1 || { deb_install "curl"; }
	type fzy >/dev/null 2>&1 || { deb_install "fzy"; }
	type sqlite3 >/dev/null 2>&1 || { deb_install "sqlite3"; }
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

check_zsh () {
	# Checks to see if zsh is the default shell and offers to change it if it isn't
	if [[ $(getent passwd $USER | awk -F: '{print $NF}') != "/bin/zsh" ]]; then
		read -r -p "Change default shell to /bin/zsh? [Y/n] " input

		case $input in
		    [yY][eE][sS]|[yY])
		 chsh -s /bin/zsh
		 ;;
		    [nN][oO]|[nN])
		 echo "You can change the default shell to zsh using 'chsh -s /bin/zsh'"
		       ;;
		    *)
		 echo "Invalid input..."
		 exit 1
		 ;;
		esac

	else
		echo "zsh is already the default shell"
	fi
}

dep_check
get_zsh
check_zsh
zsh
echo 'reload shell or run exec zsh'