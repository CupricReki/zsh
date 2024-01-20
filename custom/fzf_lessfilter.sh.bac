#! /usr/bin/env sh

has_cmd() { command -v "$1" >/dev/null 2>&1 ; }

mime=$(file -bL --mime-type "$1")
category=${mime%%/*}
kind=${mime##*/}

if [ -d "$1" ]; then
    has_cmd exa && exa -a --color=always -l -g --git --group-directories-first --icons "$1"
    has_cmd lsd && lsd -al --color=always --icon=always "$1"
elif [ "$category" = image ]; then
    has_cmd chafa && chafa "$1"
    has_cmd exiftool && exiftool "$1"
elif [ "$kind" = vnd.openxmlformats-officedocument.spreadsheetml.sheet ] || \
	[ "$kind" = vnd.ms-excel ]; then
	in2csv "$1" | xsv table | bat -ltsv --color=always
elif [ "$category" = text ]; then
    has_cmd bat && bat --color=always --line-range :200 "$1"
else
	$ZSH_CUSTOM/fzf_lesspipe.sh "$1" | bat --color=always --line-range :200
fi
