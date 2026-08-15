# Carapace Completion Integration — Implementation Plan

> **Required sub-skills:** subagent-driven-development

**Goal:** Integrate carapace as the primary zsh completion engine using cached
init-script generation, preserving fzf-tab UI and zsh-completions fallback.

**Architecture:** Carapace's Go binary generates zsh completion functions once
into `$ZSH_CACHE_DIR/carapace-init.zsh`, regenerated only when the binary
updates. Background pre-warming populates carapace's spec cache each session.
`CARAPACE_BRIDGES='zsh'` falls through to native for uncovered commands. zsh
`use-cache` handles expensive dynamic subprocess results.

**Tech Stack:** carapace-bin (Go) → cached init script → compinit → `.zcompdump`
bytecode + zsh use-cache + fzf-tab UI.

---

## Task Overview

| Task | Component | Files | Deps |
|------|-----------|-------|------|
| A | `use-cache` zstyle | `zshrc` | none |
| B | Carapace integration | `zshrc:245-257` | A |
| C | Migration 003 | `migrations/003_carapace_init.zsh` | B |
| D | Ansible delegation [GATED] | `roles/zsh/tasks/main.yml` | B |
| E | Performance validation | CLI | B, C |
| F | Integration testing | CLI | B, C, D |
| Z | Final verification | CLI | all |

---

### Task A: Add `use-cache` zstyle to zshrc

**Files:** Modify `zshrc:289` (after matcher-list zstyle, before git-checkout sort)

Add zsh's built-in completion result cache for expensive subprocess output.

- [ ] **Step 1: Insert use-cache zstyle**

After line 289 (`zstyle ':completion:*' matcher-list ...`), insert:

```zsh
# ==== Completion Result Caching ====
# Cache expensive subprocess results (apt list, ps, kubectl, git, etc.)
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${ZSH_CACHE_DIR}/completion"
```

- [ ] **Step 2: Commit**

```bash
git add zshrc
git commit -m "feat(completion): enable zsh use-cache for tab result caching"
```

---

### Task B: Carapace Integration in zshrc

**Files:** Modify `zshrc:245-257`

Replace the "Additional tool-specific completions" block (lines 245-257: from
`# Additional tool-specific completions` through `_tailscale` comment).

- [ ] **Step 1: Replace old completion block**

Delete lines 245-257 and insert:

```zsh
# ================================================
# Carapace — multi-shell completion engine
# ================================================
# Generates zsh completion functions from declarative YAML specs (1600+ commands).
# Init script is cached; regenerated only when the carapace binary updates.
# Pre-warms carapace's spec cache in background each session.
# CARAPACE_BRIDGES enables fallback to native zsh for uncovered commands.

if command_exists carapace; then
  _carapace_init="${ZSH_CACHE_DIR}/carapace-init.zsh"

  # Generate cached init script on first run or after carapace update
  if [[ ! -f "$_carapace_init" ]] || [[ "$_carapace_init" -ot "${commands[carapace]}" ]]; then
    log info "Generating carapace completions (one-time)..."
    carapace _carapace > "$_carapace_init"
  fi
  source "$_carapace_init"

  # Pre-warm carapace spec cache in background (populates ~/.cache/carapace/)
  (carapace --list 2>/dev/null | while read -r _carapace_cmd; do
    carapace "$_carapace_cmd" '' &>/dev/null
  done) &!
  unset _carapace_init

  # Fall back to native zsh completions for commands carapace doesn't cover
  export CARAPACE_BRIDGES='zsh'
fi

# ================================================
# Custom completion files
# ================================================
# $ZCOMPLETION is in $FPATH (set in zshenv). compinit auto-discovers _files.
# Carapace handles most tools; hand-authored _files kept for outliers
# (cursor-agent, audio_split-tag, rbw, sheldon).
```

- [ ] **Step 2: Commit**

```bash
git add zshrc
git commit -m "feat(completion): add carapace with cached init and bridge fallback"
```

