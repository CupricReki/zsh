"""Per-handler behavior against real archives in tmpdirs (spec §7.2)."""

import shutil
import subprocess
import tarfile
import zlib
from pathlib import Path

import pytest

from extract.engine import ErrorClass
from extract.handlers import (
    LibarchiveHandler,
    SingleFileHandler,
    SevenZipHandler,
    TarSubprocessHandler,
    TarfileHandler,
    UnrarHandler,
    UnzipHandler,
    ZlibHandler,
    run_streamed,
    safe_join,
)


def make_tar_gz(path: Path) -> None:
    src = path.parent / "src"
    src.mkdir(exist_ok=True)
    (src / "hello.txt").write_text("hello\n")
    (src / "sub").mkdir(exist_ok=True)
    (src / "sub" / "nested.txt").write_text("nested\n")
    with tarfile.open(path, "w:gz") as tf:
        tf.add(src / "hello.txt", arcname="hello.txt")
        tf.add(src / "sub", arcname="sub")


def sevenz():  # noqa: D401
    return shutil.which("7z") or shutil.which("7za")


class TestSafeJoin:
    def test_normal_path(self, tmp_path):
        assert safe_join(tmp_path, "a/b/c.txt") == tmp_path / "a" / "b" / "c.txt"

    def test_parent_traversal_rejected(self, tmp_path):
        with pytest.raises(ValueError):
            safe_join(tmp_path, "../../etc/passwd")

    def test_absolute_path_is_contained(self, tmp_path):
        assert safe_join(tmp_path, "/etc/thing") == tmp_path / "etc" / "thing"


class TestRunStreamed:
    def test_returns_rc_and_output(self):
        rc, out = run_streamed(["/bin/echo", "hello stream"])
        assert rc == 0
        assert "hello stream" in out

    def test_failure_rc(self):
        rc, _ = run_streamed(["/bin/sh", "-c", "exit 3"])
        assert rc == 3

    def test_output_streamed_to_stderr(self, capsys):
        run_streamed(["/bin/echo", "live!"])
        assert "live!" in capsys.readouterr().err

    def test_shell_metacharacters_safe(self):
        # list argv, never shell: metacharacters pass through literally
        rc, out = run_streamed(["/bin/echo", "a;rm -rf /;b $HOME"])
        assert rc == 0
        assert "a;rm -rf /;b $HOME" in out


class TestTarfileHandler:
    def test_extracts_tar_gz(self, tmp_path):
        archive = tmp_path / "x.tar.gz"
        make_tar_gz(archive)
        dest = tmp_path / "out"
        dest.mkdir()
        result = TarfileHandler().extract(archive, dest, None)
        assert result.ok
        assert (dest / "hello.txt").read_text() == "hello\n"
        assert (dest / "sub" / "nested.txt").read_text() == "nested\n"

    def test_unsupported_compression_descends(self, tmp_path):
        archive = tmp_path / "x.tar.zst"
        archive.write_bytes(b"not a real zst archive")
        dest = tmp_path / "out"
        dest.mkdir()
        result = TarfileHandler().extract(archive, dest, None)
        assert result.cls is ErrorClass.BACKEND_UNSUPPORTED

    def test_corrupt_archive_is_extract_error(self, tmp_path):
        archive = tmp_path / "x.tar.gz"
        archive.write_bytes(b"\x1f\x8b garbage garbage")
        dest = tmp_path / "out"
        dest.mkdir()
        result = TarfileHandler().extract(archive, dest, None)
        assert result.cls is ErrorClass.EXTRACT_ERROR


