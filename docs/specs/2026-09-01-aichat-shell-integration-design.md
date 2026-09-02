# Design: aichat inline command generation (LM Studio local-first, cloud-switchable)

- **Date:** 2026-09-01
- **Scope:** zsh repo (primary) + one companion change in the `ansible` repo
- **Status:** draft — pending user review

## 1. Goal

Add the ability to type a natural-language request directly on the zsh command line and turn it into a concrete, reviewable shell command — backed by a local LM Studio model by default, with cloud LLMs available on demand.

Two entry points:

- **Compose** (`Ctrl+O`): transform the current command line into a concrete command, inserted into the buffer (never auto-run).
- **REPL** (`Ctrl+Alt+O`): open aichat's interactive REPL.

## 2. Context / current state

- zsh dotfiles live in this repo, provisioned by the `ansible` repo's `roles/zsh` role (clones this repo, symlinks `.zshrc`/`.zshenv`, installs tools, runs `sheldon lock`).
- Plugin manager: sheldon (`sheldon/plugins.toml`). fzf is deeply integrated (fzf-tab, `ftb-tmux-popup`, fzf widgets). vi mode. powerlevel10k.
- Keybindings are declarative: `custom/keybinding/keymap_zsh.yaml` → `interpret_zsh.py` → `keybindings.gen.zsh` (mtime-gated, sourced by `custom/keybindings.zsh` from `zshrc:289`).
- Local inference runs in **LM Studio** on the RX 6800/6900 XT (16 GB VRAM, ROCm); model `qwen/qwen3.5-9b` is loaded with **Thinking disabled**. (Ollama is also configured in `zshrc` but is not used for this feature.)
- The `ansible` role installs Rust tools via `zsh_rust_tools_packages` (`roles/zsh/vars/main.yml:41`): pinned registry download → `cargo-binstall` → `cargo install` fallback.

## 3. Chosen tool

**aichat** (Rust, `sigoden/aichat`).

Rationale:

- Native multi-provider support (Ollama, OpenAI, Claude, Gemini, and 20+ others) — this is the "adaptive, local-first → cloud-switchable" property.
- `-e/--execute` Shell Assistant generates OS/shell-aware commands from natural language.
- Ships an official zsh shell-integration script (the exact compose behavior we want).
- Rust binary matches the existing toolchain (sheldon, eza, bat, rg, fd, delta, carapace).

## 4. Architecture / components

### 4.1 aichat binary + config (user-local, not committed)

