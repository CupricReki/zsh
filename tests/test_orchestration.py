"""Orchestration: temp dirs, placement, collapse, merge, -r safeguard (spec §6)."""

import os
import tarfile
from pathlib import Path

from extract.orchestration import (
    MARKER_NAME,
    collapse_tree,
    compute_target,
    make_tempdir,
    merge_into,
    process_archive,
    remove_archive,
    sweep_stale,
)


def make_tar(path: Path) -> None:
    src = path.parent / "src"
    src.mkdir(exist_ok=True)
    (src / "a.txt").write_text("a\n")
    (src / "b.txt").write_text("b\n")
    with tarfile.open(path, "w:gz") as tf:
        tf.add(src / "a.txt", arcname="a.txt")
        tf.add(src / "b.txt", arcname="b.txt")


def make_single_dir_tar(path: Path) -> None:
    src = path.parent / "pkg"
    src.mkdir(exist_ok=True)
    (src / "inner.txt").write_text("i\n")
    with tarfile.open(path, "w:gz") as tf:
        tf.add(src / "inner.txt", arcname="pkg/inner.txt")


class TestMakeTempdir:
    def test_creates_marked_sibling(self, tmp_path):
        archive = tmp_path / "x.zip"
        archive.write_text("x")
        tmp = make_tempdir(archive)
        assert tmp.parent == tmp_path
        assert tmp.name.startswith(".extract-x.zip-")
        marker = tmp / MARKER_NAME
        assert marker.is_file()
        assert f"archive={archive}" in marker.read_text()


class TestSweepStale:
    def test_removes_marked_stale(self, tmp_path):
        archive = tmp_path / "x.zip"
        archive.write_text("x")
        tmp = make_tempdir(archive)
        assert tmp.exists()
        sweep_stale(archive)
        assert not tmp.exists()

    def test_leaves_unmarked_dir(self, tmp_path):
        archive = tmp_path / "x.zip"
        archive.write_text("x")
        stranger = tmp_path / ".extract-x.zip-000000"
        stranger.mkdir()
        (stranger / "precious.txt").write_text("keep")
        sweep_stale(archive)
        assert (stranger / "precious.txt").read_text() == "keep"


class TestComputeTarget:
    def test_fresh_target(self, tmp_path):
        assert compute_target(tmp_path / "a.tar.gz", force=False) == tmp_path / "a"

    def test_existing_target_gets_suffix(self, tmp_path):
        (tmp_path / "a").mkdir()
        target = compute_target(tmp_path / "a.tar.gz", force=False)
        assert target != tmp_path / "a"
        assert target.name.startswith("a-")

    def test_force_reuses_target(self, tmp_path):
        (tmp_path / "a").mkdir()
        assert compute_target(tmp_path / "a.tar.gz", force=True) == tmp_path / "a"


class TestCollapseTree:
    def test_flattens_single_dir(self, tmp_path):
        tree = tmp_path / "t"
        (tree / "pkg").mkdir(parents=True)
        (tree / "pkg" / "inner.txt").write_text("i")
        collapse_tree(tree)
        assert (tree / "inner.txt").read_text() == "i"
        assert not (tree / "pkg").exists()

    def test_multiple_entries_untouched(self, tmp_path):
        tree = tmp_path / "t"
        (tree / "one").mkdir(parents=True)
        (tree / "two").mkdir(parents=True)
        collapse_tree(tree)
        assert (tree / "one").is_dir() and (tree / "two").is_dir()


