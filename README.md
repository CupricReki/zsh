# Install

````code
wget -O - https://gitlab.ogbase.net/cupric/zsh/-/raw/master/init.sh | bash
````

> Install zsh, oh-my-zsh, curl, and fzy first
````code
sudo apt install -y zsh git curl fzy
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
``````
Run init script (this is enough for a full install)
````code
./init.sh
````

## Remove pre-configured files
````code
rm -fdr .oh-my.zsh
mv zsh .zsh
rm .zshrc
````

## Link new config file
````code
ln -s .zsh/.zshrc .zshrc
````

## Get Antigen
````code
mkdir ~/.zsh/antigen
cd ~/.zsh/antigen
curl -L git.io/antigen > antigen.zsh
````


## Initialize
````code
exec zsh
````

## Fedora install fzy
````code
sudo dnf install dnf-plugins-core
sudo dnf copr enable lehrenfried/fzy
sudo dnf install fzy -y
````
## Change shell to zsh
````code
chsh -s /bin/zsh
````

## Update

````code
cd ~/.zsh && git pull && exec zsh
````
