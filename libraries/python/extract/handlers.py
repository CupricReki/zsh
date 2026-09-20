"""Backend handlers implementing spec §7.2 chains.

Defensive rules (spec §7.1): list argv only (never shell), stdin closed,
availability probes, output-driven classification, no writes outside `dest`.
"""

import os
import shutil
import subprocess
import sys
import zlib
from pathlib import Path

from extract.engine import ErrorClass, Result

CHAIN_TABLE: dict[str, tuple[str, ...]] = {
    "tar": ("libarchive", "tarfile", "tar_subprocess"),
    "zip": ("libarchive", "unzip"),
    "7z": ("libarchive", "sevenzip"),
    "rar": ("unrar",),
    "rpm": ("libarchive", "rpm2cpio"),
    "cpio": ("libarchive", "cpio"),
    "deb": ("ar_deb",),
    "cab": ("cabextract",),
    "zlib": ("zlib_py",),
    "single": ("single_file",),
}


def _tool(candidates: tuple[str, ...]) -> str | None:
    for name in candidates:
        found = shutil.which(name)
        if found:
            return found
    return None


def run_streamed(cmd: list[str], cwd: Path | None = None, timeout: float | None = None) -> tuple[int, str]:
    """Run `cmd`, tee combined output to stderr, return (rc, combined).

    LC_ALL=C pins subprocess output to English (finding M4: Info-ZIP/7z NLS
    output would break wrong-password marker matching). `timeout` SIGKILLs the
    process group on wall-clock expiry (finding C1: an interactive password
    prompt cannot be killed with SIGTERM alone).
    """
    env = {**os.environ, "LC_ALL": "C", "LANG": "C"}
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        stdin=subprocess.DEVNULL,
        cwd=str(cwd) if cwd else None,
        text=True,
        errors="replace",
        env=env,
        start_new_session=True,
    )
    chunks: list[str] = []
    try:
        assert proc.stdout is not None
        for line in proc.stdout:
            chunks.append(line)
            sys.stderr.write(line)
            sys.stderr.flush()
        return proc.wait(timeout=timeout), "".join(chunks)
    except subprocess.TimeoutExpired:
        import signal
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        proc.wait()
        return 137, "".join(chunks) + "\n[timeout] killed unresponsive subprocess\n"


def safe_join(dest: Path, member: str) -> Path:
    """Join an archive member path onto `dest`, refusing parent traversal."""
    parts = [p for p in Path(member).parts if p not in ("", ".", "/", "\\")]
    if any(p == ".." for p in parts):
        raise ValueError(f"unsafe member path: {member!r}")
    return dest.joinpath(*parts)


def _err(detail: str) -> Result:
    return Result(ErrorClass.EXTRACT_ERROR, detail)


def _tail(text: str, lines: int = 20) -> str:
    """Last ~20 output lines for diagnostics (spec §7.1)."""
    return "\n".join(text.splitlines()[-lines:])


class LibarchiveHandler:
    name = "libarchive"
    password_capable = True

    def available(self) -> bool:
        try:
            import libarchive  # noqa: F401
            return True
        except ImportError:
            return False

    def extract(self, archive: Path, dest: Path, password: str | None) -> Result:
        import libarchive

        kwargs: dict = {}
        if password is not None:
            kwargs["passphrase"] = password.encode("utf-8", "surrogateescape")
        try:
            count = 0
            with libarchive.file_reader(str(archive), **kwargs) as reader:
                for entry in reader:
                    pathname = str(entry.pathname or "")
                    if not pathname:
                        continue
                    count += 1
                    target = safe_join(dest, pathname)
                    if entry.isdir:
                        target.mkdir(parents=True, exist_ok=True)
                        continue
                    if entry.issym:
                        target.parent.mkdir(parents=True, exist_ok=True)
                        os.symlink(str(entry.linkpath), target)
                        continue
                    if entry.islnk:
                        source = safe_join(dest, str(entry.linkpath))
                        target.parent.mkdir(parents=True, exist_ok=True)
                        if source.exists():
                            os.link(source, target)
                        continue
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with open(target, "wb") as fh:
                        for block in entry.get_blocks():
                            fh.write(block)
            if count == 0:
                return _err("empty or unreadable archive")
            return Result(ErrorClass.NONE)
        except Exception as exc:  # noqa: BLE001 — ValueError from safe_join lands here too
            return self._classify(str(exc))

    @staticmethod
    def _classify(message: str) -> Result:
        low = message.lower()
        # libarchive wording (measured, Task D Step 0 spike): AES wrong
        # passphrase -> "Incorrect passphrase"; ZipCrypto wrong passphrase ->
        # "ZIP bad CRC" (decrypts to garbage that fails CRC). Both are
        # wrong-password, not corruption.
        if "passphrase" in low or "wrong password" in low or "incorrect password" in low or "bad crc" in low:
            return Result(ErrorClass.WRONG_PASSWORD, message)
        # finding C4/M7: libarchive raises "encrypted, but currently not
        # supported" for encrypted 7z and "unrecognized archive format" for
        # rpm/tar.br — both mean "descend to a CLI fallback", not fatal.
        # "Seek error" (split .7z.001) is left fatal so the documented xfail
        # gap holds rather than silently succeeding via the 7z CLI.
        if ("encrypted" in low and "not supported" in low) or (
            "unsupported" in low and ("encryption" in low or "encrypted" in low)
        ) or "unrecognized archive format" in low:
            return Result(ErrorClass.BACKEND_UNSUPPORTED, message)
        return _err(message)


