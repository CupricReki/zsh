#!/usr/bin/env python3
"""extract — password & recursive archive extraction.

Wrapper around the `extract` package in ../libraries/python/extract.
Passwords passed to unzip/7z/unrar appear in those tools' argv while they
run (spec §8.3); passwords are never written to logs.
"""

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent          # zsh/bin
ZSH_DIR = HERE.parent                             # zsh root
sys.path.insert(0, str(ZSH_DIR / "libraries" / "python"))
sys.path.insert(0, str(ZSH_DIR / "libraries" / "python" / "standards" / "python"))

from extract.cli import app  # noqa: E402

if __name__ == "__main__":
    app()
