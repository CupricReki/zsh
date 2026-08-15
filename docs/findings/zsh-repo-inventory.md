**Status:** Active

# Zsh Dotfiles Repo — Deep Inventory Findings

**Date range:** 2026-07-10  
**Context:** Four sub-agents analyzed `/home/cupric/dev/zsh` for optimization, plugin replacement, general improvements, and feature recommendations. This document consolidates all findings into a single ranked inventory.

---

## Executive Summary

The zsh dotfiles repo is already **well-optimized** — first prompt lag of ~32ms, first command lag of ~165ms, sheldon with zsh-defer lazy loading, p10k instant prompt, and smart completion caching. The optimization analysis found few performance issues beyond fine-tuning. However, the inventory surfaced **significant structural debt** around stale dependencies, oh-my-zsh monorepo overhead, and missing modern tooling that provides 10× QoL improvements for daily workflow.

### Top 5 Highest-Impact Recommendations

| Rank | Recommendation | Benefit | Effort | Category |
|------|---------------|---------|--------|----------|
| 1 | Replace `k` and `enhancd` with eza aliases + zoxide | **10/10** | 15 min | Replace abandoned deps |
| 2 | Add `zsh-abbr` for fish-style inline abbreviations | **9/10** | 10 min | New QoL feature |
| 3 | Add `glab`, `gh`, `delta` completions | **9/10** | 5 min | Zero-cost completions |
| 4 | Drop ohmyzsh as a dependency (inline the 7 plugins) | **8/10** | 1 hour | Architecture cleanup |
| 5 | Add `forgit` + `navi` for interactive git and cheatsheets | **8/10** | 15 min | New QoL feature |

### By the Numbers

- **58 MB** of dead antibody cache to delete (instant win)
- **26 MB** of ohmyzsh monorepo cloned for ~37 KB of actual plugin code
- **16 plugins** → **10–12 plugins** after cleanup; **8 ohmyzsh plugins** → **0–1**
- **4 keybindings** managed by a 550-line Python YAML interpreter (worth auditing)
- **~12–30ms** of achievable startup savings from quick wins
- **0 abandoned dependencies** after cleanup (currently: 1 dead, 1 stale)

---

## Findings by Category

### 🔴 Category A: Replace Abandoned / Stale Dependencies

These are immediate action items — dead or dying plugins that have clear modern replacements.

| # | Finding | Benefit | Effort | Detail |
|---|---------|---------|--------|--------|
| A1 | **Replace `supercrabtree/k` with eza aliases** | **10/10** | Low | Abandoned since 2018. eza is already installed and configured in your enhancd/FZF previews. Replace 591 lines of dead shell code with 4 eza aliases. ✅ Fact |
| A2 | **Replace `enhancd` with zoxide** | **10/10** | Low | enhancd is shell-script (~2400 lines), zoxide is Rust binary. Installed via `pacman -S zoxide`. Drop-in replacement with cleaner syntax. ✅ Fact |
| A3 | **Drop `zsh-ssh` — fzf-tab covers SSH completions** | **7/10** | Trivial | Zsh 5.9+ has built-in `_ssh` completion. fzf-tab already provides fzf-powered completion for all commands including ssh. The 290-line plugin is redundant. ✅ Fact |

### 🟠 Category B: Eliminate Oh-My-Zsh Monorepo Dependency

Loading individual files from ohmyzsh means cloning a 26 MB monorepo for ~37 KB of actual plugin code. Each plugin can be replaced with a 3–30 line inline alternative.