@pytest.mark.skipif(
    not shutil.which("7z") and not shutil.which("7za"),
    reason="7z/7za required for encrypted fixture creation",
)
class TestLibarchiveHandler:
    def test_extracts_tar_gz(self, tmp_path):
        archive = tmp_path / "x.tar.gz"
        make_tar_gz(archive)
        dest = tmp_path / "out"
        dest.mkdir()
        result = LibarchiveHandler().extract(archive, dest, None)
        assert result.ok
        assert (dest / "hello.txt").read_text() == "hello\n"

    def test_traversal_member_rejected(self, tmp_path):
        archive = tmp_path / "x.tar"
        with tarfile.open(archive, "w") as tf:
            import io
            info = tarfile.TarInfo("../evil.txt")
            data = b"x"
            info.size = len(data)
            tf.addfile(info, io.BytesIO(data))
        dest = tmp_path / "out"
        dest.mkdir()
        result = LibarchiveHandler().extract(archive, dest, None)
        assert result.cls is ErrorClass.EXTRACT_ERROR  # safe_join raises -> classify

    def test_wrong_passphrase_classified(self, tmp_path):
        archive = tmp_path / "x.zip"
        TestUnzipHandler()._make_zipcrypto(archive, "secret")
        dest = tmp_path / "out"
        dest.mkdir()
        result = LibarchiveHandler().extract(archive, dest, "nope")
        assert result.cls is ErrorClass.WRONG_PASSWORD

    def test_aes_zip_extracts(self, tmp_path):
        # finding C4: libarchive-c decrypts WinZip AES-256 with passphrase=
        # (measured) — it does NOT decline to the unzip fallback.
        archive = tmp_path / "x.zip"
        TestUnzipHandler()._make_aes_zip(archive, "secret")
        dest = tmp_path / "out"
        dest.mkdir()
        result = LibarchiveHandler().extract(archive, dest, "secret")
        assert result.ok
        assert (dest / "f.txt").read_text() == "zipped\n"

    def test_empty_archive_is_error(self, tmp_path):
        # libarchive yields 0 entries for a 0-byte file without raising;
        # treat that as a failure, not a successful empty extraction.
        archive = tmp_path / "x.zip"
        archive.write_bytes(b"")
        dest = tmp_path / "out"
        dest.mkdir()
        result = LibarchiveHandler().extract(archive, dest, None)
        assert result.cls is ErrorClass.EXTRACT_ERROR


@pytest.mark.skipif(
    not shutil.which("7z") and not shutil.which("7za"),
    reason="7z/7za required for encrypted zip fixtures",
)
class TestUnzipHandler:
    def _make_zipcrypto(self, path: Path, password: str) -> None:
        src = path.parent / "zsrc"
        src.mkdir(exist_ok=True)
        (src / "f.txt").write_text("zipped\n")
        subprocess.run(
            [sevenz(), "a", f"-p{password}", str(path), str(src / "f.txt")],
            cwd=src, capture_output=True, text=True, check=True,
        )

    def _make_aes_zip(self, path: Path, password: str) -> None:
        src = path.parent / "zsrc"
        src.mkdir(exist_ok=True)
        (src / "f.txt").write_text("zipped\n")
        subprocess.run(
            [sevenz(), "a", f"-p{password}", "-mem=AES256", str(path), str(src / "f.txt")],
            cwd=src, capture_output=True, text=True, check=True,
        )

    def test_correct_password(self, tmp_path):
        archive = tmp_path / "x.zip"
        self._make_zipcrypto(archive, "secret")
        dest = tmp_path / "out"
        dest.mkdir()
        result = UnzipHandler().extract(archive, dest, "secret")
        assert result.ok
        assert (dest / "f.txt").read_text() == "zipped\n"

    def test_wrong_password(self, tmp_path):
        archive = tmp_path / "x.zip"
        self._make_zipcrypto(archive, "secret")
        dest = tmp_path / "out"
        dest.mkdir()
        result = UnzipHandler().extract(archive, dest, "nope")
        assert result.cls is ErrorClass.WRONG_PASSWORD

    def test_corrupt_zip(self, tmp_path):
        archive = tmp_path / "x.zip"
        archive.write_bytes(b"PK\x03\x04garbage")
        dest = tmp_path / "out"
        dest.mkdir()
        result = UnzipHandler().extract(archive, dest, None)
        assert result.cls is ErrorClass.EXTRACT_ERROR

    def test_aes_zip_unsupported(self, tmp_path):
        # finding C4: Info-ZIP 6.00 cannot read WinZip AES (exit 81). The zip
        # chain never reaches unzip for AES when libarchive is present; this
        # documents the standalone limitation.
        archive = tmp_path / "x.zip"
        self._make_aes_zip(archive, "secret")
        dest = tmp_path / "out"
        dest.mkdir()
        result = UnzipHandler().extract(archive, dest, "secret")
        assert result.cls is ErrorClass.EXTRACT_ERROR


