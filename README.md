# claude-mods

Portable Claude Code customizations.

## spending-tracker

Tracks per-session and monthly spending in the Claude Code status line.

**What it does:**
- Shows `Session: $X.XX | Month (Feb): $Y.YY` in the status bar
- Accumulates monthly totals across sessions in `~/.claude/monthly-cost.json`
- Auto-resets when the month rolls over

**Install on a new machine:**

```bash
bash spending-tracker/install.sh
```

This copies the scripts to `~/.claude/` and merges the required hooks into `~/.claude/settings.json`.
