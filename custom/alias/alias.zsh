# To disable autocorrect for any command
# alias foobar="nocorrect foobar"
# updated 20241130


# Check for ccat
if command_exists ccat; then
  alias cat='ccat'
fi

# Check for bat
if command_exists bat; then
  alias cat="bat --pager=less --style=plain --wrap=character --theme='Coldark-Dark'"
  # the following breaks enhancd https://github.com/babarot/enhancd/issues/224
  # alias cat="bat --pager=less --color='always' --style=plain --wrap=character --theme='Coldark-Dark'"
fi

# Check for nvim
if command_exists nvim; then
  alias vi='nvim'
  alias vim='nvim'
  alias nvimconf='vi $HOME/.config/nvim/init.vim'
  export VISUAL=nvim;
  export SUDO_EDITOR=nvim;
  export EDITOR=nvim;
fi

# Check for apitude
if command_exists aptitude; then
  alias apt='aptitude'
fi

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
alias afind='ack -il'
# Bitwarden unlock - converted to function for proper error handling
bwe() {
  local session
  if session=$(bw unlock --raw 2>/dev/null); then
    export BW_SESSION="$session"
    log success "Bitwarden unlocked successfully"
  else
    log error "Failed to unlock Bitwarden"
    return 1
  fi
}
# backup - Create timestamped backup of file or directory
# Usage: backup <file|directory> [destination]
# Creates: filename.YYYYMMDD_HHMMSS.bak or custom destination
backup() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: backup <file|directory> [destination]" >&2
        echo "Example: backup myfile.txt" >&2
        echo "         backup mydir/ /backups/mydir.bak" >&2
        return 1
    fi
    
    local src="$1"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local dest="${2:-${src%/}.${timestamp}.bak}"
    
    if [[ ! -e "$src" ]]; then
        echo "Error: '$src' does not exist" >&2
        return 1
    fi
    
    if [[ -e "$dest" ]]; then
        echo "Warning: '$dest' already exists" >&2
        read -q "REPLY?Overwrite? (y/n) "
        echo
        [[ $REPLY != "y" ]] && return 1
    fi
    
    echo "Backing up: $src → $dest"
    if rsync -a --info=progress2 "$src" "$dest"; then
        log success "Backup complete: $dest"
        du -sh "$dest"
    else
        log error "Backup failed"
        return 1
    fi
}
alias cd=__enhancd::cd
# alias cp='nocorrect cp'
alias ca="cursor-agent"
alias dd='dd conv=noerror status=progress'
alias df='df -h'
alias dgu='git -C ~/.dotfiles pull origin main'
alias diff='diff --color'
alias dirs='dirs -v'
alias distro='cat /etc/*-release'
alias dl='docker logs -f'
alias di='wget -O - https://gitlab.ogbase.net/cupric/dot/-/raw/main/init.sh | bash'
alias dri='ssh -o RemoteCommand="wget -O - https://gitlab.ogbase.net/cupric/dot/-/raw/main/init.sh | bash"'
alias dcrmva='docker volume rm $(docker volume ls -qf dangling=true)' # delete all volumes associated with docker
# alias ebuild='nocorrect ebuild'
alias egrep='egrep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn,.idea,.tox}'
alias explain=explain-command
alias explain-last=explain-last-command
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
# Delete all merged git branches (except main/master/dev variants)
# Converted from alias to function for better error handling
gbda() {
  local branches
  branches=$(git branch --no-color --merged | \
    command grep -vE "^(\+|\*|\s*($(git_main_branch)|development|develop|devel|dev)\s*$)")
  
  if [[ -z "$branches" ]]; then
    echo "No merged branches to delete"
    return 0
  fi
  
  echo "$branches" | command xargs -n 1 git branch -d
}
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
# alias gist='nocorrect gist'
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
# alias heroku='nocorrect heroku'
# alias hpodder='nocorrect hpodder'
alias ip='ip --color=auto'
alias jc='sudo journalctl'
alias jcu='sudo journalctl -u'
alias jcuf='sudo journalctl -f -x -e -u'
alias jcuu='journalctl --user -u'
alias jcuuf='journalctl --user -f -x -e -u'
alias l='ls -lah'
alias la='ls -lAh'
alias ll='ls -lh'
alias ls='ls --color=tty'
alias lsa='ls -lah'
# alias man='nocorrect man'
alias md='mkdir -p'
# alias mkdir='nocorrect mkdir'
# alias mv='nocorrect mv'
alias myip='curl http://ipecho.net/plain; echo'
# alias mysql='nocorrect mysql'
alias oscc="osc copy"
alias oscp="osc paste"
alias perms='stat -c '\''%a - %n'\'
alias pip='noglob pip'
alias pipir='pip install -r requirements.txt'
alias pipreq='pip freeze > requirements.txt'
alias pipunall='pipreq && pip uninstall -r requirements.txt -y && rm -rf requirements.txt'
alias pipupall='pipreq && sed -i '\''s/==/>=/g'\'' requirements.txt && pip install -r requirements.txt --upgrade && rm -rf requirements.txt'
alias please=sudo
alias plz=sudo
alias rd='rm -fdr'
alias reboot_windows='sudo gksu grub-reboot 2 && sudo gksu reboot'
alias restart_plasmashell='sudo pkill plasmashell && kstart5 plasmashell > /dev/null 2>&1'
alias rsynccopy='rsync --stats --partial --progress --append --rsh=ssh -a -h'
alias rsyncmove='rsync --stats --partial --progress --append --rsh=ssh -a -h --remove-sent-files'
alias sc='sudo systemctl'
alias scu='systemctl --user'
alias scustart='systemctl start --user'
alias scustat='systemctl status --user'
alias scur='systemctl restart --user'
alias scue='systemctl enable --user'
alias scuen='systemctl enable --now --user'
alias scstart='sudo systemctl start'
alias scstat='sudo systemctl status'
alias scstop='sudo systemctl stop'
alias scr='sudo systemctl restart'
alias sce='sudo systemctl enable'
alias scen='sudo systemctl enable --now'
alias subl=/opt/sublime_text/sublime_text
alias sudo='sudo '
alias ug='sudo -s -u ${USER}' # Update group
alias which-command=whence
alias xc='xclip -selection clipboard'
alias zse='vi ~/.zshrc'
alias zgu='git -C $HOME/.config/zsh pull origin master && sheldon lock --update && rm -f ~/.zcompdump* 2>/dev/null; exec zsh'
alias zgi='wget -O - https://gitlab.ogbase.net/cupric/zsh/-/raw/master/init.sh | bash'
alias zri='ssh -o RemoteCommand="wget -O - https://gitlab.ogbase.net/cupric/zsh/-/raw/master/init.sh | bash"'
alias zfslist='zfs list -o name,used,avail,refquota,compressratio,logicalused,mountpoint'

