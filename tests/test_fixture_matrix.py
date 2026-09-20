"""Fixture-driven conformance matrix for ``extract.py``.

Data source: ``tests/fixtures/manifest.json`` (see ``tests/fixtures/README.md``).

Until ``zsh/bin/extract.py`` exists every test here skips, so the module is inert
during Tasks A-E and becomes the cross-cutting RED harness for Task F/Z. It is
deliberately self-contained: it does **not** use ``tests/conftest.py`` (Task A owns
that file) and derives all paths from ``__file__``.

Assertions encode measured toolchain behaviour, not assumptions — see
``docs/findings/extract-password-recursive-spec-review.md``. Two cases are marked
``xfail`` where the desired behaviour is a *finding* rather than a plan
requirement, so they inform without blocking.
"""
from __future__ import annotations

import json
import os
import shutil
import signal
import subprocess
import sys
from pathlib import Path

import pytest

TESTS_DIR = Path(__file__).resolve().parent
FIXTURES = TESTS_DIR / "fixtures"
REPO_ROOT = TESTS_DIR.parent
# Overridable so Task Z can point the matrix at a staging build (and so the
# harness can be exercised with a stub while bin/extract.py is still absent).
CLI = Path(os.environ.get("EXTRACT_CLI") or (REPO_ROOT / "bin" / "extract.py"))
MANIFEST = FIXTURES / "manifest.json"
PASSWORDS = FIXTURES / "passwords"

PAYLOAD_A = b"fixture payload A\n"
SENTINEL = b"pre-existing\n"

pytestmark = pytest.mark.skipif(
    not CLI.is_file(),
    reason="zsh/bin/extract.py not implemented yet (plan Task F)",
)

if not MANIFEST.is_file():  # pragma: no cover - misconfigured checkout
    pytest.skip(
        f"fixture manifest missing; run: python3 {FIXTURES / 'make_fixtures.py'}",
        allow_module_level=True,
    )

META: list[dict] = json.loads(MANIFEST.read_text())["fixtures"]


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #
def select(kind=None, expect=None, encryption=None, available=True):
    out = []
    for m in META:
        if m["available"] is not available:
            continue
        if kind is not None and m["kind"] not in kind:
            continue
        if expect is not None and m["expect"] not in expect:
            continue
        if encryption is not None and m["encryption"] != encryption:
            continue
        out.append(m)
    return out


def ids(cases):
    return [c["path"] for c in cases]


def by_name(name: str) -> dict:
    for m in META:
        if m["path"].endswith("/" + name):
            return m
    raise KeyError(f"no fixture named {name}")


def stage(meta: dict, tmp_path: Path) -> tuple[Path, Path]:
    """Copy one fixture into a private dir. Returns (workdir, archive_path)."""
    work = tmp_path / "work"
    work.mkdir()
    src = FIXTURES / meta["path"]
    dst = work / src.name
    if src.is_dir():
        shutil.copytree(src, dst)
    else:
        shutil.copy2(src, dst)
    return work, dst


def entries(work: Path, archive: Path) -> list[str]:
    """Everything in `work` other than the archive itself."""
    return sorted(p.name for p in work.iterdir() if p.name != archive.name)


def run_extract(args, cwd, timeout=60):
    """Run the CLI in its own process group.

    `start_new_session` + `killpg` matter: Info-ZIP `unzip` reads a password from
    `/dev/tty` and ignores SIGTERM, so a plain `subprocess.run(timeout=...)` can
    leave an unkillable child (findings C1).
    """
    proc = subprocess.Popen(
        [sys.executable, str(CLI), *args],
        cwd=str(cwd),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        errors="replace",
        start_new_session=True,
    )
    try:
        out, err = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
        except ProcessLookupError:  # pragma: no cover
            pass
        proc.communicate()
        pytest.fail(
            f"extract.py did not finish within {timeout}s: {' '.join(args)}\n"
            "See findings C1 (unzip prompts on /dev/tty and ignores SIGTERM)."
        )
    return proc.returncode, out, err


# --------------------------------------------------------------------------- #
# plain extraction, one fixture per format / every zip alias
# --------------------------------------------------------------------------- #
# Formats the spec's §6 dispatch table does NOT cover. They are findings (see the
# review doc), not plan requirements, so they are asserted as xfail rather than
# blocking Task Z.
BEYOND_SPEC = {
    "archives/plain/plain.tar.br",
    "archives/plain/plain.tar.bz",
    "archives/plain/plain.tar.Z",
    "archives/plain/plain.tar.z",
    "archives/plain/plain.txt.br",
    "archives/plain/plain.txt.zstd",
}

