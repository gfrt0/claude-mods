#!/bin/bash
# Wait on cluster jobs (SGE) and report a TERMINAL STATE, never the absence of one.
#
#   watch_job.sh 372415 372416 --expect 20 --results '~/proj/cluster/results'
#   watch_job.sh 372407 --log LL_pytest --done-grep "passed|failed" --logs '~/proj/logs'
#   watch_job.sh 372353 --logs '~/Scratch/x/logs' --log-glob '*.{job}.*.out' \
#                --done-grep "finished at" --expect 6      # one array, 6 tasks
#   watch_job.sh 372415 --expect 20 --selftest             # probe once and exit
#
# Exit codes:  0 DONE   2 GONE (left the queue without its artifacts)   3 TIMEOUT
#              4 the watch itself is broken (refused to start)
#
# WHY THIS EXISTS. Every hand-rolled watcher has failed the same way: its POSITIVE branch could not
# fire, so it reported "not yet" forever, or reported a healthy job as dead. Real instances: a local
# `~` expanded on the WRONG machine so the remote grep searched a path that does not exist (a
# completed merge reported GONE an hour later); a grep of `logs/NAME.363367.out` when SGE wrote
# `logs/NAME.o363367`; `pgrep -f` matching its own command line; an `eval` setting `done=` while the
# test read `$done_`. Hence --selftest: the probe must demonstrate it can currently distinguish
# "not yet" from "fired" BEFORE the loop is trusted. Prose loses to a script you can run.
#
# Load-bearing details:
#   - Remote paths are in SINGLE quotes so the REMOTE shell expands ~, never this one.
#   - The ssh exit status is checked. A timed-out ssh returns an empty string, which reads exactly
#     like "the job is gone". rc != 0 is never evidence of anything.
#   - GONE is a distinct outcome, not success: a job killed on the wall clock or by qdel writes no
#     terminal line, and waiting only on the artifact would hang forever.
#
# TWO WAYS TO SAY "FINISHED", pick the one that matches what the job writes:
#   --expect N --results DIR            N files under DIR/<jobid>/ containing --results-grep
#                                       (default '"complete": true')
#   --done-grep PAT [--expect N]        log FILES matching the glob that contain PAT. Default glob
#                                       '{name}.o{job}*' is SGE's default naming; jobs that set -o
#                                       need --log-glob, e.g. '{name}.{job}.*.out' for an array.
#                                       Without --expect, one matching file is enough.
#
# Defaults for a project live in the environment, so a project's command need not repeat them:
#   CLUSTER_WATCH_HOST, CLUSTER_WATCH_LOGS, CLUSTER_WATCH_RESULTS, CLUSTER_WATCH_LOG_GLOB

set -uo pipefail

JOBS=(); EXPECT=""; INTERVAL=300; DEADLINE_H=14; SELFTEST=0; LOGNAME=""; DONE_GREP=""
RESULTS_ROOT="${CLUSTER_WATCH_RESULTS:-}"
LOG_ROOT="${CLUSTER_WATCH_LOGS:-}"
LOG_GLOB="${CLUSTER_WATCH_LOG_GLOB:-{name}.o{job}*}"
RESULTS_GREP='"complete": true'
HOST="${CLUSTER_WATCH_HOST:-myriad}"

while [ $# -gt 0 ]; do
  case "$1" in
    --expect)       EXPECT="$2"; shift 2 ;;
    --interval)     INTERVAL="$2"; shift 2 ;;
    --hours)        DEADLINE_H="$2"; shift 2 ;;
    --results)      RESULTS_ROOT="$2"; shift 2 ;;
    --results-grep) RESULTS_GREP="$2"; shift 2 ;;
    --logs)         LOG_ROOT="$2"; shift 2 ;;
    --log)          LOGNAME="$2"; shift 2 ;;
    --log-glob)     LOG_GLOB="$2"; shift 2 ;;
    --done-grep)    DONE_GREP="$2"; shift 2 ;;
    --host)         HOST="$2"; shift 2 ;;
    --selftest)     SELFTEST=1; shift ;;
    -h|--help)      sed -n '2,32p' "$0"; exit 0 ;;
    -*)             echo "unknown flag $1" >&2; exit 4 ;;
    *)              JOBS+=("$1"); shift ;;
  esac
