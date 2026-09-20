"""pytest bootstrap: make the extract package and standards lib importable."""

import sys
from pathlib import Path

TESTS_DIR = Path(__file__).resolve().parent
ZSH_ROOT = TESTS_DIR.parent

for p in (
    ZSH_ROOT / "libraries" / "python",                            # for `import extract`
    ZSH_ROOT / "libraries" / "python" / "standards" / "python",   # for `import standard_logging`
):
    if str(p) not in sys.path:
        sys.path.insert(0, str(p))
