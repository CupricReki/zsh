# zsh

sudo apt install -y zsh git curl

sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

git clone https://github.com/CupricReki/zsh.git

rm -fdr .oh-my.zsh

mv zsh .zsh

rm .zshrc

ln -s .zsh/.zshrc .zshrc

source .zshrc
