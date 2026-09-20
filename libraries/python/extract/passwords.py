"""Password candidate parsing (spec §8.1).

Rules: one candidate per line; strip trailing CR/LF, then trim leading and
trailing spaces/tabs only; skip blank and whitespace-only lines; preserve
everything else verbatim (symbols, interior spaces, non-ASCII); de-duplicate
keeping first occurrence and order.
"""


def parse_password_file(text: str) -> list[str]:
    """Parse file text into ordered, de-duplicated password candidates."""
    text = text.removeprefix("\ufeff")  # strip a UTF-8 BOM (finding M3)
    candidates: list[str] = []
    seen: set[str] = set()
    for raw in text.split("\n"):
        line = raw.rstrip("\r").strip(" \t")
        if not line or line in seen:
            continue
        seen.add(line)
        candidates.append(line)
    return candidates


def load_candidates(password: str | None, password_file: str | None) -> list[str]:
    """Merge -p/-P into one ordered candidate list.

    `password` and `password_file` are mutually exclusive (enforced in
    cli.py); file candidates come first, then the literal (deduplicated).
    """
    candidates: list[str] = []
    seen: set[str] = set()

    def add(candidate: str) -> None:
        if candidate not in seen:
            seen.add(candidate)
            candidates.append(candidate)

    if password_file is not None:
        with open(password_file, "r", encoding="utf-8", errors="surrogateescape") as fh:
            for candidate in parse_password_file(fh.read()):
                add(candidate)
    if password:  # empty literal is not a candidate (finding M1)
        add(password)
    return candidates
