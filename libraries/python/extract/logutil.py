"""Output discipline (spec §5): all of extract's status goes to stderr.

The vendored standard_logging sends only error/critical to stderr; redirect
stdout to stderr for the duration of the call so every level lands there.
"""

import sys

from standard_logging import log as _log


def log(level: str, *messages: str) -> None:
    """standard_logging.log with every level forced to stderr."""
    real_stdout = sys.stdout
    sys.stdout = sys.stderr
    try:
        _log(level, *messages)
    finally:
        sys.stdout = real_stdout


def redact(text: str, candidates: list[str]) -> str:
    """Mask every candidate in `text` (spec §8.3 — never log passwords)."""
    for candidate in candidates:
        if candidate:
            text = text.replace(candidate, "***")
    return text
