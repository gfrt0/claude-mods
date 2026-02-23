---
allowed-tools: Bash(git *), Read, Glob, Grep, Edit
description: Review code for cleanliness, then commit
---

You are performing a code review and commit workflow. Follow these steps precisely.

## Step 1 — Gather context

Run these commands in parallel:

- `git status`
- `git diff HEAD`
- `git log --oneline -5`
- `git branch --show-current`

If there are no changes (nothing staged or unstaged, no untracked files), tell the user there is nothing to commit and stop.

## Step 2 — Review

Read every changed and newly added file **in full** (use the Read tool, not git diff). For each file, check:

- Stale comments, leftover TODOs, debug prints or console.logs that don't belong
- Inconsistencies between code and documentation (e.g. README says one thing, code does another)
- Unused imports or dead code introduced by the diff
- Obvious bugs, typos, or formatting issues

## Step 3 — Fix or report

- **Small fixes** (stale comments, typos, unused imports): fix them directly with the Edit tool.
- **Larger issues** (logic bugs, design questions): list them for the user and **stop**. Do not commit.

If you made fixes, re-run `git diff HEAD` to confirm the working tree is clean of issues before proceeding.

## Step 4 — Commit

Stage the relevant files by name (do **not** use `git add -A` or `git add .`). Write a concise commit message following the style shown by `git log`:

- Summarize the *why*, not the *what*
- End the message with:
  `Co-Authored-By: Claude <noreply@anthropic.com>`

Use a heredoc to pass the message:

```bash
git commit -m "$(cat <<'EOF'
Your message here

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

## Step 5 — Confirm

Run `git status` to verify the commit succeeded and the working tree is clean.
