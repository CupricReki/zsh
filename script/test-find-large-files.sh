#!/usr/bin/env bash
# Integration test for find-large-files
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
RESET='\033[0m'

pass() { echo -e "${GREEN}PASS${RESET} $*"; }
fail() { echo -e "${RED}FAIL${RESET} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL="$SCRIPT_DIR/find-large-files"

# ----- Test 1: ZFS preamble with mocked zfs -----
echo "=== Test 1: ZFS preamble ==="

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Create a mock zfs binary
cat > "$TMPDIR/zfs" << 'MOCK'
#!/usr/bin/env bash
if [[ "$*" == *"list"* ]]; then
    cat << 'EOF'
zroot	978567168000	12992200704	24253415424	none
zroot/ROOT	692060160000	12992200704	0	none
zroot/ROOT/default	552599310336	12992200704	24253415424	/
zroot/data	286494883840	12992200704	0	none
zroot/data/games	177167400960	12992200704	0	/mnt/games
tb	396000000000	574000000000	0	/mnt/tb
EOF
fi
MOCK
chmod +x "$TMPDIR/zfs"

PATH="$TMPDIR:$PATH" TOOL_OUTPUT=$(bash "$TOOL" --skip-zfs -d "$TMPDIR" -s 1G 2>&1) || true
if echo "$TOOL_OUTPUT" | grep -qF "zroot"; then
    fail "zfs preamble: should not show pool data with --skip-zfs"
else
    pass "zfs preamble: skips when --skip-zfs"
fi

PATH="$TMPDIR:$PATH" TOOL_OUTPUT=$(bash "$TOOL" -d "$TMPDIR" -s 1G 2>&1) || true
if echo "$TOOL_OUTPUT" | grep -qF "zroot"; then
    pass "zfs preamble: shows pool name"
else
    fail "zfs preamble: missing pool name in output:\n$TOOL_OUTPUT"
fi
if echo "$TOOL_OUTPUT" | grep -qF "98%"; then
    pass "zfs preamble: shows capacity percentage"
else
    fail "zfs preamble: missing capacity percentage in output:\n$TOOL_OUTPUT"
fi
if echo "$TOOL_OUTPUT" | grep -qF "ncdu /"; then
    pass "zfs preamble: shows ncdu hint for dataset mountpoint"
else
    fail "zfs preamble: missing ncdu hint in output:\n$TOOL_OUTPUT"
fi

# ----- Test 2: File scan with sorting -----
echo "=== Test 2: Sorted file output ==="

TMPTEST=$(mktemp -d)
trap 'rm -rf "$TMPTEST" "$TMPDIR"' EXIT

# Create test files with known sizes
dd if=/dev/zero of="$TMPTEST/a.bin" bs=1M count=50 2>/dev/null
dd if=/dev/zero of="$TMPTEST/b.bin" bs=1M count=10 2>/dev/null
dd if=/dev/zero of="$TMPTEST/c.bin" bs=1M count=5 2>/dev/null

# Run with asc sort (smallest first, largest last)
TOOL_OUTPUT=$(bash "$TOOL" -d "$TMPTEST" -s 1M --sort asc --skip-zfs 2>&1) || true

# Extract just the file lines (after the header, before the footer)
FILES=$(echo "$TOOL_OUTPUT" | grep -E '^\s+[0-9.]+[KMG]?iB' || true)
if [[ -z "$FILES" ]]; then
    fail "sort asc: no file lines found in output:\n$TOOL_OUTPUT"
fi

# Files should be in size order ascending: c.bin (5M) < b.bin (10M) < a.bin (50M)
FIRST=$(echo "$FILES" | head -1)
LAST=$(echo "$FILES" | tail -1)
if echo "$FIRST" | grep -q 'c.bin' && echo "$LAST" | grep -q 'a.bin'; then
    pass "sort asc: smallest first, largest last"
else
    fail "sort asc: unexpected order:\n$FILES"
fi

# Run with desc sort
TOOL_OUTPUT=$(bash "$TOOL" -d "$TMPTEST" -s 1M --sort desc --skip-zfs 2>&1) || true
FILES=$(echo "$TOOL_OUTPUT" | grep -E '^\s+[0-9.]+[KMG]?iB' || true)
FIRST=$(echo "$FILES" | head -1)
LAST=$(echo "$FILES" | tail -1)
if echo "$FIRST" | grep -q 'a.bin' && echo "$LAST" | grep -q 'c.bin'; then
    pass "sort desc: largest first, smallest last"
else
    fail "sort desc: unexpected order:\n$FILES"
fi

# ----- Test 3: --top limits output -----
echo "=== Test 3: --top limits output ==="

TOOL_OUTPUT=$(bash "$TOOL" -d "$TMPTEST" -s 1M --skip-zfs -n 1 2>&1) || true
FILE_COUNT=$(echo "$TOOL_OUTPUT" | grep -cE '^\s+[0-9.]+ [KMG]?iB' || true)
if [[ "$FILE_COUNT" -le 1 ]]; then
    pass "--top 1: shows at most 1 result"
else
    fail "--top 1: expected ≤1 result, got $FILE_COUNT:\n$TOOL_OUTPUT"
fi

echo ""
echo -e "${GREEN}All tests passed${RESET}"
