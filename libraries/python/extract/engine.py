"""Generic dispatch engine: capability-gated chains (spec §7.1, §7.3)."""

from collections.abc import Callable
from dataclasses import dataclass
from enum import Enum, auto
from pathlib import Path
from typing import Protocol


class ErrorClass(Enum):
    NONE = auto()
    WRONG_PASSWORD = auto()
    BACKEND_UNSUPPORTED = auto()
    EXTRACT_ERROR = auto()


@dataclass
class Result:
    cls: ErrorClass
    detail: str = ""
    candidate_index: int | None = None

    @property
    def ok(self) -> bool:
        return self.cls is ErrorClass.NONE


PASSWORD_FAMILIES = frozenset({"zip", "7z", "rar"})


class Handler(Protocol):
    name: str
    password_capable: bool

    def available(self) -> bool: ...

    def extract(self, archive: Path, dest: Path, password: str | None) -> Result: ...


def resolve(
    archive: Path,
    family: str,
    chain: tuple[str, ...],
    handlers: dict[str, Handler],
    passwords: list[str],
    new_tempdir: Callable[[], Path],
) -> tuple[Result, Path | None]:
    """Walk `chain` for `archive`; returns (result, tempdir) — tempdir only on success.

    Traversal rules (spec §7.3):
    - unavailable handlers are skipped;
    - the password gate applies only within PASSWORD_FAMILIES (candidates are
      ignored for every other family — a single no-password attempt per handler);
    - WRONG_PASSWORD advances candidates within the same handler;
    - BACKEND_UNSUPPORTED descends to the next handler, candidates restarted;
    - EXTRACT_ERROR is fatal for the archive.
    The caller owns the final placement; this function deletes every tempdir
    it creates except the successful one it returns.
    """
    import shutil

    if passwords and family in PASSWORD_FAMILIES:
        attempts: list[str | None] = list(passwords)
    else:
        attempts = [None]

    for handler_name in chain:
        handler = handlers.get(handler_name)
        if handler is None or not handler.available():
            continue
        if attempts[0] is not None and not handler.password_capable:
            continue
        for index, password in enumerate(attempts):
            tmp = new_tempdir()
            result = handler.extract(archive, tmp, password)
            if result.ok:
                result.candidate_index = index if password is not None else None
                return result, tmp
            shutil.rmtree(tmp, ignore_errors=True)
            if result.cls is ErrorClass.WRONG_PASSWORD:
                continue
            if result.cls is ErrorClass.BACKEND_UNSUPPORTED:
                break
            return result, None
    return Result(ErrorClass.EXTRACT_ERROR, "no capable handler succeeded"), None