PLAIN = [m for m in select(kind={"tar", "zip", "7z", "other", "package"},
                           expect={"extract"})
         if m["encryption"] is None
         and m["path"] not in BEYOND_SPEC
         and not m["path"].endswith("-dash.tar")]


@pytest.mark.parametrize("meta", PLAIN, ids=ids(PLAIN))
def test_plain_extracts(meta, tmp_path):
    work, archive = stage(meta, tmp_path)
    rc, out, err = run_extract([archive.name], work)
    assert rc == 0, f"{meta['path']} exit={rc}\nstdout:{out}\nstderr:{err}"
    assert entries(work, archive), f"{meta['path']}: nothing was extracted"
    assert archive.exists(), "a successful extraction must leave the source in place"


SINGLE = [m for m in select(kind={"single"}, expect={"extract"})
          if m["path"] not in BEYOND_SPEC]


@pytest.mark.parametrize("meta", SINGLE, ids=ids(SINGLE))
def test_single_file_decompresses(meta, tmp_path):
    work, archive = stage(meta, tmp_path)
    rc, out, err = run_extract([archive.name], work)
    assert rc == 0, f"{meta['path']} exit={rc}\nstdout:{out}\nstderr:{err}"
    produced = [p for p in work.rglob("*") if p.is_file() and p != archive]
    assert any(p.stat().st_size for p in produced), \
        f"{meta['path']}: no non-empty output file (single-file formats emit a FILE)"


def test_gz_payload_is_exact(tmp_path):
    """A bare .gz must decompress to the original bytes, not the gzip stream."""
    meta = by_name("plain.txt.gz")
    work, archive = stage(meta, tmp_path)
    rc, _, err = run_extract([archive.name], work)
    assert rc == 0, err
    produced = [p for p in work.rglob("*") if p.is_file() and p != archive]
    assert any(p.read_bytes() == PAYLOAD_A for p in produced), \
        f"expected {PAYLOAD_A!r} among {[p.name for p in produced]}"


# --------------------------------------------------------------------------- #
# passwords
# --------------------------------------------------------------------------- #
ENCRYPTED = [m for m in META
             if m["available"] and m["encryption"]
             and m["kind"] in {"zip", "7z", "rar"}
             and m["expect"] in {"extract", "partial-on-wrong-password"}]


@pytest.mark.parametrize("meta", ENCRYPTED, ids=ids(ENCRYPTED))
def test_password_list_decrypts(meta, tmp_path):
    """One shared -P list contains every fixture password, after decoys."""
    work, archive = stage(meta, tmp_path)
    rc, out, err = run_extract(["-P", str(PASSWORDS / "passwords.txt"), archive.name], work)
    assert rc == 0, f"{meta['path']} exit={rc}\nstdout:{out}\nstderr:{err}"
    assert entries(work, archive), f"{meta['path']}: decrypted but nothing extracted"
    assert meta["password"] not in out and meta["password"] not in err, \
        "the password must never be logged (spec §8.3)"


@pytest.mark.parametrize("meta", ENCRYPTED, ids=ids(ENCRYPTED))
def test_all_wrong_passwords_preserve_archive(meta, tmp_path):
    """-r must not delete an archive whose password was never found."""
    work, archive = stage(meta, tmp_path)
    rc, out, err = run_extract(
        ["-P", str(PASSWORDS / "passwords_wrong.txt"), "-r", archive.name], work
    )
    assert rc == 1, f"{meta['path']} exit={rc}\nstdout:{out}\nstderr:{err}"
    assert archive.exists(), "-r removed an archive that failed to extract"
    # Temp-dir orchestration must leave no partial output behind. A naive
    # in-place implementation leaves the plaintext members of enc_mixed.zip here
    # (findings C2/M5).
    assert entries(work, archive) == [], \
        f"{meta['path']}: partial output left behind: {entries(work, archive)}"


def test_encrypted_without_candidates_does_not_hang(tmp_path):
    """Regression test for findings C1: one encrypted archive must not wedge the run."""
    meta = by_name("enc.7z")
    work, archive = stage(meta, tmp_path)
    rc, out, err = run_extract([archive.name], work, timeout=45)
    assert rc == 1, f"expected a clean per-archive failure, got exit={rc}"
    assert archive.exists()


def test_aes256_zip_decrypts(tmp_path):
    """Canary for the chain: Info-ZIP unzip cannot read AES (findings C4)."""
    meta = by_name("enc_aes256.zip")
    work, archive = stage(meta, tmp_path)
    rc, out, err = run_extract(["-p", meta["password"], archive.name], work)
    assert rc == 0, (
        f"AES-256 zip failed (exit={rc}). unzip 6.00 exits 81 with "
        f"'need PK compat' — .zip must route to libarchive-c or the 7z CLI.\n"
        f"stdout:{out}\nstderr:{err}"
    )
    assert entries(work, archive)


