# Install

Install zsh, oh-my-zsh, curl, and fzy first
````code
sudo apt install -y zsh git curl
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
``````

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
