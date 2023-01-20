# Requirements
# 1. ZSH
# 2. antidote (This script will install if needed)
# 3. powerline 
# 4. powerline-fonts
# 5. fzf (yay)
#
## Recommended
# 1. bat
# 2. exa 

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi


# ZSH modules
# zmodload zsh/zprof

# Compdef is basically a function used by zsh for load the auto-completions. 
# The completion system needs to be activated. 
autoload -Uz compinit && compinit

autoload -Uz promptinit && promptinit && prompt powerlevel10k

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
# setopt share_history 

# Custom environmental  variables
# Local environment variables should go into $ZDOTDIR/.zshenv where $ZDOTDIR is home unless specified
 
# Better questions
autoload -U colors && colors
export SPROMPT="Correct $fg[red]%R$reset_color to $fg[green]%r?$reset_color (Yes, No, Abort, Edit) "

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:$HOME/.local/bin"

export ZHOME="$HOME/.zsh"

# Customizations folder
export ZSH_CUSTOM="$ZHOME/zcustom"

# Cache directory
# Needed for kubectl
ZSH_CACHE_DIR="$ZHOME/.cache"

# Functions folder
export ZFUNC="$ZHOME/zfunc"
export ZSCRIPTS="$ZHOME/zscripts"
export ZLOCAL="$ZHOME/zlocal"

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

# Antidote Plug Manager
antidote_dir=$HOME/.cache/antidote
# Check to see if it's installed (and in the path)
[ ! -d "$antidote_dir" ] && git clone --depth=1 https://github.com/mattmc3/antidote.git $antidote_dir
source $antidote_dir/antidote.zsh
# generate zsh_plugins.zsh
antidote bundle <$ZHOME/plugins.txt >$ZHOME/plugins.zsh

# Powerline loading
# powerline-daemon -q
# . /usr/share/powerline/bindings/zsh/powerline.zsh

# Initialize enhancd
ENHANCD_FILTER=fzy; export ENHANCD_FILTER
source "$HOME/.cache/antidote/https-COLON--SLASH--SLASH-github.com-SLASH-b4b4r07-SLASH-enhancd/init.sh"

# Set docker-compose alias for v1
docker-compose --version &> /dev/null
if [ $? -eq 0 ]; then
    alias dc="docker-compose"

# Set docker-compose alias for v2 
docker compose --version &> /dev/null
elif [ $? -eq 0 ]; then
    alias dc="docker compose"
fi

# Load custom key bindings
source "$ZSH_CUSTOM/keybindings.zsh"

# Fzf configuration
bindkey '^D' fzf-file-widget
# export FZF_COMPLETION_TRIGGER=''
# bindkey '^Tab' fzf-completion
# bindkey '^I' $fzf_default_completion
 

# Load tmux bundle if installed
command -v tmux &>/dev/null && ZSH_TMUX_AUTOSTART=false 

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f $ZSH_CUSTOM/p10k.zsh ]] || source $ZSH_CUSTOM/p10k.zsh