PASSWORD_FILE_CASES = [
    ("passwords_bom.txt", "enc_zipcrypto_infozip.zip", True),
    ("passwords_crlf.txt", "enc_zipcrypto_infozip.zip", True),
    ("passwords_padded.txt", "enc_zipcrypto_infozip.zip", True),
    ("passwords_symbols.txt", "enc_spacepass.7z", True),
    ("passwords_with_comments.txt", "enc_zipcrypto_infozip.zip", True),
    ("passwords_empty.txt", "enc_zipcrypto_infozip.zip", False),
]


@pytest.mark.parametrize("pwfile,archive_name,should_succeed", PASSWORD_FILE_CASES,
                         ids=[c[0] for c in PASSWORD_FILE_CASES])
def test_password_file_parsing(pwfile, archive_name, should_succeed, tmp_path):
    """spec §7.1 plus findings M2/M3: BOM, CRLF, trimming, dedupe, comments."""
    meta = by_name(archive_name)
    work, archive = stage(meta, tmp_path)
    rc, out, err = run_extract(["-P", str(PASSWORDS / pwfile), archive.name], work)
    assert (rc == 0) is should_succeed, \
        f"{pwfile} -> exit={rc}\nstdout:{out}\nstderr:{err}"


def test_password_and_password_file_conflict(tmp_path):
    meta = by_name("enc_zipcrypto_infozip.zip")
    work, archive = stage(meta, tmp_path)
    rc, _, _ = run_extract(
        ["-p", "x", "-P", str(PASSWORDS / "passwords.txt"), archive.name], work
    )
    assert rc == 2, "spec §5: -p and -P together is a usage error (exit 2)"


# --------------------------------------------------------------------------- #
# recursion
# --------------------------------------------------------------------------- #
def _stage_tree(tmp_path: Path) -> Path:
    work = tmp_path / "work"
    work.mkdir()
    shutil.copytree(FIXTURES / "archives/tree", work / "tree")
    return work / "tree"


TREE_TARGETS = ["a/one", "a/one_enc", "a/pkg", "a/outer_with_inner",
                "names/with space", "names/UPPER", "names/-dash"]


def test_recursive_extracts_in_place(tmp_path):
    tree = _stage_tree(tmp_path)
    rc, out, err = run_extract(["-R", "-P", str(PASSWORDS / "passwords.txt"), "."], tree)
    assert rc == 0, f"exit={rc}\nstdout:{out}\nstderr:{err}"
    for rel in TREE_TARGETS:
        assert (tree / rel).exists(), f"{rel} was not extracted next to its archive"
    # The pre-existing target must be skipped, not clobbered.
    assert (tree / "b/c/two/SENTINEL-do-not-delete").read_bytes() == SENTINEL


def test_recursive_is_rerunnable(tmp_path):
    tree = _stage_tree(tmp_path)
    run_extract(["-R", "-P", str(PASSWORDS / "passwords.txt"), "."], tree)
    rc, out, err = run_extract(["-R", "-P", str(PASSWORDS / "passwords.txt"), "."], tree)
    assert rc == 0, f"skips must not fail the run\nstdout:{out}\nstderr:{err}"
    assert "skip" in (out + err).lower()
    assert (tree / "b/c/two/SENTINEL-do-not-delete").exists()


def test_force_does_not_wipe_unrelated_files(tmp_path):
    """-F reuses an existing dir; it must not delete what it did not create (C2)."""
    tree = _stage_tree(tmp_path)
    rc, out, err = run_extract(
        ["-R", "-F", "-P", str(PASSWORDS / "passwords.txt"), "."], tree
    )
    assert rc == 0, f"exit={rc}\nstdout:{out}\nstderr:{err}"
    sentinel = tree / "b/c/two/SENTINEL-do-not-delete"
    assert sentinel.exists(), "-F deleted a pre-existing file it did not create"
    assert sentinel.read_bytes() == SENTINEL


# --------------------------------------------------------------------------- #
# -r semantics and safety
# --------------------------------------------------------------------------- #
def test_remove_deletes_archive_after_success(tmp_path):
    meta = by_name("plain.tar.gz")
    work, archive = stage(meta, tmp_path)
    rc, _, err = run_extract(["-r", archive.name], work)
    assert rc == 0, err
    assert not archive.exists(), "-r should remove the archive after success"


