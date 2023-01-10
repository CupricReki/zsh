# Requirements
# 1. ZSH
# 2. antibody (This script will install if needed)
# 3. powerline 
# 4. powerline-fonts
# 5. fzf (yay)


# ZSH modules
# zmodload zsh/zprof

# Compdef is basically a function used by zsh for load the auto-completions. 
# The completion system needs to be activated. 
autoload -Uz compinit && compinit

# Auto-completion case-insensitive
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'

# # Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# # The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
HIST_STAMPS="yyyy-mm-dd"

# History file
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=1000
export SAVEHIST=1000
# Set options
# Set command line autocorrect
setopt correct
# Share history between terminal sessions
setopt share_history 

# Custom environmental  variables
# Local environment variables should go into $ZDOTDIR/.zshenv where $ZDOTDIR is home unless specified
 
# Better questions
autoload -U colors && colors
export SPROMPT="Correct $fg[red]%R$reset_color to $fg[green]%r?$reset_color (Yes, No, Abort, Edit) "

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:$HOME/.local/bin"

# Customizations folder
export ZSH_CUSTOM="$HOME/.zsh/zcustom"

# Cache directory
# Needed for kubectl
ZSH_CACHE_DIR="$HOME/.zsh/.cache"

# Functions folder
export ZFUNC="$HOME/.zsh/zfunc"
export ZSCRIPTS="$HOME/.zsh/zscripts"
export ZLOCAL="$HOME/.zsh/zlocal"

# Adding to the path variable
export FPATH="$ZSCRIPTS:$ZFUNC:$ZLOCAL:$FPATH"

autoload -Uz extract
autoload -Uz sshdc
autoload -Uz mkcd
autoload -Uz zssh
autoload -Uz update_os
autoload -Uz install_rsub
autoload -Uz update_zsh

# # Load Alias
source $ZSH_CUSTOM/alias.zsh

# Load any local configuration
if [ "$(ls $ZLOCAL)" ]; then   
  for file in $ZLOCAL/*; do
      source "$file"
  done
fi

# Antibody Plug Manager
# Check to see if it's installed (and in the path)
type antibody >/dev/null 2>&1 || { curl -sfL git.io/antibody | sudo sh -s - -b /usr/local/bin; }
source <(antibody init)
export ANTIBODY_HOME="$HOME/.cache/antibody"
antibody bundle ohmyzsh/ohmyzsh path:plugins/git
antibody bundle ohmyzsh/ohmyzsh path:plugins/pip
antibody bundle ohmyzsh/ohmyzsh path:plugins/sudo
antibody bundle ohmyzsh/ohmyzsh path:plugins/command-not-found
antibody bundle ohmyzsh/ohmyzsh path:plugins/colored-man-pages
antibody bundle ohmyzsh/ohmyzsh path:plugins/extract
antibody bundle ohmyzsh/ohmyzsh path:plugins/fzf

antibody bundle supercrabtree/k
antibody bundle "zsh-users/zsh-autosuggestions"
antibody bundle "zsh-users/zsh-completions"

# Back directory
# https://github.com/Tarrasch/zsh-bd
# antibody bundle "Tarrasch/zsh-bd"
# antibody bundle cupricreki/zsh-bw-completion

# Open command on explain-shell.com usage: explain <command>
# antibody bundle "gmatheu/zsh-plugins explain-shell"

# Syntax highlighting bundle.
# antibody bundle "zsh-users/zsh-syntax-highlighting"

# Vi mode
antibody bundle "jeffreytse/zsh-vi-mode"

# Powerline loading
# powerline-daemon -q
# . /usr/share/powerline/bindings/zsh/powerline.zsh

# Initialize enhancd
antibody bundle "b4b4r07/enhancd"
ENHANCD_FILTER=fzy; export ENHANCD_FILTER
source "$HOME/.cache/antibody/https-COLON--SLASH--SLASH-github.com-SLASH-b4b4r07-SLASH-enhancd/init.sh"

# Load kubectl bundle if installed
kubectl --version &> /dev/null
if [ $? -eq 0 ]; then
  # Load bundle
  antibody bundle "ohmyzsh/ohmyzsh path:plugins/kubectl" 
fi

# Load docker bundle if installed
docker --version &> /dev/null
if [ $? -eq 0 ]; then
  antibody bundle "ohmyzsh/ohmyzsh path:plugins/docker" 
fi

# Set docker-compose alias for v1
docker-compose --version &> /dev/null
if [ $? -eq 0 ]; then
  alias dc=docker-compose
fi

# Set docker-compose alias for v2 
docker compose --version &> /dev/null
if [ $? -eq 0 ]; then
  alias dc="docker compose"
fi

# Load aws bundle if installed
aws --version &> /dev/null
if [ $? -eq 0 ]; then
  antibody bundle "ohmyzsh/ohmyzsh path:plugins/aws"
fi

# Load custom key bindings
source "$ZSH_CUSTOM/keybindings.zsh"

# Theme
eval "$(starship init zsh)"

# Load tmux bundle if installed
command -v tmux &>/dev/null && ZSH_TMUX_AUTOSTART=false && antibody bundle "ohmyzsh/ohmyzsh path:plugins/tmux"
