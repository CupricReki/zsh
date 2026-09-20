"""Archive discovery: families, split volumes, target naming (spec §6.2)."""

import pytest

from extract.discovery import (
    DiscoveryError,
    discover,
    family_for,
    is_skipped_volume,
    target_name,
)


def test_family_mapping():
    assert family_for("a.tar.gz") == "tar"
    assert family_for("B.TGZ") == "tar"
    assert family_for("a.tar.zst") == "tar"
    assert family_for("a.tar.br") == "tar"
    assert family_for("a.tar.bz") == "tar"
    assert family_for("a.tar.Z") == "tar"
    assert family_for("x.zip") == "zip"
    assert family_for("x.whl") == "zip"
    assert family_for("x.7z") == "7z"
    assert family_for("x.7z.001") == "7z"
    assert family_for("x.rar") == "rar"
    assert family_for("x.part1.rar") == "rar"
    assert family_for("x.rpm") == "rpm"
    assert family_for("x.deb") == "deb"
    assert family_for("x.gz") == "single"
    assert family_for("x.br") == "single"
    assert family_for("x.Z") == "single"
    assert family_for("x.lz") == "single"
    assert family_for("x.zstd") == "single"
    assert family_for("x.zlib") == "zlib"
    assert family_for("x.cab") == "cab"
    assert family_for("notes.txt") is None


def test_target_name_strips_extension_chain():
    assert target_name("foo.tar.gz") == "foo"
    assert target_name("bar.2024.tgz") == "bar.2024"
    assert target_name("foo.tar.bz2") == "foo"
    assert target_name("foo.part1.rar") == "foo"
    assert target_name("foo.7z.001") == "foo"
    assert target_name("foo.zip") == "foo"
    assert target_name("archive.tar.zst") == "archive"


@pytest.mark.parametrize(
    ("name", "expected"),
    [
        ("foo.part1.rar", False),
        ("foo.part2.rar", True),
        ("foo.part10.rar", True),
        ("foo.rar", False),
        ("foo.r00", True),
        ("foo.r01", True),
        ("foo.7z.001", False),
        ("foo.7z.002", True),
        ("foo.z01", True),
        ("foo.z02", True),
        ("foo.zip", False),
    ],
)
def test_volume_filter(name, expected):
    assert is_skipped_volume(name) is expected


def test_discover_recursive_sorts_and_filters(tmp_path):
    (tmp_path / "b.zip").write_text("x")
    (tmp_path / "a.tar.gz").write_text("x")
    (tmp_path / "a.tar.gz.part2.rar").write_text("x")
    (tmp_path / "sub").mkdir()
    (tmp_path / "sub" / "c.rar").write_text("x")
    (tmp_path / "sub" / "c.r00").write_text("x")
    (tmp_path / "notes.txt").write_text("x")
    found = discover([tmp_path], recursive=True)
    assert [p.name for p in found] == ["a.tar.gz", "b.zip", "c.rar"]


def test_discover_explicit_file_bypasses_volume_filter(tmp_path):
    part = tmp_path / "foo.part2.rar"
    part.write_text("x")
    found = discover([part], recursive=False)
    assert [p.name for p in found] == ["foo.part2.rar"]


def test_discover_rejects_unknown_path(tmp_path):
    stray = tmp_path / "notes.txt"
    stray.write_text("x")
    with pytest.raises(DiscoveryError):
        discover([stray], recursive=False)


def test_discover_directory_requires_recursive(tmp_path):
    (tmp_path / "a.zip").write_text("x")
    with pytest.raises(DiscoveryError):
        discover([tmp_path], recursive=False)
