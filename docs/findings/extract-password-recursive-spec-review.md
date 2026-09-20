**Status:** Active

# extract.py — spec review, edge cases & missed formats

**Date:** 2026-09-19
**Context:** Adversarial review of `docs/specs/2026-09-19-extract-password-recursive-design.md`
(the `extract.py` password + recursive extraction tool), performed while building
the test fixtures in `tests/fixtures/`. Every exit code, message and failure mode
below was **measured on this host**, not inferred from documentation — the
evidence commands are reproducible and the fixtures are committed.

**Audience:** the agent implementing `zsh/bin/extract.py` and `zsh/custom/extract.zsh`.

> **Read the reconciliation section first.** An implementation plan already exists
> (`docs/plans/extract-password-recursive_7f3a9c2b.plan.md`) whose architecture
> differs from the spec — libarchive-c primary engine, fallback chain, temp-dir
> extraction, `safe_join`, split-volume discovery. That resolves several findings
> below and changes the priority of others. The reconciliation table marks each
> one; the libarchive section is measured against the plan's actual engine.

---

## Executive summary

The spec's structure is sound and most of its tool choices are correct, but four
issues will cause hangs, data loss, or silently-unsupported archives:

1. **`unzip` without `-P` hangs forever.** It reads the password from `/dev/tty`,
   ignores `stdin=/dev/null`, and **ignores SIGTERM** — a `timeout 5` did not kill
   it. One encrypted zip in a `-R` tree freezes the whole run.
2. **The "clear the target dir between password attempts" rule destroys user data
   under `-F`.** `-F` reuses a pre-existing directory; clearing it to retry a
   password deletes the user's files, and the failure path then removes the dir.
3. **7z exit code 2 is ambiguous** — it means *both* "wrong password" and
   "corrupt / not a 7z archive". The spec's `exit 2 → next candidate` rule makes a
   corrupt archive burn the entire candidate list and then be reported as a wrong
   password.
4. **Info-ZIP `unzip` 6.00 cannot read AES zip archives at all** (exit 81,
   `need PK compat. v5.1 (can do v4.6)`). Since `.zip` is dispatched to `unzip`
   only, every modern WinZip/7-Zip AES zip is unsupported. `7z` reads both
   ZipCrypto *and* AES.

Plus one security item: the spec is silent on Python's `tarfile` extraction
filter, and `filter='fully_trusted'` **does** write outside the target directory.

The fixtures in `tests/fixtures/` cover 79 usable artifacts across 40+ extensions
and include counterexamples for each finding above.

---

## Reconciliation with the implementation plan — read this first

The plan departs from the spec in ways that matter: **libarchive-c is the primary
engine** behind a `CHAIN_TABLE` of fallbacks, extraction goes to a **temp dir**
merged into place on success, traversal is blocked by `safe_join`, split volumes
are handled by discovery, and suffix matching is longest-first.

