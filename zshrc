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

# ================================================
# Preflight Checks
# ================================================
# Run preflight checks for required tools and versions
source "$ZSCRIPTS/preflight-check"

# Recommended tools (checked silently via has() function throughout config)
# - eza/lsd: Modern ls replacement (for enhancd, fzf previews)
# - rg (ripgrep): Fast grep (for fzf file search)
# - bat: Syntax highlighting (for fzf previews)
# - git-delta: Better git diffs
# - nvim: Modern vim
# - pandoc: Document converter
# - mdcat: Markdown renderer
# - grc: Colorize output
# - pdftotext: PDF extraction
# - osc: OSC 52 clipboard support


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
# Smart caching: Rebuild if cache is old OR completion files changed
autoload -Uz compinit

# Determine cache file location
_comp_cache="${ZDOTDIR:-$HOME}/.zcompdump"

# Check multiple conditions for rebuilding
_needs_rebuild=0

# 1. Cache doesn't exist or is older than 24 hours
if [[ ! -f "$_comp_cache" ]] || [[ -n ${_comp_cache}(#qN.mh+24) ]]; then
  _needs_rebuild=1
fi

# 2. Custom completion files have been modified recently
if [[ $_needs_rebuild -eq 0 ]] && [[ -d "$ZCOMPLETION" ]]; then
  _comp_files=($ZCOMPLETION/**/*(.Nmh-24))
  if [[ ${#_comp_files} -gt 0 ]]; then
    _needs_rebuild=1
  fi
  unset _comp_files
fi

# 3. Check if FPATH directories are newer than cache (new tools installed)
if [[ $_needs_rebuild -eq 0 ]]; then
  for _fdir in $fpath; do
    if [[ -d "$_fdir" ]] && [[ "$_fdir" -nt "$_comp_cache" ]]; then
      _needs_rebuild=1
      break
    fi
  done
  unset _fdir
fi

# Run appropriate compinit
if [[ $_needs_rebuild -eq 1 ]]; then
  compinit  # Full rebuild
else
  compinit -C  # Use cache (fast)
fi

unset _comp_cache _needs_rebuild

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
    "$HOME/.cargo/bin"                  # Rust cargo binaries (sheldon, etc)
    "$HOME/.npm-global/bin"            # local user npm bins
    "$HOME/.go/bin"                     # Go binaries (GOPATH is in .zshenv)
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

# FPATH: Directories zsh searches for functions and completions
# Adding these directories makes:
#   - Custom functions in $ZFUNC available for autoload
#   - Custom completions in $ZCOMPLETION automatically discovered by compinit
#   - Local overrides in $ZLOCAL take priority
export FPATH="$ZCOMPLETION:$ZFUNC:$ZLOCAL:$FPATH"

# Set terminal colors
# Based on https://github.com/joshjon/bliss-dircolors
# Performance: Consider caching this output to avoid eval on every shell start
if [[ -f "$ZSH_CUSTOM/bliss.dircolors" ]]; then
  eval `dircolors $ZSH_CUSTOM/bliss.dircolors`
fi

# Autoload all custom functions from the function directory
if [[ -d "$ZFUNC" ]]; then
  for func in "$ZFUNC"/*(N:t); do
    autoload -Uz "$func"
  done
fi

# Autoload extract from oh-my-zsh
autoload -Uz extract

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

# ================================================
# Plugin Manager - sheldon (fast, with lazy loading)
# ================================================

# Check if sheldon is available
if ! command -v sheldon &> /dev/null; then
    echo "" >&2
    echo "⚠️  sheldon not found" >&2
    echo "Install: cargo install sheldon" >&2
    echo "Info: https://github.com/rossmacarthur/sheldon" >&2
    echo "" >&2
    return 1
fi

# Helper: check command exists without invoking it
has() { command -v "$1" >/dev/null 2>&1 }

# Load all plugins via sheldon (configured in ~/.config/sheldon/plugins.toml)
# This includes lazy loading for non-critical plugins
eval "$(sheldon source)"

# ================================================
# Conditional Plugins - Only load if tools exist
# ================================================

# kubectl plugin (only if kubectl is installed)
if has kubectl; then
  source <(kubectl completion zsh)
fi

# AWS CLI plugin (only if aws is installed)
if has aws; then
  # Load aws completions from system or oh-my-zsh
  if [[ -f /usr/share/zsh/site-functions/_aws ]]; then
    source /usr/share/zsh/site-functions/_aws
  fi
fi

# Ansible plugin (only if ansible is installed)  
if has ansible; then
  # Ansible completions are usually in system paths
  if [[ -f /usr/share/zsh/site-functions/_ansible ]]; then
    source /usr/share/zsh/site-functions/_ansible
  fi
fi

# Golang - check for osc tool (only if go is installed)
if has go; then
  # GOPATH/bin is already in PATH from main config
  if ! has osc; then
    echo "[zshrc] osc not found. Install with: go install github.com/theimpostor/osc@latest" >&2
  fi
fi

# yt-dlp completions (only if yt-dlp is installed)
if has yt-dlp; then
  # yt-dlp completions are usually in system paths
  if [[ -f /usr/share/zsh/site-functions/_yt-dlp ]]; then
    source /usr/share/zsh/site-functions/_yt-dlp
  fi
fi

# Vi mode configuration
VI_MODE_SET_CURSOR=true         # Vertical bar on insert
bindkey -M viins '^[[3~' delete-char        # Remap delete key in insert mode
bindkey -M vicmd '^[[3~' delete-char        # Remap delete key in command mode

# Initialize enhancd configuration
export ENHANCD_DIR="$ZSH_CACHE_DIR/enhancd"
export ENHANCD_FILTER="fzf --preview 'eza -al --tree --level 1 --group-directories-first --git-ignore \
  --header --git --no-user --no-time --no-filesize --no-permissions {}' \
        --preview-window right,50% --height 35% --reverse --ansi \
        :fzy
        :peco"

# ================================================
# Additional tool-specific completions
# Custom completion files are in $ZCOMPLETION which is in $FPATH
# compinit automatically discovers and loads them - DO NOT source them manually
# ================================================
# These are custom completion files that aren't in sheldon



# Tailscale completions (custom file)
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
# Alternative: use fzf-preview.sh for more detailed previews
# --preview '$ZSCRIPTS/fzf-preview.sh {}'

# ================================================
# Tab completion with fzf
# ================================================
# fzf-tab replaces default tab completion with fzf interface
# Loaded via sheldon for better plugin management

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

# Tmux configuration (plugin is lazy-loaded via sheldon)
if has tmux; then
    export ZSH_TMUX_AUTOSTART=false
    export ZSH_TMUX_AUTOCONNECT=false
    export TMUX_OUTER_TERM="${TERM:-unknown}"
fi

# load pyenv if installed
if has pyenv; then
  export PATH="$HOME/.pyenv/bin:$PATH"
  eval "$(pyenv init -)"
  eval "$(pyenv virtualenv-init -)"
fi

# ================================================
# Syntax highlighting & autosuggestions
# ================================================
# These are loaded via sheldon with lazy loading (zsh-defer)
# This means they load after the prompt appears, making startup feel instant
# - fast-syntax-highlighting: highlights commands as you type
# - zsh-autosuggestions: suggests commands from history
# - powerlevel10k: theme (loads immediately for prompt)

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
# zsh-system-clipboard is loaded via sheldon (with lazy loading)
if has wl-copy; then
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

