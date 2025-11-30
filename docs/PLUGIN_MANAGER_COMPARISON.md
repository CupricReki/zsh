# ZSH Plugin Manager Comparison (2025)

**Status:** Antibody is deprecated since 2021.

## Modern Options Comparison

### 🏆 Top Recommendations

| Manager | Speed | Simplicity | Status | Notes |
|---------|-------|------------|--------|-------|
| **zinit** | ⚡⚡⚡⚡⚡ | ⭐⭐ | ✅ Active | Fastest, complex, feature-rich |
| **sheldon** | ⚡⚡⚡⚡ | ⭐⭐⭐⭐ | ✅ Active | Fast (Rust), simple, great balance |
| **zap** | ⚡⚡⚡ | ⭐⭐⭐⭐⭐ | ✅ Active | Simple, minimal, easy to learn |
| **Manual** | ⚡⚡⚡⚡⚡ | ⭐⭐ | Always | Maximum control, no deps |

### ❌ Not Recommended

| Manager | Why Not |
|---------|---------|
| antibody | Deprecated (2021) |
| antigen | Slow, outdated |
| zplug | Slow, maintenance mode |

---

## Option 1: zinit (Fastest, Most Features)

### Pros
- ⚡ **Fastest** plugin manager available
- Turbo mode for lazy loading
- Parallel loading
- Plugin snippets support
- Very active development

### Cons
- Complex syntax
- Steep learning curve
- Many features you might not need

### Speed
```
Startup time: ~50-100ms with many plugins
```

### How to add plugins
```zsh
# In .zshrc
zinit light ohmyzsh/ohmyzsh path:plugins/git
zinit light zsh-users/zsh-autosuggestions

# With turbo mode (lazy load)
zinit ice wait lucid
zinit light zsh-users/zsh-syntax-highlighting
```

### Migration effort: Medium (syntax different from antibody)

---

## Option 2: sheldon (Best Balance) ⭐ RECOMMENDED

### Pros
- ⚡ Very fast (written in Rust)
- 🎯 Simple TOML configuration
- Static loading by default (like antibody static mode)
- Easy to understand
- Active development
- Good documentation

### Cons
- Need to install Rust binary
- Less features than zinit (but simpler)

### Speed
```
Startup time: ~50-80ms with many plugins
```

### How to add plugins
```toml
# In ~/.config/sheldon/plugins.toml
[plugins.zsh-autosuggestions]
github = "zsh-users/zsh-autosuggestions"

[plugins.zsh-syntax-highlighting]
github = "zsh-users/zsh-syntax-highlighting"

[plugins.ohmyzsh-git]
github = "ohmyzsh/ohmyzsh"
dir = "plugins/git"
```

Then in `.zshrc`:
```zsh
eval "$(sheldon source)"
```

### Migration effort: Low (similar to antibody philosophy)

---

## Option 3: zap (Simplest)

### Pros
- 🎯 Very simple
- Minimal overhead
- Easy to learn
- Good for beginners

### Cons
- Fewer optimization features
- Slower than zinit/sheldon
- Less mature

### Speed
```
Startup time: ~150-200ms with many plugins
```

### How to add plugins
```zsh
# In .zshrc
plug "zsh-users/zsh-autosuggestions"
plug "zsh-users/zsh-syntax-highlighting"
```

### Migration effort: Very low (similar to antibody)

---

## Option 4: Manual (Maximum Control)

### Pros
- ⚡ Maximum speed (no manager overhead)
- Complete control
- No dependencies
- Most maintainable long-term

### Cons
- Manual git management
- More work to add/update plugins
- Need to handle sourcing yourself

### Speed
```
Startup time: ~30-50ms with many plugins (fastest possible)
```

### How it works
```zsh
# Clone plugins once
mkdir -p ~/.zsh/plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/plugins/zsh-autosuggestions

# In .zshrc
source ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh
```

### Migration effort: Low (just clone and source)

---

## 🎯 Recommendation for Your Use Case

