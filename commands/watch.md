---
allowed-tools: Bash(ssh *:*), Bash(~/.claude/watch_job.sh:*), Bash(*/cluster/watch_job.sh:*), Bash(qstat:*), Bash(ls:*), Bash(date:*), Read, Glob, Grep
description: "Watch a running cluster job and report terminal states. Trigger on 'keep me posted', 'status', 'poll', 'watch the job', 'let me know when it finishes', 'is it done'."
---

# Watch a cluster job

## Input

`$ARGUMENTS` — optional job ids. If none, find them: the last `qsub` in this conversation, then
`ssh <host> qstat`, then the `## Myriad jobs` section of the newest `session_logs/*.md`.

## The rule

**Never hand-roll the loop. Run `~/.claude/watch_job.sh`** (or the project's own
`cluster/watch_job.sh`, if it has one).

Every hand-written watcher has failed the same way — its POSITIVE branch could not fire, so it
reported "not yet" forever, or called a healthy job dead. `~/.claude/rules/cluster-job-polling.md`
has the casebook, and it was in context on 2026-09-19 when a hand-rolled watcher still never fired.
Reading the rule is not enough; run the script, which proves the condition can fire before it starts.

## Steps

1. **Work out what "finished" means for these jobs, and find where that evidence lands.** Do not
   guess the log path: `ssh <host> 'ls <logdir> | tail'`, and read the job script's `-o` line. SGE
   writes `<NAME>.o<id>[.<task>]` unless the script sets `-o`, and a wrong glob looks exactly like
   "not finished".
   - **Files written per seed/cell:** `--results DIR --expect N`, which counts files under
     `DIR/<jobid>/` containing `--results-grep` (default `"complete": true`).
   - **A line in the log:** `--done-grep "<pattern>"`, counting log FILES that contain it. For an
     array, add `--expect <tasks>` and a glob matching one file per task, e.g.
     `--log-glob '{name}.{job}.*.out'` or `--log-glob '*.{job}.*.out'` when watching several jobs
     with different names.

2. **Self-test first. It must pass before the watch is worth anything:**

   ```bash
   ~/.claude/watch_job.sh <ids> --logs '<logdir>' --log-glob '<glob>' --done-grep '<pat>' --expect N --selftest
   ```

   Exit 4 means the watch is broken, not that the job is unfinished. Fix the path or wait for the
   job to start; never "just run it anyway".

3. **Start it in the background** (same flags, minus `--selftest`), so the harness re-invokes you on
   exit. Do not poll in the foreground and do not `sleep` in a loop.

4. **Report the terminal state, and distinguish the three:**
   - `DONE` — every job has its artifacts. Read the results, then say what they mean.
   - `GONE` (exit 2) — left the queue WITHOUT its artifacts: killed by wall clock, memory or qdel.
     This is not success. Get `qacct -j <id> | tail -50` (ids wrap across years — read the LAST
     record and sanity-check `start_time`), then the tails of `.out` and `.err`.
   - `TIMEOUT` (exit 3) — say so plainly; do not guess an outcome.

5. **While waiting**, if the user asks for status, run one `--selftest` for a current snapshot
   rather than starting a second watcher.

## Per-project defaults

Rather than repeating paths, a project can export `CLUSTER_WATCH_HOST`, `CLUSTER_WATCH_LOGS`,
`CLUSTER_WATCH_RESULTS` and `CLUSTER_WATCH_LOG_GLOB`, and the flags above then fall back to them.

## Reporting

State counts and the terminal state first, then the substance. Never report an outcome the watcher
did not actually observe, and never present an early subset of seeds as a result — a coefficient
that passes at 3 seeds can fail at 20.
