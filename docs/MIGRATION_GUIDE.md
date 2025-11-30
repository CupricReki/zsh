# Migrating from Antibody (Deprecated)

## 🎯 Recommended: **Antidote** (Official Successor)

**Why Antidote:**
- ✅ **Official successor** recommended by antibody creators
- ✅ **Drop-in replacement** - minimal migration effort
- ✅ **Same syntax** as antibody (almost)
- ✅ **High performance** - static loading by default
- ✅ **Actively maintained** - regular updates
- ✅ **No confusion** - works just like antibody

### Installation

```bash
# Clone antidote
git clone --depth=1 https://github.com/mattmc3/antidote.git ${ZDOTDIR:-~}/.antidote

# Or via package manager (Arch)
yay -S zsh-antidote
```

### Migration Steps

#### 1. Create plugin list file

Create `~/.zsh_plugins.txt`:

```txt
# Core plugins
ohmyzsh/ohmyzsh path:plugins/pip
ohmyzsh/ohmyzsh path:plugins/sudo
ohmyzsh/ohmyzsh path:plugins/command-not-found
ohmyzsh/ohmyzsh path:plugins/colored-man-pages
ohmyzsh/ohmyzsh path:plugins/extract
supercrabtree/k
ohmyzsh/ohmyzsh path:plugins/vi-mode
b4b4r07/enhancd
zsh-users/zsh-completions
sinetoami/antibody-completion
sunlei/zsh-ssh
Aloxaf/fzf-tab
zdharma-continuum/fast-syntax-highlighting
zsh-users/zsh-autosuggestions
romkatv/powerlevel10k

# Conditional plugins (add manually in zshrc)
# ohmyzsh/ohmyzsh path:plugins/kubectl
# ohmyzsh/ohmyzsh path:plugins/aws
# ohmyzsh/ohmyzsh path:plugins/ansible
# ohmyzsh/ohmyzsh path:plugins/golang
```

#### 2. Update zshrc

Replace the entire antibody section (lines ~200-280) with:

```zsh
# ================================================
# Antidote Plugin Manager (antibody successor)
# ================================================

# Set the root name of the plugins files (.txt and .zsh) antidote will use.
zsh_plugins=${ZDOTDIR:-~}/.zsh_plugins

# Ensure the .zsh file is newer than the .txt file; regenerate if needed.
if [[ ! $zsh_plugins.zsh -nt $zsh_plugins.txt ]]; then
  (
    source ${ZDOTDIR:-~}/.antidote/antidote.zsh
    antidote bundle <$zsh_plugins.txt >|$zsh_plugins.zsh
  )
fi

# Source the generated static plugin file
source $zsh_plugins.zsh

# Helper: check command exists without invoking it
has() { command -v "$1" >/dev/null 2>&1 }

# Vi mode configuration
VI_MODE_SET_CURSOR=true
bindkey -M viins '^[[3~' delete-char
bindkey -M vicmd '^[[3~' delete-char

# Enhancd configuration
export ENHANCD_DIR="$ZSH_CACHE_DIR/enhancd"
export ENHANCD_FILTER="fzf --preview 'eza -al --tree --level 1 --group-directories-first --git-ignore \
  --header --git --no-user --no-time --no-filesize --no-permissions {}' \
        --preview-window right,50% --height 35% --reverse --ansi \
        :fzy
        :peco"

# Conditional plugins
if has kubectl; then
  source <(antidote init) && antidote bundle ohmyzsh/ohmyzsh path:plugins/kubectl
fi

if has aws; then
  source <(antidote init) && antidote bundle ohmyzsh/ohmyzsh path:plugins/aws
fi

if has ansible; then
  source <(antidote init) && antidote bundle ohmyzsh/ohmyzsh path:plugins/ansible
fi

if has go; then
  source <(antidote init) && antidote bundle ohmyzsh/ohmyzsh path:plugins/golang
  export PATH="$PATH:$GOPATH/bin"

  if ! has osc; then
    echo "[zshrc] osc not found. You can install it via:"
    echo "         go install github.com/theimpostor/osc@latest"
  elif [[ -r $ZCOMPLETION/_osc ]]; then
    source "$ZCOMPLETION/_osc"
  fi
fi

if has yt-dlp; then
  source <(antidote init) && antidote bundle clavelm/yt-dlp-omz-plugin
fi

if has tailscale && [[ -r "$ZSH_CUSTOM/tailscale_zsh_completion.zsh" ]]; then
  source "$ZSH_CUSTOM/tailscale_zsh_completion.zsh"
fi
```

#### 3. First run

```bash
# This will generate .zsh_plugins.zsh from .zsh_plugins.txt
exec zsh
```

---

## How to Add New Plugins with Antidote

Super simple - just like antibody!

### Method 1: Edit plugin list (Recommended)

```bash
# Edit ~/.zsh_plugins.txt
echo "user/repo" >> ~/.zsh_plugins.txt

# Regenerate (automatic on next shell start, or force it)
rm ~/.zsh_plugins.zsh
exec zsh
```

### Method 2: One-liner

```bash
# Add to .zsh_plugins.txt and reload
echo "user/new-plugin" >> ~/.zsh_plugins.txt && rm ~/.zsh_plugins.zsh && exec zsh
```

### Method 3: Conditional (like kubectl)

Add to zshrc:
```zsh
if has mycommand; then
  source <(antidote init) && antidote bundle user/my-plugin
fi
```

---

## Expected Performance

### Current (antibody)
```
Plugin loading: 373.94ms (82% of total time)
Total startup:  ~456ms
```

### After Antidote Migration
```
Plugin loading: ~50-80ms (static loading)
Total startup:  ~132-162ms

Improvement: 65-70% faster! 🚀
```

---

## Commands You'll Use

```bash
# Update all plugins
antidote update

# Clean cache
rm ~/.zsh_plugins.zsh && exec zsh

# List installed plugins
cat ~/.zsh_plugins.txt
```

---

## Why Antidote > Other Options

| Feature | Antidote | zinit | sheldon | Manual |
|---------|----------|-------|---------|--------|
| Speed | ⚡⚡⚡⚡ | ⚡⚡⚡⚡⚡ | ⚡⚡⚡⚡ | ⚡⚡⚡⚡⚡ |
| Simplicity | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| Migration | ✅ Easy | 🔶 Medium | 🔶 Medium | 🔶 Medium |
| Confusion | ❌ None | ⚠️ Some | 🔶 Little | ⚠️ Some |
| Official successor | ✅ Yes | ❌ No | ❌ No | N/A |

---

## Alternative: sheldon (If you want to try something different)

**Pros:** Very fast (Rust), clean TOML config  
**Cons:** Different workflow than antibody

See `PLUGIN_MANAGER_COMPARISON.md` for details.

---

## My Strong Recommendation

**Use Antidote.** It's:
1. The official successor (blessed by antibody authors)
2. Drop-in replacement (minimal confusion)
3. Same workflow you're used to
4. Fast (static loading like antibody's recommended way)
5. Actively maintained

Plus, you'll save ~300ms just by switching! 🎯