---

### Task C: Migration 003 — First-Run Carapace Init

**Files:** Create `migrations/003_carapace_init.zsh`

Pre-generate the init script during first-run preflight-checks (not on first
interactive shell start). No-op if carapace isn't installed yet.

- [ ] **Step 1: Create migration**

```zsh
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
```

- [ ] **Step 2: Commit**

```bash
git add migrations/003_carapace_init.zsh
git commit -m "feat(migration): pre-generate carapace init on first run"
```

---

### Task D: Ansible Delegation — Go Package + Config Dirs [GATED]

> **Delegation only.** Dispatch an ansible agent with the handover at
> `docs/handover/2026-08-05/ansible-carapace-install.md`. Do NOT modify
> ansible files yourself. Task B must be committed before dispatch.

**Files the ansible agent modifies:**
- `roles/zsh/tasks/main.yml` — add `go install` + config dir tasks after osc

**What the agent does:**
1. Installs `carapace` via `go install` to `/usr/local/go-packages/bin/` (same pattern as `osc`)
2. Creates `~/.config/carapace/{specs,overlays,variables}/` for target user

- [ ] **Step 1: Verify handover exists**

```bash
ls docs/handover/2026-08-05/ansible-carapace-install.md
```

- [ ] **Step 2: Dispatch ansible sub-agent with handover**

Session label: `ansible-carapace-install`

- [ ] **Step 3: Gate check — verify ansible agent completed**

- [ ] `go install` task added to `roles/zsh/tasks/main.yml`
- [ ] Config directory creation task added
- [ ] Task idempotency verified (second run = no change)

---

### Task E: Performance Validation

**Files:** None (CLI only)

- [ ] **Step 1: Baseline startup time**

```bash
for i in 1 2 3; do time zsh -i -c exit; done
```

Record the average. Expected: varies by machine.

- [ ] **Step 2: Apply changes (Tasks A-C) and restart shell**

```bash
exec zsh
```

- [ ] **Step 3: Post-carapace startup time**

```bash
for i in 1 2 3; do time zsh -i -c exit; done
```

Expected: within 10ms of baseline. Cached init file is cheap to source.

- [ ] **Step 4: Verify cache artifacts exist**

```bash
ls -la ~/.cache/zsh/carapace-init.zsh
ls ~/.cache/carapace/ 2>/dev/null && echo "spec cache present"
ls ~/.cache/zsh/completion/ 2>/dev/null && echo "use-cache dir present"
```

- [ ] **Step 5: Tab latency — measure actual numbers**

Tab-complete: `tailscale`, `docker`, `kubectl`, `git checkout`.
Record first-tab and second-tab latency for each. Expected: first tab
20-200ms (spec-dependent), subsequent tabs <20ms. Don't pre-state values
in results — record what you actually measure.

- [ ] **Step 6: Record results**

Update this section with measured numbers.

---

### Task F: Integration Testing

**Files:** None (CLI manual testing)

- [ ] **Step 1: Carapace completions**

```bash
tailscale <TAB>     # subcommands: up, down, status, ssh, ping
docker <TAB>        # subcommands: run, build, ps, images
git checkout <TAB>  # branches (dynamic, use-cache)
kubectl <TAB>       # subcommands
```

- [ ] **Step 2: Bridge fallback**

```bash
osc <TAB>           # zsh native _osc
sheldon <TAB>       # zsh native _sheldon
cursor-agent <TAB>  # custom _cursor-agent from $ZCOMPLETION
rbw <TAB>           # custom _rbw from $ZCOMPLETION
```

- [ ] **Step 3: mcpd-tool (Typer-based Python CLI)**

```bash
mcpd-tool <TAB>
```

Check if carapace's bridge system extracts Typer completions. If it doesn't
produce results, a spec file in `~/.config/carapace/specs/mcpd-tool.yaml` is
the fallback.

- [ ] **Step 4: fzf-tab previews still work**

