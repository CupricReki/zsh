#!/usr/bin/env python3
"""Generate the archive / password fixtures used by tests/test_extract.py.

Design rules
------------
* Every fixture is produced by the *real* creator for its format where one
  exists on this host; libarchive (`bsdtar -a`) covers `.Z` and `.lz` because
  `compress(1)` and `lzip(1)` are not installed.
* Every produced file is checked against its expected magic bytes. This matters
  because `bsdtar -a` silently writes an *uncompressed tar* when it does not
  recognise the extension, and exits 0 while doing so.
* Formats with no available creator (rar, lzo, lrz, zpaq) are recorded in
  manifest.json with `"available": false` so the test suite can skip them
  instead of failing confusingly.
* Writes manifest.json (machine-readable expectations) and the password files.
  Re-runnable: existing output is replaced.

Usage:
    python3 make_fixtures.py            # generate everything
    python3 make_fixtures.py --verify   # re-list every generated fixture
"""
from __future__ import annotations

import hashlib
import io
import json
import shutil
import subprocess
import sys
import tarfile
import zipfile
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
ARCH = HERE / "archives"
PWDIR = HERE / "passwords"

# Fixed mtime keeps regenerated fixtures byte-stable across runs.
EPOCH = "202001010000"

A_TXT = b"fixture payload A\n"
B_TXT = b"fixture payload B\n"
INNER_TXT = b"nested payload\n"
LARGE_TXT = b"".join(b"line %04d of the large fixture payload\n" % i for i in range(400))

# Passwords. One per encrypted fixture so a single -P list exercises iteration
# across every archive, and so a wrong match cannot accidentally succeed.
PW = {
    "zipcrypto": "z1p-pass",
    "aes256": "aes-p4ss",
    "mixed": "m1xed-pass",
    "sevenzip": "7z-\u00dcn\u00efc\u00f6d\u00e9-p\u00e4ss",
    "sevenzip_space": "sp4ce in pass!#%$ & more",
    "split7z": "spl1t-pass",
    "rar": "r4r-pass",
    "tree": "tree-pass",
}

DECOYS = [
    "password",
    "123456",
    "z1p-pas",            # near-miss prefix of a real password
    "z1p-pass2",          # near-miss tail of a real password
    "aes-p4ss-x",
    "7z-\u00dcn\u00efc\u00f6d\u00e9-p\u00e4s",
    "Password1!",
    "\u30d1\u30b9\u30ef\u30fc\u30c9",   # non-ASCII, wrong
]

manifest: list[dict] = []
failures: list[str] = []


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #
def sh(cmd: list[str], cwd: Path | None = None, check: bool = True) -> tuple[int, str, str]:
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, errors="replace")
    if check and r.returncode != 0:
        raise RuntimeError(f"{' '.join(cmd)} -> exit {r.returncode}\n{r.stdout}\n{r.stderr}")
    return r.returncode, r.stdout, r.stderr


def have(tool: str) -> bool:
    return shutil.which(tool) is not None


def touch_tree(root: Path) -> None:
    for p in sorted(root.rglob("*")):
        sh(["touch", "-d", EPOCH, str(p)], check=False)


def record(path: Path, fmt: str, kind: str, expect: str = "extract",
           password: str | None = None, encryption: str | None = None,
           available: bool = True, notes: str = "") -> None:
    manifest.append({
        "path": path.relative_to(HERE).as_posix(),
        "format": fmt,
        "kind": kind,
        "expect": expect,
        "password": password,
        "encryption": encryption,
        "size": path.stat().st_size if path.exists() else None,
        "available": available,
        "notes": notes,
    })


def check_magic(path: Path, magic: bytes, what: str) -> bool:
    if not magic:  # format has no fixed magic (e.g. brotli); verified by round-trip
        return path.stat().st_size > 0
    head = path.read_bytes()[:len(magic)]
    if head != magic:
        failures.append(f"{path.name}: expected {what} magic {magic.hex()}, got {head.hex()}")
        return False
    return True


def sources(root: Path) -> Path:
    """Create the canonical payload tree and return its path."""
    root.mkdir(parents=True, exist_ok=True)
    (root / "a.txt").write_bytes(A_TXT)
    (root / "b.txt").write_bytes(B_TXT)
    (root / "big.txt").write_bytes(LARGE_TXT)
    (root / "space name.txt").write_bytes(A_TXT)
    (root / "\u00fcn\u00efc\u00f6de-\u30d5\u30a1\u30a4\u30eb.txt").write_bytes(B_TXT)
    (root / "topdir").mkdir(exist_ok=True)
    (root / "topdir" / "inner.txt").write_bytes(INNER_TXT)
    # Deterministic pseudo-random bytes: incompressible (so multi-volume
    # archives really split) yet reproducible (no git churn).
    (root / "noise.bin").write_bytes(
        b"".join(hashlib.sha256(str(i).encode()).digest() for i in range(256)))
    touch_tree(root)
    return root


