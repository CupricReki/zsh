# zsh
# zsh setup script
# Update 5/2/21
# Requires zsh, git, and curl
if ! command -v zsh &>/dev/null; then
  echo 'Install ZSH first'
  exit 2
elif ! command -v git &>/dev/null; then
  echo 'Install git first'
  exit 2
elif ! command -v curl &>/dev/null; then
  echo 'Install curl first'
  exit 2
fi

cd ~
git clone https://github.com/CupricReki/zsh.git
mv zsh .zsh
rm .zshrc
ln -s .zsh/.zshrc .zshrc

# Installing oh-my-zsh
cd ~/.zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --keep-zshrc

# Antigen
curl -L git.io/antigen > antigen.zsh

source .zshrc
