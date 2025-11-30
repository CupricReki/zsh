# ==== Profiling ====
# Uncomment to enable profiling (adds ~10ms overhead)
# To see results, run: zprof | head -20
# zmodload zsh/zprof

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
# 5. lsd (community exa - ls alternative needed for fzf)
# 6. tree
# 7. fd

# Recommended
# 1. git-delta
# 2. bat: view code
# 3. pandoc: convert any kind of file to markdown. Any generated cache file will be store in same /tmp/zsh-fzf-tab-$USER as fzf-tab
# 4. mdcat: render markdown
# 5. grc: colorize the output of some commands
# 6. less: a pager
# 7. pdftotext
# 8. osc (go install -v github.com/theimpostor/osc@latest) - OSC 52 support (copy from terminal)

# Included executables
# 1. fzf


# 4.1 Supported compression methods and archive formats
#
#     gzip, compress requires gzip
#     bzip2 requires bzip2
#     lzma requires lzma
#     xz requires xz
#     zstd requires zstd
#     brotli requires bro
#     lz4 requires lz4
#     tar requires optionally archive_color for coloring
#     ar library requires bsdtar or ar
#     zip archive requires bsdtar or unzip
#     jar archive requires bsdtar or unzip
#     rar archive requires bsdtar or unrar or rar
#     7-zip archive requires 7zr
#     lzip archive requires lzip
#     iso images requires bsdtar or isoinfo
#     rpm requires rpm2cpio and cpio or bsdtar
#     Debian requires bsdtar or ar
#     cab requires cabextract
#
# 4.2 List of preprocessed file types
#
#     directory displayed using ls -lA
#     nroff(man) requires groff or mandoc
#     shared library requires nm
#     MS Word (doc) requires wvText or antiword or catdoc or libreoffice
#     Powerpoint (ppt) requires catppt
#     Excel (xls) requires in2csv (csvkit) or xls2csv
#     odt requires pandoc or odt2txt or libreoffice
#     odp requires libreoffice
#     ods requires xlscat or libreoffice
#     MS Word (docx) requires pandoc or docx2txt or libreoffice
#     Powerpoint (pptx) requires pptx2md or libreoffice
#     Excel (xlsx) requires in2csv or xlscat or excel2csv or libreoffice
#     csv requires csvtable or csvlook or column or pandoc
#     rtf requires unrtf or libreoffice
#     epub requires pandoc
#     html,xml requires w3m or lynx or elinks or html2text
#     pdf requires pdftotext or pdftohtml
#     perl pod requires pod2text or perldoc
#     dvi requires dvi2tty
#     djvu requires djvutxt
#     ps requires ps2ascii (from the gs package)
#     mp3 requires id3v2
#     multimedia formats requires mediainfo or exiftools
#     image formats requires mediainfo or exiftools or identify
#     hdf, nc4 requires h5dump or ncdump (NetCDF format)
#     crt, pem, csr, crl requires openssl
#     matlab requires matdump
#     Jupyter notebook requires pandoc
#     markdown requires mdcat or pandoc
#     log requires ccze
#     java.class requires procyon
#     MacOS X plist requires plistutil
#     binary data requires strings
#     json requires jq
#     device tree blobs requires dtc (extension dtb or dts)

# Suggested
# 1. mediainfo
# 2. lsd
# 3. Chafa

# ZSH modules
# zmodload zsh/zprof

# Compdef is basically a function used by zsh for load the auto-completions.
# The completion system needs to be activated.
# Use cache to speed up loading (only rebuild once per day)
autoload -Uz compinit
if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# # The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
HIST_STAMPS="yyyy-mm-dd"

# History file
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=10000
export SAVEHIST=10000
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

# ==== Environment Variable Setup ====
# Note: Most env vars are now in .zshenv to be available in all zsh instances
# Only interactive-specific variables should be here

# ==== Path Configuration ====
# Ensure unique entries
typeset -U path