```bash
git checkout <TAB>  # should show git diff/delta preview
cd <TAB>            # should show eza directory preview
kill <TAB>          # should show process preview
```

- [ ] **Step 5: No duplicate group headers**

Check if carapace's format string clashes with fzf-tab's group display.
Detection: look for doubled headers like `[commands] [commands]` or
`[Completing commands]` appearing twice in the completion menu.
If double headers appear, add to the completion zstyle block in zshrc:

```zsh
zstyle ':completion:*:carapace:*' format ''
```

- [ ] **Step 6: Document issues**

Note any tool with degraded completions. Fix via overlay or spec disable.

---

### Task Z: Final Verification

**Files:** None

- [ ] **Step 1: Shellcheck migrations**

```bash
shellcheck migrations/003_carapace_init.zsh
```

- [ ] **Step 2: zshrc syntax**

```bash
zsh -n zshrc
```

- [ ] **Step 3: Migration numbering**

```bash
ls migrations/[0-9]*.zsh
# Expected: 001, 002, 003
```

- [ ] **Step 4: Full smoke test**

First, ensure migrations have run (via `source $ZSCRIPTS/run-migrations` or `zgu`)
then:

```bash
exec zsh
echo $CARAPACE_BRIDGES      # Expected: zsh
tailscale <TAB>              # Should show completions
cat ~/.cache/zsh/.migration_version  # Should be 3 or higher
```

- [ ] **Step 5: Write `.test-evidence.json`**

```json
{
  "plan": "2026-08-04-carapace-completions",
  "completed_at": "<ISO timestamp>",
  "tests": {
    "shellcheck_003": "pass",
    "zshrc_syntax": "pass",
    "migration_numbering": "pass",
    "startup_no_errors": "pass",
    "carapace_bridge_env": "pass",
    "tailscale_completion": "pass",
    "docker_completion": "pass",
    "fzf_tab_previews": "pass",
    "bridge_fallback_osc": "pass",
    "bridge_fallback_sheldon": "pass",
    "mcpd_tool_completion": "pass"
  }
}
```

---

## Task Summary

| Task | Status |
|------|--------|
| A: `use-cache` zstyle | [ ] |
| B: Carapace integration | [ ] |
| C: Migration 003 | [ ] |
| D: Ansible delegation [GATED] | [ ] |
| E: Performance validation | [ ] |
| F: Integration testing | [ ] |
| Z: Final verification | [ ] |

---

## Configuration Reference

| Path | Purpose |
|------|---------|
| `$ZSH_CACHE_DIR/carapace-init.zsh` | Cached carapace completion functions |
| `$ZSH_CACHE_DIR/completion/` | zsh use-cache (dynamic results) |
| `~/.cache/carapace/` | Carapace spec cache (automatic) |
| `~/.config/carapace/specs/` | Custom carapace specs |
| `~/.config/carapace/overlays/` | Override built-in carapace completers |
| `/usr/local/go-packages/bin/carapace` | System-wide binary (Go install) |
| `$ZCOMPLETION/` | Hand-authored `_` files (bridge fallback) |

## Gotchas

1. **First shell start after install.** If carapace is installed but init cache
   doesn't exist, zshrc generates it synchronously (~500ms-2s). Migration 003
   front-loads this to preflight-check.

2. **Carapace quality varies per tool.** Check docker, tailscale, kubectl, git
   completions. Degraded tools can be fixed via overlay or spec.

3. **Pre-warming runs every session.** ~1-3s background CPU for all 1600+
   commands. Add a session-once flag if this is problematic.

4. **fzf-tab header clash.** Carapace's format string may produce double
   headers. Fix: `zstyle ':completion:*:carapace:*' format ''`.

5. **Existing `_` files are NOT removed.** `_tailscale`, `_docker`, and other
   `$ZCOMPLETION` files remain as fallbacks. Carapace takes priority via
   loading order; native completions activate via `CARAPACE_BRIDGES='zsh'`
   for commands carapace doesn't cover.
