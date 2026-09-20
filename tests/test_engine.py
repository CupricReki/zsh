"""Dispatch engine traversal (spec §7.1/§7.3) with mocked handlers."""

from pathlib import Path

import pytest

from extract.engine import ErrorClass, Result, resolve


class FakeHandler:
    def __init__(self, name, *, password_capable=False, available=True):
        self.name = name
        self.password_capable = password_capable
        self._available = available
        self.calls: list[tuple[str, str | None]] = []

    def available(self):
        return self._available

    def extract(self, archive, dest, password):
        self.calls.append((self.name, password))
        return Result(ErrorClass.NONE)


@pytest.fixture
def tempdirs(tmp_path):
    made = []

    def factory():
        d = tmp_path / f"tmp{len(made)}"
        d.mkdir()
        made.append(d)
        return d

    return made, factory


def test_success_first_handler(tempdirs):
    made, factory = tempdirs
    h = FakeHandler("h1", password_capable=True)
    result, tmp = resolve(Path("a.zip"), "zip", ("h1",), {"h1": h}, ["pw"], factory)
    assert result.ok
    assert tmp == made[0]
    assert h.calls == [("h1", "pw")]


def test_chain_is_data_driven(tempdirs):
    # reordering the chain changes the winner — zero engine changes (spec §7.1)
    made, factory = tempdirs
    h1 = FakeHandler("h1")
    h2 = FakeHandler("h2")
    result, _ = resolve(Path("a.tar"), "tar", ("h2", "h1"), {"h1": h1, "h2": h2}, [None], factory)
    assert result.ok
    assert h2.calls and not h1.calls


def test_unavailable_handler_skipped(tempdirs):
    made, factory = tempdirs
    h1 = FakeHandler("h1", available=False)
    h2 = FakeHandler("h2")
    result, tmp = resolve(Path("a.zip"), "zip", ("h1", "h2"), {"h1": h1, "h2": h2}, [None], factory)
    assert result.ok
    assert h1.calls == [] and h2.calls == [("h2", None)]


def test_password_gate_skips_non_capable_handler(tempdirs):
    made, factory = tempdirs
    h1 = FakeHandler("h1", password_capable=False)
    h2 = FakeHandler("h2", password_capable=True)
    resolve(Path("a.zip"), "zip", ("h1", "h2"), {"h1": h1, "h2": h2}, ["pw"], factory)
    assert h1.calls == []
    assert h2.calls == [("h2", "pw")]


def test_candidates_ignored_for_non_password_family(tempdirs):
    made, factory = tempdirs
    h = FakeHandler("h1", password_capable=False)
    resolve(Path("a.tar.gz"), "tar", ("h1",), {"h1": h}, ["pw"], factory)
    assert h.calls == [("h1", None)]


def test_wrong_password_advances_candidate_same_handler(tempdirs):
    made, factory = tempdirs

    class Rejecting(FakeHandler):
        def extract(self, archive, dest, password):
            self.calls.append((self.name, password))
            return Result(ErrorClass.NONE if password == "good" else ErrorClass.WRONG_PASSWORD)

    h = Rejecting("h1", password_capable=True)
    result, tmp = resolve(Path("a.7z"), "7z", ("h1",), {"h1": h}, ["bad", "good"], factory)
    assert result.ok and result.candidate_index == 1
    assert h.calls == [("h1", "bad"), ("h1", "good")]
    assert not made[0].exists()  # failed attempt's temp dir was removed


def test_backend_unsupported_descends_and_restarts_candidates(tempdirs):
    made, factory = tempdirs

    class Unsupported(FakeHandler):
        def extract(self, archive, dest, password):
            self.calls.append((self.name, password))
            return Result(ErrorClass.BACKEND_UNSUPPORTED)

    h1 = Unsupported("h1", password_capable=True)
    h2 = FakeHandler("h2", password_capable=True)
    result, tmp = resolve(Path("a.zip"), "zip", ("h1", "h2"), {"h1": h1, "h2": h2}, ["pw"], factory)
    assert result.ok
    assert h1.calls == [("h1", "pw")]
    assert h2.calls == [("h2", "pw")]  # candidates restarted on descend


def test_extract_error_is_fatal(tempdirs):
    made, factory = tempdirs

    class Broken(FakeHandler):
        def extract(self, archive, dest, password):
            self.calls.append((self.name, password))
            return Result(ErrorClass.EXTRACT_ERROR, "corrupt")

    h1 = Broken("h1")
    h2 = FakeHandler("h2")
    result, tmp = resolve(Path("a.tar"), "tar", ("h1", "h2"), {"h1": h1, "h2": h2}, [None], factory)
    assert result.cls is ErrorClass.EXTRACT_ERROR
    assert tmp is None
    assert h2.calls == []  # chain stops


def test_all_fail_returns_error_and_no_tempdir(tempdirs):
    made, factory = tempdirs

    class Wrong(FakeHandler):
        def extract(self, archive, dest, password):
            self.calls.append((self.name, password))
            return Result(ErrorClass.WRONG_PASSWORD)

    h = Wrong("h1", password_capable=True)
    result, tmp = resolve(Path("a.zip"), "zip", ("h1",), {"h1": h}, ["a", "b"], factory)
    assert result.cls is ErrorClass.EXTRACT_ERROR
    assert tmp is None
    assert not made[0].exists() and not made[1].exists()
