# zsh

sudo apt install zsh

sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

git clone https://github.com/CupricReki/zsh.git

rm -fdr .oh-my.zsh
mv zsh .zsh
rm .zshrc
ln -s .zsh/zshrc .zshrc