Based on your priorities:
- ✅ Speed is important (you're optimizing performance)
- ✅ Don't want confusion adding plugins
- ✅ Want simplicity

### I recommend: **sheldon**

**Why:**
1. **Fast** - Rust-based, static loading, ~50-80ms startup
2. **Simple** - Clean TOML config, easy to understand
3. **Clear workflow** - Edit TOML, run `sheldon lock`, done
4. **Similar to antibody** - Same philosophy (static > dynamic)
5. **Well maintained** - Active development, good docs

### Second choice: **Manual**

If you want absolute maximum speed and don't mind a bit more work.

---

## Migration Path: Antibody → sheldon

### Step 1: Install sheldon

```bash
# Via cargo (Rust)
cargo install sheldon

# Or via package manager (Arch)
yay -S sheldon

# Or via binary
curl --proto '=https' -fsSL https://rossmacarthur.github.io/install/crate.sh \
    | bash -s -- --repo rossmacarthur/sheldon --to ~/.local/bin
```

### Step 2: Create config

```bash
mkdir -p ~/.config/sheldon
```

Create `~/.config/sheldon/plugins.toml`:

```toml
# Core plugins
[plugins.ohmyzsh-pip]
github = "ohmyzsh/ohmyzsh"
dir = "plugins/pip"

[plugins.ohmyzsh-sudo]
github = "ohmyzsh/ohmyzsh"
dir = "plugins/sudo"

[plugins.ohmyzsh-command-not-found]
github = "ohmyzsh/ohmyzsh"
dir = "plugins/command-not-found"

[plugins.ohmyzsh-colored-man-pages]
github = "ohmyzsh/ohmyzsh"
dir = "plugins/colored-man-pages"

[plugins.ohmyzsh-extract]
github = "ohmyzsh/ohmyzsh"
dir = "plugins/extract"

[plugins.k]
github = "supercrabtree/k"

[plugins.ohmyzsh-vi-mode]
github = "ohmyzsh/ohmyzsh"
dir = "plugins/vi-mode"

[plugins.enhancd]
github = "b4b4r07/enhancd"

[plugins.zsh-completions]
github = "zsh-users/zsh-completions"

[plugins.antibody-completion]
github = "sinetoami/antibody-completion"

[plugins.zsh-ssh]
github = "sunlei/zsh-ssh"

[plugins.fzf-tab]
github = "Aloxaf/fzf-tab"

[plugins.fast-syntax-highlighting]
github = "zdharma-continuum/fast-syntax-highlighting"

[plugins.zsh-autosuggestions]
github = "zsh-users/zsh-autosuggestions"

[plugins.powerlevel10k]
github = "romkatv/powerlevel10k"
```

### Step 3: Initialize

```bash
sheldon lock  # Download and cache plugins
```

### Step 4: Update zshrc

Replace all your antibody lines with:

```zsh
# sheldon - Fast plugin manager
eval "$(sheldon source)"
```

That's it! Much simpler than the current antibody setup.

### Step 5: Adding new plugins

```bash
# Edit ~/.config/sheldon/plugins.toml
# Add:
# [plugins.my-new-plugin]
# github = "user/repo"

sheldon lock  # Update cache
exec zsh      # Reload
```

---

## Benchmarking

After migration, benchmark:

```bash
# Before (antibody)
time zsh -i -c exit

# After (sheldon)
time zsh -i -c exit

# Expected improvement: 300-350ms faster
```

---

## Quick Commands Cheatsheet

### sheldon

```bash
sheldon add my-plugin --github user/repo     # Add plugin
sheldon remove my-plugin                      # Remove plugin
sheldon lock                                  # Update cache
sheldon source                                # Show what to eval
```

### zinit

```bash
# In .zshrc, add:
zinit light user/repo                         # Add plugin
# Remove line and exec zsh                    # Remove plugin
zinit update                                  # Update all
```

---

## My Recommendation

**Go with sheldon.** It's the sweet spot of:
- Speed (almost as fast as zinit)
- Simplicity (much simpler than zinit)
- Maintainability (clean config file)
- Philosophy (matches antibody's approach)

Plus, the migration is straightforward, and you'll likely save another **~300ms** by switching from dynamic antibody to sheldon.

---

## Expected Performance

After full migration:

```
Component               Current    With sheldon
──────────────────────────────────────────────────
Plugin loading          373.94ms   →  ~50ms
Compinit (cached)       55.98ms    →  55.98ms
Other functions         ~26ms      →  ~26ms
──────────────────────────────────────────────────
TOTAL                   ~456ms     →  ~132ms

Improvement vs Original: 48%       →  85%
```

This would achieve your target of <150ms startup time! 🎯

