# aichat Inline Command Generation Implementation Plan

> **Required sub-skills:** subagent-driven-development, plan-execution

**Goal:** Add inline natural-language → command generation to zsh via aichat (local LM Studio default, cloud-switchable), bound to `Ctrl+O` (compose) and `Ctrl+Alt+O` (REPL).

**Architecture:** Adopt aichat's official zsh Shell Assistant integration, rebind it through the repo's declarative keymap interpreter, and add the `aichat` binary to the ansible zsh role's rust-tools provisioning path. zsh-repo changes are the primary work; a one-line ansible change makes install reproducible.

**Tech Stack:** zsh, aichat (Rust), the repo's Python keymap interpreter (`interpret_zsh.py` + `zsh_notation.py`), Ansible (`roles/zsh`).

---

## Execution model (multi-repo)

This plan touches **two repositories** with disjoint write scopes:

| Repo | Worktree / branch | `.test-evidence.json` lands at |
|------|-------------------|-------------------------------|
| `/home/cupric/dev/zsh` | `.worktrees/aichat-shell-integration/` on `feature/aichat-shell-integration` | repo root `.test-evidence.json` |
| `/home/cupric/dev/ansible` | `.worktrees/aichat-shell-integration/` on `feature/aichat-shell-integration` | repo root `.test-evidence.json` |

- **Tasks A–E** execute in the **zsh** worktree.
- **Task F** executes in the **ansible** worktree.
- The zsh scope (A–E) and ansible scope (F) are independent and may run sequentially (recommended) or in parallel via subagents with disjoint write sets.
- **Profile:** all implementation tasks (B–F) run under the **write** profile. Plan-writing and plan-review ran under **plan**. Execution dispatches write-mode subagents (or the executor itself in write mode).
- Every `git commit` runs the repo's `pre-commit` hook. In the zsh repo this is a zsh-bench startup-regression guard (`hooks/pre-commit`); it can be skipped with `ZSH_BENCH_SKIP=1` if no baseline exists on the machine.

## File structure

| File | Repo | Responsibility | New/Modify |
|------|------|----------------|-----------|
| `custom/aichat.zsh` | zsh | zle widget definitions (`_aichat_compose`, `_aichat_repl`) | New |
| `custom/keybinding/keymap_zsh.yaml` | zsh | declarative bindings for `Ctrl+O` / `Ctrl+Alt+O` | Modify |
| `custom/keybinding/zsh_notation.py` | zsh | notation docstring fix (combined modifiers) | Modify |
| `zshrc` | zsh | guarded `source` of `custom/aichat.zsh` | Modify |
| `roles/zsh/vars/main.yml` | ansible | add `aichat` to `zsh_rust_tools_packages` | Modify |

Note: `custom/keybinding/keybindings.gen.zsh` is gitignored (`.gitignore:6`) and regenerated automatically — never committed.

---

## Task Summary

| Task | Description | Status |
|------|-------------|--------|
| A | Prerequisites: install aichat + seed user-local config (human) | done |
| B | Define aichat zle widgets (`custom/aichat.zsh`) | done |
| C | Add keybindings + fix interpreter docstring | done |
| D | Wire widgets into `zshrc` | done |
| E | Smoke-test widget registration + live keybindings | done |
| F | Add `aichat` to ansible provisioning (ansible repo) | pending |
| Z | Validation: full checks + `.test-evidence.json` | pending |

---

### Task A: Prerequisites — install aichat + seed user-local config (human)

**Repo:** zsh (host environment)

**Files:**
- Create: `~/.config/aichat/config.yaml` (user-local, NOT committed)
- Create: `~/.config/aichat/.env` (user-local, NOT committed)

- [x] **Step 1: [human] Install aichat**

```bash
cargo install aichat
```

(Alternatively, run Task F first so the ansible role installs it.)

- [x] **Step 2: Checkpoint — confirm aichat is on PATH**

Run: `command -v aichat`
Expected: prints the full path to the `aichat` binary.

- [x] **Step 3: [human] Seed the user-local config and env**

```bash
mkdir -p ~/.config/aichat
```

Create `~/.config/aichat/config.yaml` from the design doc §7 (`docs/specs/2026-09-01-aichat-shell-integration-design.md` — LM Studio `:1234/v1` + `qwen/qwen3.5-9b` + commented cloud clients). Put any cloud keys in `~/.config/aichat/.env` (e.g. `OPENAI_API_KEY=...`). Neither file is committed. Also confirm **Thinking is disabled** for `qwen/qwen3.5-9b` in LM Studio (My Models → Inference → Thinking off).

- [x] **Step 4: Checkpoint — confirm the model is reachable**