| # | Finding | Benefit | Effort | Detail |
|---|---------|---------|--------|--------|
| B1 | **Replace `command-not-found` with native `pkgfile`** | **9/10** | Low | On Arch, `pkgfile` is the native solution. Replace 74-line OMZ abstraction with `source /usr/share/doc/pkgfile/command-not-found.zsh`. ✅ Fact |
| B2 | **Replace `colored-man-pages` with inline function** | **8/10** | Trivial | 54-line OMZ plugin → 6-line `LESS_TERMCAP_*` exports in a `man()` wrapper. ✅ Fact |
| B3 | **Replace `sudo` plugin with inline keybinding** | **8/10** | Trivial | 108-line OMZ plugin → 5-line zle widget. The ESC-ESC or Ctrl+S prepend-sudo behavior is trivially inlined. ✅ Fact |
| B4 | **Replace `extract` with inline function** | **7/10** | Low | 137-line OMZ plugin → inline function. Your `function/tarz` already handles tar.xz/gz. Add remaining formats. ✅ Fact |
| B5 | **Replace `pip` plugin with `noglob` alias** | **7/10** | Trivial | One alias: `alias pip='noglob pip'`. The OMZ plugin adds very little beyond this. ✅ Fact |
| B6 | **Replace `vi-mode` plugin — evaluate migration to `jeffreytse/zsh-vi-mode`** | **6/10** | Medium | Your zshrc already has extensive manual vi-mode configuration. Either: (a) drop OMZ plugin + keep manual config, or (b) migrate to the dedicated `zsh-vi-mode` plugin (4k+ stars, actively maintained). ⚠️ Migration conflicts with existing keybindings |
| B7 | **Replace `git` plugin with cherry-picked aliases** | **5/10** | High | 445-line OMZ plugin with 150+ aliases. Audit your actual usage first (`history | grep ...`). Your `alias.zsh` already duplicates many. High effort due to muscle memory impact. ⚠️ |

### 🟡 Category C: Startup Performance Optimizations

Your startup is already fast. These squeeze out additional milliseconds with minimal effort.

