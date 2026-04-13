#!/bin/bash
# Merged statusline: cost tracking + enhanced context bar
# Color theme via STATUSLINE_COLOR env var: gray, orange, blue, teal, green, lavender, rose, gold, slate, cyan

input=$(cat)
echo "$input" | python3 -c "
import sys, json, os, subprocess
from datetime import datetime

# Read input
data = json.load(sys.stdin)

# Color theme
COLOR = os.environ.get('STATUSLINE_COLOR', 'blue')
RESET = '\033[0m'
GRAY = '\033[38;5;245m'
BAR_EMPTY = '\033[38;5;238m'
ACCENTS = {
    'orange': '\033[38;5;173m', 'blue': '\033[38;5;74m', 'teal': '\033[38;5;66m',
    'green': '\033[38;5;71m', 'lavender': '\033[38;5;139m', 'rose': '\033[38;5;132m',
    'gold': '\033[38;5;136m', 'slate': '\033[38;5;60m', 'cyan': '\033[38;5;37m',
}
ACCENT = ACCENTS.get(COLOR, GRAY)

# --- Cost tracking ---
session_id = data.get('session_id', '')
session_cost = data.get('cost', {}).get('total_cost_usd', 0) or 0

# Write current session cost to temp file for SessionEnd hook
if session_id:
    path = os.path.expanduser(f'~/.claude/.session-cost-{session_id}')
    with open(path, 'w') as f:
        f.write(str(session_cost))

# Read monthly accumulated cost
monthly_file = os.path.expanduser('~/.claude/monthly-cost.json')
current_month = datetime.now().strftime('%Y-%m')
month_name = datetime.now().strftime('%b')
monthly_total = 0.0

try:
    with open(monthly_file) as f:
        mdata = json.load(f)
    if mdata.get('month') == current_month:
        monthly_total = float(mdata.get('total_usd', 0))
except (FileNotFoundError, json.JSONDecodeError, ValueError):
    pass

combined = monthly_total + session_cost

# --- Model info ---
model_name = data.get('model', {}).get('display_name', '?')
model_id = data.get('model', {}).get('id', '')
version = ''
if model_id:
    # Extract version from id like 'claude-opus-4-5' -> '4.5'
    parts = model_id.replace('claude-', '').split('-')
    digits = [p for p in parts if p.isdigit()]
    if len(digits) >= 2:
        version = f'{digits[0]}.{digits[1]}'
model = f'{model_name} {version}'.strip() if version else model_name

# --- Directory and git info ---
cwd = data.get('cwd', '')
dir_name = os.path.basename(cwd) if cwd else '?'

