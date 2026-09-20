# extract.py test fixtures

Archive and password fixtures for `tests/test_extract.py` (the `extract.py`
password/recursive extraction tool, spec:
`docs/specs/2026-09-19-extract-password-recursive-design.md`).

## Layout

| Path | What it is |
|------|-----------|
| `make_fixtures.py` | Regenerates everything. Idempotent; asserts magic bytes per format. |
| `manifest.json` | Machine-readable expectation for every fixture (format, kind, password, expect, availability). Drive the test suite from this. |
| `archives/plain/` | Unencrypted fixtures, one per format + extension-per-alias probes. |
| `archives/encrypted/` | Password-bearing fixtures (zip / 7z) and multi-volume probes. |
| `archives/tree/` | Directory tree for `-R` tests: nested archives, a pre-extracted target, awkward names. |
| `archives/edge/` | Empty, truncated, path-traversal, symlink and name-collision cases. |
| `passwords/` | Password files exercising every parsing rule in spec §7.1. |
| `.gitattributes` | `* -text` — fixtures are byte-exact; EOL conversion would corrupt them. |

Regenerate with `python3 make_fixtures.py`; re-check without rewriting with
`python3 make_fixtures.py --verify`. Regeneration needs `7z`, `zip`/`unzip`,
`tar`, `gzip`, `bzip2`, `xz`, `zstd`, `lz4`, `brotli`, `gcab`, `cabextract`,
`cpio`, `ar`, `bsdtar`, `rpmbuild`.

Regeneration is *content*-stable but not byte-identical: gzip and 7z embed
creation timestamps in their headers, so re-running produces small diffs. The
committed fixtures are the source of truth for the test suite; regenerate only
when intentionally adding or changing a fixture.

## Passwords

| Fixture | Password | Notes |
|---------|----------|-------|
| `encrypted/enc_zipcrypto_infozip.zip` | `z1p-pass` | ZipCrypto, written by Info-ZIP `zip -P` |
| `encrypted/enc_zipcrypto_7z.zip` | `z1p-pass` | ZipCrypto, written by `7z -tzip -p` |
| `encrypted/enc_aes256.zip` | `aes-p4ss` | WinZip AES-256 — **unzip 6.00 cannot read this** (exit 81) |
| `encrypted/enc_mixed.zip` | `m1xed-pass` | one plaintext + one encrypted member |
| `encrypted/enc.7z` | `7z-Ünïcödé-päss` | non-ASCII password; AES, headers visible |
| `encrypted/enc_mhe.7z` | `7z-Ünïcödé-päss` | header-encrypted (`-mhe=on`) — filenames need the password |
| `encrypted/enc_solid.7z` | `7z-Ünïcödé-päss` | solid block |
| `encrypted/enc_spacepass.7z` | `sp4ce in pass!#%$ & more` | interior spaces + shell metacharacters |
| `encrypted/enc_split.7z.001` | `spl1t-pass` | multi-volume |
| `tree/a/one_enc.7z` | `tree-pass` | password inside the `-R` tree |
| `encrypted/plain_with_password_args.zip` | *(none needed)* | **not** encrypted; passwords must be ignored |

`encrypted/plain.rar`, `encrypted/enc.rar` and `enc_split.part1.rar` are declared
in `manifest.json` with `"available": false` — no `rar` creator exists on this
host (the format is proprietary and AUR-only). The generator creates them when
`rar` is on `PATH`. `unrar` *is* installed, so extraction can be tested the
moment a `.rar` fixture is dropped in.

## Password files

| File | Purpose |
|------|---------|
| `passwords.txt` | Canonical candidate list: 8 decoys first (including near-misses `z1p-pas`, `z1p-pass2`, `7z-…-päs`), then every real password. A correct match is never at index 0. |
| `passwords_wrong.txt` | Only wrong candidates — drives the all-passwords-exhausted path. |
| `passwords_padded.txt` | Blank lines, whitespace-only lines, CRLF-free; duplicates and a `  z1p-pass  ` line that must trim to a duplicate and be deduplicated. |
| `passwords_symbols.txt` | Line 1 is the exact `enc_spacepass.7z` password; also `'`, `"`, `\`, an interior tab, and `  z1p-pass  ` (trim + dedupe, end-to-end). |
| `passwords_crlf.txt` | CRLF line endings. |
| `passwords_bom.txt` | UTF-8 BOM before `z1p-pass`. |
| `passwords_with_comments.txt` | Contains `#`, `;` and `//` lines — the spec does **not** strip comments, so these become candidates. |
| `passwords_empty.txt` | No usable candidates (blank/whitespace only). |

## Expected outcomes

`manifest.json` `expect` values:

- `extract` — must succeed, contents land next to the archive.
- `collapse` — `plain.topdir.tar.gz`: single top-level dir must be hoisted up.
- `ambiguous` — `alpine.apk` is a **tar.gz**, not a zip; spec maps `.apk` to unzip.
- `unzip-unsupported` — `enc_aes256.zip`: unzip fails, 7z succeeds. Any zip
  implementation that is unzip-only silently cannot handle this file.
- `partial-on-wrong-password` — `enc_mixed.zip`: a wrong password extracts the
  plaintext member and exits 1 (not 82), leaving files behind.
- `security` — `traversal.zip`, `traversal.tar`, `symlink.tar`.
- `unsupported` — `enc_split.7z.001` (no spec entry matches `.001`), rar, lzo/lrz/zpaq.
- `error` — empty/truncated archives, and `collision/f.tar.gz` where the target
  name already exists as a regular file.
- `skip` — `tree/b/c/two` pre-exists; `-R` must skip and preserve its sentinel.

## libarchive conformance

The implementation plan (`docs/plans/extract-password-recursive_*.plan.md`) uses
**libarchive-c** as its primary engine, so `manifest.json` records per fixture what
libarchive can do: `la_read` (open and read entry data, using the fixture's
password when it has one), `la_raw` (same with `format_name='raw'`, required for
bare single-file streams) and `la_note` (the exact error when it fails).

`la_read` fails for single-file formats *by design* — they need `raw`. Measured on
this host:

| Fixtures | libarchive-c result | Consequence |
|---|---|---|
| tar family, `.zip` incl. **AES-256**, `.cab`/`.exe`, `.deb`, `.cpio`/`.obscpio`, `.tar.lz` | reads OK; decrypts ZIP/ZipCrypto/AES with `passphrase=` | primary engine handles these |
| bare single-file `.gz/.bz2/.xz/.lzma/.zst/.zstd/.lz4` | OK **only with `format_name='raw'`** | handler must enable raw |
| `enc*.7z` (incl. `-mhe`) | **`encrypted, but currently not supported`** | needs the `7z` CLI fallback |
| `enc_split.7z.001` | **`Seek error`** | needs the `7z` CLI fallback |
| `plain.rpm` | **`Unrecognized archive format`** | needs `rpm2cpio \| cpio` |
| `plain.tar.br` | **`Unrecognized archive format`** | no brotli filter → `brotli` CLI |
| `plain.txt.br`, `plain.zlib` | `raw` reports success but returns the **compressed** bytes | the trap: compare output size to input size; `br`→brotli CLI, `.zlib`→stdlib `zlib` |

## Safety

`archives/edge/traversal.{zip,tar}` and `symlink.tar` deliberately contain `../`
paths, an absolute path and a symlink to `/etc/passwd`. **Never extract these
outside a throwaway directory.** They exist to test that extraction cannot write
outside the target.