@pytest.mark.skipif(
    not shutil.which("7z") and not shutil.which("7za"),
    reason="7z/7za required for 7z fixtures",
)
class TestSevenZipHandler:
    def _make(self, path: Path, password: str) -> None:
        src = path.parent / "s7src"
        src.mkdir(exist_ok=True)
        (src / "f.txt").write_text("seven\n")
        subprocess.run(
            [sevenz(), "a", f"-p{password}", str(path), str(src / "f.txt")],
            cwd=src, capture_output=True, text=True, check=True,
        )

    def test_correct_password(self, tmp_path):
        archive = tmp_path / "x.7z"
        self._make(archive, "secret")
        dest = tmp_path / "out"
        dest.mkdir()
        result = SevenZipHandler().extract(archive, dest, "secret")
        assert result.ok
        assert (dest / "f.txt").read_text() == "seven\n"

    def test_wrong_password(self, tmp_path):
        archive = tmp_path / "x.7z"
        self._make(archive, "secret")
        dest = tmp_path / "out"
        dest.mkdir()
        result = SevenZipHandler().extract(archive, dest, "nope")
        assert result.cls is ErrorClass.WRONG_PASSWORD

    def test_corrupt_archive_is_data_error_not_password(self, tmp_path):
        archive = tmp_path / "x.7z"
        self._make(archive, "secret")
        data = bytearray(archive.read_bytes())
        data[len(data) // 2 : len(data) // 2 + 8] = b"\x00" * 8
        archive.write_bytes(bytes(data))
        dest = tmp_path / "out"
        dest.mkdir()
        result = SevenZipHandler().extract(archive, dest, "secret")
        assert result.cls is ErrorClass.EXTRACT_ERROR


class TestUnrarHandler:
    def test_extracts(self, tmp_path):
        pytest.skip("rar creator unavailable on this host; covered by engine tests")


class TestSingleFileHandler:
    def test_gz_roundtrip(self, tmp_path):
        import gzip
        archive = tmp_path / "x.gz"
        with gzip.open(archive, "wb") as fh:
            fh.write(b"gzipped content\n")
        dest = tmp_path / "out"
        dest.mkdir()
        result = SingleFileHandler().extract(archive, dest, None)
        assert result.ok
        assert (dest / "x").read_bytes() == b"gzipped content\n"

    def test_xz_roundtrip(self, tmp_path):
        import lzma
        archive = tmp_path / "x.xz"
        archive.write_bytes(lzma.compress(b"xz content\n"))
        dest = tmp_path / "out"
        dest.mkdir()
        result = SingleFileHandler().extract(archive, dest, None)
        assert result.ok
        assert (dest / "x").read_bytes() == b"xz content\n"

    def test_missing_tool(self, tmp_path):
        handler = SingleFileHandler()
        # force an unavailable tool by clearing PATH for the probe
        old_path = handler._tool_names[".gz"]
        handler._tool_names[".gz"] = ((("definitely-not-a-real-tool",), "stdout"),)
        try:
            archive = tmp_path / "x.gz"
            archive.write_bytes(b"\x1f\x8b\x08\x00" + b"\x00" * 20)
            dest = tmp_path / "out"
            dest.mkdir()
            result = handler.extract(archive, dest, None)
            assert result.cls is ErrorClass.EXTRACT_ERROR
            assert "requires" in result.detail
        finally:
            handler._tool_names[".gz"] = old_path


class TestZlibHandler:
    def test_roundtrip(self, tmp_path):
        archive = tmp_path / "x.zlib"
        archive.write_bytes(zlib.compress(b"zlib content\n"))
        dest = tmp_path / "out"
        dest.mkdir()
        result = ZlibHandler().extract(archive, dest, None)
        assert result.ok
        assert (dest / "x").read_bytes() == b"zlib content\n"
