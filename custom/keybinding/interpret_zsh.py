#!/usr/bin/env python3
"""
Zsh keymap interpreter.

Reads a universal list-format YAML and writes bindkey lines to stdout.
keybindings.zsh sources the generated keybindings.gen.zsh via mtime-gated check.

Usage:
    interpret_zsh.py <keymap.yaml> [section1 [section2 ...]]
    interpret_zsh.py --validate <keymap.yaml>   # validate only, no output

    With no sections, all sections are loaded.
    With sections specified, only those sections are loaded.

Output is a zsh script — redirect to a file and source it:
    interpret_zsh.py keymap_zsh.yaml > keybindings.gen.zsh
    source keybindings.gen.zsh

Shortcut notation (universal → bindkey):
    C-x          → ^x           (Ctrl)
    C-<Space>    → ^            (Ctrl+Space)
    C-<Tab>      → ^I
    M-x          → ^[x          (Meta/Alt, ESC-prefix)
    M-<Space>    → ^[           (ESC + space)
    M-<Tab>      → ^[^I
    bare key     → passed through unchanged

For terminal-specific sequences (arrow keys, F-keys, Delete), set
`raw: true` on the entry and write the bindkey sequence directly:

    - shortcut: "^[[A"
      description: Up arrow
      action: up-line-or-history
      raw: true

See cheat/example/zsh_notation.yaml for the full notation reference.
Conversion logic lives in zsh_notation.py (same directory as this file).
"""

import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Error: PyYAML not installed. Run: pip install pyyaml", file=sys.stderr)
    sys.exit(1)

# Import conversion function and maps from the notation module
_HERE = Path(__file__).parent
sys.path.insert(0, str(_HERE))
from zsh_notation import shortcut_to_zsh, SPECIAL_KEYS, CSI_SEQUENCES, MODIFIERS  # noqa: F401


# =============================================================================
# Unit tests
# =============================================================================

def _run_tests():
    cases = [
        # Ctrl keys
        ('C-a',        '^a'),
        ('C-r',        '^r'),
        ('C-<Space>',  '^ '),
        ('C-<Tab>',    '^I'),
        ('C-<Return>', '^M'),
        ('C-<BS>',     '^H'),
        ('C-<Del>',    '^?'),
        # Meta/Alt keys
        ('M-t',        '^[t'),
        ('M-f',        '^[f'),
        ('M-b',        '^[b'),
        ('M-d',        '^[d'),
        ('A-c',        '^[c'),
        # Meta + special
        ('M-<Space>',  '^[ '),
        ('M-<Tab>',    '^[^I'),
        ('M-<Return>', '^[^M'),
        ('M-<BS>',     '^[^H'),
        ('M-<Del>',    '^[^?'),
        # Bare keys — pass through
        ('x',          'x'),
        ('|',          '|'),
        ('-',          '-'),
    ]
    failed = 0
    for inp, expected in cases:
        result = shortcut_to_zsh(inp)
        if result != expected:
            print(f"FAIL: shortcut_to_zsh({inp!r}) = {result!r}, expected {expected!r}")
            failed += 1

    # Unsupported modifier must raise ValueError
    try:
        shortcut_to_zsh('S-x')
        print("FAIL: shortcut_to_zsh('S-x') should have raised ValueError")
        failed += 1
    except ValueError:
        pass  # expected

    # display_only entries must not appear in generated output
    _do_config = {
        '_tool_name': 'Test',
        'binds': [
            {'shortcut': 'C-a', 'description': 'real', 'action': 'beginning-of-line'},
            {'shortcut': 'C-e', 'description': 'cheatsheet only', 'display_only': True},
        ],
    }
    _do_lines = generate_bindkey_lines(_do_config, [])
    _do_out = '\n'.join(_do_lines)
    if 'C-e' in _do_out or 'cheatsheet only' in _do_out:
        print("FAIL: display_only entry leaked into generated output")
        failed += 1
    if 'beginning-of-line' not in _do_out:
        print("FAIL: real entry missing from generated output")
        failed += 1

    # Section with only display_only entries must emit no section comment
    _sec_config = {
        'only_display': [
            {'shortcut': 'M-x', 'description': 'doc only', 'display_only': True},
        ],
    }
    _sec_lines = generate_bindkey_lines(_sec_config, [])
    _sec_out = '\n'.join(_sec_lines)
    if '# only_display' in _sec_out:
        print("FAIL: empty section comment emitted for display_only-only section")
        failed += 1

    total = len(cases) + 3
    if failed == 0:
        print(f"All {total} tests passed.")
    else:
        print(f"{failed}/{total} tests FAILED.")
        sys.exit(1)


# =============================================================================
# Config loading and bindkey generation
# =============================================================================

def load_config(yaml_path: Path) -> dict:
    try:
        with open(yaml_path, 'r', encoding='utf-8') as f:
            config = yaml.safe_load(f)
        if not isinstance(config, dict):
            raise ValueError("YAML root must be a mapping (got non-dict)")
        return config
    except (yaml.YAMLError, ValueError) as e:
        print(f"Error: could not parse {yaml_path}: {e}", file=sys.stderr)
        sys.exit(1)


