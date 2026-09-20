# Design: extract — password & recursive extraction tool (`extract.py` + `extract()` wrapper)

- **Date:** 2026-09-19
- **Scope:** zsh repo (primary); optional companion change in the `ansible` repo (typer dependency)
- **Status:** draft — pending user review

## 1. Goal

Extend archive extraction with two capabilities the oh-my-zsh `extract` plugin lacks:

1. **Passwords** — pass a single password (`-p`) or a password file (`-P`) and have each encrypted archive tried against the candidates until one works.
2. **Recursion** — `-R` walks a directory tree, finds every archive, and extracts each one next to itself, preserving folder structure.

The tool is a standalone Python CLI (`extract.py`, callable from any shell) plus a thin zsh wrapper so the existing `extract` command gains the new flags while everything else continues to use the sheldon-loaded oh-my-zsh plugin unchanged.

## 2. Context / current state

- `extract` today comes from the oh-my-zsh `extract` plugin (`zsh/sheldon/plugins.toml`, `[plugins.ohmyzsh-extract]`, loaded eagerly). It defines `extract()`, `alias x=extract`, and a `_extract` completion. It supports `-r/--remove` only.
- Repo conventions:
  - Executables live in `zsh/bin/`, which `zshenv` puts on `$PATH` (`$ZSH_DIR/bin`).
  - Sourced snippets live in `zsh/custom/*.zsh` (alias files, fzf config, …).
  - Hand-authored completions live in `zsh/completion/` (`$ZCOMPLETION`, first in `$FPATH`, compinit-discovered).
  - `libraries/python/standards` (submodule) provides the logging standard; `zshenv` adds `$ZSH_DIR/libraries/python/standards/python` to `PYTHONPATH` in zsh shells only.
- Standards repo (`/home/cupric/dev/standards`) mandates: **Typer** for Python CLIs (carapace completion extraction), and the **standard_logging** module for output. Both are available on this system (typer 0.27.2, click 8.3.3, Python 3.14).
- Carapace is bridged to native zsh completions (`CARAPACE_BRIDGES='zsh'` in `zshrc`), so a committed `_extract` completion is picked up for both `extract.py` and the `extract` function.

## 3. Components

