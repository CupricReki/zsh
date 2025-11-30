# alternative using ripgrep-all (rga) combined with fzf-tmux preview
# This requires ripgrep-all (rga) installed: https://github.com/phiresky/ripgrep-all
# allows to search in PDFs, E-Books, Office documents, zip, tar.gz, etc.
# find-in-file - usage: fif <searchTerm> or fif "string with spaces" or fif "regex"
fif() {
    if [[ $# -eq 0 ]]; then 
        echo "Usage: fif <search term>" >&2
        return 1
    fi
    
    local file opener
    file="$(rga --max-count=1 --ignore-case --files-with-matches --no-messages "$*" | \
            fzf-tmux +m --preview="rga --ignore-case --pretty --context 10 '$*' {}")"
    
    [[ -z "$file" ]] && return 1
    
    # Cross-platform file opener
    if command -v xdg-open &>/dev/null; then
        opener=xdg-open  # Linux
    elif command -v open &>/dev/null; then
        opener=open      # macOS
    else
        echo "Error: No file opener found (xdg-open or open)" >&2
        return 1
    fi
    
    echo "Opening $file..."
    "$opener" "$file"
}

# Use fd and fzf to get the args to a command.
# Works only with zsh
# Examples:
# f mv # To move files. You can write the destination after selecting the files.
# f 'echo Selected:'
# f 'echo Selected music:' --extension mp3
# fm rm # To rm files in current directory
f() {
    sels=( "${(@f)$(fd "${fd_default[@]}" "${@:2}"| fzf)}" )
    test -n "$sels" && print -z -- "$1 ${sels[@]:q:q}"
}

# Like f, but not recursive.
fm() f "$@" --max-depth 1

# Deps
alias fz="fzf-noempty --bind 'tab:toggle,shift-tab:toggle+beginning-of-line+kill-line,ctrl-j:toggle+beginning-of-line+kill-line,ctrl-t:top' --color=light -1 -m"
fzf-noempty () {
	local in="$(</dev/stdin)"
	test -z "$in" && (
		exit 130
	) || {
		ec "$in" | fzf "$@"
	}
}
ec () {
	if [[ -n $ZSH_VERSION ]]
	then
		print -r -- "$@"
	else
		echo -E -- "$@"
	fi
}
