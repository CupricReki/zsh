"""Typer CLI for extract (spec §5)."""

from pathlib import Path

import typer

from extract.discovery import DiscoveryError, discover, family_for
from extract.logutil import log
from extract.orchestration import process_archive
from extract.passwords import load_candidates

app = typer.Typer(no_args_is_help=True)


def _candidates(password: str | None, password_file: str | None) -> list[str]:
    if password is not None and password_file is not None:
        raise typer.BadParameter("use either --password or --password-file, not both")
    candidates = load_candidates(password, password_file)
    # finding M1: an empty -p value or a -P file with no usable candidates is a
    # usage error, not "all passwords wrong".
    if (password is not None or password_file is not None) and not candidates:
        raise typer.BadParameter("no password candidates (empty -p value or -P file)")
    return candidates


@app.command()
def extract(
    paths: list[str] = typer.Argument(..., help="Archives, or (with -R) directories"),
    recursive: bool = typer.Option(False, "-R", "--recursive", help="Extract every archive below each directory, in place"),
    password: str | None = typer.Option(None, "-p", "--password", help="Single password (or candidate) for encrypted archives"),
    password_file: str | None = typer.Option(None, "-P", "--password-file", help="File of password candidates, one per line (verbatim — no comment syntax)"),
    force: bool = typer.Option(False, "-F", "--force", help="Merge into an existing target directory instead of skipping/suffixing"),
    remove: bool = typer.Option(False, "-r", "--remove", help="Delete each archive after a successful extraction"),
) -> None:
    """Extract archives, optionally password-protected or recursive."""
    candidates = _candidates(password, password_file)
    archives: list[Path] = []
    failed = 0
    for raw in paths:
        try:
            archives.extend(discover([Path(raw)], recursive))
        except DiscoveryError as exc:
            # per-path isolation: one bad path must not abort the run
            log("error", str(exc))
            failed += 1
    if recursive and not archives and not failed:
        log("warning", "no archives found under the given path(s)")  # finding M11
    for archive in archives:
        family = family_for(archive.name)
        if family is None:
            log("error", f"{archive.name}: unknown extension")
            failed += 1
            continue
        if not process_archive(
            archive,
            candidates,
            force=force,
            remove=remove,
            skip_existing=recursive,
            family=family,
        ):
            failed += 1
    if failed:
        raise typer.Exit(code=1)


if __name__ == "__main__":
    app()
