# extract() wrapper — sourced AFTER sheldon loads the ohmyzsh extract plugin.
# Saves the plugin function as extract_orig, then delegates invocations using
# the new flags to the installed `extract` binary (single-file zipapp installed
# by the ansible zsh role). Everything else falls through to the plugin.
# ``ZBIN`` is the tests/dev seam (zshenv exports it as the repo's bin/, so it is
# never empty in a real shell) — it only wins while a shim actually lives there.
# One-shot save (finding C6): re-sourcing zshrc must not capture the wrapper
# itself as extract_orig, or extract would recurse forever.
if (( ! $+functions[extract_orig] )) && (( $+functions[extract] )); then
  functions[extract_orig]="${functions[extract]}"
fi
extract() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      -R*|-p*|-P*|-F*|-r*|--recursive*|--password*|--password-file*|--force*|--remove*)
        if [[ -n ${ZBIN:-} && -f ${ZBIN}/extract.py ]]; then
          python3 "${ZBIN}/extract.py" "$@"
        elif (( $+commands[extract] )); then
          command extract "$@"
        else
          print -u2 "extract: the extract tool is not installed (run the ansible zsh role)"
          return 1
        fi
        return $?
        ;;
    esac
  done
  if (( $+functions[extract_orig] )); then extract_orig "$@"; else
    print -u2 "extract: plugin not loaded and the extract tool's flags not given"; return 1
  fi
}