def generate_bindkey_lines(config: dict, sections: list) -> list:
    """Generate bindkey lines from the config."""
    all_sections = [k for k in config if not k.startswith('_')]
    active = sections if sections else all_sections

    lines = ['# Generated by interpret_zsh.py — do not edit by hand.', '']

    for section_name in active:
        if section_name not in config:
            print(f"Warning: section '{section_name}' not found in config", file=sys.stderr)
            continue

        entries = config[section_name]
        if not isinstance(entries, list):
            print(f"Warning: section '{section_name}' is not a list, skipping", file=sys.stderr)
            continue

        active_entries = []
        for idx, e in enumerate(entries):
            if not isinstance(e, dict):
                print(f"Warning: section '{section_name}'[{idx}] is not a mapping, skipping", file=sys.stderr)
                continue
            if not e.get('display_only') and e.get('shortcut') and e.get('action'):
                active_entries.append(e)
        if not active_entries:
            continue

        lines.append(f'# {section_name}')
        for entry in active_entries:
            shortcut = entry.get('shortcut', '')
            action   = entry.get('action', '')
            desc     = entry.get('description', '')

            if entry.get('raw'):
                zsh_key = shortcut          # literal passthrough — no conversion
            else:
                try:
                    zsh_key = shortcut_to_zsh(shortcut)
                except ValueError as e:
                    print(f"Warning: skipping '{shortcut}': {e}", file=sys.stderr)
                    continue

            # Escape single quotes so the generated bindkey '...' line is valid zsh
            zsh_key = zsh_key.replace("'", "'\\''")
            comment = f'  # {desc}' if desc else ''
            lines.append(f"bindkey '{zsh_key}' {action}{comment}")

        lines.append('')

    return lines


_KNOWN_FIELDS = {'shortcut', 'description', 'action', 'raw', 'display_only'}


def validate_config(config: dict, yaml_path: str = '') -> list:
    """
    Validate a zsh keymap config.

    Returns a list of issue strings (empty = clean).
    Warnings are prefixed with 'warn:'; errors with 'error:'.
    """
    issues = []
    seen: dict = {}   # shortcut → (section, action) for duplicate detection

    all_sections = [k for k in config if not k.startswith('_')]
    for section in all_sections:
        entries = config[section]
        if not isinstance(entries, list):
            issues.append(f"warn:  [{section}] is not a list, skipping")
            continue

        for idx, entry in enumerate(entries):
            if not isinstance(entry, dict):
                issues.append(f"warn:  [{section}][{idx}] is not a mapping, skipping")
                continue

            # display_only entries are cheatsheet-only; skip all validation checks
            if entry.get('display_only'):
                continue

            loc = f"[{section}][{idx}]"
            shortcut = entry.get('shortcut', '').strip()
            action   = entry.get('action', '').strip()

            if not shortcut:
                issues.append(f"error: {loc} missing 'shortcut'")
            if not action:
                issues.append(f"error: {loc} missing 'action'")

            # Unknown fields (likely typos)
            for key in entry:
                if key not in _KNOWN_FIELDS:
                    issues.append(f"warn:  {loc} unknown field '{key}' (known: {sorted(_KNOWN_FIELDS)})")

            # Duplicate detection (all zsh bindings share one namespace)
            if shortcut:
                try:
                    resolved = shortcut if entry.get('raw') else shortcut_to_zsh(shortcut)
                except ValueError as e:
                    issues.append(f"warn:  {loc} {e}")
                    continue
                if resolved in seen:
                    prev_sec, prev_act = seen[resolved]
                    issues.append(
                        f"warn:  {loc} duplicate shortcut '{shortcut}' (→ '{resolved}') "
                        f"also bound to '{prev_act}' in [{prev_sec}]"
                    )
                else:
                    seen[resolved] = (section, action)

    return issues


def _print_issues(issues: list, yaml_path: str):
    errors = [i for i in issues if i.startswith('error:')]
    warns  = [i for i in issues if i.startswith('warn:')]
    label  = yaml_path or 'config'
    if errors or warns:
        print(f"interpret_zsh: {label}", file=sys.stderr)
        for issue in issues:
            print(f"  {issue}", file=sys.stderr)
    return len(errors)


def main():
    args = sys.argv[1:]

    if not args or args[0] in ('-h', '--help'):
        print(__doc__)
        sys.exit(0)

    if args[0] == '--test':
        _run_tests()
        return

    validate_only = False
    if args[0] == '--validate':
        validate_only = True
        args = args[1:]

    if not args:
        print("Error: no YAML file specified", file=sys.stderr)
        sys.exit(1)

    yaml_path = Path(args[0])
    sections  = args[1:]

    if not yaml_path.exists():
        print(f"Error: {yaml_path} not found", file=sys.stderr)
        sys.exit(1)

    config = load_config(yaml_path)

    issues = validate_config(config, str(yaml_path))
    n_errors = _print_issues(issues, str(yaml_path))

    if validate_only:
        if not issues:
            print(f"interpret_zsh: {yaml_path} — OK", file=sys.stderr)
        sys.exit(1 if n_errors else 0)

    # Best-effort: generate whatever is valid, errors already printed to stderr
    lines = generate_bindkey_lines(config, sections)
    for line in lines:
        print(line)


if __name__ == '__main__':
    main()