branch = ''
git_status = ''
if cwd and os.path.isdir(cwd):
    try:
        branch = subprocess.check_output(
            ['git', '-C', cwd, 'branch', '--show-current'],
            stderr=subprocess.DEVNULL, text=True
        ).strip()
    except:
        branch = ''

    if branch:
        # Count uncommitted files
        try:
            tracked = subprocess.check_output(
                ['git', '-C', cwd, '--no-optional-locks', 'status', '--porcelain', '-uno'],
                stderr=subprocess.DEVNULL, text=True
            ).strip().split('\n')
            untracked = subprocess.check_output(
                ['git', '-C', cwd, '--no-optional-locks', 'ls-files', '--others', '--exclude-standard'],
                stderr=subprocess.DEVNULL, text=True
            ).strip().split('\n')
            tracked = [f for f in tracked if f]
            untracked = [f for f in untracked if f]
            file_count = len(tracked) + len(untracked)
        except:
            file_count = 0

        # Check sync status
        sync_status = 'local'
        try:
            upstream = subprocess.check_output(
                ['git', '-C', cwd, 'rev-parse', '--abbrev-ref', '@{upstream}'],
                stderr=subprocess.DEVNULL, text=True
            ).strip()
            if upstream:
                # Get ahead/behind
                counts = subprocess.check_output(
                    ['git', '-C', cwd, 'rev-list', '--left-right', '--count', 'HEAD...@{upstream}'],
                    stderr=subprocess.DEVNULL, text=True
                ).strip().split()
                ahead, behind = int(counts[0]), int(counts[1]) if len(counts) > 1 else 0
                if ahead == 0 and behind == 0:
                    # Check last fetch time
                    fetch_head = os.path.join(cwd, '.git', 'FETCH_HEAD')
                    fetch_ago = ''
                    if os.path.exists(fetch_head):
                        import time
                        diff = int(time.time() - os.path.getmtime(fetch_head))
                        if diff < 60: fetch_ago = '<1m'
                        elif diff < 3600: fetch_ago = f'{diff // 60}m'
                        elif diff < 86400: fetch_ago = f'{diff // 3600}h'
                        else: fetch_ago = f'{diff // 86400}d'
                    sync_status = f'synced {fetch_ago}' if fetch_ago else 'synced'
                elif ahead > 0 and behind == 0:
                    sync_status = f'+{ahead}'
                elif ahead == 0 and behind > 0:
                    sync_status = f'-{behind}'
                else:
                    sync_status = f'+{ahead}/-{behind}'
        except:
            pass

        # Build git status string
        if file_count == 0:
            git_status = f'({sync_status})'
        elif file_count == 1:
            try:
                single = subprocess.check_output(
                    ['git', '-C', cwd, '--no-optional-locks', 'status', '--porcelain'],
                    stderr=subprocess.DEVNULL, text=True
                ).strip().split('\n')[0][3:]
                git_status = f'({single}, {sync_status})'
            except:
                git_status = f'(1 file, {sync_status})'
        else:
            git_status = f'({file_count} files, {sync_status})'

# --- Context calculation from transcript ---
transcript_path = data.get('transcript_path', '')
max_context = data.get('context_window', {}).get('context_window_size', 200000) or 200000
max_k = max_context // 1000
max_display = f'{max_k // 1000}M' if max_k >= 1000 else f'{max_k}k'

pct = 0
pct_prefix = ''
baseline = 20000

if transcript_path and os.path.exists(transcript_path):
    try:
        with open(transcript_path) as f:
            lines = [json.loads(line) for line in f if line.strip()]
        # Find last message with usage that isn't sidechain or error
        context_length = 0
        for msg in reversed(lines):
            if msg.get('isSidechain') or msg.get('isApiErrorMessage'):
                continue
            usage = msg.get('message', {}).get('usage', {})
            if usage:
                context_length = (
                    usage.get('input_tokens', 0) +
                    usage.get('cache_read_input_tokens', 0) +
                    usage.get('cache_creation_input_tokens', 0)
                )
                break
        if context_length > 0:
            pct = context_length * 100 // max_context
        else:
            pct = baseline * 100 // max_context
            pct_prefix = '~'
    except:
        pct = baseline * 100 // max_context
        pct_prefix = '~'
else:
    pct = baseline * 100 // max_context
    pct_prefix = '~'

pct = min(pct, 100)

# Build progress bar
bar_width = 10
bar = ''
for i in range(bar_width):
    bar_start = i * 10
    progress = pct - bar_start
    if progress >= 8:
        bar += f'{ACCENT}█{RESET}'
    elif progress >= 3:
        bar += f'{ACCENT}▄{RESET}'
    else:
        bar += f'{BAR_EMPTY}░{RESET}'

ctx = f'{bar} {GRAY}{pct_prefix}{pct}%{RESET}'

# --- Output ---
cost_str = f'\${session_cost:.2f}/\${combined:.2f}'
output = f'{ACCENT}{cost_str}{GRAY} | {model} | 📁{dir_name}'
if branch:
    output += f' | 🔀{branch} {git_status}'
output += f' | {ctx}{RESET}'

print(output)
"