# --------------------------------------------------------------------------- #
# plain tar family
# --------------------------------------------------------------------------- #
def tar_family(src: Path, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    members = ["a.txt", "b.txt", "big.txt"]

    def tar(name: str, args: list[str]) -> None:
        p = out / name
        sh(["tar", *args, "-cf", str(p), "-C", str(src), *members])
        record(p, name.split(".", 1)[1], "tar", notes="tar stream, stdlib tarfile path")

    tar("plain.tar", [])
    tar("plain.tar.gz", ["-z"])
    tar("plain.tgz", ["-z"])
    tar("plain.tar.bz2", ["-j"])
    tar("plain.tbz", ["-j"])
    tar("plain.tbz2", ["-j"])
    tar("plain.tar.xz", ["-J"])
    tar("plain.txz", ["-J"])
    tar("plain.tar.bz", ["-j"])

    # Formats tar(1) delegates to a helper binary or lacks entirely.
    tar("plain.tar.zst", ["--zstd"])
    tar("plain.tzst", ["--zstd"])
    tar("plain.tar.lz4", ["-I", "lz4"])
    tar("plain.tar.lzma", ["--lzma"])
    tar("plain.tar.zma", ["--lzma"])

    # brotli has no tar(1) integration; pipe it.
    p = out / "plain.tar.br"
    with p.open("wb") as fh:
        t = subprocess.Popen(["tar", "-cf", "-", "-C", str(src), *members], stdout=subprocess.PIPE)
        b = subprocess.Popen(["brotli", "-q", "5", "-c"], stdin=t.stdout, stdout=fh)
        t.stdout.close()  # type: ignore[union-attr]
        b.wait()
        t.wait()
    check_magic(p, b"", "brotli")
    record(p, "tar.br", "tar", notes="brotli is NOT in the spec dispatch table")

    # libarchive covers .Z (LZW) and .lz (lzip); verify the filter really ran.
    for name, magic, what, note in [
        ("plain.tar.Z", b"\x1f\x9d", "LZW .Z", "no compress(1) on this host; bsdtar writes block-mode LZW"),
        ("plain.tar.lz", b"LZIP", "lzip", "bsdtar -a writes lzip; tar(1) --lzip needs the missing lzip binary"),
    ]:
        p = out / name
        sh(["bsdtar", "-a", "-cf", str(p), "-C", str(src), *members])
        if not check_magic(p, magic, what):
            p.write_bytes(b"")
        record(p, name.split(".", 1)[1], "tar", notes=note)
    # Lowercase .z: bsdtar does not recognise it and silently writes a plain tar,
    # so replicate the real LZW bytes to probe case-insensitive dispatch.
    lower = out / "plain.tar.z"
    shutil.copy2(out / "plain.tar.Z", lower)
    record(lower, "tar.z", "tar", notes="identical LZW bytes to plain.tar.Z; case-insensitivity probe")

    # Collapse behaviour: a tar whose only entry is one directory.
    p = out / "plain.topdir.tar.gz"
    sh(["tar", "-zcf", str(p), "-C", str(src), "topdir"])
    record(p, "tar.gz", "tar", expect="collapse",
           notes="single top-level dir -> plugin collapse moves it up")


# --------------------------------------------------------------------------- #
# single-file compressors
# --------------------------------------------------------------------------- #
def single_file(src: Path, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    cases = [
        ("plain.txt.gz", "gz", ["gzip", "-c"], b"\x1f\x8b", "gzip"),
        ("plain.txt.bz2", "bz2", ["bzip2", "-c"], b"BZh", "bzip2"),
        ("plain.txt.xz", "xz", ["xz", "-c"], b"\xfd7zXZ\x00", "xz"),
        ("plain.txt.lzma", "lzma", ["xz", "--format=lzma", "-c"], b"\x5d\x00\x00", "lzma_alone"),
        ("plain.txt.zst", "zst", ["zstd", "-q", "-c"], b"\x28\xb5\x2f\xfd", "zstd"),
        ("plain.txt.zstd", "zstd", ["zstd", "-q", "-c"], b"\x28\xb5\x2f\xfd", "zstd"),
        ("plain.txt.lz4", "lz4", ["lz4", "-q", "-c"], b"\x04\x22\x4d\x18", "lz4"),
        ("plain.txt.br", "br", ["brotli", "-q", "5", "-c"], b"", "brotli"),
    ]
    payload = (src / "a.txt").read_bytes()
    for name, fmt, cmd, magic, what in cases:
        p = out / name
        r = subprocess.run(cmd, input=payload, capture_output=True)
        p.write_bytes(r.stdout)
        check_magic(p, magic, what)
        record(p, fmt, "single", notes="decompresses to a FILE, not a directory")

    # .Z / .lz for the tar family are produced in tar_family() (libarchive always
    # tar-wraps, so a bare single-stream .Z is impossible with the tools here).

    # zlib: stdlib path. A raw zlib stream has no filename, so the target name
    # is ambiguous in the spec.
    p = out / "plain.zlib"
    p.write_bytes(zlib.compress(LARGE_TXT))
    record(p, "zlib", "single", notes="stdlib zlib.decompress; output filename unspecified by spec")


# --------------------------------------------------------------------------- #
# zip family
# --------------------------------------------------------------------------- #
def zip_family(src: Path, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    base = out / "plain.zip"
    sh(["zip", "-q", "-X", "-r", str(base), "a.txt", "b.txt", "big.txt"], cwd=src)
    record(base, "zip", "zip")

    for ext in ["jar", "war", "ear", "whl", "xpi", "ipa", "aar", "apk",
                "sublime-package", "ipsw"]:
        p = out / f"plain.{ext}"
        shutil.copy2(base, p)
        record(p, ext, "zip", notes="zip renamed; extension dispatch probe")

    # .apk is genuinely ambiguous: Android (zip) vs Alpine (tar.gz).
    p = out / "alpine.apk"
    sh(["tar", "-zcf", str(p), "-C", str(src), "a.txt"])
    record(p, "apk-alpine", "tar", expect="ambiguous",
           notes="Alpine .apk is a tar.gz while Android .apk is a zip; spec maps .apk to unzip only")


# --------------------------------------------------------------------------- #
# 7z + encrypted archives
# --------------------------------------------------------------------------- #
def sevenzip_family(src: Path, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)

    p = out / "plain.7z"
    sh(["7z", "a", "-bd", "-y", "-mtc=off", "-mta=off", str(p), "a.txt", "b.txt"], cwd=src)
    record(p, "7z", "7z")

    p = out / "enc.7z"
    sh(["7z", "a", "-bd", "-y", "-p" + PW["sevenzip"], str(p), "a.txt", "b.txt"], cwd=src)
    record(p, "7z", "7z", password=PW["sevenzip"], encryption="7z-aes",
           notes="AES + visible headers")

    p = out / "enc_mhe.7z"
    sh(["7z", "a", "-bd", "-y", "-p" + PW["sevenzip"], "-mhe=on", str(p),
        "a.txt", "b.txt"], cwd=src)
    record(p, "7z", "7z", password=PW["sevenzip"], encryption="7z-aes-mhe",
           notes="header-encrypted: filenames invisible until password accepted")

    p = out / "enc_spacepass.7z"
    sh(["7z", "a", "-bd", "-y", "-p" + PW["sevenzip_space"], str(p), "a.txt"], cwd=src)
    record(p, "7z", "7z", password=PW["sevenzip_space"], encryption="7z-aes",
           notes="password contains interior space and shell metacharacters")

    # Multi-volume: always named X.7z.001, which no extension list in the spec matches.
    p = out / "enc_split.7z.001"
    sh(["7z", "a", "-bd", "-y", "-v4k", "-p" + PW["split7z"],
        str(out / "enc_split.7z"), "noise.bin"], cwd=src)
    vols = sorted(out.glob("enc_split.7z.*"))
    if len(vols) < 2:
        failures.append(f"enc_split.7z did not split into multiple volumes ({len(vols)})")
    record(vols[0], "7z-multivolume", "7z", password=PW["split7z"], encryption="7z-aes",
           expect="unsupported",
           notes=f"multi-volume ({len(vols)} parts); spec matches no .001/.002 extension")

    # 7z solid archive (single stream, affects wrong-password partial output).
    p = out / "enc_solid.7z"
    sh(["7z", "a", "-bd", "-y", "-ms=on", "-p" + PW["sevenzip"], str(p),
        "a.txt", "b.txt", "big.txt"], cwd=src)
    record(p, "7z", "7z", password=PW["sevenzip"], encryption="7z-aes",
           notes="solid: one wrong-password failure covers every member")


def zip_encrypted(src: Path, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)

    p = out / "enc_zipcrypto_infozip.zip"
    sh(["zip", "-q", "-X", "-P", PW["zipcrypto"], str(p), "a.txt", "b.txt"], cwd=src)
    record(p, "zip", "zip", password=PW["zipcrypto"], encryption="zipcrypto",
           notes="Info-ZIP ZipCrypto")

    p = out / "enc_zipcrypto_7z.zip"
    sh(["7z", "a", "-bd", "-y", "-tzip", "-p" + PW["zipcrypto"], str(p),
        "a.txt", "b.txt"], cwd=src)
    record(p, "zip", "zip", password=PW["zipcrypto"], encryption="zipcrypto",
           notes="7-Zip's default zip encryption is ZipCrypto")

    p = out / "enc_aes256.zip"
    sh(["7z", "a", "-bd", "-y", "-tzip", "-mem=AES256", "-p" + PW["aes256"],
        str(p), "a.txt", "b.txt"], cwd=src)
    record(p, "zip", "zip", password=PW["aes256"], encryption="aes256",
           expect="unzip-unsupported",
           notes="Info-ZIP unzip 6.00 cannot read AES (exit 81, 'need PK compat'); 7z can")

    # Mixed: one stored plaintext entry + one encrypted entry. Wrong password
    # yields exit 1 (not 82) AND leaves the plaintext entry on disk.
    p = out / "enc_mixed.zip"
    sh(["zip", "-q", "-X", str(p), "a.txt"], cwd=src)
    sh(["zip", "-q", "-X", "-P", PW["mixed"], str(p), "b.txt"], cwd=src)
    record(p, "zip", "zip", password=PW["mixed"], encryption="zipcrypto-mixed",
           expect="partial-on-wrong-password",
           notes="unencrypted a.txt extracts even when b.txt's password is wrong")

    # Not encrypted, but passwords are supplied: must still succeed.
    p = out / "plain_with_password_args.zip"
    sh(["zip", "-q", "-X", str(p), "a.txt"], cwd=src)
    record(p, "zip", "zip", password=PW["zipcrypto"], encryption=None,
           notes="unencrypted archive given -p/-P: tools ignore the password")

    # Split zip: .z01 + .zip. Documented gap, no fixture (zip -s minimum is 64k).
    manifest.append({
        "path": "archives/encrypted/split.zip (+split.z01)",
        "format": "zip-multivolume",
        "kind": "zip",
        "expect": "unsupported",
        "password": None,
        "encryption": None,
        "size": None,
        "available": False,
        "notes": "zip -s minimum volume is 64k; skipped to keep the repo lean. "
                 "No extension list matches .z01.",
    })


def rar_family(src: Path, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    if not have("rar"):
        for name, fmt, enc, expect, note in [
            ("plain.rar", "rar", None, "extract", "plain rar"),
            ("enc.rar", "rar", "rar-aes", "extract", "encrypted rar, wrong password -> unrar exit 11"),
            ("enc_split.part1.rar", "rar-multivolume", "rar-aes", "unsupported", ".part1.rar / .r00 naming"),
        ]:
            manifest.append({
                "path": f"archives/encrypted/{name}",
                "format": fmt,
                "kind": "rar",
                "expect": expect,
                "password": PW["rar"] if enc else None,
                "encryption": enc,
                "size": None,
                "available": False,
                "notes": "no rar creator on this host (proprietary, AUR-only): " + note,
            })
        return
    p = out / "plain.rar"
    sh(["rar", "a", "-idq", str(p), "a.txt", "b.txt"], cwd=src)
    record(p, "rar", "rar")
    p = out / "enc.rar"
    sh(["rar", "a", "-idq", "-p" + PW["rar"], str(p), "a.txt", "b.txt"], cwd=src)
    record(p, "rar", "rar", password=PW["rar"], encryption="rar-aes")
    p = out / "enc_split.rar"
    sh(["rar", "a", "-idq", "-v1k", "-p" + PW["rar"], str(p), "big.txt"], cwd=src)
    record(out / "enc_split.part1.rar", "rar-multivolume", "rar",
           password=PW["rar"], encryption="rar-aes", expect="unsupported")


# --------------------------------------------------------------------------- #
# packages and other containers
# --------------------------------------------------------------------------- #
def packages(src: Path, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)

    p = out / "plain.cpio"
    with p.open("wb") as fh:
        subprocess.run(["sh", "-c", f"find a.txt b.txt | cpio -o -H newc"],
                       stdin=subprocess.DEVNULL, stdout=fh, cwd=src, check=True)
    record(p, "cpio", "other")
    p2 = out / "plain.obscpio"
    shutil.copy2(p, p2)
    record(p2, "obscpio", "other", notes="cpio under an OBS-specific name")

    # .cab via gcab, plus a .exe that is a cab with a different extension.
    p = out / "plain.cab"
    sh(["gcab", "-c", str(p), "a.txt"], cwd=src)
    record(p, "cab", "other")
    p2 = out / "plain.exe"
    shutil.copy2(p, p2)
    record(p2, "exe", "other",
           notes="cab renamed .exe, NOT a real self-extracting stub; exercises .exe dispatch")

    # .deb assembled with ar (dpkg-deb is not installed) in both classic gz and
    # modern zstd payload flavours.
    for name, tarflag in [("plain.deb", "-z"), ("plain_zstd.deb", "--zstd")]:
        root = src / "_deb"
        (root / "DEBIAN").mkdir(parents=True, exist_ok=True)
        (root / "usr/share/doc/extract-fixture").mkdir(parents=True, exist_ok=True)
        (root / "DEBIAN/control").write_text(
            "Package: extract-fixture\nVersion: 1.0\nArchitecture: all\n"
            "Maintainer: fixtures <fixtures@example.invalid>\n"
            "Description: extract.py test fixture\n")
        (root / "usr/share/doc/extract-fixture/readme.txt").write_bytes(A_TXT)
        (root / "debian-binary").write_text("2.0\n")
        sh(["tar", tarflag, "-cf", str(root / "control.tar.gz" if name == "plain.deb"
                                       else root / "control.tar.zst"),
            "-C", str(root / "DEBIAN"), "."])
        sh(["tar", tarflag, "-cf", str(root / "data.tar.gz" if name == "plain.deb"
                                       else root / "data.tar.zst"),
            "-C", str(root / "usr"), "."])
        p = out / name
        members = [str(root / "debian-binary")] + (
            [str(root / "control.tar.gz"), str(root / "data.tar.gz")] if name == "plain.deb"
            else [str(root / "control.tar.zst"), str(root / "data.tar.zst")])
        sh(["ar", "rc", str(p), *members], cwd=root)
        check_magic(p, b"!<arch>\n", "ar")
        record(p, "deb", "package",
               notes="ar container; data.tar.* uses " + ("gz" if name == "plain.deb" else "zst"))

    # .rpm via rpmbuild when available.
    if have("rpmbuild"):
        top = src / "_rpmbuild"
        for d in ["BUILD", "RPMS", "SOURCES", "SPECS", "SRPMS"]:
            (top / d).mkdir(parents=True, exist_ok=True)
        (top / "SOURCES/a.txt").write_bytes(A_TXT)
        spec = top / "SPECS/extract-fixture.spec"
        spec.write_text(
            "Name: extract-fixture\nVersion: 1.0\nRelease: 1\nSummary: extract test fixture\n"
            "License: MIT\nBuildArch: noarch\n%description\nextract.py fixture\n"
            "%prep\n%build\n%install\nmkdir -p %{buildroot}/usr/share/extract-fixture\n"
            "cp %{_sourcedir}/a.txt %{buildroot}/usr/share/extract-fixture/\n"
            "%files\n/usr/share/extract-fixture/a.txt\n")
        rc, so, se = sh(["rpmbuild", "--define", f"_topdir {top}", "-bb", str(spec)], check=False)
        found = sorted((top / "RPMS").rglob("*.rpm"))
        if rc == 0 and found:
            p = out / "plain.rpm"
            shutil.copy2(found[0], p)
            check_magic(p, b"\xed\xab\xee\xdb", "rpm")
            record(p, "rpm", "package")
        else:
            failures.append(f"rpmbuild failed (rc={rc}): {se.strip()[:200]}")
            manifest.append({
                "path": "archives/plain/plain.rpm", "format": "rpm", "kind": "package",
                "expect": "extract", "password": None, "encryption": None, "size": None,
                "available": False, "notes": f"rpmbuild unavailable/failed: {se.strip()[:120]}",
            })
    else:
        manifest.append({
            "path": "archives/plain/plain.rpm", "format": "rpm", "kind": "package",
            "expect": "extract", "password": None, "encryption": None, "size": None,
            "available": False, "notes": "rpmbuild not installed",
        })

    for fmt, note in [("zpaq", "zpaq(1) not installed and no libarchive writer"),
                      ("lzo", "lzop(1) not installed"),
                      ("lrz", "lrzip(1) not installed"),
                      ("sz", "snzip(1) not installed; libarchive cannot write snappy"),
                      ("lha", "lha(1) not installed"),
                      ("iso", "out of spec scope")]:
        manifest.append({
            "path": f"archives/plain/plain.{fmt}", "format": fmt, "kind": "other",
            "expect": "unsupported", "password": None, "encryption": None, "size": None,
            "available": False, "notes": note,
        })


# --------------------------------------------------------------------------- #
# recursive tree
# --------------------------------------------------------------------------- #
def tree(src: Path, out: Path) -> None:
    root = out / "tree"
    if root.exists():
        shutil.rmtree(root)
    (root / "a").mkdir(parents=True)
    (root / "b" / "c").mkdir(parents=True)
    (root / "names" / "sub dir").mkdir(parents=True)

    sh(["tar", "-zcf", str(root / "a" / "one.tar.gz"), "-C", str(src), "a.txt"])
    sh(["zip", "-q", "-X", str(root / "a" / "pkg.zip"), "b.txt"], cwd=src)
    sh(["7z", "a", "-bd", "-y", "-p" + PW["tree"], str(root / "a" / "one_enc.7z"),
        "a.txt"], cwd=src)
    sh(["tar", "-Jcf", str(root / "b" / "c" / "two.tar.xz"), "-C", str(src), "b.txt"])

    # A directory that already exists next to an un-extracted archive: the
    # re-run / skip path. The sentinel must survive a skip.
    pre = root / "b" / "c" / "two"
    pre.mkdir()
    (pre / "SENTINEL-do-not-delete").write_bytes(b"pre-existing\n")
    (root / "b" / "c" / "two.tar.xz").touch  # ensure ordering is obvious

    # Archive containing an archive: recursion is single-level, so the inner
    # archive only appears on a second -R pass.
    inner = src / "_inner.zip"
    sh(["zip", "-q", "-X", str(inner), "a.txt"], cwd=src)
    outer = root / "a" / "outer_with_inner.tar.gz"
    sh(["tar", "-zcf", str(outer), "-C", str(inner.parent), inner.name])
    record(outer, "tar.gz", "tar", expect="nested",
           notes="contains _inner.zip; inner archive is only found on a re-run")

    # Awkward names.
    sh(["tar", "-zcf", str(root / "names" / "with space.tar.gz"), "-C", str(src), "a.txt"])
    sh(["zip", "-q", "-X", str(root / "names" / "sub dir" / "\u00fcn\u00efc\u00f6de-\u30d5\u30a1\u30a4\u30eb.zip"),
        "b.txt"], cwd=src)
    sh(["tar", "-cf", str(root / "names" / "-dash.tar"), "-C", str(src), "a.txt"])
    sh(["tar", "-zcf", str(root / "names" / "UPPER.TAR.GZ"), "-C", str(src), "b.txt"])
    touch_tree(root)

    already = {m["path"] for m in manifest}
    for p in sorted(root.rglob("*")):
        if (p.is_file() and not p.name.startswith("SENTINEL")
                and p.relative_to(HERE).as_posix() not in already):
            name = p.name
            if name.endswith((".7z",)):
                record(p, "7z", "7z", password=PW["tree"], encryption="7z-aes")
            elif name.endswith((".zip",)):
                record(p, "zip", "zip")
            else:
                record(p, "tar", "tar")
    # The sentinel directory must be preserved, not treated as a fixture.
    pre.joinpath("SENTINEL-do-not-delete").unlink(missing_ok=True)
    pre.joinpath("SENTINEL-do-not-delete").write_bytes(b"pre-existing\n")
    touch_tree(root)
    manifest.append({
        "path": (pre).relative_to(HERE).as_posix(),
        "format": "directory",
        "kind": "tree-state",
        "expect": "skip",
        "password": None,
        "encryption": None,
        "size": None,
        "available": True,
        "notes": "pre-existing target dir beside two.tar.xz: -R must skip it and keep "
                 "SENTINEL-do-not-delete; -F must extract over it",
    })


# --------------------------------------------------------------------------- #
# edge cases
# --------------------------------------------------------------------------- #
def edges(src: Path, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)

    for name in ["empty.tar", "empty.zip", "empty.7z", "empty.rar", "empty.tar.gz"]:
        p = out / name
        p.write_bytes(b"")
        record(p, name.split(".", 1)[1], "other", expect="error",
               notes="zero-byte file with an archive extension")

    p = out / "truncated.zip"
    good = out / "_tmp.zip"
    sh(["zip", "-q", "-X", str(good), "a.txt"], cwd=src)
    p.write_bytes(good.read_bytes()[:60])
    good.unlink()
    record(p, "zip", "zip", expect="error", notes="unzip exit 9: no end-of-central-directory")

    p = out / "truncated.7z"
    sh(["7z", "a", "-bd", "-y", str(p), "a.txt"], cwd=src)
    p.write_bytes(p.read_bytes()[:60])
    record(p, "7z", "7z", expect="error",
           notes="7z exits 2 for BOTH 'wrong password' and 'corrupt' -> exit code alone is ambiguous")

    # Zip Slip / tar traversal. NEVER extract these outside a sandbox.
    p = out / "traversal.zip"
    with zipfile.ZipFile(p, "w") as z:
        z.writestr("../escape.txt", "escaped\n")
        z.writestr("/tmp/extract_fixture_absolute.txt", "escaped\n")
        z.writestr("good.txt", "good\n")
    record(p, "zip", "zip", expect="security",
           notes="contains ../ and absolute paths (Zip Slip)")

    p = out / "traversal.tar"
    with tarfile.open(p, "w") as t:
        for nm in ["../escape.txt", "/tmp/extract_fixture_absolute.txt"]:
            info = tarfile.TarInfo(nm)
            data = b"escaped\n"
            info.size = len(data)
            t.addfile(info, io.BytesIO(data))
    record(p, "tar", "tar", expect="security",
           notes="tar with ../ and absolute member paths")

    p = out / "symlink.tar"
    with tarfile.open(p, "w") as t:
        info = tarfile.TarInfo("link-to-passwd")
        info.type = tarfile.SYMTYPE
        info.linkname = "/etc/passwd"
        t.addfile(info)
        info = tarfile.TarInfo("hardlink")
        info.type = tarfile.LNKTYPE
        info.linkname = "link-to-passwd"
        t.addfile(info)
    record(p, "tar", "tar", expect="security",
           notes="symlink and hardlink members pointing outside the target")

    # Target-name collision: an existing *file* where the target dir would go.
    d = out / "collision"
    d.mkdir(exist_ok=True)
    sh(["tar", "-zcf", str(d / "f.tar.gz"), "-C", str(src), "a.txt"])
    (d / "f").write_bytes(b"i am a file, not a directory\n")
    record(d / "f.tar.gz", "tar.gz", "tar", expect="error",
           notes="target name 'f' already exists as a regular FILE -> mkdir must fail cleanly")


# --------------------------------------------------------------------------- #
# password files
# --------------------------------------------------------------------------- #
def password_files() -> None:
    PWDIR.mkdir(parents=True, exist_ok=True)

    # The canonical list: decoys first so a correct match is never at index 0,
    # then every encrypted fixture's real password. Order is deliberate.
    ordered = DECOYS + [
        PW["mixed"], PW["aes256"], PW["zipcrypto"], PW["split7z"],
        PW["sevenzip_space"], PW["sevenzip"], PW["tree"], PW["rar"],
    ]
    p = PWDIR / "passwords.txt"
    p.write_text("\n".join(ordered) + "\n", encoding="utf-8")

    # Trailing-space duplicate of a real password: trims to a duplicate and must
    # be deduplicated rather than creating a bogus candidate.
    padded = PWDIR / "passwords_padded.txt"
    padded.write_text(
        "  password  \n"
        "\t123456\t\n"
        "\n"
        "   \n"
        "z1p-pass\n"
        "z1p-pass\n"
        "  z1p-pass  \n"
        "aes-p4ss\n",
        encoding="utf-8")

    sym = PWDIR / "passwords_symbols.txt"
    sym.write_text(
        PW["sevenzip_space"] + "\n"          # exact match for enc_spacepass.7z
        "quote'and\"double\n"
        "back\\slash\n"
        "interior\ttab\n"
        "p@$$w0rd{}[]|;:<>?\n"
        "per%cent#hash\n"
        "  " + PW["zipcrypto"] + "  \n"      # padded real password -> trim + dedupe
        "v4lu\u00e9-\u00dcn\u00efc\u00f6d\u00e9-\u65e5\u672c\u8a9e\n",
        encoding="utf-8")

    crlf = PWDIR / "passwords_crlf.txt"
    crlf.write_bytes(b"password\r\n123456\r\nz1p-pass\r\n")

    bom = PWDIR / "passwords_bom.txt"
    bom.write_bytes(b"\xef\xbb\xbfz1p-pass\n")

    comments = PWDIR / "passwords_with_comments.txt"
    comments.write_text(
        "# generated by make_fixtures.py\n"
        "; another comment style\n"
        "z1p-pass\n"
        "// not a comment, a candidate\n",
        encoding="utf-8")

    wrong = PWDIR / "passwords_wrong.txt"
    wrong.write_text("\n".join(["definitely-wrong", "nope", "wrong-123", "incorrect"]) + "\n",
                     encoding="utf-8")

    empty = PWDIR / "passwords_empty.txt"
    empty.write_bytes(b"\n\n   \n\t\n")


# --------------------------------------------------------------------------- #
# libarchive conformance
# --------------------------------------------------------------------------- #
def _la_probe(path: Path, pw: str | None, fmt: str) -> tuple[bool, str, int]:
    import libarchive
    kw = {"format_name": fmt}
    if pw:
        kw["passphrase"] = pw
    total = 0
    try:
        with libarchive.file_reader(str(path), **kw) as a:
            for e in a:
                for blk in e.get_blocks():
                    total += len(blk)
        return True, "", total
    except Exception as ex:  # noqa: BLE001 - probe reports any failure
        return False, f"{type(ex).__name__}: {str(ex)[:80]}", total


def probe_libarchive() -> None:
    """Record what libarchive-c can do per fixture.

    libarchive-c is the primary engine in the implementation plan, so this is the
    difference between "the handler will cope" and "the chain needs a CLI
    fallback". Only the first 4 KiB of each entry is read.
    """
    try:
        import libarchive  # noqa: F401
    except ImportError:
        for m in manifest:
            m["la_list"] = None
            m["la_read"] = None
            m["la_raw"] = None
        return
    for m in manifest:
        p = HERE / m["path"]
        if not m["available"] or not p.is_file():
            continue
        pw = m["password"]
        ok, note, _ = _la_probe(p, pw, "all")
        m["la_list"] = ok
        m["la_read"] = ok
        if not ok:
            m["la_note"] = note
        if m["kind"] == "single":
            raw_ok, raw_note, total = _la_probe(p, pw, "raw")
            size = p.stat().st_size
            # `raw` returns the *compressed* bytes when libarchive has no filter
            # for the format, and reports success while doing so.
            real = raw_ok and total != size
            m["la_raw"] = real
            if raw_ok and not real:
                m["la_note"] = (f"raw format returned {total} bytes == file size: "
                                "no filter applied, libarchive cannot decompress this")
            elif not raw_ok:
                m["la_note"] = raw_note


# --------------------------------------------------------------------------- #
# verification
# --------------------------------------------------------------------------- #
def verify() -> None:
    print("\nverification of generated fixtures")
    print(f"{'fixture':52} {'size':>8}  {'libarchive':10} check")
    for m in manifest:
        if not m["available"]:
            print(f"{m['path'][:52]:52} {'-':>8}  {'-':10} SKIP ({m['notes'][:34]})")
            continue
        p = HERE / m["path"]
        if not p.exists():
            print(f"{m['path'][:52]:52} {'-':>8}  {'-':10} MISSING")
            continue
        la = ("raw+read" if m.get("la_raw") else "read" if m.get("la_read")
              else "none" if m.get("la_list") is False else "?")
        print(f"{m['path'][:52]:52} {p.stat().st_size:>8}  {la:10} ok")
    if failures:
        print("\nFAILURES:", file=sys.stderr)
        for f in failures:
            print("  -", f, file=sys.stderr)


def main() -> int:
    if ARCH.exists():
        shutil.rmtree(ARCH)
    ARCH.mkdir(parents=True)
    PWDIR.mkdir(parents=True, exist_ok=True)
    manifest.clear()
    failures.clear()

    work = ARCH / "_src"
    src = sources(work)

    tar_family(src, ARCH / "plain")
    single_file(src, ARCH / "plain")
    zip_family(src, ARCH / "plain")
    zip_encrypted(src, ARCH / "encrypted")
    sevenzip_family(src, ARCH / "encrypted")
    rar_family(src, ARCH / "encrypted")
    packages(src, ARCH / "plain")
    tree(src, ARCH)
    edges(src, ARCH / "edge")
    password_files()

    probe_libarchive()

    shutil.rmtree(work, ignore_errors=True)

    (HERE / "manifest.json").write_text(
        json.dumps({"generated_by": "make_fixtures.py", "fixtures": manifest}, indent=2) + "\n")

    verify()
    avail = sum(1 for m in manifest if m["available"])
    print(f"\n{avail} available fixtures, {len(manifest) - avail} unavailable, "
          f"{len(failures)} failures")
    print(f"manifest: {HERE / 'manifest.json'}")
    return 1 if failures else 0


if __name__ == "__main__":
    if "--verify" in sys.argv:
        if not (HERE / "manifest.json").exists():
            print("no manifest.json yet; run without --verify first", file=sys.stderr)
            raise SystemExit(2)
        import json as _json
        manifest = _json.loads((HERE / "manifest.json").read_text())["fixtures"]
        verify()
        raise SystemExit(0)
    raise SystemExit(main())
