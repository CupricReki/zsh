> ⚠️ **STALE** — This document was current as of 2026-11-04 00:57 EST.

# extract packaging spec — Handover (2026-11-04 00:57 EST)

## Context
- **Branch:** `master`
- **Commit:** `365d0ae` (spec is currently untracked; the previous feature merge was `eac88fa`)
- **Repo:** `/home/cupric/dev/zsh`
- **Related:** `/home/cupric/dev/ansible` (catalog, `zsh_packages`, `release_artifact` role); a **new** repo `cupric/extract` (to be created); zsh integration lives here.

## What Was Done

- Wrote the packaging design at `docs/specs/2026-11-04-extract-packaging.md` (Status: **Draft**).
- Ran **three subagent review rounds** against it; it converged from 5 Critical → 2 Critical → 0 Critical. All Critical/Important findings were applied in-place (the spec is the reviewed version).
- The reviewer **empirically built and ran the zipapp** each round, confirming: typer exit codes (0/1/2), `libarchive.so` resolution without `-dev`, deterministic rebuilds, and size (~1.9 MB with `-c`).
- The `extract` tool itself (from the earlier feature work) is merged and live on `master`: `libraries/python/extract/`, `bin/extract.py`, `custom/extract.zsh`, `completion/_extract`, `tests/` (196 tests).

## Remaining

| # | Item | Notes |
|---|------|-------|
| 1 | Write the implementation plan | Use the `plan-writing` skill, consuming the spec. The spec's `## Wiring Checklist` is already a 20-step task breakdown. |
| 2 | Create `cupric/extract` repo | Move `extract/` + `tests/` (183 tests) + `bin/extract.py`; add `requirements.in/.txt`, `requirements-dev.txt`, `scripts/build-zipapp.sh`, `.gitlab-ci.yml`, `renovate.json`. |
| 3 | Ansible wiring | Catalog entry + `docs/reference/release-artifacts.md` row (CI gate) + `zsh_packages` native deps + role block (§9) + molecule verify. |
| 4 | zsh integration | Wrapper delegates to installed `extract`; completion `#compdef extract`; keep 13 wrapper tests in `tests/test_wrapper.py`. |
| 5 | Execute | Via `plan-execution` / `subagent-driven-development` in a worktree (the repo's AGENTS.md mandates this). |

## Key Gotchas

- **Relative paths resolve to the wrong workspace root.** An early `docs/specs/...` write landed in `/home/cupric/dev/dot/`. Always pass absolute paths (`/home/cupric/dev/zsh/...`) or verify the target root.
- **The CLI is NOT being rewritten.** Typer stays. Do not port to argparse — that was an earlier draft and was reverted after the user pushed back (we use only the stable typer core).
- **The zipapp vendors the full closure, not just direct deps.** `typer` pulls `rich` → `markdown-it-py` → `mdurl` + `pygments`; the lock must be compiled (9 distributions) and installed with `--no-deps`, else the bundle silently misses `markdown_it`.
- **Compile the lock for the floor:** `uv pip compile --python-version 3.10`, not the build interpreter (otherwise a newer build image can pin ≥3.11 wheels and break Alma 9).
- **Reproducibility requires normalising mtimes** (`touch -h -d '2000-01-01'`) before `zipapp`, or the sha256 changes on every rebuild and the pinned checksum fails on pipeline retries.
- **Python floor is 3.10.** Alma 9 ships 3.9; the role must *skip with a warning*, never fail. `extract/cli.py` uses PEP 604 annotations.
- **Debian `unrar-free` does not provide the `unrar` binary** the handler probes — do not install it; `unrar` is best-effort (non-free/RPM Fusion) and unencrypted RAR still works via libarchive.
- **Do not push/merge implementation without the worktree flow** — see the repo AGENTS.md (`plan-execution` / `subagent-driven-development`, `.worktrees/<slug>/`).
- **`.cache/exptest/` is untracked scratch** from an earlier agent — leave it alone.

## Quick Start Commands

```bash
cd /home/cupric/dev/zsh
sed -n '1,120p' docs/specs/2026-11-04-extract-packaging.md     # context, dependency model, repo split
grep -n '^## ' docs/specs/2026-11-04-extract-packaging.md      # section map
sed -n '/^## Wiring Checklist/,/^## Execution Order/p' docs/specs/2026-11-04-extract-packaging.md

# Inspect the established Ansible conventions the spec depends on
sed -n '1,60p' /home/cupric/dev/ansible/roles/release_artifact/README.md
sed -n '1,60p' /home/cupric/dev/ansible/inventory/group_vars/all/release_artifacts.yml
sed -n '25,115p' /home/cupric/dev/ansible/roles/zsh/vars/main.yml

# Current extract implementation (to be moved)
ls /home/cupric/dev/zsh/libraries/python/extract/ /home/cupric/dev/zsh/bin/ /home/cupric/dev/zsh/tests/
```

## Key Files

| File | Current State |
|------|---------------|
| `docs/specs/2026-11-04-extract-packaging.md` | **Draft**, 3 review rounds, 0 Critical. Authoritative design. |
| `libraries/python/extract/` | Shipped tool (typer CLI + engine/handlers/orchestration). Moves to `cupric/extract`. |
| `bin/extract.py` | Dev shim (currently `from extract.cli import app; app()`). Moves to `cupric/extract`. |
| `custom/extract.zsh` | Wrapper; spec changes delegation to the installed `extract`. |
| `completion/_extract` | Currently `#compdef extract extract.py`; spec changes to `#compdef extract`. |
| `tests/` | 196 tests; 183 move to `cupric/extract`, 13 `TestWrapper` stay in `cupric/zsh/tests/test_wrapper.py`. |
| `/home/cupric/dev/ansible/roles/release_artifact/tasks/main.yml` | Supports `single_file` + `arches.all` (no changes needed). |
| `/home/cupric/dev/ansible/inventory/group_vars/all/release_artifacts.yml` | Add the `extract` entry (spec §7). |

## Agent Prompt

> **To the agent picking this up:** the items below are your starting
> point. Read the spec first; it is the reviewed, authoritative design.

1. **Read `docs/specs/2026-11-04-extract-packaging.md` end to end**, then run the `plan-writing` skill to produce `docs/plans/2026-11-04-extract-packaging.plan.md`. The spec's `## Wiring Checklist` (20 steps) and `## Execution Order` are the decomposition; each step should become a bite-sized TDD task with exact file paths, code, and verification commands.
2. **Keep the plan's task groups disjoint by repo** (`cupric/extract`, `cupric/ansible`, `cupric/zsh`) so sub-agents can run with isolated write scopes. The cross-repo dependency is: publish the `.pyz` before the Ansible role can install it.
3. **Run `plan-review` before execution**, then execute via `plan-execution` / `subagent-driven-development` in `.worktrees/<slug>/` on `feature/<slug>` (per the repo AGENTS.md). Do not write implementation directly on `master`.
4. **Preserve the three hard-won correctness properties** when writing task steps: (a) `pip install --no-deps` + compiled 9-package lock, (b) `uv pip compile --python-version 3.10`, (c) `touch -d '2000-01-01'` before `zipapp` — each has a concrete failure mode documented in the spec's Risk Mitigations table.
5. **Do not reintroduce argparse.** The CLI is typer and stays typer; the spec's §1 is "unchanged".

**Success looks like:** a plan-review-passed `docs/plans/2026-11-04-extract-packaging.plan.md` whose tasks map 1:1 to the spec's 20-step checklist, with per-repo task groups, exact commands, and a Task Z that builds the zipapp and asserts the `python3 -S -E` exit matrix.
