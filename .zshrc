# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Requirements
# 1. ZSH
# 2. antibody (This script will install if needed)
# 3. powerline
# 4. powerline-fonts
# 5. fzf
# 6. lsd (community exa - ls alternative needed for fzf)
# 7. git-delta
# 8. bat: view code
# 9. pandoc: convert any kind of file to markdown. Any generated cache file will be store in same /tmp/zsh-fzf-tab-$USER as fzf-tab
# 10. mdcat: render markdown
# 11. grc: colorize the output of some commands
# 12. less: a pager
# 13. pdf2text


# Suggested
# 1. mediainfo
# 2. lsd
# 3. Chafa

# ZSH modules
# zmodload zsh/zprof

# Compdef is basically a function used by zsh for load the auto-completions.
# The completion system needs to be activated.
autoload -Uz compinit && compinit

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

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:$HOME/.local/bin:$HOME/.zsh/bin:/opt/android-sdk/platform-tools:$PATH"

# Customizations folder
export ZSH_CUSTOM="$HOME/.zsh/zcustom"

# Cache directory
# Needed for kubectl
ZSH_CACHE_DIR="$HOME/.zsh/.cache"

# Functions folder
export ZFUNC="$HOME/.zsh/zfunc"
export ZSCRIPTS="$HOME/.zsh/zscripts"
export ZLOCAL="$HOME/.zsh/zlocal"
export ZBIN="$HOME/.zsh/bin"
export ZCOMPLETION="$HOME/.zsh/completion"

# Adding to the path variable
export FPATH="$ZCOMPLETION:$ZSCRIPTS:$ZFUNC:$ZLOCAL:$FPATH"

# Set terminal colors
# Based on https://github.com/joshjon/bliss-dircolors
eval `dircolors $ZSH_CUSTOM/bliss.dircolors`

autoload -Uz extract
autoload -Uz sshdc
autoload -Uz mkcd
autoload -Uz zssh
autoload -Uz update_os
autoload -Uz install_rsub
autoload -Uz update_zsh
autoload -Uz zrepl_watch
autoload -Uz healthcheck_init

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
export ANTIBODY_HOME="$ZSH_CACHE_DIR/antibody"
antibody bundle ohmyzsh/ohmyzsh path:plugins/git
antibody bundle ohmyzsh/ohmyzsh path:plugins/pip
antibody bundle ohmyzsh/ohmyzsh path:plugins/sudo
antibody bundle ohmyzsh/ohmyzsh path:plugins/command-not-found
antibody bundle ohmyzsh/ohmyzsh path:plugins/colored-man-pages
antibody bundle ohmyzsh/ohmyzsh path:plugins/extract

antibody bundle "supercrabtree/k"

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
ZVM_LINE_INIT_MODE=$ZVM_MODE_INSERT

# Powerline loading
# powerline-daemon -q
# . /usr/share/powerline/bindings/zsh/powerline.zsh

# Initialize enhancd
antibody bundle "b4b4r07/enhancd"
export ENHANCD_FILTER="fzf --preview='exa --tree --group-directories-first --git-ignore --level 1 {}'"
source "$ZSH_CACHE_DIR/antibody/https-COLON--SLASH--SLASH-github.com-SLASH-b4b4r07-SLASH-enhancd/init.sh"

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
  # This repo pulls completions from the main docker repo. Prevents having to sync the full repo
  # antibody bundle "greymd/docker-zsh-completion"
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

# Load ansible bundle if installed
ansible --version &> /dev/null
if [ $? -eq 0 ]; then
  antibody bundle "ohmyzsh/ohmyzsh path:plugins/ansible"
fi

# Load custom key bindings
# source "$ZSH_CUSTOM/keybindings.zsh"

# ================================================
# Autocomplete
# ================================================

# Add more completions
antibody bundle "zsh-users/zsh-completions"
antibody bundle "sinetoami/antibody-completion"
antibody bundle "sunlei/zsh-ssh"
type yt-dlp >/dev/null 2>&1 && antibody bundle "clavelm/yt-dlp-omz-plugin"
type tailscale >/dev/null 2>&1 && source "$ZSH_CUSTOM/tailscale_zsh_completion.zsh"

# ================================================
# Fzf configuration
# ================================================
source "$ZSH_CUSTOM/fzf_key-bindings.zsh"
source "$ZSH_CUSTOM/fzf_completion.zsh"
# export FZF_COMPLETION_TRIGGER=''
# bindkey '^I' $fzf_default_completion

# Tab completion
antibody bundle "Aloxaf/fzf-tab"
antibody bundle "Freed-Wu/fzf-tab-source"           # formattting for fzf-preview in fzf-tab

# Bind rebind file search to alt+t
bindkey -r '^T'
bindkey -r '^[t'
bindkey '^[t' fzf-file-widget

# Auto-completion case-insensitive
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'

# disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false

# set descriptions format to enable group support
zstyle ':completion:*:descriptions' format '[%d]'

# set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# switch group using `<` and `>`
zstyle ':fzf-tab:*' switch-group '<' '>'
# Tmux popup window
# zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
# show systemd unit status
# zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word'
# # environment variables preview
# zstyle ':fzf-tab:complete:(-command-|-parameter-|-brace-parameter-|export|unset|expand):*' \
# 	fzf-preview 'echo ${(P)word}'
#
# # git - requires git-delta
# zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview \
# 	'git diff $word | delta'
# zstyle ':fzf-tab:complete:git-log:*' fzf-preview \
# 	'git log --color=always $word'
# zstyle ':fzf-tab:complete:git-help:*' fzf-preview \
# 	'git help $word | bat -plman --color=always'
# zstyle ':fzf-tab:complete:git-show:*' fzf-preview \
# 	'case "$group" in
# 	"commit tag") git show --color=always $word ;;
# 	*) git show --color=always $word | delta ;;
# 	esac'
# zstyle ':fzf-tab:complete:git-checkout:*' fzf-preview \
# 	'case "$group" in
# 	"modified file") git diff $word | delta ;;
# 	"recent commit object name") git show --color=always $word | delta ;;
# 	*) git log --color=always $word ;;
# 	esac'
# # review panel
# zstyle ':fzf-tab:complete:*:*' fzf-preview 'less ${(Q)realpath}'
export LESSOPEN='|$ZSH_CUSTOM/lessfilter %s'     # Formatting of panel
export LESS='-r -M -s -I --mouse'    # raw chars, verbose, chop lines, ignore case, mouse scrolling
#
# give a preview of commandline arguments when completing `kill/ps` below
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm -w -w"
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-preview \
  '[[ $group == "[process ID]" ]] && ps --pid=$word -o cmd --no-headers -w -w'
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-flags --preview-window=down:3:wrap

### fzf-tab Keybindings
# ctrl-a to select all
zstyle ':fzf-tab:*' fzf-bindings 'ctrl-a:toggle-all'

# These have to go after most plugins as they wrap other ones
antibody bundle "zdharma-continuum/fast-syntax-highlighting"
antibody bundle "zsh-users/zsh-autosuggestions"

# Powerlevel 10k
antibody bundle "romkatv/powerlevel10k"

# Load tmux bundle if installed
tmux --version &>/dev/null
if [ $? -eq 0 ]; then
    ZSH_TMUX_AUTOSTART=true \
    ZSH_TMUX_AUTOCONNECT=false \
    antibody bundle "ohmyzsh/ohmyzsh path:plugins/tmux"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f $ZSH_CUSTOM/p10k.zsh ]] || source $ZSH_CUSTOM/p10k.zsh
