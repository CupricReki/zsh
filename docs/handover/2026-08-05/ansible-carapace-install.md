> ⚠️ **STALE** — This document was current as of 2026-08-05 00:10 EDT.

# Add carapace-bin to zsh-role Go packages — Handover (2026-08-05 00:10 EDT)

## Context

- **Branch:** `main` (work will happen in `feature/carapace-completions`)
- **Commit:** current HEAD after plan commit
- **Repo:** `cupric/zsh` (zsh dotfiles) + `cupric/ansible` (ansible deployment)
- **Related:** See plan at `docs/plans/2026-08-04-carapace-completions.md`

## What Was Done

- Plan drafted for complete carapace integration (see plan doc)
- zshrc changes designed: cached init script, `use-cache` zstyle, `CARAPACE_BRIDGES`
- Migration 003 spec'd to pre-generate init on first run
- **Only the zsh-side work has been planned. Ansible changes are delegated to you.**

## Remaining

| # | Item | Notes |
|---|------|-------|
| 1 | Add `go install` task for carapace-bin | After osc install in `roles/zsh/tasks/main.yml` |
| 2 | Add config directory creation task | `~/.config/carapace/{specs,overlays,variables}/` |
| 3 | Optional: add comment in vars/main.yml | Note carapace alongside osc in Go notes |
| 4 | Test idempotency | Second playbook run should show no changes |
| 5 | Verify binary + directories on target host | `which carapace`, `ls ~/.config/carapace/` |

## Key Gotchas

1. **Same pattern as osc.** Carapace follows the exact same `go install` pattern
   as the existing `osc` task. Install location: `/usr/local/go-packages/bin/`.
   The GOPATH, GOBIN, GOCACHE, and HOME env vars must match osc's task exactly.

2. **No idempotency guard needed.** The `changed_when: true` is intentional —
   carapace runs `go install ...@latest` which picks up the latest version.
   There's no stat check for an existing binary (unlike osc which checks
   `not _zsh_osc_installed.stat.exists`). This is fine — carapace updates are
   desirable on re-runs, and `go install` with `@latest` handles dedup.

3. **Config dirs must be owned by target user.** The carapace config directories
   go under `{{ zsh_user_home }}/.config/carapace/`. Use the same ownership
   pattern as other user-dir tasks (`owner: "{{ zsh_target_user }}"`).

4. **Preflight-check runs before shell init.** The zshrc will generate a cached
   init script for carapace. Migration 003 in the zsh repo pre-generates this
   during preflight-check. No ansible task needed for this — it's handled on
   the zsh side.

5. **Devcontainer required.** All ansible commands must run inside the
   devcontainer: `devcontainer exec --workspace-folder /path/to/ansible ...`

## Quick Start Commands

```bash
# 1. Verify carapace installs correctly manually first
go install github.com/carapace-sh/carapace-bin/cmd/carapace@latest
which carapace
carapace --version

# 2. Run the zsh role against a test target
devcontainer exec --workspace-folder /home/cupric/dev/ansible \
  ansible-playbook playbooks/zsh.yml -l <test-host> --check

# 3. Apply for real
devcontainer exec --workspace-folder /home/cupric/dev/ansible \
  ansible-playbook playbooks/zsh.yml -l <test-host>

# 4. Verify on target
ssh <test-host> 'which carapace && carapace --version && ls ~/.config/carapace/'

# 5. Idempotency check
devcontainer exec --workspace-folder /home/cupric/dev/ansible \
  ansible-playbook playbooks/zsh.yml -l <test-host>
# Expected: no changes, or only carapace "changed" (go install @latest is always "changed")
```

## Key Files

| File | Current State |
|------|---------------|
| `roles/zsh/tasks/main.yml` | Has osc `go install` at lines ~310-335. Needs carapace task after. |
| `roles/zsh/vars/main.yml` | Has Go package comments. Optional: mention carapace. |
| `roles/zsh/defaults/main.yml` | Go upstream version vars. No change needed. |

## Agent Prompt

Your task: add carapace-bin installation to the zsh Ansible role. This is a
straightforward addition following an existing pattern.

### Step 1: Read the existing osc install pattern

In `roles/zsh/tasks/main.yml`, find the two osc tasks:

1. "Check if osc (OSC 52 clipboard) is installed" (stat check)
2. "Install osc (OSC 52 clipboard) via go install" (command task)
3. "Display osc installation result" (debug task)

Carapace follows the same pattern but without the stat check (we want `go install
...@latest` to always run so it picks up updates).

### Step 2: Add carapace install task

After the "Display osc installation result" task, add:

```yaml
- name: Install carapace (multi-shell completion engine) via go install
  become: true
  ansible.builtin.command: "{{ _zsh_go_binary_path_post.stdout | trim }} install github.com/carapace-sh/carapace-bin/cmd/carapace@latest"
  environment:
    GOPATH: /usr/local/go-packages
    GOBIN: /usr/local/go-packages/bin
    GOCACHE: /root/.cache/go
    HOME: /root
  when:
    - _zsh_go_binary_path_post.stdout | length > 0
  register: _zsh_carapace_install
  changed_when: true

- name: Display carapace installation result
  ansible.builtin.debug:
    msg: >-
      carapace {{ 'installed successfully' if (_zsh_carapace_install is defined and _zsh_carapace_install is changed) else 'already installed' }}
      (go binary: {{ _zsh_go_binary_path_post.stdout | trim }})
  when: _zsh_go_binary_path_post.stdout | length > 0
```

### Step 3: Add config directory creation task

After the carapace tasks, add:

```yaml
- name: Create carapace config directories for target user
  ansible.builtin.file:
    path: "{{ zsh_user_home }}/.config/carapace/{{ item }}"
    state: directory
    owner: "{{ zsh_target_user }}"
    group: "{{ zsh_target_user }}"
    mode: '0755'
  become: true
  loop:
    - specs
    - overlays
    - variables
  when: _zsh_go_binary_path_post.stdout | length > 0
```

### Step 4: Optionally update vars/main.yml

In the "Go programming language" note section for each distro, add after the
osc comment:

```yaml
    # Note: carapace (completion engine) - installed via Go
```

### Step 5: Test

Run the role against a test target. Verify:

```bash
# On target host:
which carapace          # → /usr/local/go-packages/bin/carapace
carapace --version      # → version string
ls ~/.config/carapace/  # → specs/ overlays/ variables/
```

Run a second time to verify idempotency. The carapace install task will show
"changed" (go install @latest always reports changed). Config dirs should show
"ok" (already exist).

### Success looks like

`carapace --version` prints a version string and `~/.config/carapace/{specs,overlays,variables}/`
exist as empty directories owned by the target user.
