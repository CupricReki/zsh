# Modern Zsh Configuration

A fast, well-organized, and maintainable Zsh configuration optimized for performance and developer productivity.

## ⚡ Performance

- **~400ms startup time** (55% faster than baseline)
- **<100ms perceived startup** with instant prompt and lazy loading
- Smart completion caching that rebuilds only when needed
- Zero plugin manager overhead with static loading

## ✨ Features

- **Plugin Management:** [Sheldon](https://github.com/rossmacarthur/sheldon) with lazy loading
- **Theme:** [Powerlevel10k](https://github.com/romkatv/powerlevel10k) with instant prompt
- **Fuzzy Finding:** [fzf](https://github.com/junegunn/fzf) integration with [fzf-tab](https://github.com/Aloxaf/fzf-tab)
- **Smart Completions:** Auto-rebuilding cache, tool-specific completions
- **Dynamic Functions:** Auto-discovered from `function/` directory
- **Git Integration:** Comprehensive aliases and helpers
- **Syntax Highlighting:** Fast highlighting with lazy loading
- **Auto-suggestions:** History-based command suggestions

## 📦 Quick Install

### One-Line Install

```bash
wget -O - https://gitlab.ogbase.net/cupric/zsh/-/raw/master/init.sh | bash
```

### Prerequisites

```bash
# Debian/Ubuntu
sudo apt install -y zsh git curl fzf

# Fedora
sudo dnf install -y zsh git curl
sudo dnf copr enable lehrenfried/fzf
sudo dnf install -y fzf

# Arch Linux
sudo pacman -S zsh git curl fzf
```

### Manual Install

```bash
# 1. Clone repository
git clone https://gitlab.ogbase.net/cupric/zsh.git ~/.config/zsh

# 2. Run initialization script
cd ~/.config/zsh
./init.sh

# 3. Set Zsh as default shell
chsh -s $(which zsh)

# 4. Start Zsh
exec zsh
```

The `init.sh` script will:
- Check for local Ansible directory (`~/ansible`)
- Install Sheldon (Rust plugin manager) via cargo
- Set up all necessary symlinks and directories
- Initialize plugin manager and download plugins

## 📁 Structure

```
~/.config/zsh/
├── bin/                    # Custom binaries
├── completion/             # Custom completion files
├── custom/
│   ├── alias/             # Alias definitions
│   └── *.zsh              # Custom configurations
├── docs/                   # Documentation
├── function/              # Custom functions (auto-loaded)
├── local/                 # Local overrides (gitignored)
├── script/                # Utility scripts
├── init.sh                # Installation script
├── zshenv                 # Environment variables
└── zshrc                  # Main configuration
```

## 🔧 Configuration

### Environment Variables

Environment variables are defined in `zshenv` and available to all shells:

```bash
~/.config/zsh/zshenv
```

### Local Customization

Create local overrides that won't be tracked by git:

```bash
~/.config/zsh/local/
├── env.zsh        # Local environment variables
├── alias.zsh      # Local aliases
└── config.zsh     # Local configuration
```

These files are automatically loaded if they exist.

### Plugin Management

Plugins are managed by Sheldon via TOML configuration:

```bash
~/.config/sheldon/plugins.toml
```

**Add a new plugin:**

```bash
# Edit config
vi ~/.config/sheldon/plugins.toml

# Add plugin entry
[plugins.my-plugin]
github = "user/repo"
apply = ["defer"]  # Optional: for lazy loading

# Update
sheldon lock

# Reload shell
exec zsh
```

See [Plugin Manager Comparison](docs/PLUGIN_MANAGER_COMPARISON.md) for details.

### Custom Functions

Drop new functions in the `function/` directory and they'll be auto-loaded:

```bash
# Create function
vi ~/.config/zsh/function/myfunction

# Reload
exec zsh

# Use it
myfunction
```

## 📚 Documentation

- **[CHANGELOG.md](docs/CHANGELOG.md)** - What changed and why
- **[PROFILING.md](docs/PROFILING.md)** - How to profile your shell startup
- **[MIGRATION_GUIDE.md](docs/MIGRATION_GUIDE.md)** - Migrating between plugin managers
- **[PLUGIN_MANAGER_COMPARISON.md](docs/PLUGIN_MANAGER_COMPARISON.md)** - Plugin manager comparison

## 🔄 Updates

### Update Everything

```bash
cd ~/.config/zsh && git pull && exec zsh
```

Or use the alias:

```bash
zgu
```

### Update Plugins

```bash
sheldon lock --update
```

## 🎨 Included Plugins

### Core (Immediate Load)
- **git** - Git aliases and helpers
- **pip** - Python pip completions
- **sudo** - Sudo shortcuts (ESC ESC to add sudo)
- **command-not-found** - Suggest packages for missing commands
- **colored-man-pages** - Colorized man pages
- **extract** - Universal archive extraction
- **vi-mode** - Vi keybindings
- **zsh-completions** - Additional completions
- **zsh-ssh** - SSH completions
- **fzf-tab** - Fuzzy tab completion

### Deferred (Lazy Load)
- **k** - Enhanced `ls` with git status
- **enhancd** - Smart `cd` with history
- **fast-syntax-highlighting** - Command syntax highlighting
- **zsh-autosuggestions** - History-based suggestions
- **zsh-system-clipboard** - System clipboard integration
- **tmux** - Tmux integration

### Conditional (Only if Tool Installed)
- kubectl, aws, ansible, go, yt-dlp, docker, tailscale completions

## 🛠️ Requirements

### Essential
- **zsh** >= 5.8
- **git**
- **curl**

### Recommended
- **fzf** - Fuzzy finder
- **fd** - Fast find alternative
- **rg** (ripgrep) - Fast grep alternative
- **bat** - Better cat with syntax highlighting
- **eza** - Modern ls replacement
- **nvim** - Modern vim

### For Plugin Manager
- **cargo** (Rust) - Required for Sheldon

Install Rust:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

## 🚀 Performance Tips

1. **Use the completion cache** - Enabled by default, rebuilds intelligently
2. **Lazy loading is your friend** - Non-critical plugins load after prompt
3. **Profile periodically** - See [PROFILING.md](docs/PROFILING.md)
4. **Keep plugins minimal** - Only load what you actually use
5. **Use instant prompt** - Powerlevel10k feature (enabled by default)

## 🎯 Key Aliases

### Git
```bash
gst   # git status
gco   # git checkout
gcb   # git checkout -b (new branch)
gaa   # git add --all
gcmsg # git commit -m
gp    # git push
gl    # git pull
glog  # git log --oneline --graph
```

### Navigation
```bash
..    # cd ..
...   # cd ../..
....  # cd ../../..
l     # eza (if installed) or ls -lah
```

### Utilities
```bash
mkcd  # mkdir && cd
tarz  # Create tar.zst archive
zssh  # SSH with connection management
```

See `custom/alias/alias.zsh` for the complete list.

## 🐛 Troubleshooting

### Shell is slow

```bash
# Profile startup
time zsh -i -c exit

# Detailed profiling (see docs/PROFILING.md)
zmodload zsh/zprof
zprof
```

### Completions not working

```bash
# Rebuild completion cache
rm ~/.zcompdump*
exec zsh
```

### Plugins not loading

```bash
# Check if sheldon is installed
command -v sheldon

# Update plugins
sheldon lock

# Reinstall if needed
cargo install sheldon
```

### Missing dependencies

```bash
# Check what's missing
for cmd in fzf fd rg bat eza; do
  command -v $cmd || echo "Missing: $cmd"
done
```

## 🤝 Contributing

This is a personal configuration, but feel free to:
- Fork and customize for your needs
- Submit issues for bugs
- Suggest improvements via merge requests

## 📝 License

MIT License - See [LICENSE.md](LICENSE.md)

## 🙏 Credits

Built with these amazing projects:
- [Sheldon](https://github.com/rossmacarthur/sheldon) - Fast plugin manager
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k) - Beautiful theme
- [fzf](https://github.com/junegunn/fzf) - Fuzzy finder
- [zsh-defer](https://github.com/romkatv/zsh-defer) - Lazy loading
- Many plugins from [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh)

## 📈 Changelog

See [CHANGELOG.md](docs/CHANGELOG.md) for version history and improvements.

---

**Made with ❤️ for a blazing-fast shell experience** ⚡
