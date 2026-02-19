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

# Update monthly cost accumulator
monthly_file = os.path.expanduser('~/.claude/monthly-cost.json')
current_month = datetime.now().strftime('%Y-%m')
monthly_total = 0.0

try:
    with open(monthly_file) as f:
        mdata = json.load(f)
    if mdata.get('month') == current_month:
        monthly_total = float(mdata.get('total_usd', 0))
except (FileNotFoundError, json.JSONDecodeError, ValueError):
    pass

new_total = monthly_total + session_cost
with open(monthly_file, 'w') as f:
    json.dump({'month': current_month, 'total_usd': round(new_total, 4)}, f)
"
