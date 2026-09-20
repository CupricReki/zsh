"""Per-archive orchestration (spec §6.1-§6.6)."""

import os
import random
import shutil
import tempfile
from pathlib import Path

from extract.logutil import log, redact

from extract.discovery import target_name
from extract.engine import PASSWORD_FAMILIES, resolve
from extract.handlers import CHAIN_TABLE, HANDLERS

MARKER_NAME = ".extract-owned"

_ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyz"


def _rand5() -> str:
    return "".join(random.choices(_ALPHABET, k=5))


def make_tempdir(archive: Path) -> Path:
    """Create a marked sibling temp dir (spec §6.1, §6.6)."""
    path = Path(tempfile.mkdtemp(prefix=f".extract-{archive.name}-{os.getpid()}-", dir=archive.parent))
    (path / MARKER_NAME).write_text(f"pid={os.getpid()}\narchive={archive}\n")
    return path


def sweep_stale(archive: Path) -> None:
    """Remove stale temp dirs from interrupted runs — only marker-bearing ones (spec §6.6)."""
    for stale in archive.parent.glob(f".extract-{archive.name}-*"):
        if not stale.is_dir():
            continue
        if (stale / MARKER_NAME).is_file():
            shutil.rmtree(stale, ignore_errors=True)
        else:
            log("warning", f"leaving unrecognized directory alone: {stale}")


def compute_target(archive: Path, force: bool) -> Path:
    """Final target dir: plugin parity — suffix on collision unless forced (spec §6.1/§6.3)."""
    parent = archive.parent
    base = parent / target_name(archive.name)
    target = base
    if target.exists() and not force:
        while target.exists():
            target = parent / f"{base.name}-{_rand5()}"
    return target


def collapse_tree(tree: Path) -> None:
    """Flatten a single top-level directory up one level (plugin parity)."""
    entries = [p for p in tree.iterdir() if p.name != MARKER_NAME]
    if len(entries) != 1 or not entries[0].is_dir():
        return
    child = entries[0]
    for item in list(child.iterdir()):
        item.rename(tree / item.name)
    child.rmdir()


def merge_into(src: Path, dst: Path) -> None:
    """Additive-overwrite merge; never prunes files absent from src (spec §6.6)."""
    for item in src.iterdir():
        if item.name == MARKER_NAME:
            continue
        dest_item = dst / item.name
        if (
            item.is_dir() and not item.is_symlink()
            and dest_item.is_dir() and not dest_item.is_symlink()
        ):
            merge_into(item, dest_item)
            continue
        if dest_item.is_dir() and not dest_item.is_symlink():
            shutil.rmtree(dest_item)
        elif dest_item.is_symlink():
            dest_item.unlink()
        dest_item.parent.mkdir(parents=True, exist_ok=True)
        os.replace(item, dest_item)


def remove_archive(archive: Path, stat_before: os.stat_result) -> None:
    """Unlink only the exact processed file, unchanged since start (spec §6.4/§6.6)."""
    if not archive.exists():
        return
    now = archive.stat()
    if (now.st_size, now.st_mtime_ns) != (stat_before.st_size, stat_before.st_mtime_ns):
        log("warning", f"archive changed during extraction; keeping {archive}")
        return
    archive.unlink()


def process_archive(
    archive: Path,
    passwords: list[str],
    *,
    force: bool,
    remove: bool,
    skip_existing: bool,
    family: str,
) -> bool:
    """Extract one archive; True on success or skip, False on failure."""
    # Resolve to an absolute path: subprocess handlers (ar/cpio) run with
    # cwd=dest, so a relative archive path would resolve against dest.
    archive = archive.resolve()
    sweep_stale(archive)
    base_target = archive.parent / target_name(archive.name)

    if not force and base_target.exists():
        if skip_existing:
            log("info", f"skipping {archive.name}: already extracted")
            return True
        if base_target.is_file():
            # findings M12: a target-name collision with a regular file is an
            # error (never clobber or silently suffix over an unrelated file).
            log("error", f"{archive.name}: target {base_target.name} is an existing file")
            return False
        target = compute_target(archive, force=False)
    else:
        target = base_target

    if passwords and family not in PASSWORD_FAMILIES:
        log("info", f"{archive.name}: password candidates ignored for this format")

    stat_before = archive.stat()
    tmp: Path | None = None
    try:
        result, tmp = resolve(
            archive,
            family,
            CHAIN_TABLE.get(family, ()),
            HANDLERS,
            passwords,
            new_tempdir=lambda: make_tempdir(archive),
        )
        if not result.ok:
            log("error", f"{archive.name}: {redact(result.detail, passwords)}")
            return False

        assert tmp is not None
        collapse_tree(tmp)
        (tmp / MARKER_NAME).unlink(missing_ok=True)  # don't leak the ownership marker

        if force and target.exists():
            merge_into(tmp, target)
            shutil.rmtree(tmp, ignore_errors=True)
        else:
            os.replace(tmp, target)

        if remove:
            remove_archive(archive, stat_before)
    except KeyboardInterrupt:
        if tmp is not None and tmp.exists():
            shutil.rmtree(tmp, ignore_errors=True)
        raise
    except Exception as exc:  # noqa: BLE001 — never leak a partial temp dir
        if tmp is not None and tmp.exists():
            shutil.rmtree(tmp, ignore_errors=True)
        log("error", f"{archive.name}: unexpected failure: {redact(str(exc), passwords)}")
        return False

    if result.candidate_index is not None:
        log("success", f"{archive.name} -> {target.name} (password #{result.candidate_index + 1})")
    else:
        log("success", f"{archive.name} -> {target.name}")
    return True
