# claude-mods

Portable Claude Code customizations.

## spending-tracker

Tracks per-session and monthly spending in the Claude Code status line.

**What it does:**
- Shows `Session: $X.XX | Month (Feb): $Y.YY` in the status bar
- Accumulates monthly totals across sessions in `~/.claude/monthly-cost.json`
- Auto-resets when the month rolls over

### Setup on a new machine

1. **Prerequisites:** Python 3 and [Claude Code](https://docs.anthropic.com/en/docs/claude-code) must be installed.

2. **Clone the repo:**
   ```bash
   git clone https://github.com/gfrt0/claude-mods.git
   cd claude-mods
   ```

3. **Run the installer:**
   ```bash
   bash spending-tracker/install.sh
   ```
   This will:
   - Copy `statusline.sh` and `session-cost-logger.sh` to `~/.claude/`
   - Make them executable
   - Merge the `statusLine` and `SessionEnd` hook entries into `~/.claude/settings.json` (existing settings are preserved)

4. **Allow the scripts in Claude Code.** On first launch you'll be prompted to approve the hooks. To pre-approve them, add these to `~/.claude/settings.local.json`:
   ```json
   {
     "permissions": {
       "allow": [
         "Bash(bash /home/<user>/.claude/statusline.sh)",
         "Bash(bash /home/<user>/.claude/session-cost-logger.sh)"
       ]
     }
   }
   ```
   Replace `<user>` with your username.

5. **Start Claude Code.** The status line should show session and monthly costs immediately.