| # | Finding | Benefit | Effort | Detail |
|---|---------|---------|--------|--------|
| C1 | **Cache `sheldon source` output** | **7/10** | Low | Every shell start forks `sheldon source`. Cache its output to a file, invalidate when `plugins.lock` is newer. Saves ~5–10ms. ✅ Fact |
| C2 | **Add preflight fast-path guard** | **6/10** | Low | The 284-line preflight check runs on every shell. Add a guard at the top: if all known tools exist, skip. Or `zsh-defer` it entirely. Saves ~5–15ms. ✅ Fact |
| C3 | **Fix compinit cache hours mismatch** | **6/10** | Low | `COMP_CACHE_HOURS=24` is a typeset variable, but the glob uses hardcoded `mh-24`. Changing the variable breaks the cache logic. Use `Nmh+${COMP_CACHE_HOURS}`. 🐛 Bug |
| C4 | **zcompile fzf config files** | **4/10** | Low | Three fzf files (532 lines total) are sourced uncompiled. Byte-compile them like the keybinding file. Saves ~2–5ms. ✅ Fact |
| C5 | **Delete dead antibody cache (~58 MB)** | **4/10** | Trivial | `~/.cache/zsh/antibody/` (30 MB) + `zsh/.cache/antibody/` (28 MB, inside the dotfiles repo!). Migration 001 completed; cleanup was missed. Disk savings, not runtime. ✅ Fact |
| C6 | **Remove `export` from FPATH** | **3/10** | Trivial | `export FPATH=...` in zshenv serves no purpose — FPATH is zsh-internal. Remove `export`. ✅ Fact |
| C7 | **Move ROCm PATH to zshenv array style** | **3/10** | Trivial | `PATH=$PATH:/opt/rocm/bin` in zshrc uses scalar append (inconsistent with zshenv's `path=(...)` array style). Move to zshenv's conditional path block. ✅ Fact |

### 🟢 Category D: Missing Completions (Zero Runtime Cost)

These are one-liner additions with zero startup overhead — just add completion files.

| # | Finding | Benefit | Effort | Detail |
|---|---------|---------|--------|--------|
| D1 | **`glab` (GitLab CLI) completions** | **9/10** | Trivial | You use GitLab for everything. `pacman -S glab` + add `_glab` to `$ZCOMPLETION`. |
| D2 | **`gh` (GitHub CLI) completions** | **8/10** | Trivial | Most OSS tooling lives on GitHub. Even if GitLab is primary. |
| D3 | **`delta` completions** | **7/10** | Trivial | You already use delta in fzf-tab git previews. Add completions. |
| D4 | **`just` completions** | **7/10** | Trivial | `just --completions zsh > $ZCOMPLETION/_just` |
| D5 | **`uv`/`uvx` completions** | **7/10** | Trivial | Fast Python package manager. `uv --generate-shell-completion zsh` |
| D6 | **`terraform` completions** | **7/10** | Trivial | p10k already has terraform workspace segments. `terraform -install-autocomplete` |
| D7 | **`helm` completions** | **6/10** | Trivial | If you use Kubernetes alongside Proxmox/Netbox. `helm completion zsh` |
| D8 | **`krew` completions** | **5/10** | Low | If you use kubectl plugin manager. |

### 🔵 Category E: New QoL Features & Plugins

These transform daily workflow but may add minor startup overhead (mitigated by zsh-defer).

| # | Finding | Benefit | Effort | Detail |
|---|---------|---------|--------|--------|
| E1 | **`zsh-abbr` (olets/zsh-abbr)** — Fish-style abbreviations | **9/10** | Low | Aliases expand only at command start; abbreviations expand inline as you type. Type `gst`+Space → `git status`. Complements aliases, doesn't replace them. ~5ms if deferred. ❓ Hypothesis (needs personal trial) |
| E2 | **`forgit` (wfxr/forgit)** — Interactive git with fzf | **8/10** | Low | Given heavy fzf investment, forgit is natural: `ga` becomes interactive staging, `glo` becomes interactive log browser. ~5ms if deferred. ✅ Fact |
| E3 | **`navi` + cheatsheets** — Interactive cheatsheet browser | **8/10** | Low | fzf-powered cheatsheet tool. Can write custom sheets for Ansible patterns, Proxmox commands, Zabbix operations. `pacman -S navi` (AUR) or `cargo install navi`. ❓ Hypothesis |
| E4 | **Git worktree aliases + p10k indicator** | **8/10** | Low | No worktree support currently. Given infrastructure work (ansible, proxmox, zabbix), worktrees enable parallel branch work. Add aliases + p10k custom segment. ✅ Fact |
| E5 | **Tailscale aliases** | **7/10** | Low | You already have `_tailscale` completions. Add `ts`, `tss`, `tsu`, `tsd` aliases. p10k already has tailscale in `VPN_IP_INTERFACE`. |
| E6 | **Ansible-vault fzf helper** | **7/10** | Low | Small function wrapping `ansible-vault` with fzf for file selection. Leverages existing ansible infrastructure. |
| E7 | **`atuin`** — Synced shell history | **7/10** | Medium | SQLite-backed history with cross-machine sync. Beautiful TUI. ~15ms startup (mitigated by daemon mode). Higher value if you work across multiple machines. ❓ Hypothesis (evaluate overhead) |
| E8 | **`thefuck`** — Auto-correct commands | **6/10** | Low | Type `fuck` after a failed command → suggests the fix. Low overhead, surprisingly useful. |

### ⚪ Category F: Code Quality & Architecture

Structural improvements for maintainability. Lower urgency but improve long-term health.

| # | Finding | Benefit | Effort | Detail |
|---|---------|---------|--------|--------|
| F1 | **Fix stale `.zlogin`** | **8/10** | Low | References pre-XDG paths (`$HOME/.zsh/zlogin_local/*`) that don't exist. Either delete or update to use `$ZSH_DIR`. Currently dead code that silently fails. 🐛 |
| F2 | **Fix `curl \| bash` aliases lack verification** | **7/10** | Low | `di` and `zgi` aliases pipe curl directly to bash from GitLab. Add at minimum a confirmation prompt or checksum validation. 🔒 Security |
| F3 | **Fix `eval "$(direnv hook zsh)"` error handling** | **5/10** | Low | Unlike the sheldon eval pattern, direnv hook isn't error-checked. Mirror the sheldon pattern. 🐛 |
| F4 | **Document `.zlogin` purpose or remove** | **5/10** | Low | No comment explaining whether it's kept for backwards compat or forgotten. Add a comment or delete. |
| F5 | **Audit keybinding YAML interpreter complexity** | **5/10** | Medium | 550 lines of Python + YAML config for 4 keybindings. If there's a cross-shell cheatsheet ecosystem using this YAML, keep it. If not, 4 `bindkey` lines in zshrc is simpler. ⚠️ Needs user decision |
| F6 | **Add missing script documentation** | **4/10** | Medium | Several scripts lack usage headers. `run-ansible`, `zsh-update_completions`, `set_acl-media`, `zfs-snapshot-cleanup`, `zrepl_watch` would benefit from docs matching `preflight-check`'s quality. |
| F7 | **Fix `fzf-preview.sh` bash-isms** | **4/10** | Low | Uses `${BASH_REMATCH}` — fine as standalone bash script but fragile if ever sourced in zsh context. Low risk but worth noting. |
| F8 | **Fix `ec()` dead bash branch in fzf_functions.zsh** | **3/10** | Low | Polyglot function with bash branch that never executes (file is zsh-only). Remove dead code. |
| F9 | **Guard PATH setup against re-sourcing** | **3/10** | Low | `typeset -U path` deduplicates but base entries get pushed back on re-source. Idempotency guard recommended. |

---

## Failed Approaches

*None applicable — this is an inventory of an existing system, not a debugging session.*

---

## Key Discoveries

1. **Sheldon lazy loading already gives ~80% of zinit's benefit** with ~20% of the complexity. Migrating to zinit is not currently worth the effort. ✅ Fact

2. **The p10k → starship migration is low-value right now.** starship 1.16.0 is already installed, but p10k is deeply integrated (custom `p10k.zsh` config, instant prompt). Unless you need cross-shell prompt consistency (bash/fish), keep p10k. ✅ Fact

3. **Oh-my-zsh's performance cost is disk space, not runtime.** Sheldon sources individual files from the monorepo — startup is unaffected. The win from eliminating ohmyzsh is: faster updates, fewer external dependencies, and you own all the code. ✅ Fact

4. **The keybinding YAML interpreter is over-engineered for 4 bindings** but may serve a cross-shell cheatsheet ecosystem. Needs user decision on whether to keep. ⚠️ Needs investigation

5. **Your preflight-check is well-designed** but blocks before the p10k instant prompt, creating a poor UX for first-run auto-fix scenarios. Deferring it via zsh-defer would improve the experience. ✅ Fact

6. **The `log()` function duplication** between `zshenv` (zsh colors module) and `init.sh` (raw ANSI) is a legitimate separation for different shells, not a real DRY violation. Worth documenting the dual existence. ✅ Fact

---

## Open Questions

- ❓ Does the YAML keybinding interpreter serve a wider cross-shell ecosystem (e.g., generating cheatsheets for other tools), or is it purely for zsh? If the latter, should it be simplified to inline `bindkey` lines?
- ❓ Would `atuin` history sync be valuable across multiple machines, or is single-machine history sufficient?
- ❓ How many of the 150+ ohmyzsh git aliases do you actually use? (Answer by running `history | grep -oP '^\s*\d+\s+\K(g\w+|git\s+\w+)' | sort | uniq -c | sort -rn | head -20`)
- ❓ Are there plans to add more keybindings that would justify the Python YAML interpreter, or is 4 the steady state?

---

## Next Steps

### Phase 1 — Immediate (0–30 min, zero risk)

1. Delete dead antibody cache: `rm -rf ~/.cache/zsh/antibody/ /home/cupric/dev/zsh/.cache/antibody/`
2. Remove `export` from FPATH in zshenv
3. Add completions: glab, gh, delta, just, uv, terraform, helm
4. Add eza aliases and drop `k` plugin
5. Install zoxide and drop enhancd

### Phase 2 — Short-term (30 min–2 hours)

6. Inline ohmyzsh plugins: command-not-found → pkgfile, colored-man-pages, sudo, pip, extract
7. Cache sheldon source output
8. Add preflight fast-path guard or defer it
9. Fix compinit cache hours mismatch
10. Add zsh-abbr and forgit to sheldon
11. Add git-worktree aliases and tailscale aliases

### Phase 3 — Evaluate (requires user decisions)

12. Audit git plugin alias usage → decide whether to inline
13. Decide on zsh-vi-mode migration vs keeping manual config
14. Evaluate keybinding interpreter simplification
15. Try navi, atuin, thefuck — keep what sticks
16. Fix `.zlogin` stale paths
17. Fix `curl | bash` alias security

### Phase 4 — Long-term maintenance

18. Document scripts lacking usage headers
19. Add idempotency guard for PATH setup
20. Consider p10k → starship if cross-shell consistency becomes important
21. Periodically audit sheldon plugins for staleness
