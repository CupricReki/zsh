# Findings: Plan Review — `extract-password-recursive_7f3a9c2b`

- **Date:** 2026-09-19
- **Reviewer:** Agent (plan-review)
- **Plan:** `docs/plans/extract-password-recursive_7f3a9c2b.plan.md`
- **Spec:** `docs/specs/2026-09-19-extract-password-recursive-design.md`
- **Verdict:** NEEDS FIXES — four deterministic task-gate blockers (Critical) plus five Important gaps.

## Summary

The plan is structurally sound: complete spec cross-reference, correct task ordering (A→B→C→D→E→F→Z), exact `plan_status` format, consistent cross-task interfaces (`CHAIN_TABLE` keys all present in `HANDLERS`, `resolve`/`process_archive`/`log` signatures match across tasks), and a full validation task with the correctly named `.test-evidence-extract-password-recursive.json`. Repo facts were verified: `ZBIN`/`ZSH_CUSTOM` are exported in `zshenv`, the `unalias backup 2>/dev/null` anchor sits after `eval "$_sheldon_output"`, the stale `# Note: extract function is loaded via sheldon...` comment exists at `zshrc:144`, and the vendored `standard_logging.log(level, *messages)` sends only error/critical to stderr — so the `logutil.py` shim is valid. Typer's single-command auto-dispatch was confirmed (maintainer statement, fastapi/typer discussion #937), so invoking `extract.py PATH` without a subcommand works.

However, four tasks contain test/implementation contradictions that will deterministically fail their own RED→GREEN gates, and five spec requirements (AES-zip coverage, password redaction, KeyboardInterrupt cleanup, continue-on-unknown-extension, completion registration for the `extract` function) have no working implementation path.

## Critical — deterministic task-gate blockers

### C1. Task D — `LibarchiveHandler.extract` re-raises `ValueError`; its own test expects `EXTRACT_ERROR`

- Plan `libraries/python/extract/handlers.py` (Task D Step 3): `except ValueError: raise` around the entry loop. `safe_join` raises `ValueError` for traversal members, so it propagates out of `extract()` — but the plan's own test `TestLibarchiveHandler::test_traversal_member_rejected` (Task D Step 1) asserts `result.cls is ErrorClass.EXTRACT_ERROR`.
- Impact: test fails with an unhandled exception (not an assertion); worse, `resolve()` has no per-handler exception guard and the CLI loop has none either, so a traversal member crashes the whole run instead of the spec-required per-archive failure isolation (spec §6.2, §7.1 "handlers never write outside the temp dir").
- Fix: replace `except ValueError: raise` with returning `_err(str(exc))` (classify as `EXTRACT_ERROR`), matching the test's own comment "safe_join raises -> classify".

### C2. Task B — split-volume regex misses multi-digit `.partN.rar` volumes (N ≥ 10)

- Plan `discovery.py`: `SKIP_VOLUME` uses `\.part[2-9]\d*\.rar$`. `foo.part10.rar` starts with digit `1`, so it does **not** match → volume not skipped.
- Contradiction: the plan's own parametrized test includes `("foo.part10.rar", True)`; spec §6.2 requires skipping all `.partN.rar` with N ≥ 2.
- Fix: use `\.part(?:[2-9]|\d{2,})\.rar$` (or equivalent `part\d+` with an explicit `part1` exclusion), and consider whether `.r\d{2}` / `.7z\.\d{3}` need the same multi-digit scrutiny.

### C3. Task B — `discover()` raises `DiscoveryError` for a non-recursive directory, but its test expects `[]`

- Plan `discovery.py`: a directory argument with `recursive=False` falls through to `raise DiscoveryError`. Test `test_discover_non_recursive_directory_ignores_contents` expects `discover([tmp_path], recursive=False) == []`.
- Impact: deterministic test failure; spec §5/§6.2 is silent on non-recursive directory args, so one behavior must be picked and made consistent.
- Fix: either return `[]` for non-recursive directory args (match the test) or keep the error and change the test to `pytest.raises(DiscoveryError)` — and ensure the CLI treats it per-archive (see I1).

### C4. Task F — wrapper-delegation test writes a **shell** script as the fake `extract.py`, but the wrapper invokes it with `python3`

- Plan `tests/test_cli.py` `test_delegates_new_flags` writes `#!/bin/sh\necho PYTOOL "$@"\nexit 0` into `fakebin/extract.py`; the wrapper (`custom/extract.zsh`, verbatim from spec §9) runs `python3 "${ZBIN}/extract.py" "$@"` → `SyntaxError` on line 2, empty stdout.
- Impact: `test_delegates_new_flags` fails deterministically; Task F Step 7 cannot pass.
- Fix: make the fixture a valid Python script, e.g. `#!/usr/bin/env python3\nimport sys\nprint("PYTOOL", *sys.argv[1:])`.

## Important — spec requirements without a working implementation path

### I1. CLI aborts on first `DiscoveryError` instead of per-archive "error, continue" (spec §7.2, §6.2)

