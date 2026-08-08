# Phase 1 Stage 4 evidence: wiring, states, observability

Date: 2026-08-09. Branch: worktree-phase1-pnl-core. Static evidence
only, gathered inside an isolated git worktree with no terminal
access; no live acceptance rows are claimed here.

## What changed

`MQL5/Include/AccountGuardian/State.mqh`: `g_ag_dynamic_waiting_on` added; `AgWaitingOn()`
now reports the live SYNCING poll count and the ACTIVE-state Q8/Q10 condition instead of
the fixed Phase 0 strings, one tick lagged (same lag every other proof-of-life field has,
since AgProofOfLife runs before the per-state dispatch each tick).

`MQL5/Include/AccountGuardian/Log.mqh`: `AgProofOfLife` gained an optional 5th parameter
`numbers` (default `""`), appended to the LIFE line only when non-empty. All prior 4-arg
call sites remain valid.

`MQL5/Experts/AccountGuardian/AccountGuardian.mq5`: new Phase 1 globals (Q9 baseline, Q10
marker, the rollover latch, the breach-alert cadence timestamp, the six last-known PnL
numbers); `AgPnlNumbersString()`; `AgEvaluateActive()` implementing the 4.4 per-pass order
(Q10 connection check, then Q8 anchor sanity, then the computation, then the day-rollover
latch, then Q9 coherence deferral, then the Q2 interim breach posture); `AgRefreshBanner()`
now shows live PnL numbers in ACTIVE and a DEGRADED prefix when Q10 holds; `OnTimer()` gains
the per-state dispatch after the existing SAFE_HALT early return, LOCKED left an explicit
empty case for Phase 2.

## Static acceptance rows (grep, this session, quoted from the plan's own Stage 4 list)

```
$ grep -n "AgTransition(AG_STATE_ACTIVE" MQL5/Experts/AccountGuardian/AccountGuardian.mq5
358:         AgTransition(AG_STATE_ACTIVE, "history stable",
(exactly one call site emits the SYNCING->ACTIVE transition, one TRANSITION line per exit)

$ grep -n "AG_STATE_SAFE_HALT\|AgEvaluateActive\|AG_STATE_SYNCING\|AG_STATE_LOCKED" \
    MQL5/Experts/AccountGuardian/AccountGuardian.mq5
349:   if(g_ag_state == AG_STATE_SAFE_HALT)
354:   if(g_ag_state == AG_STATE_SYNCING)
366:      AgEvaluateActive();
367:   else if(g_ag_state == AG_STATE_LOCKED)
(the SAFE_HALT early return at 349-350 precedes every dispatch branch; AgEvaluateActive's
only call site is 366, unreachable from the SAFE_HALT return above it: SAFE_HALT path
provably runs no PnL call, confirmed by this scoped read rather than assumed)

$ grep -n "g_ag_breach_deferred_once" MQL5/Experts/AccountGuardian/AccountGuardian.mq5
163:      if(current_count == g_ag_last_deal_count && !g_ag_breach_deferred_once)
166:         g_ag_breach_deferred_once = true;
181:         g_ag_breach_deferred_once = false;   // after declaring
185:      g_ag_breach_deferred_once = false;       // no breach pending this pass
(the flag is set true only on the one-pass defer branch and reset on every other path:
after a declaration and whenever no breach holds, matching the plan's pseudocode exactly)

$ grep -nE "OrderSend|OrderClose|CTrade|trade\.(Buy|Sell)" MQL5/Experts/AccountGuardian/AccountGuardian.mq5
(no matches: still zero trade calls anywhere in the build)
```

`AgEvaluateActive`'s body was read in full this session to confirm the per-pass order
matches plan section 4.4 literally: TERMINAL_CONNECTED check first (return on DEGRADED),
then `AgAnchorSanityCheck` (return on halt), then the day-rollover latch and the
realized/base/floating/limit computation, then the Q9 coherence-deferral branch on the
breach conclusion, then the Q2 ALERT/journal-line posture. No step runs before the one
ahead of it in this list.

## Compile: not attempted this session

Same obstruction as Stage 2 and Stage 3: MetaEditor's include resolution roots to the
deployed terminal MQL5 tree, not this worktree. No compile log is claimed.

## Owner-review finding 1, fixed 2026-08-09: DEGRADED visibility gap

Owner review of tip `e5d32bc` found two defects in the original wiring, both verified
against source before the fix:

1. `AgPnlNumbersString()` (mq5:75-85 as committed) returned the ACTIVE governing numbers
   with no DEGRADED marker; only `g_ag_dynamic_waiting_on` carried it, so a reader of the
   numbers field group alone (not cross-referencing `waiting_on`) could mistake stale
   figures for a live evaluation. Q10 requires the LIFE line and banner to show last-known
   figures WITH the marker.
2. `g_ag_degraded = false` ran unconditionally right after the connection check passed
   (mq5:117 as committed), before the computation that follows could still fail
   (`AgRealized`/`AgDayBase` returning `ok=false` on a HistorySelect failure). A reconnect
   pass that failed its history read would show a non-degraded banner over stale numbers.

Fix: `AgPnlNumbersString()` now prefixes `DEGRADED|` to the whole field group when
`g_ag_degraded` holds. `g_ag_degraded = false` moved from the connection-check branch to
the single point where `g_ag_have_pnl_numbers = true` is set, i.e. only once a full
computation succeeds this pass.

```
$ grep -n "g_ag_degraded" MQL5/Experts/AccountGuardian/AccountGuardian.mq5
44:bool     g_ag_degraded             = false; // Q10 DEGRADED marker
85:   string prefix = g_ag_degraded ? "DEGRADED|" : "";
101:      pnl = (g_ag_degraded ? "DEGRADED: " : "")
120:      g_ag_degraded          = true;
167:   g_ag_degraded         = false;   // cleared here, not on entry: see the note above
```

Exactly one set-true site (the disconnect branch) and one clear site (post-computation
success); no path clears it before a computation attempt can fail.

## Status

Static evidence: DONE, this session. Live/compile acceptance (LIFE-line field list,
TRANSITION line content, ALERT cadence, DEGRADED marker): OPEN, Stage 5 owner gate.
