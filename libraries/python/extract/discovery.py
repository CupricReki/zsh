"""Archive discovery: families, split-volume filtering, target naming (spec §6.2)."""

import re
from pathlib import Path

# Suffixes consumed when deriving a target name — longest first, case-insensitive.
# Compound suffixes (incl. split-archive first volumes) consume as one unit.
NAME_SUFFIXES: tuple[str, ...] = (
    ".tar.zst", ".tar.bz2", ".tar.gz", ".tar.lz4", ".tar.lrz", ".tar.lz",
    ".tar.br", ".tar.xz", ".tar.zma", ".tar.bz", ".tar.z",
    ".tbz2", ".tbz", ".tgz", ".txz", ".tzst", ".tlz",
    ".part1.rar", ".7z.001",
    ".sublime-package",
    ".tar", ".rar", ".zip", ".7z", ".gz", ".bz2", ".xz", ".lrz", ".lz4",
    ".lzma", ".z", ".zst", ".zstd", ".br", ".lz", ".zpaq", ".zlib",
    ".rpm", ".deb", ".cab", ".exe",
    ".cpio", ".obscpio", ".war", ".jar", ".ear", ".ipa", ".ipsw", ".xpi",
    ".apk", ".aar", ".whl",
)

FAMILY_BY_SUFFIX: dict[str, str] = {
    ".tar.zst": "tar", ".tar.bz2": "tar", ".tar.gz": "tar", ".tar.lz4": "tar",
    ".tar.lrz": "tar", ".tar.lz": "tar", ".tar.br": "tar", ".tar.xz": "tar",
    ".tar.zma": "tar", ".tar.bz": "tar", ".tar.z": "tar",
    ".tbz2": "tar", ".tbz": "tar", ".tgz": "tar", ".txz": "tar", ".tzst": "tar",
    ".tlz": "tar", ".tar": "tar",
    ".zip": "zip", ".war": "zip", ".jar": "zip", ".ear": "zip",
    ".sublime-package": "zip", ".ipa": "zip", ".ipsw": "zip", ".xpi": "zip",
    ".apk": "zip", ".aar": "zip", ".whl": "zip",
    ".7z": "7z", ".7z.001": "7z",
    ".rar": "rar", ".part1.rar": "rar",
    ".rpm": "rpm", ".deb": "deb", ".cab": "cab", ".exe": "cab",
    ".cpio": "cpio", ".obscpio": "cpio",
    ".zlib": "zlib",
    ".gz": "single", ".bz2": "single", ".xz": "single", ".lrz": "single",
    ".lz4": "single", ".lzma": "single", ".z": "single",
    ".zst": "single", ".zstd": "single", ".br": "single", ".lz": "single",
    ".zpaq": "single",
}

# Volume parts that discovery skips — only the first volume is processed.
SKIP_VOLUME = (
    re.compile(r"\.part(?:[2-9]|\d{2,})\.rar$", re.IGNORECASE),
    re.compile(r"\.r\d{2}$", re.IGNORECASE),
    re.compile(r"\.7z\.\d{3}$", re.IGNORECASE),
    re.compile(r"\.z\d{2}$", re.IGNORECASE),
)


class DiscoveryError(Exception):
    """Raised when an explicit path is neither an archive nor a directory."""


def family_for(name: str) -> str | None:
    """Map a filename (case-insensitive) to its dispatch family, or None."""
    low = name.lower()
    for suffix in NAME_SUFFIXES:
        if low.endswith(suffix):
            return FAMILY_BY_SUFFIX[suffix]
    return None


def target_name(name: str) -> str:
    """Archive name minus all known archive suffixes (e.g. foo.tar.gz -> foo)."""
    result = name
    low = name.lower()
    while True:
        for suffix in NAME_SUFFIXES:
            if low.endswith(suffix):
                result = result[: -len(suffix)]
                low = low[: -len(suffix)]
                break
        else:
            return result or name


def is_skipped_volume(name: str) -> bool:
    """True for non-first volumes of split archives (spec §6.2)."""
    low = name.lower()
    if low.endswith(".7z.001"):
        return False
    return any(pattern.search(low) for pattern in SKIP_VOLUME)


def discover(paths: list[Path], recursive: bool) -> list[Path]:
    """Resolve explicit args into a sorted archive list.

    With `recursive`, directory args are walked (rglob) with the volume
    filter applied; explicit file args are always returned as-is.
    """
    found: list[Path] = []
    for path in paths:
        if path.is_dir() and recursive:
            found.extend(
                a
                for a in sorted(path.rglob("*"))
                if a.is_file() and family_for(a.name) and not is_skipped_volume(a.name)
            )
        elif path.is_file() and family_for(path.name):
            found.append(path)
        else:
            raise DiscoveryError(f"not an archive or (with -R) directory: {path}")
    return found
