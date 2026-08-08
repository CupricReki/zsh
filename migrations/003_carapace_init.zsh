# Migration 003: Pre-generate carapace init script on first run
function _migration_003() {
  local _init="${ZSH_CACHE_DIR}/carapace-init.zsh"

  if ! command_exists carapace; then
    log info "migration 003: carapace not installed, skipping"
    return 0
  fi

  if [[ -f "$_init" ]] && [[ ! "$_init" -ot "${commands[carapace]}" ]]; then
    return 0
  fi

  log info "migration 003: generating carapace completions (one-time, ~1s)..."
  if carapace _carapace > "$_init"; then
    log success "migration 003: carapace init generated"
  else
    log error "migration 003: carapace init generation failed"
    return 1
  fi
}

_migration_003
unset -f _migration_003