path=(
    "$HOME/.npm-global/bin"            # local user npm bins
    /usr/local/sbin
    /usr/local/bin
    /usr/sbin
    /usr/bin
    /sbin
    /bin
    /usr/games
    /usr/local/games
    "$HOME/bin"                         # local bin
    "$HOME/.local/bin"                  # local bin
    "$ZSH_DIR/bin"                      # zsh-config bundled bin
    "$ZSCRIPTS"
    "/opt/android-sdk/platform-tools"   # Android platform tools
    "$HOME/.nix-profile/bin"
)

# Export the constructed PATH
export PATH
# FPATH: Contains a list of directories that the z/OS shell searches to find shell functions.
export FPATH="$ZCOMPLETION:$ZFUNC:$ZLOCAL:$FPATH"

# Set terminal colors
# Based on https://github.com/joshjon/bliss-dircolors
# Performance: Consider caching this output to avoid eval on every shell start
if [[ -f "$ZSH_CUSTOM/bliss.dircolors" ]]; then
  eval `dircolors $ZSH_CUSTOM/bliss.dircolors`
fi

autoload -Uz extract
autoload -Uz mkcd
autoload -Uz zssh
autoload -Uz tarz       #tar --zstd -cvf
autoload -Uz nocorrect

# # Load source alias files
if [[ -d "$ZSH_CUSTOM/alias" ]]; then
  for file in "$ZSH_CUSTOM/alias"/*.zsh(N); do
      source "$file"
  done
fi

# Load any local configuration
if [[ -d "$ZLOCAL" ]]; then
  for file in "$ZLOCAL"/*.zsh(N); do
      source "$file"
  done
fi

# Antibody Plug Manager
# Check to see if it's installed (and in the path)
type antibody >/dev/null 2>&1 || { curl -sfL git.io/antibody | sudo sh -s - -b /usr/local/bin; }

# Performance: Use static loading instead of dynamic for faster shell startup
# Generate static plugin file: antibody bundle < ~/.zsh_plugins.txt > ~/.zsh_plugins.zsh
# Then source it: source ~/.zsh_plugins.zsh
# For now, using dynamic loading but consider switching to static for production
source <(antibody init)
export ANTIBODY_HOME="$ZSH_CACHE_DIR/antibody"

# Helper: check command exists without invoking it
has() { command -v "$1" >/dev/null 2>&1 }

# Core plugins - always loaded
plugins=(
  "ohmyzsh/ohmyzsh path:plugins/pip"
  "ohmyzsh/ohmyzsh path:plugins/sudo"
  "ohmyzsh/ohmyzsh path:plugins/command-not-found"
  "ohmyzsh/ohmyzsh path:plugins/colored-man-pages"
  "ohmyzsh/ohmyzsh path:plugins/extract"
  "supercrabtree/k"
  "ohmyzsh/ohmyzsh path:plugins/vi-mode"
  "b4b4r07/enhancd"
  "zsh-users/zsh-completions"
  "sinetoami/antibody-completion"
  "sunlei/zsh-ssh"
  "Aloxaf/fzf-tab"
)

# Load core plugins
for plugin in "${plugins[@]}"; do
  antibody bundle "$plugin"
done

# Vi mode configuration
VI_MODE_SET_CURSOR=true         # Vertical bar on insert
bindkey -M viins '^[[3~' delete-char        # Remap delete key in insert mode
bindkey -M vicmd '^[[3~' delete-char        # Remap delete key in command mode

# Initialize enhancd configuration
export ENHANCD_DIR="$ZSH_CACHE_DIR/enhancd"
export ENHANCD_FILTER="fzf --preview='eza --tree --group-directories-first --git-ignore --level 1 {}'"
export ENHANCD_FILTER="fzf --preview 'eza -al --tree --level 1 --group-directories-first --git-ignore \
  --header --git --no-user --no-time --no-filesize --no-permissions {}' \
        --preview-window right,50% --height 35% --reverse --ansi \
        :fzy
        :peco"
source "$ZSH_CACHE_DIR/antibody/https-COLON--SLASH--SLASH-github.com-SLASH-b4b4r07-SLASH-enhancd/init.sh"

# Conditional plugins - only load if command exists
if has kubectl; then
  antibody bundle "ohmyzsh/ohmyzsh path:plugins/kubectl"
fi

if has docker && [[ -r $ZCOMPLETION/_docker ]]; then
  source "$ZCOMPLETION/_docker"
fi

if has aws; then
  antibody bundle "ohmyzsh/ohmyzsh path:plugins/aws"
fi

if has ansible; then
  antibody bundle "ohmyzsh/ohmyzsh path:plugins/ansible"
fi

if has go; then
  antibody bundle "ohmyzsh/ohmyzsh path:plugins/golang"
  # GOPATH is set in .zshenv
  export PATH="$PATH:$GOPATH/bin"

  if ! has osc; then
    echo "[zshrc] osc not found. You can install it via:"
    echo "         go install github.com/theimpostor/osc@latest"
  elif [[ -r $ZCOMPLETION/_osc ]]; then
    source "$ZCOMPLETION/_osc"
  fi
fi

if has yt-dlp; then
  antibody bundle "clavelm/yt-dlp-omz-plugin"
fi

if has tailscale && [[ -r "$ZSH_CUSTOM/tailscale_zsh_completion.zsh" ]]; then
  source "$ZSH_CUSTOM/tailscale_zsh_completion.zsh"
fi

# Load custom key bindings
# source "$ZSH_CUSTOM/keybindings.zsh"

# ================================================
# Fzf configuration
# ================================================
source "$ZSH_CUSTOM/fzf_key-bindings.zsh"
source "$ZSH_CUSTOM/fzf_completion.zsh"
source "$ZSH_CUSTOM/fzf_functions.zsh"
export FZF_DEFAULT_COMMAND="fd --type f"
export FZF_DEFAULT_OPTS="--height 40% --tmux center,75%  --marker='✚' --pointer='▶' --prompt='❯ '"
export FZF_CTRL_T_COMMAND="rg --files --hidden --follow --glob '!.git/*' 2>/dev/null"
# export FZF_CTRL_T_OPTS="--reverse --preview 'bat --color=always --style=header,grid --line-range :100 {}'"
export FZF_CTRL_T_OPTS="--reverse --preview '$ZSCRIPTS/fzf-preview.sh {}'"
export FZF_ALT_C_COMMAND="fd --type d"
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -100'"
# --preview '$ZSCRIPTS/fzf-preview.sh {}'

# Tab completion
# Replace tab selection with fzf
antibody bundle "Aloxaf/fzf-tab"
# antibody bundle "Freed-Wu/fzf-tab-source"           # formatttin&g for fzf-preview in fzf-tab

# Bind rebind file search to alt+t
# bindkey -r '^T'
# bindkey -r '^[t'
bindkey '^[t' fzf-file-widget
# bindkey -r '^r'
# bindkey '^r' fzf-history-widget

# Auto-completion case-insensitive
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
# disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false
# set descriptions format to enable group support
zstyle ':completion:*:descriptions' format '[%d]'
# set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:(ls|cat|bat):*' fzf-preview 'less ${(Q)realpath}'
zstyle ':completion:*' list-grouped true
# switch group using `<` and `>`
zstyle ':fzf-tab:*' switch-group '<' '>'
# Set minimum height
zstyle ':fzf-tab:*' fzf-min-height 40
# accept completion and start another immediately
zstyle ':fzf-tab:*' continuous-trigger '/'
# Tmux popup window
zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
# Minimum popup size
zstyle ':fzf-tab:*' popup-min-size 150 0
# preview directory's content with eza when completing cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -al --tree --level 1 --group-directories-first --git-ignore \
        --header --git --no-user --no-time --no-filesize --no-permissions $realpath'
# show systemd unit status
zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word'
# environment variables preview
zstyle ':fzf-tab:complete:(-command-|-parameter-|-brace-parameter-|export|unset|expand):*' \
	fzf-preview 'echo ${(P)word}'

# git - requires git-delta
zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview \
	'git diff $word | delta'
zstyle ':fzf-tab:complete:git-log:*' fzf-preview \
	'git log --color=always $word'
zstyle ':fzf-tab:complete:git-help:*' fzf-preview \
	'git help $word | bat -plman --color=always'
zstyle ':fzf-tab:complete:git-show:*' fzf-preview \
	'case "$group" in
	"commit tag") git show --color=always $word ;;
	*) git show --color=always $word | delta ;;
	esac'
zstyle ':fzf-tab:complete:git-checkout:*' fzf-preview \
	'case "$group" in
	"modified file") git diff $word | delta ;;
	"recent commit object name") git show --color=always $word | delta ;;
	*) git log --color=always $word ;;
	esac'

# # review panel
# zstyle ':fzf-tab:complete:*:*' fzf-preview 'less ${(Q)realpath}'
# export LESSOPEN='|/usr/bin/lesspipe.sh %s'     # Formatting of panel
export LESS='-r -M -S -I --mouse'    # raw, verbose, chop lines, ignore case, mouse scrolling
export LESSQUIET=1 # Suppress additional output not belonging to the file contents
#
# give a preview of commandline arguments when completing `kill/ps` below
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm -w -w"
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-preview \
  '[[ $group == "[process ID]" ]] && ps --pid=$word -o cmd --no-headers -w -w'
zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-flags --preview-window=down:3:wrap
# zstyle ':fzf-tab:complete:tailscale:*' fzf-preview


### fzf-tab Keybindings
# ctrl-a to select all
zstyle ':fzf-tab:*' fzf-bindings 'ctrl-a:toggle-all'

# Load tmux bundle if installed
if has tmux; then
    export ZSH_TMUX_AUTOSTART=false
    export ZSH_TMUX_AUTOCONNECT=false
    export TMUX_OUTER_TERM="${TERM:-unknown}"
    antibody bundle "ohmyzsh/ohmyzsh path:plugins/tmux"
fi

# load pyenv if installed
if has pyenv; then
  export PATH="$HOME/.pyenv/bin:$PATH"
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
fi

# These have to go after most plugins as they wrap other ones
# Performance: These are loaded last as they modify other plugins' behavior
antibody bundle "zdharma-continuum/fast-syntax-highlighting"
antibody bundle "zsh-users/zsh-autosuggestions"

# Powerlevel 10k
antibody bundle "romkatv/powerlevel10k"

# SSH Agent - Only run in login shells to avoid slowdown
# This checks if an agent is running and reuses it, or starts a new one
if [[ -o login ]]; then
    SSH_ENV="$HOME/.ssh/agent-environment"

    function start_agent {
        echo "Initialising new SSH agent..."
        /usr/bin/ssh-agent | sed 's/^echo/#echo/' > "${SSH_ENV}"
        echo succeeded
        chmod 600 "${SSH_ENV}"
        . "${SSH_ENV}" > /dev/null
        /usr/bin/ssh-add
    }

    # Source SSH settings if file exists and agent is still running
    if [[ -f "${SSH_ENV}" ]]; then
        . "${SSH_ENV}" > /dev/null
        # More efficient check: just test if the agent responds
        if ! kill -0 "${SSH_AGENT_PID}" 2>/dev/null; then
            start_agent
        fi
    else
        start_agent
    fi
fi

# Use system clipboard - must go after other keybindings
if has wl-copy; then
  antibody bundle "kutsan/zsh-system-clipboard"
  export ZSH_SYSTEM_CLIPBOARD_METHOD="wlc"        # Use wl-clipboard with "CLIPBOARD" selection
fi

# direnv is a tool that automatically sets/unsets environment variables when you enter/leave directories (think: auto-loading .env files, but on steroids).
# direnv hook zsh outputs some shell code that integrates direnv into your shell's behavior.
if has direnv; then
  eval "$(direnv hook zsh)"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f $ZSH_CUSTOM/p10k.zsh ]] || source $ZSH_CUSTOM/p10k.zsh

# ==== Profiling Output ====
# Uncomment to see profiling results (must also uncomment zmodload at top)
# echo "\n==== ZSH Startup Profiling ===="
# zprof | head -20