done
[ ${#JOBS[@]} -gt 0 ] || { echo "REFUSING: no job id given" >&2; exit 4; }
[ -n "$DONE_GREP" ] || [ -n "$RESULTS_ROOT" ] || {
  echo "REFUSING: give --results DIR (with --expect N) or --done-grep PATTERN." >&2
  echo "A watch with no positive condition can only ever report 'not yet'." >&2; exit 4; }
[ -n "$DONE_GREP" ] && [ -z "$LOG_ROOT" ] && {
  echo "REFUSING: --done-grep needs --logs DIR (or CLUSTER_WATCH_LOGS)." >&2; exit 4; }

# The log glob for one job, with {name} and {job} filled in. {name} empty -> '*'.
glob_for() {
  local g="${LOG_GLOB//\{job\}/$1}"
  echo "${g//\{name\}/${LOGNAME:-*}}"
}

# One probe. Prints one line per job: "<id> done=<n> queued=<n> probe=<ok|noartifact>".
probe() {
  local script=""
  for j in "${JOBS[@]}"; do
    if [ -n "$DONE_GREP" ]; then
      # count log FILES holding the pattern: one per finished array task
      script="$script
        n=\$(ls $LOG_ROOT/$(glob_for "$j") 2>/dev/null | wc -l)
        if [ \"\$n\" -gt 0 ]; then
          d=\$(grep -lE '$DONE_GREP' $LOG_ROOT/$(glob_for "$j") 2>/dev/null | wc -l); probe=ok
        else d=0; probe=noartifact; fi"
    else
      script="$script
        R=$RESULTS_ROOT/$j
        if [ -d \"\$R\" ]; then d=\$(grep -l '$RESULTS_GREP' \$R/*.json 2>/dev/null | wc -l); probe=ok
        else d=0; probe=noartifact; fi"
    fi
    script="$script
      q=\$(qstat 2>/dev/null | grep -c \"^ *$j \")
      echo \"$j done=\$d queued=\$q probe=\$probe\""
  done
  timeout 90 ssh "$HOST" "$script"
}

# --- the self-test: refuse to start a watch whose positive branch cannot fire ------------------
out=$(probe); rc=$?
if [ $rc -ne 0 ] || [ -z "$out" ]; then
  echo "REFUSING: the probe itself failed (ssh rc=$rc). Not starting a watch that cannot observe." >&2
  exit 4
fi
echo "$out"
if echo "$out" | grep -q "probe=noartifact"; then
  echo "REFUSING: no artifact to watch for the jobs above -- the results dir or the log glob" >&2
  echo "matches nothing on $HOST yet. A path that is wrong, or expanded locally, looks exactly" >&2
  echo "like 'not finished'. Re-run once the job has started, or fix --results/--logs/--log-glob." >&2
  exit 4
fi
if ! echo "$out" | grep -qE "queued=[0-9]+"; then
  echo "REFUSING: could not read the queue, so GONE could never be distinguished from DONE." >&2; exit 4
fi
[ "$SELFTEST" = 1 ] && { echo "SELFTEST OK: artifacts and queue are both readable."; exit 0; }

# --- the loop ---------------------------------------------------------------------------------
END=$(( $(date +%s) + DEADLINE_H * 3600 ))
while [ "$(date +%s)" -lt "$END" ]; do
  out=$(probe); rc=$?
  if [ $rc -eq 0 ] && [ -n "$out" ]; then
    echo "$(date +%H:%M) $(echo "$out" | tr '\n' ' ')"
    alldone=1; anyqueued=0
    while read -r _ d q _; do
      d=${d#done=}; q=${q#queued=}
      [ -n "$EXPECT" ] && { [ "$d" -ge "$EXPECT" ] || alldone=0; } || { [ "$d" -gt 0 ] || alldone=0; }
      [ "$q" -gt 0 ] && anyqueued=1
    done <<< "$out"
    [ "$alldone" = 1 ] && { echo "DONE: $(echo "$out" | tr '\n' ' ')"; exit 0; }
    [ "$anyqueued" = 0 ] && { echo "GONE: out of the queue without its artifacts -- check logs for kills"; exit 2; }
  fi
  sleep "$INTERVAL"
done
echo "TIMEOUT after ${DEADLINE_H}h: $(echo "$out" | tr '\n' ' ')"; exit 3
