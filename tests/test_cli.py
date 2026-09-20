"""End-to-end CLI and zsh wrapper tests (spec §5, §9)."""

import shutil
import subprocess
import tarfile
from pathlib import Path

import pytest

TESTS_DIR = Path(__file__).resolve().parent
ZSH_ROOT = TESTS_DIR.parent
BIN_SHIM = ZSH_ROOT / "bin" / "extract.py"
WRAPPER = ZSH_ROOT / "custom" / "extract.zsh"

HAS_7Z = bool(shutil.which("7z") or shutil.which("7za"))


def run_tool(*args: str, cwd: Path | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["python3", str(BIN_SHIM), *args],
        capture_output=True, text=True, cwd=str(cwd) if cwd else str(ZSH_ROOT),
    )


def make_tar(path: Path) -> None:
    src = path.parent / "src"
    src.mkdir(exist_ok=True)
    (src / "a.txt").write_text("a\n")
    with tarfile.open(path, "w:gz") as tf:
        tf.add(src / "a.txt", arcname="a.txt")


class TestCliBasics:
    def test_help_shows_flags(self):
        result = run_tool("--help")
        assert result.returncode == 0
        for flag in ("-R", "-p", "-P", "-F", "-r"):
            assert flag in result.stdout

    def test_both_passwords_is_usage_error(self, tmp_path):
        result = run_tool("-p", "x", "-P", "f", "whatever.zip")
        assert result.returncode == 2

    def test_tar_extraction(self, tmp_path):
        archive = tmp_path / "x.tar.gz"
        make_tar(archive)
        result = run_tool(str(archive))
        assert result.returncode == 0
        assert (tmp_path / "x" / "a.txt").read_text() == "a\n"

    def test_remove_flag(self, tmp_path):
        archive = tmp_path / "x.tar.gz"
        make_tar(archive)
        result = run_tool("-r", str(archive))
        assert result.returncode == 0
        assert not archive.exists()

    def test_recursion_preserves_structure_and_skips(self, tmp_path):
        (tmp_path / "one").mkdir()
        make_tar(tmp_path / "one" / "a.tar.gz")
        make_tar(tmp_path / "two.tar.gz")
        result = run_tool("-R", str(tmp_path))
        assert result.returncode == 0
        assert (tmp_path / "one" / "a" / "a.txt").read_text() == "a\n"
        assert (tmp_path / "two" / "a.txt").read_text() == "a\n"
        second = run_tool("-R", str(tmp_path))
        assert second.returncode == 0
        assert "skipping" in second.stderr


@pytest.mark.skipif(not HAS_7Z, reason="7z required for encrypted fixtures")
class TestCliPasswords:
    def _make_encrypted(self, path: Path, password: str) -> None:
        src = path.parent / "encsrc"
        src.mkdir(exist_ok=True)
        (src / "secret.txt").write_text("payload\n")
        subprocess.run(
            [shutil.which("7z") or shutil.which("7za"), "a", f"-p{password}", str(path), str(src / "secret.txt")],
            cwd=src, capture_output=True, text=True, check=True,
        )

    def test_correct_single_password(self, tmp_path):
        archive = tmp_path / "x.zip"
        self._make_encrypted(archive, "s3cret")
        result = run_tool("-p", "s3cret", str(archive))
        assert result.returncode == 0
        assert (tmp_path / "x" / "secret.txt").read_text() == "payload\n"

    def test_password_file_second_candidate_wins(self, tmp_path):
        archive = tmp_path / "x.zip"
        self._make_encrypted(archive, "the-real-one")
        pwfile = tmp_path / "pw.txt"
        pwfile.write_text("wrong-one\nthe-real-one\n")
        result = run_tool("-P", str(pwfile), str(archive))
        assert result.returncode == 0
        assert (tmp_path / "x" / "secret.txt").read_text() == "payload\n"

    def test_all_wrong_keeps_archive_even_with_remove(self, tmp_path):
        archive = tmp_path / "x.zip"
        self._make_encrypted(archive, "real")
        result = run_tool("-p", "nope", "-r", str(archive))
        assert result.returncode == 1
        assert archive.exists()
        assert not (tmp_path / "x").exists()

    def test_aes_zip_via_unzip_fallback(self, tmp_path):
        archive = tmp_path / "x.zip"
        src = tmp_path / "aesrc"
        src.mkdir(exist_ok=True)
        (src / "secret.txt").write_text("aes-payload\n")
        subprocess.run(
            [shutil.which("7z") or shutil.which("7za"), "a", "-psecret", "-mem=AES256",
             str(archive), str(src / "secret.txt")],
            cwd=src, capture_output=True, text=True, check=True,
        )
        result = run_tool("-p", "secret", str(archive))
        assert result.returncode == 0
        assert (tmp_path / "x" / "secret.txt").read_text() == "aes-payload\n"


class TestWrapper:
    def _zsh(self, snippet: str, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(["zsh", "-c", snippet, *args], capture_output=True, text=True)

    def _setup_fake_tool(self, tmp_path: Path) -> Path:
        fakebin = tmp_path / "bin"
        fakebin.mkdir()
        tool = fakebin / "extract.py"
        tool.write_text("#!/usr/bin/env python3\nimport sys\nprint('PYTOOL', *sys.argv[1:])\n")
        tool.chmod(0o755)
        return fakebin

    @pytest.mark.parametrize(
        "invocation",
        [
            "-R x.zip",
            "--recursive x.zip",
            "-p pw x.zip",
            "--password pw x.zip",
            "--password=pw x.zip",
            "-P pw.txt x.zip",
            "--password-file pw.txt x.zip",
            "-F x.zip",
            "--force x.zip",
            "-r x.zip",
            "--remove x.zip",
        ],
    )
    def test_delegates_each_new_flag(self, tmp_path, invocation):
        fakebin = self._setup_fake_tool(tmp_path)
        snippet = (
            "extract() { echo PLUGIN; }; "
            f"ZBIN={fakebin}; source {WRAPPER}; extract {invocation}"
        )
        result = self._zsh(snippet)
        assert result.stdout.strip() == f"PYTOOL {invocation}"

    def test_falls_through_to_plugin(self, tmp_path):
        fakebin = self._setup_fake_tool(tmp_path)
        snippet = (
            "extract() { echo PLUGIN; }; "
            f"ZBIN={fakebin}; source {WRAPPER}; extract plain.tar.gz"
        )
        result = self._zsh(snippet)
        assert result.stdout.strip() == "PLUGIN"

    def test_resourcing_does_not_recurse(self, tmp_path):
        # finding C6: a second `source` must not capture the wrapper as
        # extract_orig (which would make `extract` recurse forever).
        fakebin = self._setup_fake_tool(tmp_path)
        snippet = (
            "extract() { echo PLUGIN; }; "
            f"ZBIN={fakebin}; source {WRAPPER}; source {WRAPPER}; extract plain.tar.gz"
        )
        result = self._zsh(snippet)
        assert result.stdout.strip() == "PLUGIN"
