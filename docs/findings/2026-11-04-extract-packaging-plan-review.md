> **Status:** Applied — all Critical/Important findings were folded into `docs/plans/2026-11-04-extract-packaging.plan.md` before execution.

# extract packaging — plan review (2026-11-04)

**Reviewer:** fresh-context plan-review subagent (no session history)
**Inputs:** `docs/plans/2026-11-04-extract-packaging.plan.md`, `docs/specs/2026-11-04-extract-packaging.md`, plus the actual `cupric/zsh` and `cupric/ansible` checkouts and the running devcontainer.

## Strengths

- Task/step anchors matched `roles/zsh/tasks/main.yml` and `roles/zsh/vars/main.yml` exactly.
- The proposed catalog entry replays clean against `ci/check_release_artifacts.py` (rule 1 pending-list requirement, docs-table regex, version-embedded asset name, no duplicate URL).
- The `release_artifact` contract is correct: `.extract-version` marker content `0.1.0+<arch>`, `single_file` destination, `arches['all']` fallback.
- The moved 13 wrapper tests pass today against the `ZBIN` seam the new wrapper preserves; the 2 added tests genuinely fail against the old wrapper (real RED step).
- Host prerequisites for the VM check confirmed: `virsh`, `virt-install`, the libvirt package set, passwordless sudo, `virbr0`, and `keys/libvirt_vm_testing_ed25519`.
- Package names verified by running the actual molecule images (all four families; Alma 9 needs `epel-release`, which the role installs first).
- `tests/fixtures/.gitattributes` (`* -text`) survives `cp -r`, so fixture bytes are preserved.

## Issues found (all resolved in the plan)

| # | Severity | Location | Issue | Resolution |
|---|----------|----------|-------|-----------|
| 1 | Critical | Plan Task C Step 3 | Renaming `ZSH_ROOT` → `REPO_ROOT` left `run_tool()`'s default `cwd` referencing `ZSH_ROOT` → `NameError` on every CLI test. | Default `cwd` now `str(REPO_ROOT)`, plus a `grep -n ZSH_ROOT … \|\| echo NO_ZSH_ROOT_REFS` assertion. |
| 2 | Critical | Plan Task A Step 9 | `requirements-dev.txt` contained only `pytest`, but the suite imports `typer` → CI `test` job fails on a clean `python:3.10-bookworm`. | Now `-r requirements.txt` + `pytest==9.2.0`. |
| 3 | Critical | Plan Task Z Steps 7–8 | `inventory/test_vms.ini` generated on the host embeds a host-absolute SSH key path that does not exist inside the devcontainer (`/workspaces/extract-packaging`). | Generation now passes `-e libvirt_vm_testing_inventory_ssh_key=/workspaces/extract-packaging/keys/libvirt_vm_testing_ed25519`; Gotcha added. |
| 4 | Critical | Plan Task C Steps 6/8 | `tests/test_wrapper.py` was written in the main checkout but committed from the worktree, which cannot see untracked files. | Worktrees are created up front ("Workspace Preparation"); Task C writes and commits in the zsh worktree. |
| 5 | Minor | Plan Task C (CI placement) | Found during the fix pass: `.gitlab-ci.yml` with `pytest tests/` committed in Task B would fail because `tests/` does not exist yet. | CI moved to Task C Step 8 (after the suite lands); Task B pushes without a CI gate; headings/summary/coverage table updated. |
| 6 | Minor | Plan Task B release job | Upload + `POST /releases` were not retry-safe (409 on a retried tag pipeline). | Upload accepts 200/201/409; release falls back to `PUT /releases/:tag`. |
| 7 | Minor | Plan Task Z Step 5 | A half-finished earlier run would collide on `virsh define`/`qemu-img create`. | Pre-clean added before create. |
| 8 | Minor | Plan Task D/Z | Fixture paths still pointed at `cupric/zsh` after the move. | Point at `/home/cupric/dev/extract/tests/fixtures/…`. |
| 9 | Minor | Plan Task Z Step 10 | Molecule evidence used a `<prefix>` placeholder and ansible received a zsh-only record. | Concrete `extract-packaging-*` names; separate ansible-scoped evidence file. |
| 10 | Minor | Plan Task E Step 4 | Arch `p7zip` is a virtual provided by `7zip`; the note implied a real package. | Note corrected (name kept — pacman resolves it). |
| 11 | Minor | Plan Task E Step 7 | `fail_msg` dereferenced `ansible_facts.python_version` under `gather_facts: false`. | Plain string message. |
| 12 | Minor | Workspace prep / Task A Step 12 / Task E Step 10 / Task Z Step 9 | Stale claims after the reorder: no pipeline exists before CI lands; the spec commit was local-only; no rebase before the MR; root-owned VM dirs not removable as the normal user. | Push `master` before the worktree; corrected Step 12 note; `git fetch && git rebase origin/develop` before `git push`; `sudo rm -rf`. |

## Recommendations carried into the plan

- Repo creation is explicit (`glab api` + `git init` + `git remote add`), not dependent on `glab repo create` clone behaviour.
- Keep the anonymous-download gate in Task D Step 3 before the ansible pin; fall back to the generic-registry URL if the release-downloads redirect 404s.
- Treat `release_artifacts_checksum_pending` as a lint-contract entry for `captured_at_bump`, not as "no checksum" (the sha256 is still verified).

## Assessment

**READY TO EXECUTE** after the revisions above. No Critical or Important issue remains; the residual items are hygiene-level and are already encoded as plan steps.

## Tooling note for whoever executes this plan

`plan_status validate` reports the spec, handover, and this findings file as "probable orphans" even though all three are linked under `## Linked Documents`. That is a validator inconsistency, not a missing link: `_discover_orphans` compares the raw link text against repo-root-relative paths, while `_resolve_link` resolves links relative to the plan's directory (the supported `../category/file.md` form, per `test_validate_cross_directory_link`). Do not rewrite the links to repo-root form to silence the warning — that replaces it with `broken_link` warnings.
