#!/bin/bash
python3 -c "
import sys, json, os
from datetime import datetime

data = json.load(sys.stdin)
session_id = data.get('session_id', '')
session_cost = data.get('cost', {}).get('total_cost_usd', 0) or 0

# Write current session cost to temp file for the SessionEnd hook
if session_id:
    path = os.path.expanduser(f'~/.claude/.session-cost-{session_id}')
    with open(path, 'w') as f:
        f.write(str(session_cost))

# Read monthly accumulated cost (past sessions only)
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
print(f'Session: \${session_cost:.2f} | Month ({month_name}): \${combined:.2f}')
"
