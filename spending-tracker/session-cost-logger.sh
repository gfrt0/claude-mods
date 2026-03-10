#!/bin/bash
python3 -c "
import sys, json, os
from datetime import datetime

data = json.load(sys.stdin)
session_id = data.get('session_id', '')
if not session_id:
    sys.exit(0)

# Read session cost from temp file written by statusline.sh
cost_file = os.path.expanduser(f'~/.claude/.session-cost-{session_id}')
try:
    with open(cost_file) as f:
        session_cost = float(f.read().strip())
    os.remove(cost_file)
except (FileNotFoundError, ValueError):
    sys.exit(0)

if session_cost <= 0:
    sys.exit(0)

# Track previously recorded cost for this session to handle resumes correctly.
# The API reports cumulative session cost, so on resume we must only add the delta.
history_file = os.path.expanduser('~/.claude/session-cost-history.json')
history = {}
try:
    with open(history_file) as f:
        history = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    pass

# Clear history on month rollover to avoid unbounded growth
current_month = datetime.now().strftime('%Y-%m')
if history.get('_month') != current_month:
    history = {'_month': current_month}

prev_cost = float(history.get(session_id, 0))
delta = session_cost - prev_cost
history[session_id] = session_cost
with open(history_file, 'w') as f:
    json.dump(history, f)

if delta <= 0:
    sys.exit(0)

# Update monthly cost accumulator
monthly_file = os.path.expanduser('~/.claude/monthly-cost.json')
monthly_total = 0.0

try:
    with open(monthly_file) as f:
        mdata = json.load(f)
    if mdata.get('month') == current_month:
        monthly_total = float(mdata.get('total_usd', 0))
except (FileNotFoundError, json.JSONDecodeError, ValueError):
    pass

new_total = monthly_total + delta
with open(monthly_file, 'w') as f:
    json.dump({'month': current_month, 'total_usd': round(new_total, 4)}, f)
"
