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
# ~/.zshrc

# You can change the names/locations of these if you prefer.
antidote_dir=$HOME/.cache/antidote
export ANTIDOTE_HOME=$antidote_dir
plugins_txt=$ZSH_CUSTOM/plugins.txt
static_file=$ZSH_CUSTOM/plugins.zsh
   
# Clone antidote if necessary and generate a static plugin file.
if [[ ! $static_file -nt $plugins_txt ]]; then
  [[ -e $antidote_dir ]] ||
    git clone --depth=1 https://github.com/mattmc3/antidote.git $antidote_dir
  (
    source $antidote_dir/antidote.zsh
    [[ -e $plugins_txt ]] || touch $plugins_txt
    antidote bundle <$plugins_txt >$static_file
  )
fi

# Uncomment this if you want antidote commands like `antidote update` available
# in your interactive shell session:
autoload -Uz $antidote_dir/functions/antidote

# source the static plugins file
source $static_file

# Initialize enhancd
ENHANCD_FILTER=fzf; export ENHANCD_FILTER
source "$antidote_dir/https-COLON--SLASH--SLASH-github.com-SLASH-b4b4r07-SLASH-enhancd/init.sh"

# cleanup
unset antidote_dir plugins_txt static_file

# Load custom key bindings
source "$ZSH_CUSTOM/keybindings.zsh"

# Fzf configuration
source "$ZSH_CUSTOM/fzf_keybindings.zsh"
bindkey '^G' fzf-file-widget
# bindkey '^Tab' fzf-completion
# bindkey '^I' $fzf_default_completion
 
# Start tmux by default
# ZSH_TMUX_AUTOSTART=false 

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f $ZSH_CUSTOM/p10k.zsh ]] || source $ZSH_CUSTOM/p10k.zsh
# autoload -Uz promptinit && promptinit && prompt p10k
