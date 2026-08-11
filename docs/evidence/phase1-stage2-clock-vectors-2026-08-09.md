# Phase 1 Stage 2 evidence: Clock.mqh anchor rework + AgPhase1ClockVectors.mq5

Date: 2026-08-09. Branch: worktree-phase1-pnl-core. Source-level and
static evidence only, gathered inside an isolated git worktree with no
terminal access. Live journal evidence (owner double-click of the
vectors script) is explicitly NOT claimed here; it requires the
deployed terminal tree and is deferred to Stage 5 (owner-gated).

## What changed

`MQL5/Include/AccountGuardian/Clock.mqh`:
- `AG_DAY_ANCHOR_OFFSET_SECONDS = 3600` added as a compile-time constant (Q1 FINAL).
- `AgDayAnchor(t)` reworked to `t - ((t - AG_DAY_ANCHOR_OFFSET_SECONDS) % 86400)`, the last
  01:00-server boundary <= t, replacing the Phase 0 server-midnight floor.
- `AgNextDayAnchor(t)` unchanged in form, now derived from the new `AgDayAnchor`.
- `AgAnchorSanityCheck(fresh)` added (4.1a, Q8 FINAL): in-memory high-water-mark latch,
  halts loudly via `AgAlertEvent` on a forward jump exceeding one day, self-clears,
  never narrows the window, never lets the high mark recede on a backward step.
- `Log.mqh` now included (needed for `AgAlertEvent`/`AgWarn`); no trade-API import added.

New file `MQL5/Scripts/AccountGuardian/AgPhase1ClockVectors.mq5`: a Navigator script,
17 checks, printing `AGVEC|<name>|PASS` or `AGVEC|<name>|FAIL|<detail>` per case and a
final `AGVEC|SUMMARY|<pass>/<total>` line. No trade calls, no file writes, no chart calls.

## Static verification (source read, this session)

- Zero trade-API references in `Clock.mqh` (grep for `OrderSend|OrderClose|CTrade`, zero hits).
- Zero real `TimeLocal`/`TimeGMT`/`TimeTradeServer` calls in `Clock.mqh` (only the
  header-comment prohibition text matches).
- `AgDayAnchor`/`AgNextDayAnchor` remain pure functions of their `datetime` argument;
  no persisted state read or written (never-loaded-never-written honored vacuously).
- `AgAnchorSanityCheck` mutates only the three new in-memory globals declared alongside
  it (`g_ag_high_anchor_seeded`, `g_ag_high_anchor`, `g_ag_anchor_waiting_on`); nothing
  it touches is written to a file or a GlobalVariable.

## Compile attempt, this session, and why it does not close the row

`MetaEditor64.exe /compile:"MQL5\Scripts\AccountGuardian\AgPhase1ClockVectors.mq5" /log:... /portable`
was run from inside the worktree. Result: `error 106: file 'Include\AccountGuardian\Clock.mqh'
not found`, because MetaEditor's include resolution roots to the terminal's own installed
MQL5 tree (`C:\Program Files\MetaTrader 5\MQL5\Include\...`), not this worktree's local
`MQL5\Include\...`. Compiling this branch's actual source therefore requires copying it
into the terminal tree first, which is a Stage 5 deploy action (owner-gated, touches the
live instance) and is explicitly out of scope for this session per the standing
authorization. No compile log is claimed. This is recorded as a fact rather than
worked around, per the standing rule that a session report is not evidence, only
artifacts are: there is no artifact here claiming a clean compile.

## What the 17 vectors exercise (by inspection, not yet run)

1-3: boundary second, one second before and after (`boundary_at`, `boundary_minus_1s`, `boundary_plus_1s`).
4: frozen input, same t twice, same result (`frozen_input_repeat`).
5-6: backward step across the boundary, 1s and 25h classes.
7: forward jump across three anchors, `AgDayAnchor` tracks it directly (no latch involved).
8-10: `AgNextDayAnchor` = anchor + 86400, at the anchor, the next boundary, and across a backward step.
11-12: Q8 vector 1, first pass seeds the latch and is accepted; a legitimate one-day advance
   accepts and moves the high-water mark.
13-15: Q8 vector 2, an anomalous two-boundary jump halts, uses the retained anchor, leaves the
   high-water mark unchanged, and the `waiting_on` string names both `retained=` and `rejected=`.
16: self-clearing, a later pass back within one day of the retained high mark resumes normally.
17-18: Q8 vector 3, a backward step still widens using fresh and never substitutes the high-water mark.

## Status

Source and static evidence: DONE, this session. Live journal run (17/17 PASS expected):
OPEN, requires an owner terminal session per the Stage 5 gate.
