# Design: extract — password & recursive extraction tool (`extract.py` + `extract()` wrapper)

- **Date:** 2026-09-19
- **Scope:** zsh repo (primary); optional companion change in the `ansible` repo (typer dependency)
- **Status:** draft — pending user review

## 1. Goal

Extend archive extraction with two capabilities the oh-my-zsh `extract` plugin lacks:

1. **Passwords** — pass a single password (`-p`) or a password file (`-P`) and have each encrypted archive tried against the candidates until one works.
2. **Recursion** — `-R` walks a directory tree, finds every archive, and extracts each one next to itself, preserving folder structure.

The tool is a standalone Python CLI (`extract.py`, callable from any shell) plus a thin zsh wrapper so the existing `extract` command gains the new flags while everything else continues to use the sheldon-loaded oh-my-zsh plugin unchanged.

## 2. User requirements — key decision items

Major decisions locked in during design (rationale lives in the referenced sections):

| # | Decision | Specified |
|---|---|---|
| 1 | Standalone **Python** CLI `extract.py` in `zsh/bin/` (Typer + `standard_logging`, per the standards repo), wrapped by a zsh `extract()` that keeps the sheldon plugin untouched — plain invocations use the plugin, new flags delegate to Python | §4, §9 |
| 2 | Password interface: two explicit flags — `-p/--password` (single literal) and `-P/--password-file` (candidate file); no file-vs-literal auto-detection; both together is a usage error | §5 |
| 3 | Password file format: one candidate per line; trim leading/trailing spaces+tabs only; **all symbols and interior spaces preserved verbatim**; blank lines skipped; duplicates removed | §8.1 |
| 4 | Recursion `-R/--recursive`: extract every archive below the given directories **in place, preserving folder structure**; split archives (`.partN.rar`, `.rNN`, `.7z.NNN`, `.z01`+) processed from their first volume only | §6.2 |
| 5 | Existing target dir: **skip** by default; `-F/--force` merges with file-level overwrite | §6.3 |
| 6 | `-r/--remove` destroys the original archive **only after successful extraction** | §6.4 |
| 7 | Backend selection: **capability-gated preference hierarchy**, data-driven and defensively coded so it can be re-tuned later; `python-libarchive-c` primary (API-level passphrase, no argv exposure); rar goes through `unrar` only | §7 |
| 8 | Robustness: atomic temp-dir extraction (interrupted runs leave no partial target), live tool output, status on stderr, per-archive failures reported and skipped with exit code 1 | §6.1, §8.2 |
| 9 | Explicitly declined (for the record): zip-slip traversal pre-checks; `py7zr`, `rarfile`, `pyzipper`, `dtrx`, `atool`, `patool` as dependencies; encrypted tars; parallel extraction | §12, §13 |
| 10 | **UR — data integrity:** extraction counts as successful only when the backend's per-entry CRC/checksum verification passes; integrity failures are `EXTRACT_ERROR` (no rename, no removal, archive preserved) | §6.5 |
| 11 | **UR — data preservation:** destructive actions are guarded — `-r` re-verifies the archive before deleting it, `-F` merges never prune pre-existing files, temp dirs are deleted only with an ownership marker, and no operation follows symlinks | §6.6 |

## 3. Context / current state

- `extract` today comes from the oh-my-zsh `extract` plugin (`zsh/sheldon/plugins.toml`, `[plugins.ohmyzsh-extract]`, loaded eagerly). It defines `extract()`, `alias x=extract`, and a `_extract` completion. It supports `-r/--remove` only.
- Repo conventions:
  - Executables live in `zsh/bin/`, which `zshenv` puts on `$PATH` (`$ZSH_DIR/bin`).
  - Sourced snippets live in `zsh/custom/*.zsh` (alias files, fzf config, …).
  - Hand-authored completions live in `zsh/completion/` (`$ZCOMPLETION`, first in `$FPATH`, compinit-discovered).
  - `libraries/python/standards` (submodule) provides the logging standard; `zshenv` adds `$ZSH_DIR/libraries/python/standards/python` to `PYTHONPATH` in zsh shells only.
- Standards repo (`/home/cupric/dev/standards`) mandates: **Typer** for Python CLIs (carapace completion extraction), and the **standard_logging** module for output. Both are available on this system (typer 0.27.2, click 8.3.3, Python 3.14).
- Carapace is bridged to native zsh completions (`CARAPACE_BRIDGES='zsh'` in `zshrc`), so a committed `_extract` completion is picked up for both `extract.py` and the `extract` function.
- `python-libarchive-c` (official `extra`, already installed) is available as the primary extraction backend (§7); `python-rarfile` is also installed but deliberately not adopted (see §12).