class TestMergeInto:
    def test_merge_never_prunes(self, tmp_path):
        src = tmp_path / "src"
        dst = tmp_path / "dst"
        src.mkdir(); dst.mkdir()
        (src / "new.txt").write_text("new")
        (src / "both.txt").write_text("from-archive")
        (dst / "both.txt").write_text("old")
        (dst / "precious.txt").write_text("keep")
        merge_into(src, dst)
        assert (dst / "precious.txt").read_text() == "keep"  # not pruned
        assert (dst / "both.txt").read_text() == "from-archive"  # overwritten
        assert (dst / "new.txt").read_text() == "new"  # added

    def test_nested_dir_merge(self, tmp_path):
        src = tmp_path / "src"
        dst = tmp_path / "dst"
        (src / "d").mkdir(parents=True); (dst / "d").mkdir(parents=True)
        (src / "d" / "n.txt").write_text("n")
        (dst / "d" / "p.txt").write_text("p")
        merge_into(src, dst)
        assert (dst / "d" / "n.txt").read_text() == "n"
        assert (dst / "d" / "p.txt").read_text() == "p"

    def test_symlinked_dir_replaced_not_followed(self, tmp_path):
        src = tmp_path / "src"
        dst = tmp_path / "dst"
        (src / "d").mkdir(parents=True)
        (src / "d" / "n.txt").write_text("n")
        real = tmp_path / "real"
        real.mkdir()
        (real / "p.txt").write_text("p")
        dst.mkdir()
        (dst / "d").symlink_to(real, target_is_directory=True)
        merge_into(src, dst)
        assert not (dst / "d").is_symlink()
        assert (dst / "d" / "n.txt").read_text() == "n"
        assert (real / "p.txt").read_text() == "p"  # referent untouched


class TestRemoveArchive:
    def test_removes_unchanged(self, tmp_path):
        archive = tmp_path / "x.tar.gz"
        make_tar(archive)
        stat_before = archive.stat()
        remove_archive(archive, stat_before)
        assert not archive.exists()

    def test_keeps_changed_archive(self, tmp_path):
        archive = tmp_path / "x.tar.gz"
        make_tar(archive)
        stat_before = archive.stat()
        archive.write_bytes(archive.read_bytes() + b"\x00")
        remove_archive(archive, stat_before)
        assert archive.exists()


class TestProcessArchive:
    def test_extract_and_remove(self, tmp_path):
        archive = tmp_path / "x.tar.gz"
        make_tar(archive)
        assert process_archive(archive, [], force=False, remove=True, skip_existing=False, family="tar")
        target = tmp_path / "x"
        assert (target / "a.txt").read_text() == "a\n"
        assert not archive.exists()
        leftovers = [p for p in tmp_path.iterdir() if p.name.startswith(".extract-")]
        assert leftovers == []

    def test_collapse_applied(self, tmp_path):
        archive = tmp_path / "x.tar.gz"
        make_single_dir_tar(archive)
        assert process_archive(archive, [], force=False, remove=False, skip_existing=False, family="tar")
        target = tmp_path / "x"
        assert (target / "inner.txt").read_text() == "i\n"  # not x/pkg/inner.txt

    def test_recursive_skip(self, tmp_path):
        archive = tmp_path / "x.tar.gz"
        make_tar(archive)
        assert process_archive(archive, [], force=False, remove=False, skip_existing=False, family="tar")
        assert process_archive(archive, [], force=False, remove=False, skip_existing=True, family="tar")
        assert archive.exists()  # untouched on skip

    def test_force_merges(self, tmp_path):
        archive = tmp_path / "x.tar.gz"
        make_tar(archive)
        assert process_archive(archive, [], force=False, remove=False, skip_existing=False, family="tar")
        target = tmp_path / "x"
        (target / "mine.txt").write_text("mine")
        assert process_archive(archive, [], force=True, remove=False, skip_existing=False, family="tar")
        assert (target / "mine.txt").read_text() == "mine"  # merge never prunes
        assert (target / "a.txt").read_text() == "a\n"

    def test_failure_leaves_no_target(self, tmp_path):
        archive = tmp_path / "x.tar.gz"
        archive.write_bytes(b"\x1f\x8b total garbage")
        assert not process_archive(archive, [], force=False, remove=True, skip_existing=False, family="tar")
        assert archive.exists()  # -r never removes on failure
        assert not (tmp_path / "x").exists()