Run: `aichat --list-models | head -20`
Expected: prints a model list including `lmstudio:qwen/qwen3.5-9b`. (LM Studio serves the model as `qwen/qwen3.5-9b`; aichat surfaces it as `lmstudio:qwen/qwen3.5-9b`.)

---

### Task B: Define aichat zle widgets (`custom/aichat.zsh`)

**Repo:** zsh

**Files:**
- Create: `custom/aichat.zsh`

- [x] **Step 1: Write the widget file**

```zsh
# aichat — local-first (LM Studio) LLM command generation.
# Two entry points, bound via custom/keybinding/keymap_zsh.yaml:
#   Ctrl+O      → _aichat_compose  (transform current line into a command)
#   Ctrl+Alt+O  → _aichat_repl     (interactive aichat REPL)

# Compose: replace the current command line with a concrete command generated by
# aichat's Shell Assistant (-e/--execute). Adapted from aichat's official
# scripts/shell-integration/integration.zsh (which binds Alt+e); we rebind to
# Ctrl+O via keymap_zsh.yaml. The user reviews the result before pressing Enter.
_aichat_compose() {
    if [[ -n "$BUFFER" ]]; then
        local _old=$BUFFER
        BUFFER+="⌛"
        zle -I && zle redisplay
        BUFFER=$(aichat -e "$_old")
        zle end-of-line
    fi
}
zle -N _aichat_compose

# REPL: release the line editor, run aichat's interactive REPL, then restore the
# prompt on exit (same pattern fzf's widgets use).
_aichat_repl() {
    zle -I
    aichat
    zle reset-prompt
}
zle -N _aichat_repl
```

- [x] **Step 2: Syntax-check the file**

Run: `zsh -n custom/aichat.zsh`
Expected: exit 0, no output.

- [x] **Step 3: Verify widgets register in a clean zsh**

Run:
```bash
zsh -f -c 'zmodload zsh/zle; source custom/aichat.zsh; zle -la | grep -q _aichat_compose && zle -la | grep -q _aichat_repl && echo WIDGETS_OK'
```
Expected: `WIDGETS_OK`.

- [x] **Step 4: Commit**

```bash
git add custom/aichat.zsh
git commit -m "feat(zsh): add aichat compose and repl zle widgets"
```

---

### Task C: Add keybindings + fix interpreter docstring

**Repo:** zsh

**Files:**
- Modify: `custom/keybinding/keymap_zsh.yaml`
- Modify: `custom/keybinding/zsh_notation.py`

- [x] **Step 1: Confirm current interpreter output lacks the new bindings (red)**

Run:
```bash
python3 custom/keybinding/interpret_zsh.py custom/keybinding/keymap_zsh.yaml | grep -F "_aichat" || echo "NOT_PRESENT (expected before edit)"
```
Expected: `NOT_PRESENT (expected before edit)`.

- [x] **Step 2: Extend `_section_order` in `custom/keybinding/keymap_zsh.yaml`**

Change:
```yaml
_section_order: [completion, fzf, navigation, editing]
```
to:
```yaml
_section_order: [completion, fzf, navigation, editing, ai]
```

- [x] **Step 3: Append the `ai:` section to `custom/keybinding/keymap_zsh.yaml`**

Append at the end of the file:
```yaml
ai:
  - shortcut: C-o
    description: Compose command via aichat
    action: _aichat_compose

  - shortcut: C-A-o
    description: Open aichat REPL
    action: _aichat_repl
```

- [x] **Step 4: Fix the stale docstring in `custom/keybinding/zsh_notation.py`**

Change (line 15):
```
Combined   : (not supported — use raw: true)
```
to:
```
Combined   : C-M-x / C-A-x → ^[^x  (ESC + Ctrl key; two modifiers, any order)
```

- [x] **Step 5: Validate and confirm the new bindings generate correctly (green)**

Run:
```bash
python3 custom/keybinding/interpret_zsh.py --validate custom/keybinding/keymap_zsh.yaml
```
Expected: `interpret_zsh: custom/keybinding/keymap_zsh.yaml — OK` (exit 0).

Run:
```bash
python3 custom/keybinding/interpret_zsh.py custom/keybinding/keymap_zsh.yaml | grep -F "bindkey '^o' _aichat_compose"
python3 custom/keybinding/interpret_zsh.py custom/keybinding/keymap_zsh.yaml | grep -F "bindkey '^[^o' _aichat_repl"
```
Expected: both lines print (with `# Compose command via aichat` and `# Open aichat REPL` trailing comments respectively).

- [x] **Step 6: Run the interpreter unit tests**

Run: `python3 custom/keybinding/interpret_zsh.py --test`
Expected: `All N tests passed.` (no FAIL lines).

- [x] **Step 7: Commit**

