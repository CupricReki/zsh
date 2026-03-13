"""
Zsh key sequence notation — authoritative mapping reference for interpret_zsh.py.

Supported modifiers: C- (Ctrl), M- (Meta/Alt), A- (Alt, alias for M-).
Shift is not a bindkey modifier in zsh — use raw: true for shifted key sequences.

Universal notation (used in keymap YAML files) → zsh bindkey sequences.

Ctrl keys  : C-x       → ^x        (lowercase convention)
             C-<Space> → ^<space>
             C-<Tab>   → ^I
Alt/Meta   : M-x       → ^[x       (ESC-prefix, ^[ and \\e are equivalent)
             M-<Space> → ^[ <space>
             M-<Tab>   → ^[^I
Combined   : (not supported — use raw: true)

For arrow keys, F-keys, Delete etc., use raw: true in the YAML and look up
the CSI_SEQUENCES table below for your terminal's expected sequence.
"""

import re

# Detects an uppercase-letter modifier prefix that zsh does not support (e.g. S-)
_UNSUPPORTED_MOD_RE = re.compile(r'^[A-Z]-')

# ---------------------------------------------------------------------------
# Modifiers recognised in universal notation
# ---------------------------------------------------------------------------

MODIFIERS = {
    'C': 'ctrl',   # Ctrl
    'M': 'meta',   # Meta / Alt (ESC-prefix)
    'A': 'meta',   # Alt  → same as Meta
}

# ---------------------------------------------------------------------------
# Named special keys → their single-character ctrl-code fragment.
#
# Used to build:
#   C-<Key>   → ^ + SPECIAL_KEYS[<Key>]        e.g. C-<Tab>   → ^I
#   M-<Key>   → ^[ + ^ + SPECIAL_KEYS[<Key>]   e.g. M-<Tab>   → ^[^I
#
# Exception: <Space> maps to a literal space (not a caret-code character).
# ---------------------------------------------------------------------------

SPECIAL_KEYS = {
    '<Space>':   ' ',    # C-<Space> → ^<space>    M-<Space> → ^[ <space>
    '<Tab>':     'I',    # C-<Tab>   → ^I          M-<Tab>   → ^[^I
    '<Return>':  'M',    # C-<Return>→ ^M          M-<Return>→ ^[^M
    '<CR>':      'M',    # alias for <Return>
    '<Enter>':   'M',    # alias for <Return>
    '<BS>':      'H',    # C-<BS>    → ^H          M-<BS>    → ^[^H
    '<Del>':     '?',    # C-<Del>   → ^?  (DEL char, sent by Backspace on most terminals)
    '<Esc>':     '[',    # C-<Esc>   → ^[  (the ESC character itself)
}

# ---------------------------------------------------------------------------
# Terminal-specific CSI sequences.
#
# These sequences vary by terminal emulator (xterm, kitty, alacritty, …)
# and CANNOT be derived reliably from universal notation.
#
# Always use `raw: true` in your YAML for these keys and copy the exact
# sequence your terminal sends (check with: cat -v, then press the key).
#
# Values below are the xterm/VT100 defaults — the most common.
# ---------------------------------------------------------------------------

CSI_SEQUENCES = {
    # Arrow keys
    '<Up>':       '^[[A',
    '<Down>':     '^[[B',
    '<Right>':    '^[[C',
    '<Left>':     '^[[D',

    # Editing cluster
    '<Insert>':   '^[[2~',
    '<Delete>':   '^[[3~',   # physical Delete key (not Backspace / <BS>)
    '<Home>':     '^[[H',    # also '^[[1~' on some terminals
    '<End>':      '^[[F',    # also '^[[4~' on some terminals
    '<PgUp>':     '^[[5~',
    '<PgDown>':   '^[[6~',

    # Function keys (xterm defaults)
    '<F1>':       '^[[11~',
    '<F2>':       '^[[12~',
    '<F3>':       '^[[13~',
    '<F4>':       '^[[14~',
    '<F5>':       '^[[15~',
    '<F6>':       '^[[17~',   # note: no 16~
    '<F7>':       '^[[18~',
    '<F8>':       '^[[19~',
    '<F9>':       '^[[20~',
    '<F10>':      '^[[21~',
    '<F11>':      '^[[23~',
    '<F12>':      '^[[24~',
}

