# ZSH Profiling Guide

This guide helps you measure and improve zsh startup time.

## Quick Profiling

### Method 1: Built-in zprof

1. **Enable profiling** by uncommenting these lines in `zshrc`:

```bash
# At the top (line ~3):
zmodload zsh/zprof

# At the bottom (line ~444):
echo "\n==== ZSH Startup Profiling ===="
zprof | head -20
```

2. **Start a new shell:**
```bash
exec zsh
```

3. **Review the output** - it shows functions ranked by time:
   - First column: number of calls
   - Second column: total time
   - Third column: time per call
   - Look for functions taking >100ms

### Method 2: External Timing

```bash
# Simple timing
time zsh -i -c exit

# Multiple runs for average
for i in {1..5}; do time zsh -i -c exit; done
```

### Method 3: Detailed Timestamps

Add timestamp markers in your zshrc:

```bash
# Add after major sections
echo "Checkpoint: After compinit - $(date +%s.%N)" >&2
```

## Understanding the Results

### Common Slow Functions

1. **compinit** (100-500ms)
   - ✅ Already optimized with caching
   - Should only be slow once per day

2. **antibody bundle** (50-200ms each)
   - 💡 Consider static loading for 500-1000ms improvement
   - See AUDIT_REPORT.md for instructions

3. **eval dircolors** (10-50ms)
   - ✅ Already has safety check
   - Could cache output for slight improvement

4. **SSH agent** (100-300ms)
   - ✅ Already optimized for login shells only

5. **Plugin initialization** (variable)
   - Remove unused plugins
   - Use lazy loading

## Interpreting Timings

### Target Goals
- **Excellent:** < 500ms
- **Good:** 500-1000ms  
- **Acceptable:** 1-1.5s
- **Needs work:** > 1.5s

### What's Normal?

```
Time Component          Target    Notes
─────────────────────────────────────────
P10k instant prompt     ~10ms     Very fast
compinit (cached)       ~50ms     Daily rebuild: 200ms
Antibody plugins        ~400ms    Or 50ms with static
File sourcing           ~50ms     
SSH agent (login)       ~150ms    Only on login shells
Syntax highlighting     ~30ms     Last to load
─────────────────────────────────────────
Total (first time)      ~850ms    With all optimizations
Total (cached)          ~690ms    Subsequent shells
```

## Before/After Comparison

### Baseline (Before Cleanup)
```bash
# Enable profiling and measure
zmodload zsh/zprof
time zsh -i -c exit
# Expected: 2-3 seconds
```

### After Initial Cleanup
```bash
# Same measurement
time zsh -i -c exit  
# Expected: 1-1.5 seconds (50-70% improvement)
```

### With Static Antibody Loading
```bash
# Generate static file
antibody bundle < ~/.zsh_plugins.txt > ~/.zsh_plugins.zsh
# Modify zshrc to source static file
time zsh -i -c exit
# Expected: 0.5-1 second (additional 30-50% improvement)
```

## Profiling Checklist

- [ ] Run `time zsh -i -c exit` 5 times, note average
- [ ] Enable zprof, identify top 5 slowest functions
- [ ] Check if compinit is cached (should be fast after first run)
- [ ] Verify SSH agent only runs on login shells
- [ ] Count antibody bundle calls (fewer is better)
- [ ] Look for unnecessary eval statements
- [ ] Check for missing `has` checks before plugin loads

## Advanced Profiling

### Trace Execution

```bash
# Shows every command executed
zsh -x -i -c exit 2>&1 | less
```

### Profile Specific Sections

```bash
# Add to zshrc around suspected slow section:
start=$(date +%s.%N)
# ... code to profile ...
end=$(date +%s.%N)
echo "Section took: $(echo "$end - $start" | bc)s" >&2
```

### Compare with Minimal Config

```bash
# Rename current config
mv ~/.zshrc ~/.zshrc.full

# Create minimal config
echo "# minimal" > ~/.zshrc

# Measure baseline
time zsh -i -c exit

# Restore
mv ~/.zshrc.full ~/.zshrc
```

## Troubleshooting Slow Startups

### If still slow after optimizations:

1. **Check for network calls**
   ```bash
   # Look for wget, curl, git commands in zshrc
   grep -E "(wget|curl|git fetch|git pull)" ~/.config/zsh/zshrc
   ```

2. **Verify plugin cache exists**
   ```bash
   ls -lh ~/.cache/zsh/
   ```

3. **Check for old completions**
   ```bash
   # Remove old dumps
   rm ~/.zcompdump*
   ```

4. **Disable plugins temporarily**
   ```bash
   # Comment out all antibody bundle lines
   # Start new shell
   # Gradually re-enable to find culprit
   ```

## Reporting Results

When sharing profiling results, include:

```bash
# System info
echo "OS: $(uname -a)"
echo "ZSH: $(zsh --version)"

# Timing
echo "\n=== Timing (5 runs) ==="
for i in {1..5}; do 
  /usr/bin/time -f "Real: %E" zsh -i -c exit 2>&1 | grep Real
done

# Top functions
echo "\n=== Top Functions ==="
zsh -i -c "zprof | head -10"
```

## Continuous Monitoring

Add to your aliases (in `~/.config/zsh/custom/alias/alias.zsh`):

```bash
alias zsh-profile='zmodload zsh/zprof && source ~/.zshrc && zprof | head -20'
alias zsh-time='for i in {1..5}; do time zsh -i -c exit; done'
```

## Next Steps

1. ✅ Current optimizations implemented
2. ⏭️ Measure current baseline with profiling
3. ⏭️ Implement static antibody loading (if > 1s)
4. ⏭️ Remove unused plugins
5. ⏭️ Consider lazy loading for rarely-used tools

---

**Pro Tip:** Profile regularly after adding new plugins or configurations to catch performance regressions early!

