# zsh
# zsh setup script
# Update 5/2/21
# Requires zsh, git, curl, fzy
if ! command -v zsh &>/dev/null; then
  echo 'Install ZSH first'
  exit 2
elif ! command -v git &>/dev/null; then
  echo 'Install git first'
  exit 2
elif ! command -v curl &>/dev/null; then
  echo 'Install curl first'
  exit 2
elif ! command -v fzy &>/dev/null; then
  echo 'Install fzy first'
  exit 2
fi

cd ~
git clone https://github.com/CupricReki/zsh.git
mv zsh .zsh
rm .zshrc
ln -s .zsh/.zshrc .zshrc

# Antigen
mkdir ~/.zsh/antigen
cd ~/.zsh/antigen
curl -L git.io/antigen > antigen.zsh

# https://github.com/b4b4r07/enhancd
source .zshrc
