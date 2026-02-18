# Zsh Keybindings
# Keybindings are defined in keymap/keymap_zsh.yaml and interpreted by
# keymap/interpret_zsh.py. The gen file is regenerated only when the YAML
# changes (mtime-gated), so normal shell starts pay zero interpreter overhead.

# FZF completion (not a keybinding — sources fzf tab completion widgets)
source /usr/share/fzf/completion.zsh

# ================================================
# Universal keymap loader (mtime-gated)
# ================================================
_zsh_yaml="$ZSH_CUSTOM/keymap/keymap_zsh.yaml"
_zsh_gen="$ZSH_CUSTOM/keymap/keybindings.gen.zsh"

if [[ -f $_zsh_yaml && ( ! -f $_zsh_gen || $_zsh_yaml -nt $_zsh_gen ) ]]; then
  local _zsh_tmp="${_zsh_gen}.tmp"
  if python3 "$ZSH_CUSTOM/keymap/interpret_zsh.py" "$_zsh_yaml" > "$_zsh_tmp"; then
    mv "$_zsh_tmp" "$_zsh_gen"
    zcompile "$_zsh_gen" 2>/dev/null
  else
    rm -f "$_zsh_tmp"
    print -u2 "keybindings: failed to generate — fix errors above and reload"
  fi
fi

# Source bytecode if available, fall back to text file
if [[ -f "${_zsh_gen}.zwc" ]]; then
  source "${_zsh_gen}.zwc" 2>/dev/null || source "$_zsh_gen"
elif [[ -f "$_zsh_gen" ]]; then
  source "$_zsh_gen"
fi

unset _zsh_yaml _zsh_gen