# ---------------------------------------------------------------------------
# shortcut_to_zsh  — core conversion function
# ---------------------------------------------------------------------------

def shortcut_to_zsh(shortcut: str) -> str:
    """
    Convert a universal shortcut notation string to a zsh bindkey sequence.

    Examples:
        C-a          → ^a
        C-<Space>    → ^ (caret + space)
        C-<Tab>      → ^I
        M-t          → ^[t
        M-<Space>    → ^[ (ESC + space)
        M-<Tab>      → ^[^I
        M-<BS>       → ^[^H
        M-<Del>      → ^[^?
        x            → x   (bare key, pass through)

    For terminal-specific sequences (arrow keys, F-keys, Delete) use
    raw: true in the YAML instead of relying on this converter.
    """
    shortcut = shortcut.strip()
    if not shortcut:
        return shortcut

    # Parse leading modifier tokens: C- and/or M-/A-
    ctrl = False
    meta = False
    rest = shortcut

    # Consume up to two modifier prefixes in any order
    for _ in range(2):
        if rest.startswith('C-'):
            ctrl = True
            rest = rest[2:]
        elif rest.startswith('M-') or rest.startswith('A-'):
            meta = True
            rest = rest[2:]
        else:
            break

    if not ctrl and not meta:
        # No known modifier was consumed. If the input looks like an unsupported
        # modifier prefix (uppercase letter + hyphen, e.g. S-x), raise clearly
        # rather than silently passing it through as an invalid bindkey sequence.
        if _UNSUPPORTED_MOD_RE.match(rest):
            raise ValueError(
                f"unrecognised modifier in '{shortcut}' — "
                f"zsh supports C-, M-, A- only (use raw: true for Shift/special sequences)"
            )
        # Bare key — pass through unchanged
        return shortcut

    # After consuming known modifiers, if the remainder still looks like an
    # unsupported modifier prefix, the user wrote something like C-S-x.
    if _UNSUPPORTED_MOD_RE.match(rest):
        raise ValueError(
            f"unrecognised modifier in '{shortcut}' — "
            f"zsh supports C-, M-, A- only (use raw: true for Shift/special sequences)"
        )

    # Reject keys that are terminal-specific CSI sequences — these cannot be
    # combined with modifiers reliably; the user should use raw: true instead.
    if rest in CSI_SEQUENCES:
        raise ValueError(
            f"'{rest}' is a terminal-specific CSI sequence in '{shortcut}' — "
            f"use raw: true in the YAML with the exact sequence your terminal sends"
        )

    # Resolve the key part: look up in SPECIAL_KEYS or use as-is
    if rest in SPECIAL_KEYS:
        key_char = SPECIAL_KEYS[rest]
        # Special case: <Space> maps to a literal space, no caret encoding
        if rest == '<Space>':
            ctrl_part = '^' + key_char   # "^ " (caret + space)
        else:
            ctrl_part = '^' + key_char   # "^I", "^M", "^H", etc.
    else:
        # Plain letter or symbol — lowercase for Ctrl convention
        key_char = rest.lower() if (len(rest) == 1 and rest.isalpha()) else rest
        ctrl_part = '^' + key_char

    if meta and ctrl:
        # M-C-x → ^[^x
        return '^[' + ctrl_part
    elif meta:
        # M-x   → ^[x     M-<Tab> → ^[^I
        if rest in SPECIAL_KEYS and rest != '<Space>':
            return '^[' + ctrl_part   # e.g. M-<Tab> → ^[^I
        else:
            return '^[' + key_char    # e.g. M-t → ^[t,  M-<Space> → ^[ (space)
    else:
        # C-x   → ^x
        return ctrl_part