- **Install:** `cargo install aichat` (manually) or via the `ansible` role's rust-tools path (see §4.3).
- **Config:** `~/.config/aichat/config.yaml` — aichat auto-generates on first run.
- **Secrets:** `~/.config/aichat/.env` (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GEMINI_API_KEY`, …). Never committed.

### 4.2 zsh integration (this repo)

- `custom/aichat.zsh` (new) — defines the two zle widgets.
- `custom/keybinding/keymap_zsh.yaml` — add an `ai:` section and extend `_section_order`.
- `zshrc` — one guarded `source` line, placed before the keybindings source.
- `custom/keybinding/zsh_notation.py` — one-line docstring fix (remove the stale "combined not supported" note).

### 4.3 Ansible provisioning (companion)

- `roles/zsh/vars/main.yml` — add `aichat` to `zsh_rust_tools_packages`.

## 5. Keybindings

| Action | Key | YAML `shortcut` | Generated `bindkey` |
|--------|-----|-----------------|---------------------|
| Compose → buffer | `Ctrl+O` | `C-o` | `^o` |
| REPL | `Ctrl+Alt+O` | `C-A-o` | `^[^o` |

- Both added via `keymap_zsh.yaml` (main keymap, inherited by `viins`/`vicmd`).
- `C-A-o` was verified against `zsh_notation.py`: `shortcut_to_zsh` consumes the `C-` + `A-` prefixes and emits `^[^o` (combined modifiers are supported in code, despite the stale docstring noted in §8).
- Neither sequence collides with existing bindings (`C-<Space>`, `Alt+t/b/f/d`, `Ctrl+R/T`, `Tab`) or default vi-mode maps (`^o` unbound; `^[^o` falls in the `self-insert` range).

## 6. Widgets / data flow

### 6.1 `_aichat_compose` (`Ctrl+O`)

Adapted from aichat's official `scripts/shell-integration/integration.zsh` (which binds `Alt+e`), rebinding to `Ctrl+O`:

```zsh
_aichat_compose() {
    if [[ -n "$BUFFER" ]]; then
        local _old=$BUFFER
        local _new
        BUFFER+="⌛"
        zle -I && zle redisplay
        if _new=$(aichat -e "$_old"); then
            BUFFER="$_new"
        else
            BUFFER="$_old"   # on failure, keep what you typed
        fi
        zle end-of-line
    fi
}
zle -N _aichat_compose
```

Flow: type natural language → `Ctrl+O` → spinner → `aichat -e` replaces `BUFFER` with the concrete command → user reviews/edits and presses Enter.

### 6.2 `_aichat_repl` (`Ctrl+Alt+O`)

```zsh
_aichat_repl() {
    zle -I
    aichat
    zle reset-prompt
}
zle -N _aichat_repl
```

Flow: release the line editor → interactive aichat REPL → restore the prompt on exit (same pattern fzf uses).

## 7. Adaptive config (local-first, cloud-switchable)

```yaml
# ~/.config/aichat/config.yaml
model: lmstudio:qwen/qwen3.5-9b   # default = local (LM Studio)
keybindings: vi                   # match the shell

clients:
  - type: openai-compatible
    name: lmstudio
    api_base: http://localhost:1234/v1
    models:
      - name: qwen/qwen3.5-9b
        max_input_tokens: 131072

  # Cloud fallbacks — uncomment + put keys in ~/.config/aichat/.env
  # - type: openai
  # - type: claude
```

- Default model is the local LM Studio `qwen/qwen3.5-9b`; switch per-invocation with `aichat -m openai:gpt-4o "..."` or `/model` in the REPL.
- Keys live in `~/.config/aichat/.env` (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, …) — aichat reads them natively; nothing secret enters the repo.
- **LM Studio model ID is `qwen/qwen3.5-9b`** (note the `qwen/` prefix — confirmed via `GET /v1/models`).
- **Disable Thinking** for `qwen/qwen3.5-9b` in LM Studio (My Models → Inference → Thinking off). aichat does not send `enable_thinking`, so the LM Studio server-side toggle is the control point; with it off, responses skip the reasoning phase (verified: `reasoning_tokens: 0`).

## 8. Files changed

### zsh repo

| File | Change |
|------|--------|
| `custom/aichat.zsh` | **new** — `_aichat_compose` + `_aichat_repl` widgets, `zle -N` |
| `custom/keybinding/keymap_zsh.yaml` | add `ai:` section (2 entries); extend `_section_order` to `[…, ai]` |
| `zshrc` | add guarded `source "$ZSH_CUSTOM/aichat.zsh"` before the keybindings source |
| `custom/keybinding/zsh_notation.py` | fix stale "combined not supported" docstring line |

### ansible repo

| File | Change |
|------|--------|
| `roles/zsh/vars/main.yml` | add `aichat` to `zsh_rust_tools_packages` |

## 9. Error handling

- **aichat not installed** → the `zshrc` source is guarded by `command_exists aichat`; widgets simply don't register (no errors).
- **Empty buffer on `Ctrl+O`** → no-op (matches aichat's official behavior).
- **LM Studio not running / model not loaded** → aichat surfaces its own error on stderr; `_aichat_compose` restores the original buffer so the typed request isn't lost. `_aichat_repl` is unaffected (its REPL UI shows the error).
- **Cloud model without a key** → aichat auth error; `~/.config/aichat/.env` is the single place to fix it.

## 10. Testing / validation

### zsh repo

- `python3 custom/keybinding/interpret_zsh.py --validate custom/keybinding/keymap_zsh.yaml` — confirms `C-A-o` resolves and no duplicate shortcuts.
- `python3 custom/keybinding/interpret_zsh.py --test` — confirms notation unit tests still pass.
- zsh smoke test in a subshell: source the config, assert `zle -la` lists `_aichat_compose`/`_aichat_repl` and `bindkey` shows `^o` / `^[^o`.

### ansible repo

- `ansible-lint` + the `zsh` role's molecule scenario (run inside the devcontainer, per `ansible/AGENTS.md`).

## 11. Out of scope / follow-ups

- Adding `aichat` to the `rust-tools` CI `PACKAGES` list + tagging + bumping `zsh_rust_tools_tag` (pinned-registry fast path; the `cargo-binstall`/`cargo install` fallback works meanwhile).
- Seeding `~/.config/aichat/config.yaml` via Ansible (currently user-local, self-generated).
- (Resolved) Default model is LM Studio `qwen/qwen3.5-9b` with Thinking disabled — connection verified responsive via `curl`.
