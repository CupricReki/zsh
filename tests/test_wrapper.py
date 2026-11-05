"""zsh wrapper tests for custom/extract.zsh (spec §11).

These tests exercise the shell wrapper only. The Python package, its CLI tests,
and its fixtures live in the `cupric/extract` repo.
"""

import subprocess
from pathlib import Path

import pytest

ZSH_ROOT = Path(__file__).resolve().parent.parent
WRAPPER = ZSH_ROOT / "custom" / "extract.zsh"


class TestWrapper:
    def _zsh(self, snippet: str, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run(["zsh", "-c", snippet, *args], capture_output=True, text=True)

    def _setup_fake_tool(self, tmp_path: Path) -> Path:
        fakebin = tmp_path / "bin"
        fakebin.mkdir()
        tool = fakebin / "extract.py"
        tool.write_text("#!/usr/bin/env python3\nimport sys\nprint('PYTOOL', *sys.argv[1:])\n")
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
            f"ZBIN={fakebin}; source {WRAPPER}; extract {invocation}"
        )
        result = self._zsh(snippet)
        assert result.stdout.strip() == f"PYTOOL {invocation}"

    def test_falls_through_to_plugin(self, tmp_path):
        fakebin = self._setup_fake_tool(tmp_path)
        snippet = (
            "extract() { echo PLUGIN; }; "
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
            f"ZBIN={fakebin}; source {WRAPPER}; source {WRAPPER}; extract plain.tar.gz"
        )
        result = self._zsh(snippet)
        assert result.stdout.strip() == "PLUGIN"

    def test_delegates_to_installed_command(self, tmp_path):
        fakebin = tmp_path / "bin"
        fakebin.mkdir()
        tool = fakebin / "extract"
        tool.write_text('#!/bin/sh\necho INSTALLED "$@"\n')
        tool.chmod(0o755)
        snippet = (
            "extract() { echo PLUGIN; }; "
            f"PATH={fakebin}:$PATH; rehash; unset ZBIN; "
            f"source {WRAPPER}; extract -p pw x.zip"
        )
        result = self._zsh(snippet)
        assert result.stdout.strip() == "INSTALLED -p pw x.zip"

    def test_reports_missing_tool(self, tmp_path):
        snippet = (
            "extract() { echo PLUGIN; }; "
            f"PATH={tmp_path}; rehash; unset ZBIN; "
            f"source {WRAPPER}; extract -p pw x.zip"
        )
        result = self._zsh(snippet)
        assert result.returncode == 1
        assert "not installed" in result.stderr

    def test_delegates_when_zbin_has_no_shim(self, tmp_path):
        # zshenv exports ZBIN for every shell; the production case is
        # "ZBIN set, no extract.py there, binary on PATH".
        fakebin = tmp_path / "bin"
        fakebin.mkdir()
        tool = fakebin / "extract"
        tool.write_text('#!/bin/sh\necho INSTALLED "$@"\n')
        tool.chmod(0o755)
        emptybin = tmp_path / "zbin"
        emptybin.mkdir()
        snippet = (
            "extract() { echo PLUGIN; }; "
            f"PATH={fakebin}:$PATH; rehash; ZBIN={emptybin}; "
            f"source {WRAPPER}; extract -p pw x.zip"
        )
        result = self._zsh(snippet)
        assert result.stdout.strip() == "INSTALLED -p pw x.zip"
