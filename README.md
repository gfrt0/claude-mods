# claude-mods

Portable Claude Code customizations.

## Quick Start

```bash
git clone https://github.com/gfrt0/claude-mods.git
cd claude-mods
bash install.sh
```

This installs all mods at once. You can also install each mod individually (see below).

---

## spending-tracker

Tracks per-session and monthly spending in the Claude Code status line.

**What it does:**
- Shows `Session: $X.XX | Month (Feb): $Y.YY` in the status bar
- Accumulates monthly totals across sessions in `~/.claude/monthly-cost.json`
- Auto-resets when the month rolls over

### Setup

1. **Prerequisites:** Python 3 and [Claude Code](https://docs.anthropic.com/en/docs/claude-code) must be installed.

2. **Install:**
   ```bash
   bash spending-tracker/install.sh
   ```
   This copies `statusline.sh` and `session-cost-logger.sh` to `~/.claude/`, makes them executable, and merges the `statusLine` and `SessionEnd` hook entries into `~/.claude/settings.json` (existing settings are preserved).

3. **Allow the scripts in Claude Code.** On first launch you'll be prompted to approve the hooks. To pre-approve them, add these to `~/.claude/settings.local.json`:
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

4. **Start Claude Code.** The status line should show session and monthly costs immediately.

---

## notify

WSL toast notifications for Claude Code events. Shows a native Windows popup when Claude finishes a task, completes a subagent, or needs your attention.

Adapted from [claude-code-notify-hook-in-WSL](https://github.com/wanyukang/claude-code-notify-hook-in-WSL) by [@wanyukang](https://github.com/wanyukang) (MIT license).

**What it does:**
- Displays a WPF toast (350x140px, white background, green accent, rounded corners) at the top right of your Windows screen
- Hooks into three Claude Code events: `Stop`, `SubagentStop`, and `Notification`
- **Dynamic titles:** uses the `CLAUDE_TAB` env var if set, otherwise the project directory name, fallback "Claude Code"
- **Dynamic messages:** shows the first line of Claude's last response (Stop/SubagentStop) or the notification message (Notification)

**Requires:** WSL with `powershell.exe` accessible from the Linux side (the default WSL setup).

### Setup

1. **Prerequisites:** Python 3, [Claude Code](https://docs.anthropic.com/en/docs/claude-code), and WSL.

2. **Install:**
   ```bash
   bash notify/install.sh
   ```
   This copies `cc-notify` and `cc-notify-hook` to `~/.claude/`, makes them executable, and merges the `Notification`, `Stop`, and `SubagentStop` hook entries into `~/.claude/settings.json`.

3. **Allow the hook in Claude Code.** On first launch you'll be prompted to approve the hook. To pre-approve it, add this to `~/.claude/settings.local.json`:
   ```json
   {
     "permissions": {
       "allow": [
         "Bash(bash /home/<user>/.claude/cc-notify-hook)"
       ]
     }
   }
   ```
   Replace `<user>` with your username.

4. **Optional: set `CLAUDE_TAB`** to customize the toast title per terminal tab (e.g. `export CLAUDE_TAB="my-project"`). Otherwise the project directory name is used.

5. **Test directly:**
   ```bash
   ~/.claude/cc-notify "Test Title" "Hello from WSL"
   ```

---

## Skills (Custom Slash Commands)

The `claude-skills/` directory is a Claude Code plugin marketplace that lives inside this repo. `install.sh` symlinks it into `~/.claude/plugins/marketplaces/` so Claude Code auto-discovers the commands.

### /review-commit

Reviews code changes for cleanliness, then commits.

**What it does:**
1. Gathers git context (status, diff, log, branch)
2. Reads every changed file in full and checks for stale comments, TODOs, debug leftovers, unused imports, doc/code inconsistencies, and obvious bugs
3. Fixes small issues automatically; stops and reports larger ones
4. Stages relevant files and commits with a message matching the repo's existing style
5. Verifies the commit with `git status`

**Usage:** Type `/review-commit` in Claude Code after making changes.
