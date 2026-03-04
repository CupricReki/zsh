# Migration 002: Switch Cargo bin path to XDG-compliant location
#
# ~/.cargo/bin is replaced by ~/.local/share/cargo/bin in PATH.
# Symlink ~/.cargo/bin -> ~/.local/share/cargo/bin so any hard-coded
# references or shell history still work.

function _migration_002() {
  local old_bin="$HOME/.cargo/bin"
  local new_bin="$HOME/.local/share/cargo/bin"

  if [[ -d "$old_bin" && ! -L "$old_bin" ]]; then
    if [[ ! -d "$new_bin" ]]; then
      mkdir -p "${new_bin:h}"
      mv "$old_bin" "$new_bin" \
        && ln -s "$new_bin" "$old_bin" \
        && log info "migration 002: moved $old_bin -> $new_bin and created symlink"
    else
      # $new_bin already exists — merge any binaries from $old_bin that are not
      # already present, then replace $old_bin with a symlink so nothing is lost.
      local -i errors=0
      for f in "$old_bin"/*(N); do
        local dest="$new_bin/${f:t}"
        if [[ ! -e "$dest" ]]; then
          mv "$f" "$dest" || (( errors++ ))
        else
          log warning "migration 002: skipping ${f:t} (already exists in $new_bin)"
        fi
      done
      if (( errors == 0 )); then
        rm -rf "$old_bin" \
          && ln -s "$new_bin" "$old_bin" \
          && log info "migration 002: merged $old_bin -> $new_bin and replaced with symlink"
      else
        log error "migration 002: $errors file(s) failed to move; leaving $old_bin intact"
        return 1
      fi
    fi
  elif [[ -L "$old_bin" ]]; then
    log info "migration 002: $old_bin is already a symlink, nothing to do"
  else
    log info "migration 002: $old_bin does not exist, nothing to do"
  fi
}

_migration_002
unset -f _migration_002
