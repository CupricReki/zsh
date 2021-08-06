# Would you like to use another custom folder than $ZSH/custom?
ZSH_CUSTOM=$HOME/.zsh/zcustom

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

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

# User configuration

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"
# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/dsa_id"

# Functions folder
export ZFUNC="$HOME/.zsh/zfunc"
export ZSCRIPTS="$HOME/.zsh/zscripts"
export ZLOCAL="$HOME/.zsh/zlocal"

# Adding to the path variable
export FPATH="$ZSCRIPTS:$ZFUNC:$ZLOCAL:$FPATH"

# Add any local configruations
for file in $ZLOCAL/*; do
    source "$file"
done

autoload -Uz extract
autoload -Uz sshdc
autoload -Uz mkcd
autoload -Uz zssh
autoload -Uz update_os
autoload -Uz install_rsub

# Antigen plugin manager
# https://github.com/zsh-users/antigen

# Set antigen directory
export ADOTDIR=$HOME/.zsh/antigen

export ANTIGEN_LOG=$ADOTDIR/antigen.log
# Source Antigen
source $HOME/.zsh/antigen/antigen.zsh

# Load the oh-my-zsh's library.
antigen use oh-my-zsh

# Bundles from the default repo (robbyrussell's oh-my-zsh).
antigen bundle git
antigen bundle pip
antigen bundle command-not-found
antigen bundle b4b4r07/enhancd
antigen bundle supercrabtree/k
antigen bundle zsh-users/zsh-autosuggestions
antigen bundle colored-man-pages
antigen bundle zsh-users/zsh-completions
#antigen bundle cupricreki/zsh-bw-completion

# Save better command history using sqlite3
# Usage: histdb
antigen bundle larkery/zsh-histdb

# Open command on explain-shell.com usage: explain <command>
antigen bundle gmatheu/zsh-plugins explain-shell

# Syntax highlighting bundle.
antigen bundle zsh-users/zsh-syntax-highlighting

# Load the theme.
antigen theme denysdovhan/spaceship-prompt


# Tell Antigen that you're done.
antigen apply

# Custom environmental  variables

# Better questions
export SPROMPT="Correct %R to %r? (Yes, No, Abort, Edit) "

# Alias
# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias dirs="dirs -v"
alias df="df -h"
alias dl="docker logs -f"
alias dc="docker-compose"
alias dcl="docker-compose logs -f"
alias dcu="docker-compose up"
alias dcud="docker-compose up -d"
alias dcd="docker-compose down"
alias dd="dd conv=noerror status=progress"
alias please="sudo"
alias plz="sudo"
alias rsyncmove="rsync --stats --partial --progress --append --rsh=ssh -r -h --remove-sent-files"
alias rsynccopy="rsync --stats --partial --progress --append --rsh=ssh -r -h"
alias sc="sudo systemctl"
alias scstart="sudo systemctl start"
alias scstop="sudo systemctl stop"
alias scstat="sudo systemctl status"
alias jc="sudo journalctl"
alias jcu="sudo journalctl -u"
alias jcuf="sudo journalctl -f -x -e -u"
alias subl="/opt/sublime_text/sublime_text"
alias ezsh="subl ~/.zsh/.zshrc"
alias zgu='git -C ~/.zsh pull origin master && source ~/.zshrc'
alias xc="xclip -selection clipboard"
alias myip='curl http://ipecho.net/plain; echo'
alias distro='cat /etc/*-release'
alias bwe='export BW_SESSION=$( bw unlock --raw )'
alias perms="stat -c '%a - %n'"

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


# Initialize enhancd
ENHANCD_FILTER=fzy; export ENHANCD_FILTER
source $ADOTDIR/bundles/b4b4r07/enhancd/init.sh


