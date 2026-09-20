# extract() wrapper — sourced AFTER sheldon loads the ohmyzsh extract plugin.
# Saves the plugin function as extract_orig, then delegates invocations using
# the new flags to bin/extract.py (spec §9); everything else falls through.
# One-shot save (finding C6): re-sourcing zshrc must not capture the wrapper
# itself as extract_orig, or extract would recurse forever.
if (( ! $+functions[extract_orig] )) && (( $+functions[extract] )); then
  functions[extract_orig]="${functions[extract]}"
fi
# Resolve the shim: ZBIN when set (tests), else the repo's bin/ under ZSH_CUSTOM.
: ${ZBIN:=${ZSH_CUSTOM:h}/bin}
extract() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      -R*|-p*|-P*|-F*|-r*|--recursive*|--password*|--password-file*|--force*|--remove*)
        "${ZBIN}/extract.py" "$@" && return 0 || return $?
        ;;
    esac
  done
  if (( $+functions[extract_orig] )); then
    extract_orig "$@"
  else
    print -u2 "extract: plugin not loaded and extract.py flags not given"
    return 1
  fi
}
