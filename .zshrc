# Compdef is basically a function used by zsh for load the auto-completions. 
# The completion system needs to be activated. 
autoload -Uz compinit 
compinit

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
UPDATE_ZSH_DAYS=13

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
HIST_STAMPS="yyyy-mm-dd"

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"

# Customizations folder
export ZSH_CUSTOM=$HOME/.zsh/zcustom

# Cache directory
# Needed for kubectl
ZSH_CACHE_DIR=$HOME/.zsh/.cache

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

# Load Alias
source $ZSH_CUSTOM/alias

# Load any local configuration
if [ "$(ls $ZLOCAL)" ]; then   
  for file in $ZLOCAL/*; do
      source "$file"
      echo "sourcing local config $file"
  done
fi

# Custom environmental  variables

# Better questions
export SPROMPT="Correct %R to %r? (Yes, No, Abort, Edit) "

# Alias commands only if commands exist
# Check for ccat
ccat --version &> /dev/null
if [ $? -eq 0 ]; then
  alias cat='ccat'
fi

# Check for nvim
nvim --version &> /dev/null
if [ $? -eq 0 ]; then
	alias vi='nvim'
  	alias vim='nvim'
	export VISUAL=nvim;
 	export EDITOR=nvim;
fi

# Antibody Plug Manager
source <(antibody init)
antibody bundle ohmyzsh/ohmyzsh path:plugins/git
antibody bundle ohmyzsh/ohmyzsh path:plugins/pip
antibody bundle ohmyzsh/ohmyzsh path:plugins/command-not-found
antibody bundle ohmyzsh/ohmyzsh path:plugins/colored-man-pages
# antibody bundle supercrabtree/k
antibody bundle zsh-users/zsh-autosuggestions
antibody bundle zsh-users/zsh-completions
antibody bundle Tarrasch/zsh-bd
#antibody bundle cupricreki/zsh-bw-completion

# Save better command history using sqlite3
# Usage: histdb
antibody bundle larkery/zsh-histdb

# Open command on explain-shell.com usage: explain <command>
antibody bundle gmatheu/zsh-plugins explain-shell

# Syntax highlighting bundle.
antibody bundle zsh-users/zsh-syntax-highlighting

# Load the theme.
# Spaceship prompt
antibody bundle spaceship-prompt/spaceship-prompt
# Don't get battery
export SPACESHIP_BATTERY_SHOW=false

# Initialize enhancd
antibody bundle b4b4r07/enhancd
ENHANCD_FILTER=fzy; export ENHANCD_FILTER
source $HOME/.cache/antibody/https-COLON--SLASH--SLASH-github.com-SLASH-b4b4r07-SLASH-enhancd/init.sh

# Load kubectl bundle if installed
kubectl --version &> /dev/null
if [ $? -eq 0 ]; then
  # Load bundle
  antibody bundle ohmyzsh/ohmyzsh path:plugins/kubectl 
fi

# Load docker bundle if installed
docker --version &> /dev/null
if [ $? -eq 0 ]; then
  antibody bundle ohmyzsh/ohmyzsh path:plugins/docker 
fi