class TarfileHandler:
    name = "tarfile"
    password_capable = False

    # Compressions delegated to TarSubprocessHandler in the chain. stdlib
    # tarfile natively reads gz/bz2/xz (and zst on Python 3.14+); the exotic
    # ones are declined here so the chain descends (spec §7.2). On Python <3.14
    # tarfile.open raises CompressionError for these; on 3.14+ it raises
    # ReadError, so decline by suffix first to keep the classification stable.
    _subprocess_suffixes = (
        ".tar.zst", ".tzst", ".tar.lz4", ".tar.zma", ".tlz",
        ".tar.br", ".tar.z", ".tar.bz", ".tar.lrz",
    )

    def available(self) -> bool:
        return True

    def extract(self, archive: Path, dest: Path, password: str | None) -> Result:
        import tarfile

        if archive.name.lower().endswith(self._subprocess_suffixes):
            return Result(ErrorClass.BACKEND_UNSUPPORTED, "compression delegated to tar_subprocess")
        try:
            with tarfile.open(archive) as tf:
                tf.extractall(dest, filter="data")
            return Result(ErrorClass.NONE)
        except tarfile.CompressionError as exc:
            return Result(ErrorClass.BACKEND_UNSUPPORTED, str(exc))
        except tarfile.TarError as exc:
            return _err(str(exc))