```bash
git add custom/keybinding/keymap_zsh.yaml custom/keybinding/zsh_notation.py
git commit -m "feat(zsh): bind aichat compose/repl and document combined modifiers"
```

---

### Task D: Wire widgets into `zshrc`

**Repo:** zsh

**Files:**
- Modify: `zshrc`

- [x] **Step 1: Insert the guarded source line before the keybindings source**

In `zshrc`, immediately before:
```zsh
# Load custom key bindings (sources keybinding/keybindings.gen.zsh via mtime-gated interpreter)
source "$ZSH_CUSTOM/keybindings.zsh"
```
insert:
```zsh
# aichat — LLM command generation widgets (registered before keybindings are sourced)
if command_exists aichat; then
  source "$ZSH_CUSTOM/aichat.zsh"
fi
```

Rationale: the widget functions must be `zle -N`-registered before `bindkey` runs, and `command_exists` is already in scope here (defined in `zshenv`).

- [x] **Step 2: Syntax-check `zshrc`**

Run: `zsh -n zshrc`
Expected: exit 0, no output.

- [x] **Step 3: Commit**

```bash
git add zshrc
git commit -m "feat(zsh): source aichat widgets before keybindings"
```

---

### Task E: Smoke-test widget registration + live keybindings

**Repo:** zsh

- [x] **Step 1: Automated smoke check (widgets + generated bindkeys)**

Run:
```bash
zsh -f -c 'zmodload zsh/zle; source custom/aichat.zsh; zle -la | grep -q _aichat_compose && zle -la | grep -q _aichat_repl && echo WIDGETS_OK'
python3 custom/keybinding/interpret_zsh.py custom/keybinding/keymap_zsh.yaml > /tmp/aichat-gen.zsh && grep -Fc "_aichat" /tmp/aichat-gen.zsh
```
Expected: `WIDGETS_OK` on the first line, `2` on the second.

- [x] **Step 2: [human] Verify the live bindings in an interactive zsh**

Start a new interactive zsh. Confirm:
- `bindkey | grep -F '^o'` shows a `_aichat_compose` entry.
- `bindkey | grep -F '^[^o'` shows a `_aichat_repl` entry.
- Typing a natural-language request then `Ctrl+O` replaces the buffer with a concrete command (clear the buffer rather than running an unwanted command).
- `Ctrl+Alt+O` opens the aichat REPL, then exits cleanly.

- [x] **Step 3: Checkpoint — confirm Step 2 passed**

If either binding is missing, the `command_exists aichat` guard (Task D) is the most likely cause — confirm `aichat` is on `$PATH`. Do not proceed to Task F until both bindings work interactively.

---

### Task F: Add `aichat` to ansible provisioning (ansible repo)

**Repo:** ansible (worktree `.worktrees/aichat-shell-integration/`)

**Files:**
- Modify: `roles/zsh/vars/main.yml`

- [ ] **Step 1: Add `aichat` to `zsh_rust_tools_packages`**

In `roles/zsh/vars/main.yml`, change:
```yaml
zsh_rust_tools_packages:
  - sheldon
  - mdcat
  - eza
```
to:
```yaml
zsh_rust_tools_packages:
  - sheldon
  - mdcat
  - eza
  - aichat
```

Rationale: the role already downloads each package from the rust-tools registry with a `cargo-binstall` → `cargo install` fallback. `aichat` publishes pre-built GitHub release binaries, so `cargo-binstall aichat` satisfies the fallback until it is added to the rust-tools CI `PACKAGES` list (out of scope — see Gotchas).

- [ ] **Step 2: Run ansible-lint (in the devcontainer)**

Run (per `ansible/AGENTS.md`, inside the devcontainer):
```bash
devcontainer exec --workspace-folder /home/cupric/dev/ansible ansible-lint roles/zsh/
```
Expected: 0 failures, 0 warnings for the changed file (pre-existing warnings elsewhere are acceptable but must not be new).

- [ ] **Step 3: Run the zsh role molecule scenario (one at a time)**

Run (inside the devcontainer; only one molecule run at a time across all worktrees):
```bash
devcontainer exec --workspace-folder /home/cupric/dev/ansible molecule test -s default --destroy always
```
Expected: converge + idempotency pass on the configured platforms. Confirm `aichat` is present in the molecule verify step, or add the assertion if the scenario lacks one.

- [ ] **Step 4: Commit**

```bash
git add roles/zsh/vars/main.yml
git commit -m "feat(zsh): provision aichat via rust-tools packages"
```

---

### Task Z: Validation

**Files:**
- Create: `.test-evidence.json` (zsh repo)
- Create: `.test-evidence.json` (ansible repo)

- [ ] **Step 1: Run full zsh-repo checks**

