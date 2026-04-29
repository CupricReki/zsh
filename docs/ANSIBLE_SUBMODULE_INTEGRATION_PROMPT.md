# Ansible Integration Prompt (Submodule Libraries)

Use this prompt with another agent to implement Ansible-side setup for the shared standards library submodule workflow.

## Prompt For Agent

Implement Ansible changes to support the standards library submodule topology used by zsh.

### Context
- `~/.config/zsh` now contains a Git submodule at `libraries/python/standards`.
- zsh update flow (`zgu`) already updates submodules.
- Ansible work must focus on initial setup/provisioning only.
- Do **not** modify zgu behavior in this task.

### Required Outcomes
1. Ensure initial zsh checkout/installation uses submodule-aware clone/update steps.
2. Ensure hosts provisioned via Ansible end with initialized submodules under `~/.config/zsh`.
3. Keep tasks idempotent and safe on re-runs.
4. Preserve existing local user changes policy (do not force reset local changes).

### Constraints
- Apply changes in Ansible repository only.
- No destructive git commands (`reset --hard`, force checkout, force clean).
- Prefer `--recurse-submodules` on clone paths and `git submodule update --init --recursive` on existing clones.

### Suggested Validation
- Fresh host/bootstrap path: zsh repo exists and `libraries/python/standards` is populated.
- Existing host path: re-run playbook and confirm no errors, no destructive changes.
- Run `git -C ~/.config/zsh submodule status` and verify standards submodule is present.

### Deliverables
- Updated Ansible tasks/roles implementing submodule initialization.
- Brief note in Ansible docs/changelog describing submodule initialization behavior.
