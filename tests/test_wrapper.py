"""zsh wrapper tests for custom/extract.zsh (spec §11).

These tests exercise the shell wrapper only. The Python package, its CLI tests,
and its fixtures live in the `cupric/extract` repo.

Every invocation runs with a *hermetic* PATH (a python3 symlink plus the test's
own fake bin). The wrapper prefers an installed `extract`, so inheriting the
ambient PATH would make these tests pass or fail depending on whether the host
has already run the ansible zsh role.
"""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

ZSH_ROOT = Path(__file__).resolve().parent.parent
WRAPPER = ZSH_ROOT / "custom" / "extract.zsh"

PYTHON3 = shutil.which("python3") or "/usr/bin/python3"


class TestWrapper:
    def _zsh(self, snippet: str, *args: str) -> subprocess.CompletedProcess:
        # Drop an inherited ZBIN: a developer shell exports it, and the tests
        # must not depend on whether this machine has a deployed zsh config.
        env = {key: value for key, value in os.environ.items() if key != "ZBIN"}
        return subprocess.run(
            ["zsh", "-f", "-c", snippet, *args],
            capture_output=True,
            text=True,
            env=env,
        )

    def _hermetic_path(self, tmp_path: Path, *extra: Path) -> str:
        """A PATH with only a python3 symlink and the given test directories."""
        bindir = tmp_path / "pybin"
        bindir.mkdir(exist_ok=True)
        link = bindir / "python3"
        if not link.exists():
            link.symlink_to(PYTHON3)
        return ":".join([str(bindir), *(str(d) for d in extra)])

    def _setup_fake_tool(self, tmp_path: Path) -> Path:
        fakebin = tmp_path / "bin"
        fakebin.mkdir()
        tool = fakebin / "extract.py"
        tool.write_text("#!/usr/bin/env python3\nimport sys\nprint('PYTOOL', *sys.argv[1:])\n")
        tool.chmod(0o755)
        return fakebin

    def _setup_fake_binary(self, tmp_path: Path, body: str = 'echo INSTALLED "$@"') -> Path:
        fakebin = tmp_path / "installed"
        fakebin.mkdir()
        tool = fakebin / "extract"
        tool.write_text(f"#!/bin/sh\n{body}\n")
        tool.chmod(0o755)
        return fakebin

    @pytest.mark.parametrize(
        "invocation",
        [
            "-R x.zip",
            "--recursive x.zip",
            "-p pw x.zip",
            "--password pw x.zip",
            "--password=pw x.zip",
            "-P pw.txt x.zip",
            "--password-file pw.txt x.zip",
            "-F x.zip",
            "--force x.zip",
            "-r x.zip",
            "--remove x.zip",
        ],
    )
    def test_delegates_each_new_flag(self, tmp_path, invocation):
        fakebin = self._setup_fake_tool(tmp_path)
        snippet = (
            "extract() { echo PLUGIN; }; "
            f"PATH={self._hermetic_path(tmp_path, fakebin)}; rehash; "
            f"ZBIN={fakebin}; source {WRAPPER}; extract {invocation}"
        )
        result = self._zsh(snippet)
        assert result.stdout.strip() == f"PYTOOL {invocation}"

    def test_falls_through_to_plugin(self, tmp_path):
        fakebin = self._setup_fake_tool(tmp_path)
        snippet = (
            "extract() { echo PLUGIN; }; "
            f"PATH={self._hermetic_path(tmp_path, fakebin)}; rehash; "
            f"ZBIN={fakebin}; source {WRAPPER}; extract plain.tar.gz"
        )
        result = self._zsh(snippet)
        assert result.stdout.strip() == "PLUGIN"

    def test_resourcing_does_not_recurse(self, tmp_path):
        # finding C6: a second `source` must not capture the wrapper as
        # extract_orig (which would make `extract` recurse forever).
        fakebin = self._setup_fake_tool(tmp_path)
        snippet = (
            "extract() { echo PLUGIN; }; "
            f"PATH={self._hermetic_path(tmp_path, fakebin)}; rehash; "
            f"ZBIN={fakebin}; source {WRAPPER}; source {WRAPPER}; extract plain.tar.gz"
        )
        result = self._zsh(snippet)
        assert result.stdout.strip() == "PLUGIN"

    def test_delegates_to_installed_command(self, tmp_path):
        fakebin = self._setup_fake_binary(tmp_path)
        snippet = (
            "extract() { echo PLUGIN; }; "
            f"PATH={self._hermetic_path(tmp_path, fakebin)}; rehash; "
            f"source {WRAPPER}; extract -p pw x.zip"
        )
        result = self._zsh(snippet)
        assert result.stdout.strip() == "INSTALLED -p pw x.zip"

    def test_reports_missing_tool(self, tmp_path):
        snippet = (
            "extract() { echo PLUGIN; }; "
            f"PATH={self._hermetic_path(tmp_path)}; rehash; "
            f"source {WRAPPER}; extract -p pw x.zip"
        )
        result = self._zsh(snippet)
        assert result.returncode == 1
        assert "not installed" in result.stderr

    def test_delegates_when_zbin_has_no_shim(self, tmp_path):
        # zshenv exports ZBIN for every shell; the production case is
        # "ZBIN set, no extract.py there, binary on PATH".
        fakebin = self._setup_fake_binary(tmp_path)
        emptybin = tmp_path / "zbin"
        emptybin.mkdir()
        snippet = (
            "extract() { echo PLUGIN; }; "
            f"PATH={self._hermetic_path(tmp_path, fakebin)}; rehash; "
            f"ZBIN={emptybin}; source {WRAPPER}; extract -p pw x.zip"
        )
        result = self._zsh(snippet)
        assert result.stdout.strip() == "INSTALLED -p pw x.zip"

    def test_installed_binary_wins_over_a_stale_shim(self, tmp_path):
        # A leftover bin/extract.py must not shadow a working installation.
        shim = self._setup_fake_tool(tmp_path)
        binary = self._setup_fake_binary(tmp_path)
        snippet = (
            "extract() { echo PLUGIN; }; "
            f"PATH={self._hermetic_path(tmp_path, binary)}; rehash; "
            f"ZBIN={shim}; source {WRAPPER}; extract -p pw x.zip"
        )
        result = self._zsh(snippet)
        assert result.stdout.strip() == "INSTALLED -p pw x.zip"

    def test_propagates_the_tool_exit_status(self, tmp_path):
        fakebin = self._setup_fake_binary(tmp_path, body="exit 7")
        snippet = (
            "extract() { echo PLUGIN; }; "
            f"PATH={self._hermetic_path(tmp_path, fakebin)}; rehash; "
            f"source {WRAPPER}; extract -p pw x.zip"
        )
        result = self._zsh(snippet)
        assert result.returncode == 7