| Finding | Status under the plan |
|---|---|
| **C1** unzip hangs | **Still applies** to every CLI fallback handler. libarchive-c does not prompt, so the hang only bites in the subprocess path. |
| **C2** clearing the target dir | **Resolved** — temp-dir extraction + merge removes the need to clear in place. Verify the merge respects `-F` and never deletes pre-existing user files. |
| **C3** 7z exit-code ambiguity | **Still applies**, and now doubly so because of the libarchive 7z gap below. |
| **C4** AES zips unsupported | **Resolved** — libarchive-c decrypts ZipCrypto *and* AES-256 with `passphrase=` (measured). |
| **C5** tarfile filter | **Mostly resolved** — `safe_join` + temp dir. Add `EXTRACT_SECURE_NODOTDOT \| EXTRACT_SECURE_NOABSOLUTEPATHS` if libarchive's own disk writer is used anywhere. |
| **C6** wrapper recursion | **Still applies** — the plan's wrapper is verbatim from spec §8. |
| **M1–M6, M8, M9, M11, M12** | **Still apply** unless the plan handles them explicitly (M4's `LC_ALL=C` matters for any CLI fallback). |
| **M7** multi-volume | **Half-resolved** — discovery finds volumes, but libarchive cannot read `.7z.001` (Seek error), so the `7z` CLI is required. |
| **M10** longest-first suffixes | **Resolved** — the plan does longest-first. |

## libarchive conformance — the plan's primary engine

Measured with libarchive-c (installed on this host) reading each fixture, passing
the fixture's password where it has one. `manifest.json` now records this per
fixture as `la_read`, `la_raw` and `la_note`.

| Fixtures | libarchive-c result |
|---|---|
| tar family; `.zip` incl. **AES-256**; `.cab`/`.exe`; `.deb`; `.cpio`/`.obscpio`; `.tar.lz` | reads OK. **Decrypts ZIP, ZipCrypto and AES-256 via `passphrase=`**; a wrong passphrase is rejected. |
| bare single-file `.gz/.bz2/.xz/.lzma/.zst/.zstd/.lz4` | reads OK **only with `format_name='raw'`**; otherwise `ArchiveError: Unrecognized archive format`. |
| `enc.7z`, `enc_mhe.7z`, `enc_spacepass.7z`, `enc_solid.7z`, `tree/one_enc.7z` | **`ArchiveError: The file content is encrypted, but currently not supported`** — *even with the correct passphrase*. |
| `enc_split.7z.001` | `ArchiveError: Seek error`. |
| `plain.rpm` | `ArchiveError: Unrecognized archive format`, while `rpm2cpio \| cpio -id` exits 0. |
| `plain.tar.br` | `ArchiveError: Unrecognized archive format` (no brotli filter). |
| `plain.txt.br`, `plain.zlib` | `format_name='raw'` reports success but returns the **compressed** bytes unchanged. |

Consequences for the chain:

1. **`.7z` password handling must use the `7z` CLI, not libarchive.** With the
   passphrase supplied, libarchive-c still raises *"encrypted, but currently not
   supported"* — a hard limitation, not a wrong-password signal, so a handler
   cannot even classify the failure. There is no in-library alternative:
   `libarchive.extract_file(filepath, flags=None)` takes **no passphrase**. The
   `7z` CLI reads header-encrypted (`-mhe=on`) and multi-volume (`.001`) archives
   correctly (exit 0, measured).
2. **Single-file formats need `format_name='raw'`**, plus an output filename
   derived from the archive name, because raw entries carry no name (this is also
   finding **M8**).
3. **`.br` and `.zlib` need non-libarchive fallbacks, and the failure is silent.**
   libarchive has no brotli filter and no raw-zlib/deflate filter; in `raw` mode it
   returns the compressed bytes *without raising*. An "exceptions mean failure"
   check will happily write compressed garbage. Compare output size against input
   size, or route `.br` to the `brotli` CLI and `.zlib` to stdlib `zlib`.
4. **`.rpm` needs `rpm2cpio | cpio`** in this environment, despite libarchive
   nominally supporting rpm.
5. **`.tar.lz` (lzip) does *not* need the `lzip` binary** — libarchive reads it,
   even though `tar --lzip` fails here. If any handler still shells out to
   `tar --lzip`, that path is broken where the libarchive path works.

## Empirical evidence (measured, this host)

Toolchain: `unzip` 6.00 (Info-ZIP), `7-Zip` 26.03, `unrar` 7.30, GNU `tar` 1.35,
`xz` 5.8.4, `zstd` 1.5.7, `lz4` 1.10.0, Python 3.14.7.
`compress`, `pigz`, `lzip`, `lzop`, `lrzip`, `zpaq`, `rar`, `dpkg-deb` are **not installed**.

| Situation | Command shape | Exit | Message / effect |
|---|---|---|---|
| wrong password, fully-encrypted zip | `unzip -P wrong z.zip` | **82** | `skipping: … incorrect password`; **no partial files** |
| wrong password, *mixed* zip (some plaintext members) | `unzip -P wrong z.zip` | **1** | plaintext member **is extracted**; leftovers remain |
| AES zip, correct password | `unzip -P right aes.zip` | **81** | `need PK compat. v5.1 (can do v4.6)` |
| truncated zip | `unzip -P x t.zip` | **9** | `cannot find zipfile directory` |
| encrypted zip, **no `-P` at all** | `unzip z.zip` | **hung** | reads `/dev/tty`; `stdin=/dev/null` irrelevant; SIGTERM ignored |
| same, but `-P ''` | `unzip -P '' z.zip` | 82 | no prompt — **empty `-P` is the fix** |
| `-q` + wrong password | `unzip -q -P wrong z.zip` | 82 | **output is empty** — the "incorrect password" marker disappears |
| 7z wrong password | `7z x -pwrong a.7z` | **2** | `Data Error in encrypted file. Wrong password?` |
| 7z corrupt / not a 7z | `7z t corrupt.7z` | **2** | `Cannot open the file as [7z] archive` |
| 7z unencrypted + `-p<anything>` | `7z x -px plain.7z` | 0 | password ignored |
| 7z warning (trailing junk) | `7z t warn.7z` | **0** | prints `WARNINGS:` but still `Everything is Ok` |
| 7z encrypted, no `-p` | `7z x a.7z < /dev/null` | 255 | `Enter password:` … `Break signaled` |
| `unrar` on a non-rar | `unrar x -px f.zip` | **10** | `no files to extract` |
| GNU tar, `.tar.lz4` | `tar -xf x.tar.lz4` | 2 | `This does not look like a tar archive` |
| GNU tar, `.tar.lz` | `tar --lzip -xf x.tar.lz` | 2 | `lzip: Cannot exec: No such file or directory` |
| Python 3.14 `tarfile.extractall()` default | traversal tar | raises | `OutsideDestinationError`, **nothing at all extracted** |
| Python `tarfile.extractall(filter='fully_trusted')` | traversal tar | 0 | wrote `../escape.txt` **and** the absolute `/tmp` path |
| Python `zipfile.extractall()` default | traversal zip | 0 | sanitised: `../` and absolute paths stayed inside |

Note GNU tar 1.35 *does* auto-detect `.Z`, `.bz`, `.zma`, `.zst` and `.br`
(`tar -xf` succeeded on all of them) but **not** `.lz4` — so the spec's explicit
`lz4 -dc | tar` pipe is necessary, not optional.

---

## Critical findings

### C1 — `unzip` hangs without `-P`; the hang is not reliably killable
**Spec:** §6 (`.zip` row uses `-P` "when passwords given"), §7.2.
When no password candidates are supplied and an encrypted zip is encountered,
`unzip` prompts on `/dev/tty`. `stdin=subprocess.DEVNULL` does **not** help (only
the *overwrite* prompt reads stdin — verified separately), and `timeout`'s SIGTERM
did not terminate it. In `-R` mode this is a hard freeze on the first encrypted zip.

**Fix:** always pass `-P`, even when the candidate list is empty — `unzip -P ''`
was measured to fail cleanly with exit 82. Also pass `start_new_session=True` and
enforce a wall-clock timeout with SIGKILL as a backstop, and consider
`-o`/`-n` explicitly so the overwrite prompt can never appear.

### C2 — clearing the target dir between attempts deletes user data under `-F`
**Spec:** §7.2 ("the target dir's contents are cleared so partial output … doesn't
pollute the next attempt") + §5.3 (`-F` reuses an existing directory).
`-F` deliberately targets a directory the tool did **not** create. If that
directory has user content and the password list needs more than one attempt, the
spec's clearing step empties the user's directory; the all-candidates-exhausted
path then **removes the directory entirely**.

**Fix options (pick one and state it):** (a) forbid `-F` together with `-p`/`-P`;
(b) extract every attempt into a fresh temporary directory and only `-F`-merge
into the real target after success; (c) track exactly which entries this run
created and delete only those. Option (b) is simplest and also fixes partial
output on plain failure.

### C3 — 7z exit code 2 conflates "wrong password" with "corrupt archive"
**Spec:** §7.2 (`7z`/`7za`: `exit 2 = next candidate; any other exit = fatal`).
Measured: corrupt/unsupported archives also exit 2. A corrupt `.7z` therefore
consumes the whole candidate list and is finally reported as "all passwords
wrong", which hides the real cause.

**Fix:** do not rely on the exit code alone. Distinguish on output — a wrong
password prints `Wrong password?`, a corrupt archive prints
`Cannot open the file as [7z] archive`. Prefer a cheap `7z t`/`7z l` probe first,
and treat `exit 0` **and** `exit 1` (warnings) as success.

### C4 — `.zip` dispatched to `unzip` only ⇒ AES zips are unsupported
**Spec:** §6 `.zip` row. Info-ZIP 6.00 cannot read WinZip AES (`exit 81`), which
is what 7-Zip produces with `-mem=AES256` and what modern Windows tools produce.
`unzip`'s exit 81 is *not* a password failure, so it correctly falls into the
"fatal for this archive" branch — but the archive then simply fails.

**Fix:** use `7z x` as the zip engine, or fall back to it when `unzip` exits 81.
`7z` was measured to read Info-ZIP ZipCrypto, 7-Zip ZipCrypto *and* AES zips, which
also collapses three exit-code models into one. Fixture: `enc_aes256.zip`.

### C5 — path traversal: pass the tarfile filter explicitly
**Spec:** §6 (`.tar*` via stdlib `tarfile`) — silent on extraction filters.
Verified: on Python 3.14 the default filter is `data`, which raises
`OutsideDestinationError` and aborts the **entire** extraction (even benign
members are not written); with `filter='fully_trusted'` — the implicit pre-3.12
default — `../escape.txt` and an absolute `/tmp` path were written outside the
target. So correctness here is version-dependent, and the failure mode is a
surprise exception rather than a clean per-archive error.

**Fix:** pass `filter="data"` explicitly (never `fully_trusted`), and catch
`tarfile.FilterError` / `OutsideDestinationError` so a single hostile member
becomes a reported per-archive failure. Fixtures: `traversal.tar`, `traversal.zip`,
`symlink.tar`. Note `zipfile.extractall()` sanitises by itself, so zip and tar
need different expectations.

### C6 — the zsh wrapper recurses infinitely when `zshrc` is re-sourced
**Spec:** §8.
```zsh
if (( $+functions[extract] )); then
  functions[extract_orig]="${functions[extract]}"
fi
```
On the second `source ~/.zshrc` (routine: every new tab in some setups, every
config reload), `extract` is *already the wrapper*, so `extract_orig` is set to the
wrapper — and `extract_orig "$@"` calls itself forever.

**Fix:** guard on the *target* and make it one-shot:
```zsh
if (( ! $+functions[extract_orig] )) && (( $+functions[extract] )); then
  functions[extract_orig]="${functions[extract]}"
fi
```

---

## Major findings

- **M1 — empty candidate set is unhandled.** `-p ''`, an empty `-P` file, or an
  all-blank file yields zero candidates (fixture `passwords_empty.txt`). The spec
  never says what happens; the likely implementation reports "all candidates
  exhausted", which is a confusing lie. Make it a usage error (exit 2) or at
  least a distinct message.

- **M2 — password files have no comment syntax.** Per §7.1 every non-blank line is
  a candidate verbatim, so `#`, `;` and `//` lines become passwords and are tried
  (and logged as failed attempts). Real-world passlists carry comments.
  Fixture: `passwords_with_comments.txt`. Either strip `#`-prefixed lines or
  document loudly that comments are not supported.

- **M3 — a UTF-8 BOM corrupts the first candidate.** `passwords_bom.txt` starts
  `EF BB BF z1p-pass`; without an explicit BOM strip the first candidate is
  `\ufeffz1p-pass` and never matches. Strip a leading BOM after decoding.

- **M4 — locale must be pinned, and `-q` must not be used on unzip.** The wrong-
  password signal the spec keys on is the English string `incorrect password`
  (Info-ZIP ships NLS translations), and `unzip -q` *suppresses* it entirely
  (measured: empty output with exit 82). Pass `LC_ALL=C` and `LANG=C` in the
  subprocess environment and do not pass `-q`.

- **M5 — unzip's exit code for a bad password is not stable, so use the marker as
  the primary signal.** Fully-encrypted → 82; mixed archive → 1 *plus* leftover
  files; truncated → 9. The spec's marker-based rule is the right call; just make
  it the source of truth and treat the exit code as secondary. This also means the
  "leftovers" cleanup is genuinely required — the mixed-archive case *does* leave
  files behind (measured), which is why C2's fix must not be "skip the cleanup".

- **M6 — no `shutil.which` preflight.** The table assumes `lzcat`, `lz4`, `7z`,
  `unrar`, `cabextract`, `rpm2cpio`, `cpio`, `ar`, `brotli` exist. On this host
  `.tar.lz` fails with a raw `lzip: Cannot exec`, and `.lrz`/`.lzo`/`.zpaq` have no
  tools at all. Per-archive errors should say "tool not installed", and a startup
  preflight should warn once.

- **M7 — multi-volume archives are invisible to `-R`.** `enc_split.7z.001` (and
  `.part1.rar` / `.r00` / `.z01`) match no extension in §6, so `rglob` never finds
  them and the user gets silence, not an error. 7z *does* extract happily when
  pointed at `.001` (measured) — the only problem is discovery. Either add `.001`
  handling or document the limitation explicitly.

- **M8 — single-file decompressors produce a FILE, but §5.1 describes a target
  *directory*.** For `plain.txt.gz` the spec's naming yields a directory
  `plain.txt/` containing the file `plain.txt` (which is what the oh-my-zsh plugin
  does). Say so explicitly. Worse, `.zlib` carries no filename at all, so the
  output name is undefined — pick a rule (e.g. strip `.zlib`, or the archive's
  stem) and document it.

- **M9 — `.apk` is ambiguous.** Android `.apk` is a zip; Alpine `.apk` is a
  tar.gz. §6 maps `.apk` to `unzip`, so Alpine packages fail. Fixture
  `alpine.apk` is the counterexample. Sniff the magic bytes or fail with a hint.

- **M10 — extension matching must be longest-first.** `foo.tar.gz` matches both
  `.tar.gz` and `.gz`; with a naive set-membership test the single-file `.gz`
  branch can win and the tool would try to gunzip a tar. Iterate known extensions
  by descending length, and note the spec's strip-loop should not strip *all*
  extensions blindly (a file literally named `notes.gz` is data, not an archive).

- **M11 — `-R` with zero archives found has no defined exit code.** Recommend `0`
  plus a warning ("nothing to do is not a failure"), but state it, because exit 1
  would break scripts that run `extract -R .` in mixed trees.

- **M12 — `-F` + pre-existing target + name collision.** Fixture
  `edge/collision/f.tar.gz` sits beside a **regular file** `f`. `mkdir` on an
  existing file fails; the spec doesn't say whether that is a per-archive error
  (recommended) or a crash.

---

## Minor / nits

- **Wrapper flag detection is exact-token only.** `--password=secret`,
  `--password-file=…`, clustered `-Rp`, and `-Fp pass` all fall through to the
  plugin and are *silently ignored*. Add `--password=*` / `--password-file=*`
  patterns, or parse the arguments properly.
- **`${ZBIN}` is referenced but not established by the spec.** Per the spec's own
  §2, `zsh/bin` is already on `$PATH`, so `extract.py` alone is more robust than
  `${ZBIN}/extract.py`.
- **`-p`/`-P` do not clash** in Typer/Click (short flags are case-sensitive) —
  verified, no issue. Worth a test to lock it in.
- **Passwords starting/ending with a space are inexpressible** (§7.1 acknowledges
  this). Since trimming happens before comparison, no fixture can assert the
  opposite; keep the accepted trade-off but record it in `--help`.
- **Completions:** the committed `_extract` only takes effect after carapace's
  bridge refreshes; a stale completion cache can shadow the new flags. Mention the
  refresh in the commit message.
- **The `x` alias** is defined by the plugin; if the plugin failed to load, `x` is
  undefined while `extract` (the wrapper) still works — the wrapper's error branch
  should probably still serve `x`.
- **`.exe` handling:** `cabextract` handles a CAB-with-`.exe`-extension and many
  real SFX stubs; the fixture `plain.exe` is the former, not a real stub.

---

## Missed formats worth considering

Fixtures marked ✅ exist in `tests/fixtures/`; ❌ have no creator on this host.

| Format | Status | Note |
|---|---|---|
| `.br`, `.tar.br` | ✅ | **Genuine gap.** `brotli` is installed and common. Not in §6 at all. |
| `.Z`, `.tar.Z` | ✅ | §6 lists only lowercase `.z`; uppercase `.Z` is the conventional name. GNU tar handles `.tar.Z` directly. |
| `.tar.lz` / bare `.lz` | ✅ | lzip. Bare `.lz` is entirely absent from §6. `tar --lzip` **fails on this host** (no `lzip` binary) — libarchive wrote the fixture. |
| `.tar.bz` | ✅ | Two-letter variant of `.tar.bz2`; §6 has `.tbz`/`.tbz2` but not `.tar.bz`. |
| `.zstd` | ✅ | Long form of `.zst`; §6 has `.zst` only. |
| `.tar.lz4` | ✅ | Present, but note plain `tar -xf` fails — the explicit `lz4 -dc | tar` pipe is required. |
| `.cbz`, `.cbr` | ❌ | Comic archives. `.cbz` is a zip but **`.cbr` is a rar** — do not map them to the same engine. |
| `.epub`, `.odt`/`.ods`/`.odp`, `.docx`/`.xlsx`/`.pptx`, `.nupkg`, `.vsix` | ❌ | All zip containers. Cheap to add if "archive" is interpreted broadly. |
| `.crx` | ❌ | Chrome extension: a zip with a prepended header. `unzip` usually copes (it scans for the EOCD); `7z` definitely does. Good edge case. |
| `.gem` | ❌ | tar wrapper around `data.tar.gz` + `metadata.gz`; needs a nested pass like `.deb`. |
| `.001`, `.part1.rar`, `.r00`, `.z01` | ✅/❌ | Multi-volume (see M7). |
| `.lzo`/`.tar.lzo`, `.lrz`/`.tar.lrz`, `.zpaq`, `.sz`/`.tar.sz`, `.lha`/`.lzh`, `.iso`, `.msi` | ❌ | No creators/tools here. `.lhz`/`.lha` and `.msi` are common enough to be worth a dispatch row if the tools are installed. |
| `.ar`, `.a` | ✅ via `.deb` | §6 uses `ar` for `.deb` but exposes no `.ar` row. |

---

## Test-plan gaps (spec §10)

§10 covers zip / 7z / rar / tar.gz / recursion / single-file / wrapper. Uncovered
by the plan, all subsequently given fixtures:

- ~25 of the dispatch rows: `.tar.lz4`, `.tar.zma`/`.tlz`, `.tar.Z`, `.tar.lz`,
  `.tar.br`, `.tar.bz`, the eight single-file compressors, `.zlib`, `.cpio`,
  `.obscpio`, `.rpm`, both `.deb` flavours, `.cab`, `.exe`, and every zip alias.
- Cross-cutting behaviours: AES zip (**C4**), mixed zip partial extraction
  (**M5**), 7z corrupt-vs-wrong-password (**C3**), `-F` over a pre-existing
  directory (**C2**), empty candidate list (**M1**), BOM / CRLF / comment password
  files (**M2/M3**), traversal & symlink safety (**C5**), name collision (**M12**),
  multi-volume invisibility (**M7**), wrapper re-source (**C6**), and `-R` with
  zero archives (**M11**).
- `manifest.json` is designed to drive this data-driven — one test per entry,
  branching on `kind` and `expect`.

---

## Open questions

1. Should `.zip` be handled by `7z` as the primary engine? It resolves C4, and
   unifies the exit-code/retry model, at the cost of making `7z` mandatory for the
   most common format.
2. Should `-F` be permitted together with `-p`/`-P` at all (C2)?
3. Should password files support `#` comments (M2)? This is a real fork: a
   password legitimately starting with `#` would be unreachable.
4. Is `.zlib` (raw zlib stream) worth keeping? It has no filename and is
   vanishingly rare as a standalone user artifact.
5. Should `-R` gain `--max-depth` and/or opt-in symlink following? `pathlib.rglob`
   does not descend into symlinked directories, which is the safe default but
   undocumented.

---

## Fixture status

`tests/fixtures/` — 79 usable fixtures, 10 declared-unavailable, 0 failures.
`python3 tests/fixtures/make_fixtures.py` regenerates; `manifest.json` is the
machine-readable matrix (including the per-fixture libarchive capability fields
`la_read`/`la_raw`/`la_note`). See `tests/fixtures/README.md` for the password map
and the libarchive summary table. Unable to generate on this host: **rar** (no
creator — `unrar` is present for extraction), **lzo**, **lrz**, **zpaq**, **sz**,
**lha**.

Related: `docs/findings/plan-review-extract-password-recursive.md` covers
plan-internal test/implementation contradictions (split-volume regex, handler
error classification, wrapper-test fixture). The two documents are complementary:
that one reviews the plan's own gates, this one covers the format/toolchain
reality those gates run against.