## 4. Components

| File | Role | New/Edit |
|---|---|---|
| `zsh/bin/extract.py` | Standalone Python 3 CLI (stdlib + typer + standards logging) | new |
| `zsh/custom/extract.zsh` | Wrapper: delegates `-R/-p/-P/-F` invocations to `extract.py`, otherwise calls the plugin's function | new |
| `zshrc` | One source line for the wrapper, placed **after** the sheldon eval (near the `unalias backup` line); update the stale comment at line ~144 | edit |
| `zsh/completion/_extract` | zsh completion generated from the Typer CLI (shadows the plugin's copy via `$FPATH` order) | new |
| `zsh/tests/test_extract.py` | pytest suite | new |

The sheldon plugin **stays as-is**; `extract.py` is a sibling, not a replacement.

## 5. CLI

```
extract.py [-r|--remove] [-R|--recursive] [-p TEXT|--password TEXT]
           [-P FILE|--password-file FILE] [-F|--force] PATH [PATH ...]
```

- `-r, --remove`: delete the source archive **after a successful extraction only**. With `-R` it applies per archive; a failed (all-passwords-wrong) archive is never deleted.
- `-R, --recursive`: directory arguments become roots; every archive below them is extracted in place. File arguments are still processed as single archives.
- `-p, --password TEXT`: single literal password.
- `-P, --password-file FILE`: file containing password candidates (see §8.1).
- `-F, --force`: extract even when the target directory already exists (see §6.3).
- `-p` and `-P` together is a usage error (exit 2).
- Exit codes: `0` all requested archives succeeded; `1` at least one archive failed (skips are not failures); `2` usage error.
- All of `extract.py`'s own status/diagnostic output goes to **stderr** (`standard_logging` with `use_stderr`), keeping the tool pipe-friendly; underlying tool output is streamed live (§8.2).
- Typer is the CLI framework (standards mandate). `--show-completion` (exact flag verified at implementation) generates the zsh completion in §10.

## 6. Behavior

### 6.1 Single-file mode (plugin parity)

- Target dir = archive name minus known archive extensions, e.g. `foo.tar.gz` → `foo`, `bar.2024.tgz` → `bar.2024`. Extension stripping loops (`foo.tar.gz` strips `.gz` then `.tar`), a superset of the plugin's one-level `.tar` rule.
- If the target path already exists: append a random 5-char base36 suffix (plugin behavior) — **unless** `-F`, which reuses the existing dir.
- Extraction always happens in a **sibling temp dir** named `.extract-<name>-<pid>`; only on success is it renamed to the final target, after which the collapse runs. Stale `.extract-<name>-*` dirs from interrupted runs are removed when that archive is next processed — only if they carry the ownership marker (§6.6).
- After extraction: if the target dir contains exactly one entry and it is a directory, move it up (plugin's collapse, including its 3-step rename for name collisions).

### 6.2 Recursive mode (`-R`)

- For each directory argument, walk the tree (`pathlib.rglob`, case-insensitive) matching the extension set in §7; results are sorted for deterministic order.
- **Folder structure is preserved**: each archive extracts into `archive.parent / <name-without-extensions>`, i.e. next to itself.
- **Split archives:** discovery skips all but the first volume of a set — `*.partN.rar` (N ≥ 2), `*.rNN`, `*.7z.NNN` (≥ 002), `*.z01`+ zip sidecars; when a base file and part volumes share a stem, only the first volume is extracted. Explicitly passed file arguments are always attempted regardless.
- Per-archive failure (bad passwords, corrupt archive, unsupported format) is reported via `standard_logging`, the archive is left untouched, and processing continues with the remaining archives. Final exit code is 1 if anything failed.

### 6.3 Skip vs force

- **In recursive mode**: target dir already exists + no `-F` → log "skipping: already extracted" and continue. Skips don't fail the run. This makes `-R` re-runnable.
- **In single-file mode**: an existing target dir takes the plugin's unique-suffix path instead (§6.1); it is never skipped.
- `-F` (either mode) → extraction runs in the fresh temp dir (§6.1), then its tree is **merged into the existing target with file-level overwrite**. (No subprocess overwrite flags needed — the temp dir is always fresh; only the merge overwrites.) The merge never prunes (§6.6).

### 6.4 Removal (`-r`)

- Archive deleted only after that archive's extraction succeeded **and the temp dir was renamed into place** (correct password found, or no password needed). Failure or skip → archive preserved. Deletion itself is guarded by §6.6.

### 6.5 Data integrity (UR)

- **Success requires verification:** an extraction is successful only when the backend's per-entry CRC/checksum verification passes with no corruption indicators — "bad CRC"/"checksum error" output, truncated streams, or partial-failure warnings all mean failure. A multi-entry archive with even one failing entry is a failure for the whole archive.
- Integrity failure = `EXTRACT_ERROR` (§7.3): the temp dir is discarded, the target is never created/renamed, and the archive is preserved even with `-r`.
- The atomic rename (§6.1) happens only after a clean, verified extraction — a partial tree can never become the target.
- No extra post-hoc verification pass (`unzip -t` etc.) by default; the backends already verify during extraction.

### 6.6 Destructive action safeguards (UR: data preservation)

- **`-r` archive removal:** before unlinking, re-stat the archive and confirm its size and mtime match the file that was processed; if it changed during the run (e.g. replaced by an in-flight download), abort the deletion and warn. Only the exact processed regular file is ever unlinked.
- **`-F` merge:** strictly additive-overwrite — files present in the existing target but absent from the extracted tree are **never deleted or pruned**.
- **Temp-dir cleanup:** every temp dir we create gets an ownership marker file (`.extract-owned` with pid + archive path). Cleanup paths (failed attempt, `KeyboardInterrupt`, stale sweep) delete only directories created and tracked this run; the stale sweep removes sibling dirs matching our pattern **only when they carry the marker** — a matching dir without the marker is left alone with a warning.
- **No symlink following:** deletion and merge operations never follow symlinks (a symlinked archive is unlinked, not its referent; symlinked target dirs are not entered for pruning).

## 7. Format dispatch — capability-gated backend hierarchy

Dispatch is **data-driven and defensive**: handlers and per-format preference chains are declared as data, and a generic engine walks them. Tuning the tree later (adding a backend, reordering preferences, adding a format) is a table edit, never an engine change.

### 7.1 Architecture

- **Handler registry** — each handler is a record with:
  - `name` — stable key;
  - `available()` — probe (module import or `shutil.which`); unavailable handlers are skipped with a debug log;
  - `capabilities` — the format families it serves plus password-relevant traits (e.g. libarchive: `aes_zip: false`);
  - `extract(archive, dest, passwords)` → `Result` — runs one attempt (one candidate) into a fresh temp dir, streaming output live;
  - `classify_failure(...)` — maps its own failures into the shared error classes (§7.3).
- **Chain tables** — `CHAINS: dict[family, list[handler_names]]` in preference order (§7.2); `EXTENSION_FAMILIES` maps every known extension (case-insensitive) to a family.
- **Engine** — generic `resolve(archive)`: walks the chain, skips handlers that are unavailable or incapable of the current requirement (e.g. passwords present but handler has no password support), runs the attempt, and reacts to the result class (§7.3). The engine knows nothing about specific tools; handlers own their mechanics, so new handlers plug in without touching the engine.
- **Defensive rules** (enforced for every handler):
  - subprocesses always run with **list argv, never `shell=True`** — passwords containing `$`, spaces, quotes, or `;` cannot break out;
  - every subprocess is preceded by its availability probe; if a tool is missing the archive fails with "requires <tool>" (chain first, then error);
  - unknown exit codes / unrecognizable output → `EXTRACT_ERROR` carrying the tool's last ~20 output lines for diagnosis;
  - `finally`/`KeyboardInterrupt` guarantees temp-dir cleanup;
  - handlers never write outside the temp dir and the explicitly computed target.

### 7.2 Per-format chains

| Family | Extensions | Chain (preference order) | Passwords |
|---|---|---|---|
| tar | `.tar` `.tar.gz` `.tgz` `.tar.bz2` `.tbz` `.tbz2` `.tar.xz` `.txz` `.tar.zst` `.tzst` `.tar.lz` `.tar.lz4` `.tar.lrz` `.tar.zma` `.tlz` | ① libarchive-c → ② stdlib `tarfile` (gz/bz2/xz only) → ③ subprocess `tar --zstd` / `zstdcat\|tar` / `lz4 -dc\|tar` / `lrzuntar` | no |
| zip | `.zip` `.war` `.jar` `.ear` `.sublime-package` `.ipa` `.ipsw` `.xpi` `.apk` `.aar` `.whl` | ① libarchive-c (`passphrase=`) → ② `unzip [-P]` | **yes** |
| 7z | `.7z` | ① libarchive-c (`passphrase=`, AES-capable) → ② `7z x -p` (fallback `7za`) | **yes** |
| rar | `.rar` | ① `unrar x [-p]` — **single handler by design** (libarchive's partial rar support would only add flaky duplicate attempts) | **yes** |
| rpm | `.rpm` | ① libarchive-c → ② `rpm2cpio \| cpio -id` | no |
| cpio | `.cpio` `.obscpio` | ① libarchive-c → ② `cpio -idmvF` | no |
| deb | `.deb` | fixed path: `ar` + internal engine for `control.tar.*`/`data.tar.*` (plugin parity) | no |
| single-file | `.gz` `.bz2` `.xz` `.lrz` `.lz4` `.lzma` `.z` `.zst` `.zpaq` | one handler each: `pigz`→`gunzip`, `bunzip2`, `unxz`, `lrunzip`, `lz4`, `unlzma`, `uncompress`, `unzstd`, `zpaq` | no |
| zlib | `.zlib` | stdlib `zlib.decompress` → file inside target dir | no |
| cab | `.cab` `.exe` | `cabextract` | no |

Unknown extension → error for that archive, continue.

### 7.3 Error classification (drives traversal)

| Class | Meaning | Engine action |
|---|---|---|
| `WRONG_PASSWORD` | candidate rejected | next password candidate, same handler |
| `BACKEND_UNSUPPORTED` | format/codec/encryption this handler can't do (e.g. libarchive on an AES zip) | descend to next handler in the chain, candidates restart there |
| `EXTRACT_ERROR` | corrupt/invalid data | fatal for this archive, chain stops |

## 8. Password handling

### 8.1 Candidate sources and parsing

- `-p TEXT` → single candidate.
- `-P FILE` → read as UTF-8 (`surrogateescape` fallback), then:
  - split into **lines** (handles LF and CRLF),
  - strip trailing CR/LF, then trim **leading/trailing spaces and tabs only**,
  - skip blank/whitespace-only lines,
  - **everything else preserved verbatim** — interior spaces, `$`, `\`, `%`, `#`, quotes, non-ASCII all survive,
  - duplicates removed (first occurrence kept), order preserved.
- Rationale: passwords frequently contain symbols and internal spaces; line-based parsing with edge-trim only is the robust rule. Accepted trade-off: a password that genuinely begins/ends with a space cannot be expressed (favors the common padded-lines file format).

### 8.2 Retry and success detection

- Candidates apply to the three password-capable families (§7.2). For any other format, candidates are ignored (single info log).
- Tool output is **streamed live to the terminal** while being captured (tee-style) for detection; nothing is swallowed.
- The engine runs the chain (§7); each attempt extracts into a fresh temp dir (§6.1); a failed attempt's tree is deleted wholesale, so partial output (unzip extracts non-encrypted entries before failing) never pollutes the next attempt.
- `WRONG_PASSWORD` classification per handler (drives the candidate loop):
  - libarchive-c: exception whose message matches passphrase/password phrases (case-insensitive) → next candidate.
  - `7z`/`7za`: exit 2 ("Wrong password") → next candidate.
  - `unrar`: exit 11 → next candidate.
  - `unzip`: exit 0 **and** no "incorrect password" in combined output = success (also catches partially encrypted zips); "incorrect password" present → next candidate.
  - Any other exit/output per handler → `EXTRACT_ERROR` (fatal, §7.3) — includes CRC/checksum failures (data integrity, §6.5).
- `BACKEND_UNSUPPORTED` (e.g. libarchive on an AES zip, exotic 7z codec) → descend to the next handler in the chain; candidate iteration restarts there.
- All candidates exhausted in all capable handlers → log failure, remove the temp dir; the target is never created, archive preserved even with `-r`.
- On success, log which candidate index matched (never the password itself).

### 8.3 Security notes

- Passwords reach argv **only** on the two remaining subprocess paths: AES-encrypted zip (`unzip -P`) and rar (`unrar -p`) — visible in `/proc/<pid>/cmdline` while those processes run; inherent to those tools' only non-interactive interface. The primary libarchive-c path passes the passphrase via API (no argv exposure), covering 7z and ZipCrypto/unencrypted zips.
- The password value is never written to logs; diagnostic dumps (§7.1) redact any line matching a candidate.

## 9. Wrapper (`custom/extract.zsh`)

Sourced in `zshrc` **after** `eval "$_sheldon_output"`:

```zsh
if (( $+functions[extract] )); then
  functions[extract_orig]="${functions[extract]}"
fi
extract() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      -R|--recursive|-p|--password|-P|--password-file|-F|--force)
        python3 "${ZBIN}/extract.py" "$@" && return 0 || return $?
        ;;
    esac
  done
  if (( $+functions[extract_orig] )); then
    extract_orig "$@"
  else
    print -u2 "extract: plugin not loaded and extract.py flags not given"
    return 1
  fi
}
```

- Flags are matched as **exact tokens** — filenames containing the strings (`-password-hints.txt`) never match; flag order/position doesn't matter. A file literally named `-p` would delegate, but `extract.py` honors `--`, so the outcome is still correct.
- Plugin's `x` alias still resolves to `extract` → wrapper → plugin. Completions keep working (§10).

## 10. Completion

- Generate the zsh completion from the Typer CLI and commit it to `zsh/completion/_extract` (re-generated whenever flags change; the file notes the generating command).
- `$ZCOMPLETION` precedes the plugin's dir in `$FPATH`, so the local file wins and covers the new flags; carapace's zsh bridge picks it up.

## 11. Testing

pytest suite in `zsh/tests/test_extract.py`, invoking `extract.py` via subprocess against tmpdirs (mirrors `libraries/python/standards/python/test_standard_logging.py` conventions):

1. **Password file parsing** — symbols, interior spaces, CRLF, padding, blank lines, dedupe, order.
2. **Encrypted zip** (created with `7z a -p…`): correct `-p`; wrong-then-correct `-P` list (2nd candidate); all-wrong → archive preserved even with `-r`.
3. **Encrypted 7z** — same matrix.
4. **rar** — integration tests run only when a rar creator is available; otherwise skipped (noted).
5. **tar.gz regression** — stdlib tarfile path, collapse behavior.
6. **Recursion** — nested tree, structure preserved, re-run skips, `-F` re-extracts (file-level overwrite merge), `-r` removes per archive, split-volume filtering (unit test on the discovery filter with fake filenames; integration only where a volume-creating tool exists).
7. **Single-file** — unique suffix on existing target, `-F` reuse.
8. **Wrapper** — `zsh -c` with mocked `extract`/`extract_orig`: delegation for each new flag, fall-through otherwise.
9. **Temp-dir robustness** — failed extraction leaves no target dir; stale `.extract-*` dirs cleaned on the next run (simulated interrupted run); live output reaches the terminal while detection still works.
10. **Dispatch engine** — parametrized over chains with mocked handlers: availability skip, capability gate (passwords vs handler capability), `WRONG_PASSWORD` keeps the handler, `BACKEND_UNSUPPORTED` descends, `EXTRACT_ERROR` fails; a registry edit (added/reordered handler) works with zero engine changes. Classification unit tests per handler; subprocess safety (list argv, no shell) and the missing-tool "requires <tool>" path.
11. **Integrity & safeguards** — corrupted archive (bad CRC) → `EXTRACT_ERROR`, no rename, archive preserved with `-r`; `-r` aborts when the archive changed during the run; `-F` merge never prunes pre-existing files; stale temp dir without marker is left alone, with marker is cleaned; symlink non-following.

## 12. Trade-offs / risks

- `python-libarchive-c` as primary backend (official `extra`, installed): one API covers tar/zip/7z/rpm/cpio with API-level passphrase (no argv exposure). Gaps — AES-encrypted zip and encrypted RAR5 — keep the `unzip`/`unrar` subprocess paths alive; the chain design (§7) makes swapping backends a table edit.
- `unrar x` without the plugin's `-ad` flag: `-ad` nests contents under an archive-named subdir inside the target dir; dropping it yields `target/contents` directly. Deliberate deviation for cleaner recursion results.
- rar is a **single-handler chain** (`unrar` only): libarchive's partial rar support would add flaky duplicate attempts; predictability wins. Revisitable as a one-line chain edit if libarchive's rar support matures.
- stdlib `tarfile` remains the zero-dep fallback tier for the tar family when libarchive-c is unavailable.
- §6.1's extract-to-temp-then-collapse mirrors `atool`'s design (prior art, not a dependency).
- `pyzipper` (AUR-only) would remove the last zip argv case (AES zips); not adopted — noted as a future chain insertion point.
- `typer` is a runtime dependency (vs stdlib argparse). Mandated by the standards repo; installed on this system. Companion note: ensure `python-typer` in the ansible role's zsh provisioning (tracked separately, not in this repo).

## 13. Out of scope

- Encrypted `tar`-based archives (tools have no native support).
- Parallel extraction across archives.
- Auto-detecting encrypted archives and prompting interactively.
- Any change to the sheldon plugin or its `_extract` completion source.
