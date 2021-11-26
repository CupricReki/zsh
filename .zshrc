# Compdef is basically a function used by zsh for load the auto-completions. 
# The completion system needs to be activated. 
autoload -Uz compinit 
compinit

# Would you like to use another custom folder than $ZSH/custom?
ZSH_CUSTOM=$HOME/.zsh/zcustom

ZSH_CACHE_DIR=$HOME/.cache

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

autoload -Uz extract
autoload -Uz sshdc
autoload -Uz mkcd
autoload -Uz zssh
autoload -Uz update_os
autoload -Uz install_rsub
autoload -Uz update_zsh


# Load any local configuration
# for file in $ZLOCAL/*; do
#     source "$file"
#     echo "sourcing local config $file"
# done

# Custom environmental  variables

# Better questions
export SPROMPT="Correct %R to %r? (Yes, No, Abort, Edit) "

alias '-'='cd -'
alias ...=../..
alias ....=../../..
alias .....=../../../..
alias ......=../../../../..
alias 1='cd -'
alias 2='cd -2'
alias 3='cd -3'
alias 4='cd -4'
alias 5='cd -5'
alias 6='cd -6'
alias 7='cd -7'
alias 8='cd -8'
alias 9='cd -9'
alias _='sudo '
alias afind='ack -il'
alias bwe='export BW_SESSION=$( bw unlock --raw )'
alias cd=__enhancd::cd
alias cp='nocorrect cp'
alias dc=docker-compose
alias dcd='docker-compose down'
alias dcl='docker-compose logs -f'
alias dcu='docker-compose up'
alias dcud='docker-compose up -d'
alias dd='dd conv=noerror status=progress'
alias df='df -h'
alias diff='diff --color'
alias dirs='dirs -v'
alias distro='cat /etc/*-release'
alias dl='docker logs -f'
alias ebuild='nocorrect ebuild'
alias egrep='egrep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox}'
alias explain=explain-command
alias explain-last=explain-last-command
alias ezsh='subl ~/.zsh/.zshrc'
alias fgrep='fgrep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox}'
alias g=git
alias ga='git add'
alias gaa='git add --all'
alias gam='git am'
alias gama='git am --abort'
alias gamc='git am --continue'
alias game_time='~/dev/kvm/vm_scripts/gaming_start.sh'
alias gams='git am --skip'
alias gamscp='git am --show-current-patch'
alias gap='git apply'
alias gapa='git add --patch'
alias gapt='git apply --3way'
alias gau='git add --update'
alias gav='git add --verbose'
alias gb='git branch'
alias gbD='git branch -D'
alias gba='git branch -a'
alias gbd='git branch -d'
alias gbda='git branch --no-color --merged | command grep -vE "^(\+|\*|\s*($(git_main_branch)|development|develop|devel|dev)\s*$)" | command xargs -n 1 git branch -d'
alias gbl='git blame -b -w'
alias gbnm='git branch --no-merged'
alias gbr='git branch --remote'
alias gbs='git bisect'
alias gbsb='git bisect bad'
alias gbsg='git bisect good'
alias gbsr='git bisect reset'
alias gbss='git bisect start'
alias gc='git commit -v'
alias 'gc!'='git commit -v --amend'
alias gca='git commit -v -a'
alias 'gca!'='git commit -v -a --amend'
alias gcam='git commit -a -m'
alias 'gcan!'='git commit -v -a --no-edit --amend'
alias 'gcans!'='git commit -v -a -s --no-edit --amend'
alias gcas='git commit -a -s'
alias gcasm='git commit -a -s -m'
alias gcb='git checkout -b'
alias gcd='git checkout develop'
alias gcf='git config --list'
alias gcl='git clone --recurse-submodules'
alias gclean='git clean -id'
alias gcm='git checkout $(git_main_branch)'
alias gcmsg='git commit -m'
alias 'gcn!'='git commit -v --no-edit --amend'
alias gco='git checkout'
alias gcor='git checkout --recurse-submodules'
alias gcount='git shortlog -sn'
alias gcp='git cherry-pick'
alias gcpa='git cherry-pick --abort'
alias gcpc='git cherry-pick --continue'
alias gcs='git commit -S'
alias gcsm='git commit -s -m'
alias gcss='git commit -S -s'
alias gcssm='git commit -S -s -m'
alias gd='git diff'
alias gdca='git diff --cached'
alias gdct='git describe --tags $(git rev-list --tags --max-count=1)'
alias gdcw='git diff --cached --word-diff'
alias gds='git diff --staged'
alias gdt='git diff-tree --no-commit-id --name-only -r'
alias gdw='git diff --word-diff'
alias gf='git fetch'
alias gfa='git fetch --all --prune --jobs=10'
alias gfg='git ls-files | grep'
alias gfo='git fetch origin'
alias gg='git gui citool'
alias gga='git gui citool --amend'
alias ggpull='git pull origin "$(git_current_branch)"'
alias ggpur=ggu
alias ggpush='git push origin "$(git_current_branch)"'
alias ggsup='git branch --set-upstream-to=origin/$(git_current_branch)'
alias ghh='git help'
alias gignore='git update-index --assume-unchanged'
alias gignored='git ls-files -v | grep "^[[:lower:]]"'
alias gist='nocorrect gist'
alias git-svn-dcommit-push='git svn dcommit && git push github $(git_main_branch):svntrunk'
alias gk='\gitk --all --branches'
alias gke='\gitk --all $(git log -g --pretty=%h)'
alias gl='git pull'
alias glg='git log --stat'
alias glgg='git log --graph'
alias glgga='git log --graph --decorate --all'
alias glgm='git log --graph --max-count=10'
alias glgp='git log --stat -p'
alias glo='git log --oneline --decorate'
alias globurl='noglob urlglobber '
alias glod='git log --graph --pretty='\''%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset'\'
alias glods='git log --graph --pretty='\''%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset'\'' --date=short'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'
alias glol='git log --graph --pretty='\''%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'\'
alias glola='git log --graph --pretty='\''%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'\'' --all'
alias glols='git log --graph --pretty='\''%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset'\'' --stat'
alias glp=_git_log_prettily
alias glum='git pull upstream $(git_main_branch)'
alias gm='git merge'
alias gma='git merge --abort'
alias gmom='git merge origin/$(git_main_branch)'
alias gmt='git mergetool --no-prompt'
alias gmtvim='git mergetool --no-prompt --tool=vimdiff'
alias gmum='git merge upstream/$(git_main_branch)'
alias gp='git push'
alias gpd='git push --dry-run'
alias gpf='git push --force-with-lease'
alias 'gpf!'='git push --force'
alias gpoat='git push origin --all && git push origin --tags'
alias gpr='git pull --rebase'
alias gpristine='git reset --hard && git clean -dffx'
alias gpsup='git push --set-upstream origin $(git_current_branch)'
alias gpu='git push upstream'
alias gpv='git push -v'
alias gr='git remote'
alias gra='git remote add'
alias grb='git rebase'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'
alias grbd='git rebase develop'
alias grbi='git rebase -i'
alias grbm='git rebase $(git_main_branch)'
alias grbo='git rebase --onto'
alias grbs='git rebase --skip'
alias grep='grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox}'
alias grev='git revert'
alias grh='git reset'
alias grhh='git reset --hard'
alias grm='git rm'
alias grmc='git rm --cached'
alias grmv='git remote rename'
alias groh='git reset origin/$(git_current_branch) --hard'
alias grrm='git remote remove'
alias grs='git restore'
alias grset='git remote set-url'
alias grss='git restore --source'
alias grst='git restore --staged'
alias grt='cd "$(git rev-parse --show-toplevel || echo .)"'
alias gru='git reset --'
alias grup='git remote update'
alias grv='git remote -v'
alias gsb='git status -sb'
alias gsd='git svn dcommit'
alias gsh='git show'
alias gsi='git submodule init'
alias gsps='git show --pretty=short --show-signature'
alias gsr='git svn rebase'
alias gss='git status -s'
alias gst='git status'
alias gsta='git stash push'
alias gstaa='git stash apply'
alias gstall='git stash --all'
alias gstc='git stash clear'
alias gstd='git stash drop'
alias gstl='git stash list'
alias gstp='git stash pop'
alias gsts='git stash show --text'
alias gstu='gsta --include-untracked'
alias gsu='git submodule update'
alias gsw='git switch'
alias gswc='git switch -c'
alias gtl='gtl(){ git tag --sort=-v:refname -n -l "${1}*" }; noglob gtl'
alias gts='git tag -s'
alias gtv='git tag | sort -V'
alias gunignore='git update-index --no-assume-unchanged'
alias gunwip='git log -n 1 | grep -q -c "\-\-wip\-\-" && git reset HEAD~1'
alias gup='git pull --rebase'
alias gupa='git pull --rebase --autostash'
alias gupav='git pull --rebase --autostash -v'
alias gupv='git pull --rebase -v'
alias gwch='git whatchanged -p --abbrev-commit --pretty=medium'
alias gwip='git add -A; git rm $(git ls-files --deleted) 2> /dev/null; git commit --no-verify --no-gpg-sign -m "--wip-- [skip ci]"'
alias heroku='nocorrect heroku'
alias history='omz_history -i'
alias hpodder='nocorrect hpodder'
alias jc='sudo journalctl'
alias jcu='sudo journalctl -u'
alias jcuf='sudo journalctl -f -x -e -u'
alias l='ls -lah'
alias la='ls -lAh'
alias ll='ls -lh'
alias ls='ls --color=tty'
alias lsa='ls -lah'
alias man='nocorrect man'
alias md='mkdir -p'
alias mkdir='nocorrect mkdir'
alias mv='nocorrect mv'
alias myip='curl http://ipecho.net/plain; echo'
alias mysql='nocorrect mysql'
alias perms='stat -c '\''%a - %n'\'
alias pip='noglob pip'
alias pipir='pip install -r requirements.txt'
alias pipreq='pip freeze > requirements.txt'
alias pipunall='pipreq && pip uninstall -r requirements.txt -y && rm -rf requirements.txt'
alias pipupall='pipreq && sed -i '\''s/==/>=/g'\'' requirements.txt && pip install -r requirements.txt --upgrade && rm -rf requirements.txt'
alias please=sudo
alias plz=sudo
alias rd=rmdir
alias reboot_windows='sudo gksu grub-reboot 2 && sudo gksu reboot'
alias rsynccopy='rsync --stats --partial --progress --append --rsh=ssh -r -h'
alias rsyncmove='rsync --stats --partial --progress --append --rsh=ssh -r -h --remove-sent-files'
alias sc='sudo systemctl'
alias scstart='sudo systemctl start'
alias scstat='sudo systemctl status'
alias scstop='sudo systemctl stop'
alias subl=/opt/sublime_text/sublime_text
alias sudo='nocorrect sudo'
alias which-command=whence
alias xc='xclip -selection clipboard'
alias zgu='git -C ~/.zsh pull origin master && source ~/.zshrc'


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
#ENHANCD_FILTER=fzy; export ENHANCD_FILTER
#source $ADOTDIR/bundles/b4b4r07/enhancd/init.sh


# Antibody
# source $HOME/.zsh/antibody/antibody/antibody.zsh
source <(antibody init)
antibody bundle ohmyzsh/ohmyzsh path:plugins/git
antibody bundle ohmyzsh/ohmyzsh path:plugins/pip
antibody bundle ohmyzsh/ohmyzsh path:plugins/kubectl
antibody bundle ohmyzsh/ohmyzsh path:plugins/command-not-found
antibody bundle b4b4r07/enhancd
# antibody bundle supercrabtree/k
antibody bundle zsh-users/zsh-autosuggestions
antibody bundle ohmyzsh/ohmyzsh path:plugins/colored-man-pages
antibody bundle zsh-users/zsh-completions
antibody bundle ohmyzsh/ohmyzsh path:plugins/docker
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
