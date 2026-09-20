"""Password candidate parsing (spec §8.1)."""

import pytest

from extract.passwords import load_candidates, parse_password_file


def test_symbols_and_interior_spaces_preserved():
    text = "p@ss w0rd!\na\\b$c%d#e\n'a\"quoted\";pw"
    assert parse_password_file(text) == ["p@ss w0rd!", "a\\b$c%d#e", "'a\"quoted\";pw"]


def test_crlf_blank_lines_and_padding_trimmed():
    text = "  first  \r\n\r\n\t second \t\r\n   \n\ttabs\t\n"
    assert parse_password_file(text) == ["first", "second", "tabs"]


def test_interior_whitespace_kept_edges_trimmed():
    assert parse_password_file("  keep inner  spaces  \n") == ["keep inner  spaces"]


def test_duplicates_removed_first_kept():
    assert parse_password_file("dup\nother\ndup\n") == ["dup", "other"]


def test_unicode_preserved():
    assert parse_password_file("pässwörd🔑\n") == ["pässwörd🔑"]


def test_blank_input():
    assert parse_password_file("") == []
    assert parse_password_file("\n \t\n") == []


def test_utf8_bom_stripped():
    # finding M3: a UTF-8 BOM must not corrupt the first candidate
    assert parse_password_file("\ufefffirst\nsecond\n") == ["first", "second"]


def test_empty_literal_yields_no_candidates():
    # finding M1: an empty -p value is a usage error upstream, not a candidate
    assert load_candidates("", None) == []


def test_load_candidates_from_file(tmp_path):
    pwfile = tmp_path / "pw.txt"
    pwfile.write_text("one\n two \n", encoding="utf-8")
    assert load_candidates(None, str(pwfile)) == ["one", "two"]


def test_load_candidates_literal():
    assert load_candidates("s3cret", None) == ["s3cret"]


def test_load_candidates_none():
    assert load_candidates(None, None) == []