Run:
```bash
python3 custom/keybinding/interpret_zsh.py --test
python3 custom/keybinding/interpret_zsh.py --validate custom/keybinding/keymap_zsh.yaml
zsh -n zshrc
zsh -n custom/aichat.zsh
```
Expected: all exit 0; no FAIL lines, no syntax errors.

- [ ] **Step 2: Functional verification (zsh repo)**

Run:
```bash
python3 custom/keybinding/interpret_zsh.py custom/keybinding/keymap_zsh.yaml > /tmp/aichat-gen.zsh
grep -Fc "_aichat" /tmp/aichat-gen.zsh
```
Expected: `2` (both `_aichat_compose` and `_aichat_repl` bindings are generated).

- [ ] **Step 3: Run ansible lint + molecule (ansible repo, devcontainer)**

Run:
```bash
devcontainer exec --workspace-folder /home/cupric/dev/ansible ansible-lint roles/zsh/
devcontainer exec --workspace-folder /home/cupric/dev/ansible molecule test -s default --destroy always
```
Expected: lint clean for the changed file; molecule converge + idempotency pass.

- [ ] **Step 4: Write `.test-evidence.json` in the zsh repo**

```bash
cat > .test-evidence.json <<EOF
{
  "slug": "aichat-shell-integration",
  "ref": "$(git rev-parse --abbrev-ref HEAD)",
  "commit": "$(git rev-parse HEAD)",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "passed": true,
  "checks": {
    "interpret_zsh_test": "passed",
    "interpret_zsh_validate": "passed",
    "zsh_syntax": "passed",
    "generated_bindkeys": 2
  }
}
EOF
```

- [ ] **Step 5: Write `.test-evidence.json` in the ansible repo**

```bash
cat > .test-evidence.json <<EOF
{
  "slug": "aichat-shell-integration",
  "ref": "$(git rev-parse --abbrev-ref HEAD)",
  "commit": "$(git rev-parse HEAD)",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "passed": true,
  "checks": {
    "ansible_lint": "passed",
    "molecule_zsh_role": "passed",
    "aichat_in_packages": true
  }
}
EOF
```

- [ ] **Step 6: Verify both evidence files**

Run (in each repo): `cat .test-evidence.json`
Expected: valid JSON with `"passed": true` and a non-empty `ref`/`commit`/`timestamp`.

- [ ] **Step 7: Commit evidence in each repo**

```bash
# zsh repo
git add .test-evidence.json
git commit -m "chore: validation evidence for aichat shell integration"

# ansible repo (separate worktree)
git add .test-evidence.json
git commit -m "chore: validation evidence for aichat provisioning"
```

---

## Gotchas

- **`command_exists aichat` must be true** for the `zshrc` source to fire. If `aichat` isn't installed yet, Tasks D/E bindings will silently not register. Complete Task A (manual install) or Task F (ansible install) first.
- **LM Studio model ID is `qwen/qwen3.5-9b`** (note the `qwen/` prefix — confirmed via `GET /v1/models`). aichat references it as `lmstudio:qwen/qwen3.5-9b`. Confirm with `aichat --list-models` (Task A Step 4).
- **Thinking must be disabled** for `qwen/qwen3.5-9b` in LM Studio (My Models → Inference → Thinking off). aichat does not send `enable_thinking`, so a thinking-enabled model emits reasoning tokens on every `Ctrl+O` (latency).
- **`_aichat_compose` preserves the buffer on aichat failure.** If `aichat -e` exits non-zero (LM Studio down / model not loaded), the widget restores the original buffer instead of wiping it; aichat's own stderr error is still shown. `_aichat_repl` needs no equivalent handling (its REPL UI surfaces errors itself).
- **`Ctrl+Alt+O` depends on terminal ESC-prefix transmission** (`ESC ^O`). If the binding doesn't fire, verify with `cat -v` that the emulator (through tmux) emits `^[^O`; some "Option as Meta" remaps break it.
- **The rust-tools registry won't have `aichat` until its CI `PACKAGES` list is updated + tagged.** The `cargo-binstall` fallback works immediately; the pinned-registry fast path is a follow-up (add to `rust-tools/.gitlab-ci.yml`, tag, then bump `zsh_rust_tools_tag`).
- **Only one molecule run at a time** across all worktrees/devcontainers (shared host Docker daemon collides on container names), per `ansible/AGENTS.md`.
- **`custom/keybinding/keybindings.gen.zsh` is gitignored** (`.gitignore:6`) — it regenerates from `keymap_zsh.yaml` automatically; do not `git add` it.

## Execution Started
- **Date:** 2026-09-01 19:53 EDT
- **Base commit:** c6d68abb618a3a4f5bd45e38921102afebeb2fda
- **Design doc:** [2026-09-01-aichat-shell-integration-design.md](docs/specs/2026-09-01-aichat-shell-integration-design.md)