@pytest.mark.parametrize("name", ["traversal.tar", "traversal.zip", "symlink.tar"])
def test_traversal_cannot_escape_target(name, tmp_path):
    """Findings C5: refusing is fine, sanitising is fine, escaping is not."""
    escaped_rel = tmp_path / "escape.txt"
    escaped_abs = Path("/tmp/extract_fixture_absolute.txt")
    escaped_abs.unlink(missing_ok=True)
    try:
        work = tmp_path / "work"
        work.mkdir()
        shutil.copy2(FIXTURES / "archives/edge" / name, work / name)
        rc, out, err = run_extract([name], work, timeout=45)
        assert not escaped_rel.exists(), f"{name} wrote outside the target directory"
        assert not escaped_abs.exists(), f"{name} wrote to an absolute path"
        # Non-vacuous: either it refused (non-zero) or it produced sanitised output.
        assert rc != 0 or entries(work, work / name), \
            f"{name}: neither refused nor extracted anything"
    finally:
        escaped_abs.unlink(missing_ok=True)


def test_target_name_collides_with_regular_file(tmp_path):
    """Findings M12: refuse cleanly, never clobber the existing file."""
    work = tmp_path / "work"
    (work / "collision").mkdir(parents=True)
    shutil.copytree(FIXTURES / "archives/edge/collision",
                    work / "collision", dirs_exist_ok=True)
    existing = work / "collision/f"
    before = existing.read_bytes()
    rc, out, err = run_extract(["f.tar.gz"], work / "collision")
    assert rc == 1, f"exit={rc}\nstdout:{out}\nstderr:{err}"
    assert existing.read_bytes() == before, "the existing regular file was clobbered"


def test_collapse_single_top_level_dir(tmp_path):
    meta = by_name("plain.topdir.tar.gz")
    work, archive = stage(meta, tmp_path)
    rc, _, err = run_extract([archive.name], work)
    assert rc == 0, err
    assert (work / "plain.topdir" / "inner.txt").is_file(), \
        "a lone top-level directory must be collapsed up (spec §5.1)"


def test_leading_dash_filename(tmp_path):
    work = tmp_path / "work"
    work.mkdir()
    shutil.copy2(FIXTURES / "archives/tree/names/-dash.tar", work / "-dash.tar")
    rc, out, err = run_extract(["--", "-dash.tar"], work)
    assert rc == 0, f"exit={rc}\nstdout:{out}\nstderr:{err}"


# --------------------------------------------------------------------------- #
# corrupt input
# --------------------------------------------------------------------------- #
ERRORS = [m for m in select(expect={"error"}) if "collision" not in m["path"]]


@pytest.mark.parametrize("meta", ERRORS, ids=ids(ERRORS))
def test_corrupt_input_fails_cleanly(meta, tmp_path):
    work, archive = stage(meta, tmp_path)
    rc, out, err = run_extract([archive.name], work, timeout=45)
    assert rc in (1, 2), f"{meta['path']} exit={rc}\nstdout:{out}\nstderr:{err}"
    assert "Traceback" not in err, f"{meta['path']} crashed instead of reporting"
    assert archive.exists()


# --------------------------------------------------------------------------- #
# known gaps — documented, non-blocking
# --------------------------------------------------------------------------- #
@pytest.mark.xfail(strict=False,
                   reason="findings: format absent from spec §6 (brotli, .tar.bz, "
                          "uppercase/compound .Z, .zstd). Included so the gap stays visible.")
@pytest.mark.parametrize("meta", [m for m in META
                                  if m["path"] in BEYOND_SPEC and m["available"]],
                         ids=[m["path"] for m in META if m["path"] in BEYOND_SPEC])
def test_beyond_spec_formats(meta, tmp_path):
    work, archive = stage(meta, tmp_path)
    rc, out, err = run_extract([archive.name], work, timeout=45)
    assert rc == 0, f"{meta['path']} exit={rc}\nstdout:{out}\nstderr:{err}"


@pytest.mark.xfail(strict=False,
                   reason="findings M9: Alpine .apk is a tar.gz, Android .apk is a "
                          "zip; spec maps .apk to unzip only, so this needs magic-byte sniffing")
def test_alpine_apk_is_a_tar_gz(tmp_path):
    meta = by_name("alpine.apk")
    work, archive = stage(meta, tmp_path)
    rc, _, err = run_extract([archive.name], work)
    assert rc == 0, err


@pytest.mark.xfail(strict=False,
                   reason="findings M7: no spec extension matches .001, and libarchive "
                          "cannot read multi-volume 7z (Seek error); the 7z CLI can")
def test_multivolume_7z_first_volume(tmp_path):
    meta = by_name("enc_split.7z.001")
    work = tmp_path / "work"
    work.mkdir()
    # All volumes must be present, not just .001.
    for vol in sorted((FIXTURES / "archives/encrypted").glob("enc_split.7z.*")):
        shutil.copy2(vol, work / vol.name)
    rc, _, err = run_extract(["-p", meta["password"], "enc_split.7z.001"], work)
    assert rc == 0, err