- Plan `cli.py`: `except DiscoveryError → log → typer.Exit(1)` stops processing all remaining paths. Spec §7.2: "Unknown extension → error for that archive, continue"; §6.2 requires per-archive failure isolation.
- Fix: catch per path inside the loop (or make `discover` return a structured result), log the error, increment `failed`, and continue.

### I2. No AES-zip integration test; libarchive password classification untested (spec §11.2/§11.3)

- Spec §11.2 explicitly requires AES zip fixtures (`7z a -mem=AES256 -p…`) exercising the `unzip -P` fallback, i.e. the libarchive → `BACKEND_UNSUPPORTED` descent. The plan's only zip fixtures are default ZipCrypto; the descent path is never integration-tested.
- Task D Step 4's note "if a libarchive exception-message test fails, adjust `_classify` matchers" references a test that does not exist in the plan — there is no test for `WRONG_PASSWORD`/`BACKEND_UNSUPPORTED` classification of real libarchive failures.
- Fix: add AES-zip fixtures (unzip handler + end-to-end CLI), plus a direct libarchive wrong-passphrase test, pinning the local exception wording per the plan's own verify-at-implementation note.

### I3. No password redaction in diagnostic dumps (spec §8.3)

- Spec: "diagnostic dumps (§7.1) redact any line matching a candidate." Plan handlers return raw `out[-2000:]` as `Result.detail`, which is logged verbatim via `log("error", ...)`.
- Fix: add a `redact(text, candidates)` helper and apply it in every handler before returning details (and in `resolve()`'s final error).

### I4. No explicit KeyboardInterrupt / finally cleanup path (spec §7.1 defensive rule, §6.6 cleanup paths)

- Plan relies solely on `sweep_stale()` at the next run. An interrupt mid-`handler.extract` leaks the current temp dir until that archive is processed again; spec §7.1 lists "`finally`/`KeyboardInterrupt` guarantees temp-dir cleanup" as an enforced defensive rule.
- Fix: wrap the `resolve()` + placement block in `process_archive` with `try/finally` that removes the in-flight temp dir on `KeyboardInterrupt` (marker-guarded, per §6.6).

### I5. Generated completion registers only `#compdef extract.py` — the `extract` function loses completion and the plugin's `_extract` is shadowed (spec §10)

- Typer generates a zsh completion for the program name (`extract.py`). Committed as `completion/_extract` (first in `$FPATH`), it shadows the plugin's `_extract` for the `extract` function while only registering the new flags for `extract.py`. The plan's Verify step accepts any `#compdef` line, so this passes silently and breaks completion for plain `extract` invocations.
- Fix: after generation, ensure the file registers for both (`#compdef extract.py extract` or append `compdef _extract.py_completion extract`), and extend the Verify step to assert the `extract` registration.

## Minor

1. **Wrapper delegation tests** cover only `-R` and `-p`; spec §11.8 wants "delegation for each new flag" — parametrize over `-R/-p/-P/-F` (and long forms).
2. **Missing spec §11 tests:** live-output-while-detecting (§11.9), registry-edit with zero engine changes (§11.10), list-argv/no-shell subprocess safety (§11.10), symlink non-following (§11.11).
3. **Spec §8.2** "candidates ignored → single info log" is not implemented (engine silently drops candidates for non-password families).
4. **Spec §7.1** says diagnostic dumps carry "the tool's last ~20 output lines"; plan uses last 2000 characters.
5. **Spec §7.1** handler record has a `classify_failure` method; plan folds classification into `extract()` — acceptable simplification, but note the deviation in code or spec.
6. **Spec §6.1** temp-dir pattern is `.extract-<name>-<pid>`; `tempfile.mkdtemp` yields a random suffix (pid lives in the marker). Cosmetic.
7. **Profile awareness:** no per-task profile notes (checklist item 7); plan header declares subagent-driven-development/plan-execution, which is the mitigating mechanism.
8. **Parallelism:** B and C depend on nothing from A, yet the plan declares a fully serial chain and identifies no parallelizable tasks.
9. **Task Z:** `zsh -n` covers `custom/extract.zsh` and `zshrc` but not `completion/_extract`; no linter is run (py_compile is an acceptable substitute if the repo has none).
10. **Task Z Step 3** smoke test uses `<(echo a.txt)` process substitution — bash/zsh only, not POSIX `sh`.
11. **Task D `_pipe`** never drains producer stderr — deadlock risk if a decompressor writes heavily to stderr.
12. **Task D** module-level `pytestmark` skips all handler tests when 7z is absent, including 7z-independent ones (`safe_join`, `run_streamed`, tarfile, zlib, single-file). Scope the skip to the encrypted-fixture classes.
13. **Task F Step 2** expected failure is wrong: `test_cli.py` has no `from extract...` import, so `ModuleNotFoundError: extract.cli` will not occur (tests fail for other reasons — fine for TDD, but the expected output should say so).
14. **Task F Step 7** count arithmetic: "7 + 3 password + 2 wrapper" should be "5 + 3 password + 2 wrapper".
15. **Task A Step 5** syncs spec §4 rows only; spec §11 still says "pytest suite in `zsh/tests/test_extract.py`" — update for consistency.
16. **Verify at Task D start:** python-libarchive-c's `file_reader(passphrase=...)` kwarg and `entry.isdir`/`entry.issym`/`entry.ishardlink` attribute support on the installed build — the plan hedges only exception wording.

## Verified-good

- `plan_status` format: header `| Task | Description | Status |`, `pending` rows, `### Task N:` headings, `- [ ] **Step N:**` steps, no emoji.
- Cross-task interfaces: `CHAIN_TABLE` values ⊆ `HANDLERS` keys; `resolve(archive, family, chain, handlers, passwords, new_tempdir)` matches orchestration's call; `process_archive(..., skip_existing=recursive)` matches the CLI; `log(level, *messages)` matches the vendored `standard_logging.log`.
- Repo anchors: `ZBIN`/`ZSH_CUSTOM` in `zshenv`; `unalias backup 2>/dev/null` after sheldon eval; stale comment at `zshrc:144`; `zsh/tests/` already exists (contains `fixtures/`); `libraries/python/` exists.
- Typer single-command auto-dispatch verified — CLI invocation shape `extract.py PATH [...]` is valid; `--help` shows the command's flags.
- Validation Task Z exists, runs pytest + py_compile + `zsh -n` + smoke test, and writes `.test-evidence-extract-password-recursive.json` (correct slug-named evidence file per repo rules).

---

## Re-review (round 2, 2026-09-19)

**Verdict: NEEDS FIXES (narrow).** All four Critical and all five Important findings from round 1 are resolved and verified in the plan text:

- C1 ✅ — `LibarchiveHandler` now has a single `except Exception` classifying `ValueError` from `safe_join` as `EXTRACT_ERROR`; matches its test.
- C2 ✅ — `SKIP_VOLUME` regex is `\.part(?:[2-9]|\d{2,})\.rar$`; `foo.part10.rar` matches; test unchanged and now consistent.
- C3 ✅ — test replaced with `test_discover_directory_requires_recursive` expecting `DiscoveryError`; implementation unchanged.
- C4 ✅ — fake shim is a Python script; delegation tests parametrized over all 8 flag forms (short + long).
- I1 ✅ — `cli.py` discovers per-path, logs, `failed += 1`, continues; exit 1 at end.
- I2 ✅ — `_make_aes_zip` fixture (`-mem=AES256`), AES tests at handler level (Unzip + Libarchive `BACKEND_UNSUPPORTED`), end-to-end `test_aes_zip_via_unzip_fallback`, and `test_wrong_passphrase_classified`.
- I3 ✅ — `redact()` in `logutil.py`; `process_archive` redacts `result.detail` before logging.
- I4 ✅ — `try/except KeyboardInterrupt` (rmtree tmp, re-raise) + `except Exception` (rmtree tmp, log, return False) in `process_archive`.
- I5 ✅ — Step 6 rewrites the compdef line to `#compdef extract extract.py` and verifies it.

All 16 Minor items from round 1 are also resolved (verified in plan text): `_tail()` 20-line truncation everywhere, `_pipe` stderr→DEVNULL, class-scoped 7z skips, corrected Step 2/7 wording, Task Z `zsh -n completion/_extract` + POSIX-safe smoke test, spec §11 sentence sync, B∥C + write-profile note, extended libarchive verify note, chain-data-driven engine test, live-output/metacharacter `run_streamed` tests, symlinked-dir merge test, pid in temp-dir prefix, ignored-candidates info log.

**Remaining findings (new, not previously listed):**

- **NEW-1 (Important)** — `test_missing_tool` fixture is still malformed: `handler._tool_names[".gz"] = (("definitely-not-a-real-tool",),)` makes `for candidates, mode in self._tool_names[ext]` raise `ValueError: not enough values to unpack` (expected 2, got 1). Task D Step 4 will fail with a test error. Fix: `handler._tool_names[".gz"] = ((("definitely-not-a-real-tool",), "stdout"),)`.
- **NEW-2 (Minor)** — `TestLibarchiveHandler::test_wrong_passphrase_classified` and `test_aes_zip_classified_backend_unsupported` create fixtures via `TestUnzipHandler()._make_*` (requires 7z) but the class carries no `skipif`; on hosts without 7z they error (`subprocess.run([None, ...])`) instead of skipping. Add the same class-level skipif.
- **NEW-3 (Minor)** — Task C Step 4 says "8 passed" but the new `test_chain_is_data_driven` makes 9 tests.
- **NEW-4 (Minor)** — Task E Step 4 says "17 passed" but the new symlinked-dir merge test makes 18 tests.
- **NEW-5 (Minor)** — Task Z Step 4 evidence JSON has a leftover duplicate `zsh -n custom/extract.zsh && zsh -n zshrc` command entry (one combined entry already covers it).
- **NEW-6 (Minor)** — `process_archive`'s `except Exception` branch logs `{exc}` unredacted; apply `redact(str(exc), passwords)` for consistency with §8.3.