| File | Role | New/Edit |
|---|---|---|
| `zsh/bin/extract.py` | Standalone Python 3 CLI (stdlib + typer + standards logging) | new |
| `zsh/custom/extract.zsh` | Wrapper: delegates `-R/-p/-P/-F` invocations to `extract.py`, otherwise calls the plugin's function | new |
| `zshrc` | One source line for the wrapper, placed **after** the sheldon eval (near the `unalias backup` line); update the stale comment at line ~144 | edit |
| `zsh/completion/_extract` | zsh completion generated from the Typer CLI (shadows the plugin's copy via `$FPATH` order) | new |
| `zsh/tests/test_extract.py` | pytest suite | new |

The sheldon plugin **stays as-is**; `extract.py` is a sibling, not a replacement.

## 4. CLI

```
extract.py [-r|--remove] [-R|--recursive] [-p TEXT|--password TEXT]
           [-P FILE|--password-file FILE] [-F|--force] PATH [PATH ...]
```

- `-r, --remove`: delete the source archive **after a successful extraction only**. With `-R` it applies per archive; a failed (all-passwords-wrong) archive is never deleted.
- `-R, --recursive`: directory arguments become roots; every archive below them is extracted in place. File arguments are still processed as single archives.
- `-p, --password TEXT`: single literal password.
- `-P, --password-file FILE`: file containing password candidates (see §7.1).
- `-F, --force`: extract even when the target directory already exists (see §5.3).
- `-p` and `-P` together is a usage error (exit 2).
- Exit codes: `0` all requested archives succeeded; `1` at least one archive failed (skips are not failures); `2` usage error.
- All of `extract.py`'s own status/diagnostic output goes to **stderr** (`standard_logging` with `use_stderr`), keeping the tool pipe-friendly; underlying tool output is streamed live (§7.2).
- Typer is the CLI framework (standards mandate). `--show-completion` (exact flag verified at implementation) generates the zsh completion in §9.

## 5. Behavior

### 5.1 Single-file mode (plugin parity)

- Target dir = archive name minus known archive extensions, e.g. `foo.tar.gz` → `foo`, `bar.2024.tgz` → `bar.2024`. Extension stripping loops (`foo.tar.gz` strips `.gz` then `.tar`), a superset of the plugin's one-level `.tar` rule.
- If the target path already exists: append a random 5-char base36 suffix (plugin behavior) — **unless** `-F`, which reuses the existing dir.
- Extraction always happens in a **sibling temp dir** named `.extract-<name>-<pid>`; only on success is it renamed to the final target, after which the collapse runs. Stale `.extract-<name>-*` dirs from interrupted runs are removed when that archive is next processed.
- After extraction: if the target dir contains exactly one entry and it is a directory, move it up (plugin's collapse, including its 3-step rename for name collisions).

### 5.2 Recursive mode (`-R`)

- For each directory argument, walk the tree (`pathlib.rglob`, case-insensitive) matching the extension set in §6; results are sorted for deterministic order.
- **Folder structure is preserved**: each archive extracts into `archive.parent / <name-without-extensions>`, i.e. next to itself.
- **Split archives:** discovery skips all but the first volume of a set — `*.partN.rar` (N ≥ 2), `*.rNN`, `*.7z.NNN` (≥ 002), `*.z01`+ zip sidecars; when a base file and part volumes share a stem, only the first volume is extracted. Explicitly passed file arguments are always attempted regardless.
- Per-archive failure (bad passwords, corrupt archive, unsupported format) is reported via `standard_logging`, the archive is left untouched, and processing continues with the remaining archives. Final exit code is 1 if anything failed.

### 5.3 Skip vs force

- **In recursive mode**: target dir already exists + no `-F` → log "skipping: already extracted" and continue. Skips don't fail the run. This makes `-R` re-runnable.
- **In single-file mode**: an existing target dir takes the plugin's unique-suffix path instead (§5.1); it is never skipped.
- `-F` (either mode) → extraction runs in the fresh temp dir (§5.1), then its tree is **merged into the existing target with file-level overwrite**. (No subprocess overwrite flags needed — the temp dir is always fresh; only the merge overwrites.)

### 5.4 Removal (`-r`)

- Archive deleted only after that archive's extraction succeeded **and the temp dir was renamed into place** (correct password found, or no password needed). Failure or skip → archive preserved.

## 6. Format dispatch

Port of the plugin's table. "Stdlib" means Python's `tarfile`/`zlib`/`lzma` modules; "subprocess" mirrors the plugin's command.

| Extensions | Method | Password? |
|---|---|---|
| `.tar.gz` `.tgz` `.tar.bz2` `.tbz` `.tbz2` `.tar.xz` `.txz` `.tar` | stdlib `tarfile` | no |
| `.tar.zma` `.tlz` | subprocess `lzcat \| tar` (lzma_alone unsupported by tarfile) | no |
| `.tar.zst` `.tzst` | subprocess `tar --zstd`, fallback `zstdcat \| tar` | no |
| `.tar.lz` | subprocess `tar xvf` (requires tar lzip support, as plugin) | no |
| `.tar.lz4` | subprocess `lz4 -dc \| tar` | no |
| `.tar.lrz` | subprocess `lrzuntar` | no |
| `.gz` | subprocess `pigz -cdk` (fallback `gunzip -ck`) → file inside target dir | no |
| `.bz2` `.xz` `.lrz` `.lz4` `.lzma` `.z` `.zst` | subprocess single-file decompress into target dir | no |
| `.zip` `.war` `.jar` `.ear` `.sublime-package` `.ipa` `.ipsw` `.xpi` `.apk` `.aar` `.whl` | subprocess `unzip` (`-P` when passwords given) | **yes** |
| `.7z` | subprocess `7z x` (fallback `7za`), `-p` when passwords given | **yes** |
| `.rar` | subprocess `unrar x -p` (no `-ad`; see §11) | **yes** |
| `.rpm` | subprocess `rpm2cpio \| cpio -id` | no |
| `.deb` | subprocess `ar` + internal engine for `control.tar.*`/`data.tar.*` (plugin parity) | no |
| `.cab` `.exe` | subprocess `cabextract` | no |
| `.cpio` `.obscpio` | subprocess `cpio -idmvF` | no |
| `.zpaq` | subprocess `zpaq x` | no |
| `.zlib` | stdlib `zlib.decompress` → file inside target dir | no |

Unknown extension → error for that archive, continue.

## 7. Password handling

### 7.1 Candidate sources and parsing

- `-p TEXT` → single candidate.
- `-P FILE` → read as UTF-8 (`surrogateescape` fallback), then:
  - split into **lines** (handles LF and CRLF),
  - strip trailing CR/LF, then trim **leading/trailing spaces and tabs only**,
  - skip blank/whitespace-only lines,
  - **everything else preserved verbatim** — interior spaces, `$`, `\`, `%`, `#`, quotes, non-ASCII all survive,
  - duplicates removed (first occurrence kept), order preserved.
- Rationale: passwords frequently contain symbols and internal spaces; line-based parsing with edge-trim only is the robust rule. Accepted trade-off: a password that genuinely begins/ends with a space cannot be expressed (favors the common padded-lines file format).

### 7.2 Retry and success detection

- Candidates apply to the three password-capable families (§6). For any other format, candidates are ignored (single info log).
- Tool stdout/stderr is **streamed live to the terminal** while being captured (tee-style) for success detection; nothing is swallowed.
- For each archive, try candidates in order:
  - `7z`/`7za`: exit 0 = success; exit 2 ("Wrong password") = next candidate; any other exit = fatal for this archive (corrupt/unsupported), stop trying.
  - `unrar`: exit 0 = success; exit 11 (bad password) = next candidate; anything else = fatal for this archive.
  - `unzip`: exit 0 **and** no "incorrect password" in combined output = success (this also catches partially encrypted zips); output containing "incorrect password" = next candidate; other nonzero exits without that marker = fatal for this archive.
- Each attempt extracts into a fresh temp dir (§5.1); a failed attempt's tree is deleted wholesale, so partial output (unzip extracts non-encrypted entries before failing) never pollutes the next attempt.
- All candidates exhausted → log failure, remove the temp dir; the target is never created, archive preserved even with `-r`.
- On success, log which candidate index matched (never the password itself).

### 7.3 Security notes

- Passwords for 7z/rar/unzip pass through the tools' argv and are visible in `/proc/<pid>/cmdline` while the process runs — inherent to those tools' only non-interactive interface. Accepted limitation; documented in the script header.
- The password value is never written to logs.

## 8. Wrapper (`custom/extract.zsh`)

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
- Plugin's `x` alias still resolves to `extract` → wrapper → plugin. Completions keep working (§9).

## 9. Completion

- Generate the zsh completion from the Typer CLI and commit it to `zsh/completion/_extract` (re-generated whenever flags change; the file notes the generating command).
- `$ZCOMPLETION` precedes the plugin's dir in `$FPATH`, so the local file wins and covers the new flags; carapace's zsh bridge picks it up.

## 10. Testing

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

## 11. Trade-offs / risks

- `unrar x` without the plugin's `-ad` flag: `-ad` nests contents under an archive-named subdir inside the target dir; dropping it yields `target/contents` directly. Deliberate deviation for cleaner recursion results.
- stdlib `tarfile` replaces `tar -I pigz/pbzip2/pixz`: loses parallel decompression speed, gains portability and testability. Accepted.
- `typer` is a runtime dependency (vs stdlib argparse). Mandated by the standards repo; installed on this system. Companion note: ensure `python-typer` in the ansible role's zsh provisioning (tracked separately, not in this repo).
- Passwords in argv (see §7.3).

## 12. Out of scope

- Encrypted `tar`-based archives (tools have no native support).
- Parallel extraction across archives.
- Auto-detecting encrypted archives and prompting interactively.
- Any change to the sheldon plugin or its `_extract` completion source.