class TarSubprocessHandler:
    name = "tar_subprocess"
    password_capable = False

    def available(self) -> bool:
        return _tool(("tar",)) is not None

    def extract(self, archive: Path, dest: Path, password: str | None) -> Result:
        low = archive.name.lower()
        if low.endswith((".tar.zst", ".tzst")):
            if _tool(("zstdcat",)):
                rc = self._pipe([_tool(("zstdcat",)) or "zstdcat", str(archive)], ["tar", "-xf", "-"], dest)
            else:
                rc, _ = run_streamed(["tar", "--zstd", "-xf", str(archive), "-C", str(dest)])
        elif low.endswith(".tar.lz4"):
            rc = self._pipe([_tool(("lz4",)) or "lz4", "-dc", str(archive)], ["tar", "-xf", "-"], dest)
        elif low.endswith((".tar.zma", ".tlz")):
            rc = self._pipe([_tool(("lzcat",)) or "lzcat", str(archive)], ["tar", "-xf", "-"], dest)
        elif low.endswith(".tar.br"):
            rc = self._pipe([_tool(("brotli",)) or "brotli", "-dc", str(archive)], ["tar", "-xf", "-"], dest)
        elif low.endswith(".tar.z"):
            rc = self._pipe([_tool(("uncompress",)) or "uncompress", "-c", str(archive)], ["tar", "-xf", "-"], dest)
        elif low.endswith(".tar.bz"):
            rc = self._pipe([_tool(("bzip2",)) or "bzip2", "-dc", str(archive)], ["tar", "-xf", "-"], dest)
        elif low.endswith(".tar.lrz"):
            binary = _tool(("lrzuntar",))
            if binary is None:
                return _err("requires lrzuntar")
            rc, _ = run_streamed([binary, str(archive)], cwd=dest)
        else:
            rc, _ = run_streamed(["tar", "-xf", str(archive), "-C", str(dest)])
        return Result(ErrorClass.NONE) if rc == 0 else _err(f"tar extraction failed (rc={rc})")

    @staticmethod
    def _pipe(producer: list[str], consumer: list[str], dest: Path) -> int:
        p1 = subprocess.Popen(producer, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        rc2 = subprocess.run(
            consumer, stdin=p1.stdout, cwd=dest,
            capture_output=True, text=True, errors="replace",
        )
        p1.wait()
        return rc2.returncode if rc2.returncode else p1.returncode


class UnzipHandler:
    name = "unzip"
    password_capable = True

    def available(self) -> bool:
        return _tool(("unzip",)) is not None

    def extract(self, archive: Path, dest: Path, password: str | None) -> Result:
        # Always pass -P (empty when no candidate) — an interactive prompt on
        # the TTY is unkillable with SIGTERM (finding C1). -o suppresses the
        # overwrite prompt. LC_ALL=C and the timeout live in run_streamed.
        cmd = ["unzip", "-o", "-P", password or "", str(archive), "-d", str(dest)]
        rc, out = run_streamed(cmd, timeout=120.0)
        if "incorrect password" in out.lower():
            return Result(ErrorClass.WRONG_PASSWORD, "unzip rejected the password")
        if rc == 0:
            return Result(ErrorClass.NONE)
        return _err(_tail(out))


class SevenZipHandler:
    name = "sevenzip"
    password_capable = True

    def available(self) -> bool:
        return _tool(("7z", "7za")) is not None

    def extract(self, archive: Path, dest: Path, password: str | None) -> Result:
        binary = _tool(("7z", "7za"))
        if binary is None:
            return _err("requires 7z")
        # -p"" (empty token) for the no-password case: p7zip otherwise prompts
        # on the TTY for encrypted archives (finding C1 analog). -bb0 keeps the
        # output quiet so marker matching is unambiguous.
        cmd = [binary, "x", "-y", "-bb0", f"-o{dest}", f"-p{password or ''}", str(archive)]
        rc, out = run_streamed(cmd, timeout=120.0)
        low = out.lower()
        if "wrong password" in low:
            return Result(ErrorClass.WRONG_PASSWORD, "7z rejected the password")
        # finding C3: exit code 2 conflates wrong-password with corrupt archive,
        # so classify on output, not the code.
        if "cannot open the file" in low or "crc failed" in low or "data error" in low:
            return _err(_tail(out))
        # p7zip returns 1 for warnings ("there is no error") — treat as success.
        if rc in (0, 1):
            return Result(ErrorClass.NONE)
        return _err(_tail(out))


class UnrarHandler:
    name = "unrar"
    password_capable = True

    def available(self) -> bool:
        return _tool(("unrar",)) is not None

    def extract(self, archive: Path, dest: Path, password: str | None) -> Result:
        binary = _tool(("unrar",))
        if binary is None:
            return _err("requires unrar")
        flag = f"-p{password}" if password is not None else "-p-"
        rc, out = run_streamed([binary, "x", flag, str(archive), str(dest) + os.sep])
        if rc == 0:
            return Result(ErrorClass.NONE)
        if rc == 11:
            return Result(ErrorClass.WRONG_PASSWORD, "unrar rejected the password")
        return _err(_tail(out))


class Rpm2cpioHandler:
    name = "rpm2cpio"
    password_capable = False

    def available(self) -> bool:
        return _tool(("rpm2cpio",)) is not None and _tool(("cpio",)) is not None

    def extract(self, archive: Path, dest: Path, password: str | None) -> Result:
        rc = TarSubprocessHandler._pipe([_tool(("rpm2cpio",)) or "rpm2cpio", str(archive)], ["cpio", "--quiet", "-id"], dest)
        return Result(ErrorClass.NONE) if rc == 0 else _err(f"rpm extraction failed (rc={rc})")


class CpioHandler:
    name = "cpio"
    password_capable = False

    def available(self) -> bool:
        return _tool(("cpio",)) is not None

    def extract(self, archive: Path, dest: Path, password: str | None) -> Result:
        rc, out = run_streamed(["cpio", "-idmvF", str(archive)], cwd=dest)
        return Result(ErrorClass.NONE) if rc == 0 else _err(_tail(out))


class ArDebHandler:
    name = "ar_deb"
    password_capable = False

    def available(self) -> bool:
        return _tool(("ar",)) is not None

    def extract(self, archive: Path, dest: Path, password: str | None) -> Result:
        import tarfile

        rc, out = run_streamed(["ar", "x", str(archive)], cwd=dest)
        if rc != 0:
            return _err(_tail(out))
        for prefix in ("control", "data"):
            members = sorted(dest.glob(f"{prefix}.tar.*"))
            if not members:
                continue
            subdir = dest / prefix
            subdir.mkdir(exist_ok=True)
            try:
                with tarfile.open(members[0]) as tf:
                    tf.extractall(subdir, filter="data")
            except tarfile.TarError as exc:
                return _err(str(exc))
        for leftover in list(dest.glob("*.tar.*")) + [dest / "debian-binary"]:
            if leftover.exists():
                leftover.unlink()
        return Result(ErrorClass.NONE)


class CabextractHandler:
    name = "cabextract"
    password_capable = False

    def available(self) -> bool:
        return _tool(("cabextract",)) is not None

    def extract(self, archive: Path, dest: Path, password: str | None) -> Result:
        rc, out = run_streamed(["cabextract", "-d", str(dest), str(archive)])
        return Result(ErrorClass.NONE) if rc == 0 else _err(_tail(out))


class ZlibHandler:
    name = "zlib_py"
    password_capable = False

    def available(self) -> bool:
        return True

    def extract(self, archive: Path, dest: Path, password: str | None) -> Result:
        out_name = archive.name[: -len(".zlib")]
        try:
            data = zlib.decompress(archive.read_bytes())
        except zlib.error as exc:
            return _err(str(exc))
        (dest / out_name).write_bytes(data)
        return Result(ErrorClass.NONE)


class SingleFileHandler:
    name = "single_file"
    password_capable = False

    # per-extension: ordered tool candidates; each entry is (cmd_tail..., mode)
    # mode "stdout": decompress to stdout, written to dest/<name minus ext>
    # mode "cwd": tool runs with cwd=dest and names its own output
    _tool_names: dict[str, tuple[tuple[tuple[str, ...], str], ...]] = {
        ".gz": ((("pigz", "-cdk"), "stdout"), (("gunzip", "-ck"), "stdout")),
        ".bz2": ((("bunzip2", "-ck"), "stdout"),),
        ".xz": ((("xz", "-dc"), "stdout"),),
        ".lzma": ((("unlzma", "-c"), "stdout"),),
        ".z": ((("uncompress", "-c"), "stdout"),),
        ".zst": ((("zstd", "-dc"), "stdout"),),
        ".zstd": ((("zstd", "-dc"), "stdout"),),
        ".lz4": ((("lz4", "-dc"), "stdout"),),
        ".br": ((("brotli", "-dc"), "stdout"),),
        ".lz": ((("lzip", "-dc"), "stdout"),),
        ".lrz": ((("lrunzip", "-o"), "cwd"),),
        ".zpaq": ((("zpaq", "x"), "cwd"),),
    }

    def available(self) -> bool:
        return True  # per-extension availability checked at extract time

    def extract(self, archive: Path, dest: Path, password: str | None) -> Result:
        ext = next((e for e in self._tool_names if archive.name.lower().endswith(e)), None)
        if ext is None:
            return _err(f"unsupported single-file extension: {archive.name}")
        out_name = archive.name[: -len(ext)]
        for candidates, mode in self._tool_names[ext]:
            binary = _tool(candidates)
            if binary is None:
                continue
            if mode == "stdout":
                cmd = [binary] + list(candidates[1:]) + [str(archive)]
                with open(dest / out_name, "wb") as fh:
                    proc = subprocess.run(cmd, stdout=fh, stderr=subprocess.PIPE, stdin=subprocess.DEVNULL)
                if proc.returncode == 0:
                    return Result(ErrorClass.NONE)
                return _err(f"{binary} failed (rc={proc.returncode})")
            else:
                cmd = [binary] + list(candidates[1:]) + [str(archive)]
                rc, _ = run_streamed(cmd, cwd=dest)
                if rc == 0:
                    return Result(ErrorClass.NONE)
                return _err(f"{binary} failed (rc={rc})")
        return _err(f"requires a decompressor for {ext}")


HANDLERS: dict = {
    "libarchive": LibarchiveHandler(),
    "tarfile": TarfileHandler(),
    "tar_subprocess": TarSubprocessHandler(),
    "unzip": UnzipHandler(),
    "sevenzip": SevenZipHandler(),
    "unrar": UnrarHandler(),
    "rpm2cpio": Rpm2cpioHandler(),
    "cpio": CpioHandler(),
    "ar_deb": ArDebHandler(),
    "cabextract": CabextractHandler(),
    "zlib_py": ZlibHandler(),
    "single_file": SingleFileHandler(),
}
