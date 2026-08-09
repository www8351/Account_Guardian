# Phase 1 Stage 5, deploy and live acceptance, 2026-08-09

Joint owner-executor session. The owner performs every terminal GUI action and reports
what the screen shows; every claim about resulting state is verified by the executor from
artifacts (journal lines, file hashes, mtimes), per the standing rule that a session
report is not evidence, only artifacts are.

Branch `worktree-phase1-pnl-core`, tip `3f478130284aa950356a4abfbf7f0e1b93866acd`.
Terminal data folder `C:\Users\www83\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075`.

---

## 0. State re-derivation

Re-derived in this session, quoted rather than carried from any report.

| Check | Result |
|---|---|
| `git rev-parse --abbrev-ref HEAD` | `worktree-phase1-pnl-core` |
| `git rev-parse HEAD` | `3f478130284aa950356a4abfbf7f0e1b93866acd` (= `3f47813`, the expected tip) |
| `git status --porcelain` | empty |
| commit-msg hook first 8 bytes | `23 21 2f 62 69 6e 2f 73` = `#!/bin/s`, BOM free |

`git log --oneline -8`:

```
3f47813 ledger: sync three owner-review fixes against tip e5d32bc, Q10 reconnect-coherence amendment banked FINAL
0685529 phase1 fix: comment AgFloating's PositionGetTicket select-and-return semantics
fb82a70 phase1 fix: reconnect coherence RESYNC gate (Q10 amended by new owner ruling 2026-08-09)
2d8a400 phase1 fix: DEGRADED marker missing from numbers field, degraded cleared too early
e5d32bc ledger: sync Phase 1 stages 2-4 plus SPEC A6, branch not merged, stage 5 blocked on owner
8dc2daf phase1: SPEC amendment A6, day anchor / PnL engine / interim breach posture
fb58788 phase1 stage 4: wiring, per-state dispatch, observability (Q2/Q8/Q9/Q10 FINAL)
e7c1560 phase1 stage 3: Pnl.mqh history engine bodies (Q2/Q3/Q4/F11/F12 FINAL)
```

Tip matches the expected value, so the deploy proceeded.

---

## 1. Backup, taken before any file moved

Halt file, copied to `docs/evidence/halt_1200252169.dat.pre-phase1-deploy-2026-08-09`,
copy verified md5-equal to source after the copy:

```
95400FD06AD9CF6A094FD31E327A94CD  halt_1200252169.dat   250 bytes   mtime 2026-08-06 16:35
```

That md5 and size match the phase0-close record of 2026-08-06 exactly (thirteen session
records, halt flag `H|0||0`), so the file has not moved since.

Terminal AccountGuardian sources snapshotted to
`docs/evidence/terminal-pre-phase1-2026-08-09/`, so rollback is a byte-verified restore
rather than a guess. Every copy verified md5-equal to its source:

| File | md5 (pre-deploy terminal state) |
|---|---|
| `Experts/AccountGuardian/AccountGuardian.mq5` | `DBB44AF87437265BA69CAA4C8C1CADA7` |
| `Include/AccountGuardian/Clock.mqh` | `8DFC362B78D1E3889F2B19E9EBCE96C3` |
| `Include/AccountGuardian/Log.mqh` | `2C7D584EB9FBDF6FEABACCAE6E08629C` |
| `Include/AccountGuardian/Persist.mqh` | `BA6AB1092B0A86979974ACECEC643BF0` |
| `Include/AccountGuardian/Pnl.mqh` | `D858C32B4501B94D0A365096127C3398` |
| `Include/AccountGuardian/State.mqh` | `A3E35B1483929C431FE70425377C9085` |
| `Include/AccountGuardian/Sweep.mqh` | `CF7D355A7C52265A7AFF5C465DA33C46` |

The prior build's compile log was also copied, to
`terminal-pre-phase1-2026-08-09/compile.log.pre-phase1`, before the new compile could
overwrite anything.

Pre-deploy ex5, recorded so the freshness check below has a baseline:

```
B918F4521168B6D4FCAA2BA954EA6E2E  AccountGuardian.ex5   40224 bytes   mtime 2026-08-04 14:29:50
```

Recorded as a negative rather than skipped: `git show main:<path> | md5sum` does NOT match
the terminal copies, and this is a line-ending artifact, not a deployment divergence.
`core.autocrlf` is `true` and `.gitattributes` carries `* text=auto`, so git blobs hold LF
while working-tree and terminal copies hold CRLF. Byte-verified rollback therefore rests on
the physical snapshot above, not on a git blob hash.

---

## 2. Deploy

Six files copied worktree to terminal. `MQL5/Scripts/AccountGuardian/` did not exist in the
terminal tree and was created. Every copy verified by md5 against the worktree after the
copy; all six match:

| File | md5, worktree and terminal after deploy |
|---|---|
| `Include/AccountGuardian/Clock.mqh` | `C3B34958D91C35711083ABF80A27048F` |
| `Include/AccountGuardian/Pnl.mqh` | `BC81EEEB8A839F3D168A838958E9B578` |
| `Include/AccountGuardian/State.mqh` | `34792807C6B6B548943215866193EB3F` |
| `Include/AccountGuardian/Log.mqh` | `C4E803FB81EBE7F521CC020E8FA1CE82` |
| `Experts/AccountGuardian/AccountGuardian.mq5` | `11195516BC4EA1F12FE376657109F51F` |
| `Scripts/AccountGuardian/AgPhase1ClockVectors.mq5` | `562E61AD6477E416F3CE0F8B3D847B8E` |

`Persist.mqh` is not touched by Phase 1 and is verified byte-identical before and after at
`BA6AB1092B0A86979974ACECEC643BF0`. `Sweep.mqh` likewise unchanged at
`CF7D355A7C52265A7AFF5C465DA33C46`.

Line-ending note, measured not assumed: the five deployed `.mq5`/`.mqh` sources carry CRLF
(equal CR and LF counts), while `AgPhase1ClockVectors.mq5` carries LF only (0 CR, 109 LF).
The script was written LF by the authoring session and git does not rewrite a working-tree
file after commit, so the working copy stayed LF. Deployed as-is and md5-verified, and it
compiled clean, so nothing is inferred about which form MetaEditor prefers.

---

## 3. Compile, in the terminal tree

Standing rule 6 applies: the metaeditor64 exit code is not a status signal and is inverted
on this installation. Both compiles exited 1; the Result line and a fresh ex5 mtime are the
evidence, and both are read.

`AccountGuardian.mq5`, log at
`Experts/AccountGuardian/compile-phase1-2026-08-09.log` (UTF-16LE, decoded explicitly per
standing rule 5):

```
Result: 0 errors, 0 warnings, 729 ms elapsed, cpu='X64 Regular'
```

`AgPhase1ClockVectors.mq5`, log at
`Scripts/AccountGuardian/compile-vectors-2026-08-09.log`:

```
Result: 0 errors, 0 warnings, 427 ms elapsed, cpu='X64 Regular'
```

Zero iterations were needed; no source was edited in either tree.

Include resolution MEASURED rather than assumed, which is the fact the 2026-08-09
implementation session could not establish. The log names every include path it took, and
every one roots at the terminal data folder, not at the MetaEditor install directory:

```
...\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Include\AccountGuardian\Log.mqh
...\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Include\AccountGuardian\Clock.mqh
...\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Include\AccountGuardian\State.mqh
...\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Include\AccountGuardian\Persist.mqh
...\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Include\AccountGuardian\Pnl.mqh
...\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Include\AccountGuardian\Sweep.mqh
```

Corroborating negative: `C:\Program Files\MetaTrader 5\MQL5\Include\AccountGuardian` does
not exist, so the install tree could not have supplied these headers. The earlier session's
error 106 is therefore explained as a consequence of compiling a file that sat outside any
MQL5 root, not as a property of MetaEditor's search order.

Fresh ex5, both written by these compiles:

```
E7854EDF5B05A1C2DC8E23B59FE9548F  AccountGuardian.ex5        49972 bytes  mtime 2026-08-09 18:32:24
9C57B411FD76B6FA3A37FA0CABB3DC2C  AgPhase1ClockVectors.ex5   13214 bytes  mtime 2026-08-09 18:32:39
```

Both mtimes are fresh against the 2026-08-04 14:29:50 baseline. Per standing rule 7 the ex5
size and hash are not build identity and are recorded as timestamps and nothing more.

Running instance UNDISTURBED by the deploy and both compiles, which is the required
outcome, since MT5 does not hot-reload an externally recompiled ex5. Measured from
`MQL5\Logs\20260809.log`: 2225 lines, of which ZERO are non-LIFE, so no init, no deinit and
no alert occurred at any point today. The LIFE lattice runs at exact 30 s straight through
both compiles, `seconds_in_state` stepping 266131, 266161, 266191, 266221 at 18:30:42,
18:31:12, 18:31:42 and 18:32:12, with the compiles at 18:32:24 and 18:32:39. The image in
memory is still the Phase 0 build, confirmed by its `waiting_on` string still reading the
Phase 0 "not implemented in Phase 0, SYNCING is terminal in this build" text.

---

## Two expectation corrections found before the owner touched the terminal

Both are documentation errors, not code errors, and both are recorded here before the run
so that a correct result is not mistaken for a fault.

**The vectors script emits 20 checks, not 17.** Counted mechanically from the source: 20
`AgVecCheck`/`AgVecCheckDT` call sites, so the expected output is 20 `AGVEC` lines plus
`AGVEC|SUMMARY|20/20`. The figure 17 appears in the LEDGER 2026-08-09 ACTIONS entry and in
`docs/evidence/phase1-stage2-clock-vectors-2026-08-09.md`, both written by inspection before
the script had ever run; that evidence document's own enumeration is internally
inconsistent, headed "What the 17 vectors exercise" while its list runs to item 18. The
undercount is at Q8 vector 1, which has four checks (`q8_seed_accepts_first_pass`,
`q8_seed_sets_high_anchor`, `q8_one_day_advance_accepts`,
`q8_one_day_advance_moves_high_anchor`) where the list records two. The script is correct;
the count is corrected against the measured run below, not before it.

**The anchor reads Friday 01:00, not today's 01:00, and that is the specified behaviour.**
The live journal carries a server clock frozen at `2026.08.07 23:57:59`, the Friday
gold-close stamp, with `seconds_in_state` at 266221 seconds (about 3.08 days), so this
session sits inside the weekend freeze. `AgDayAnchor(2026.08.07 23:57:59)` returns
`2026.08.07 01:00:00`. Plan section 2.3 specifies exactly this: "during the freeze the
anchor holds Friday 01:00 ... Saturday's and Sunday's anchors are never observed; they are
absorbed as zero-deal spans inside the Friday-anchored window." The session instruction's
expectation of "today's 01:00 server" cannot hold today and should not. The verification is
therefore that the LIFE line's anchor field reads `2026.08.07 01:00:00`; any other value is
the fault.

---

## 3a. Navigator enumeration, measured on a second file class

The owner reported `AgPhase1ClockVectors` ABSENT from the Navigator after the deploy, with
Scripts showing only the stock `Examples` folder, screenshot taken. The running terminal had
started 2026-08-06 16:35:07 and the script's ex5 was written 2026-08-09 18:32:39, so the
process never enumerated it.

This extends the standing rule of 2026-08-04, established on the Presets folder only, to the
Scripts folder: files written into the terminal data folder are invisible to an already
running terminal regardless of file class. The session order was swapped on the spot,
kill-and-relaunch before the vectors rather than after, and the fresh process did enumerate
it, which closes the rule in both directions rather than only the negative half.

## 4. Clock vectors, P1-M evidence

TWO runs exist and both are banked, because they measure DIFFERENT BUILDS. The count
difference is itself the build discriminator, and a second, independent discriminator fell
out of the amendment: the original build alerted from inside `Clock.mqh`, the amended build
does not, because the announcement moved to the caller and the vectors script is not the EA.

### Run 1, 19:00:25.082, the ORIGINAL 20-check build (halt semantics)

All 20 PASS, `AGVEC|SUMMARY|20/20`. Verified from `MQL5\Logs\20260809.log` directly, not from
the session report. Names in journal order:

```
boundary_at, boundary_minus_1s, boundary_plus_1s, frozen_input_repeat,
backward_1s_class, backward_25h_class, forward_jump_three_anchors,
next_day_anchor_A0, next_day_anchor_A1, next_day_anchor_backward,
q8_seed_accepts_first_pass, q8_seed_sets_high_anchor,
q8_one_day_advance_accepts, q8_one_day_advance_moves_high_anchor,
q8_forward_jump_halts_uses_retained, q8_forward_jump_high_anchor_unchanged,
q8_forward_jump_waiting_on_names_both, q8_self_clears_within_one_day,
q8_backward_step_still_widens, q8_backward_step_high_anchor_unchanged
```

This run is kept rather than discarded because it is the only measurement of the original
halt path, which the amendment supersedes. It also produced the single ALERT line in the
entire day's journal, at the same millisecond:

```
19:00:25.082  AG|2026.08.07 23:57:59|ALERT|anchor sanity: fresh anchor 2026.02.13 01:00:00
              exceeds retained high anchor 2026.02.11 01:00:00 by more than one day,
              evaluation halted this pass
```

`2026.02.11` and `2026.02.13` are the A1 and A3 synthetic anchors of that vector, correct for
it. The owner observed the matching modal popup on screen, text identical to the journal line,
sourced to `AgPhase1ClockVectors (XAUUSD.ecn,M5)`, and closed it. Two things bank from that
popup. First, `AgAlertEvent` demonstrably raises a real popup naming both anchors, never
before observed live for this code path. Second, and it is the reason the (d) cadence cap was
ruled: ONE synthetic pass produced ONE popup, so a sustained real condition, which is what the
Monday reopen would have created, would have produced one per timer tick indefinitely.

The live instance was undisturbed across this run, confirmed by the LIFE lattice at exact 30 s
from 18:58:02 through 19:03:02 carrying `anchor=2026.08.07 01:00:00`, `base=2003.46`,
`limit=100.17` throughout.

### Run 2, 22:30:07.433, the AMENDED 26-check build (alert-and-advance)

All 26 PASS, `AGVEC|SUMMARY|26/26`. The names that differ from run 1 are exactly the
amendment's surface:

```
q8_forward_jump_accepts_fresh                 (was q8_forward_jump_halts_uses_retained)
q8_forward_jump_high_anchor_advances          (was q8_forward_jump_high_anchor_unchanged)
q8_forward_jump_note_names_both               (was q8_forward_jump_waiting_on_names_both)
q8_note_clears_on_next_ordinary_pass          (was q8_self_clears_within_one_day)
q8_forward_jump_note_carries_previous_value   (new)
q8_backward_step_sets_no_note                 (new)
q8_weekend_reopen_accepts_monday              (new)
q8_weekend_reopen_high_anchor_advances        (new)
q8_weekend_reopen_note_names_jump             (new)
q8_weekend_reopen_clears_next_pass            (new)
```

`q8_weekend_reopen_*` replays the exact live signature the original rule stalled on: seed
Friday `2026.08.07 01:00:00`, feed Monday `2026.08.10 01:00:00`, and assert acceptance, the
high mark advancing, `jump=259200s` named in the note, and the note cleared on the next pass.
The dates are the real ones from this session, not invented.

Run 2 emitted NO ALERT line. Today's journal holds exactly one ALERT in total, from run 1.
That is independent confirmation that the announcement left `Clock.mqh`: the amended function
sets a note and logs nothing, and the caller that would announce it is the EA, which a script
does not have. Recorded as a measurement rather than as an inference from the diff.

P1-M therefore closes on run 2 for the amended build, with run 1 retained as the original
build's record. The live half of P1-M is the Monday reopen, section 7 below.

## 5. Kill and relaunch

Two hard kills ran this session, the second required because the fix landed between them and
MT5 does not hot-reload an externally recompiled ex5.

### Kill 1 and relaunch 1, loading the first Phase 1 build

Pre-kill state: pid 20464 started 2026-08-06 16:35:07; halt file 250 bytes, md5
`95400FD06AD9CF6A094FD31E327A94CD`, 13 records, first 12 clean, newest `S|1786034111|0`
unclean because live; halt flag `H|0||0`.

Chain safety stated BEFORE the kill rather than discovered after: the relaunch appends a
second unclean record, but the gap between the two init stamps is about three days against a
300 s bound, so the backward walk stops at the first pair and the chain reads 1 against
`CrashLoopMaxInits=3`.

`taskkill /F /IM terminal64.exe` at 18:47:01, output `SUCCESS: The process "terminal64.exe"
with PID 20464 has been terminated.` Verified after: no `terminal64` process, and the halt
file BYTE-UNTOUCHED, md5 and mtime both unmoved. That is the 2026-08-04 discriminator, a
genuine hard kill leaves the newest record at `clean=0` because OnDeinit never runs, and the
Task Manager graceful-close trap of that entry was avoided.

Relaunch at 18:50:57, pid 9592. Journal sequence, verified from the file:

```
18:51:01.197  INFO|init|build=Phase0|account=1200252169|server=JustMarkets-Demo3
18:51:01.197  WARN|stale mutex heartbeat (240s), taking over crashed-instance mutex
18:51:01.197  INFO|mutex acquire|id_set=1|id_exists=1|hb_set=1|hb_exists=1|hb_value=1786301461
18:51:01.202  DEBUG|crash-loop check|chain=1/3 consecutive unclean, gap bound 300s
18:51:01.202  TRANSITION|BOOT->SYNCING|boot|weekly=on|timer=1s
18:51:01.203  INFO|timer armed|period=1s
18:51:02.209  LIFE|state=SYNCING|seconds_in_state=1|waiting_on=history stability poll not yet run this session
18:51:04.195  TRANSITION|SYNCING->ACTIVE|history stable|polls=3/3
18:51:05.197  INFO|day rollover|old_anchor=1970.01.01 00:00:00|new_anchor=2026.08.07 01:00:00|jump=1786064400s
18:51:32.199  LIFE|state=ACTIVE|seconds_in_state=28|waiting_on=-|anchor=2026.08.07 01:00:00|realized=0.00|floating=0.00|base=2003.46|limit=100.17|pnl_vs_limit=0.00 vs -100.17
```

This is the FIRST SYNCING exit in this build's history:
`SYNCING->ACTIVE|history stable|polls=3/3`, three consecutive stable connected polls at the
1 s timer against `HistoryStablePolls=3`, elapsed 18:51:01.202 to 18:51:04.195.

Cross-witnesses, each independent of the journal narrative:

- Halt file moved 250 to 267 bytes, md5 `D79397D1CDEE04FE29F4C268B6F2101E`, new record
  `S|1786301461|0` appended, 14 records, halt flag still `H|0||0`.
- `1786301461` in that record equals `hb_value` on the mutex-acquire line exactly.
- The `chain=1/3` DEBUG line agrees with the backward walk computed independently from the
  file's own records.
- Stale-mutex age `240s` equals kill 18:47:01 to init 18:51:01 to the second.

Anchor verification, which is the point of the row: the LIFE line reads
`anchor=2026.08.07 01:00:00`. That is Friday 01:00, PREDICTED IN WRITING BEFORE THE RELAUNCH
in the corrections section above. It is not midnight, which proves the 3600 s offset constant
is live, and it is not today's date, which is the weekend-freeze hold behaving exactly as plan
2.3 specifies. Arithmetic checks independently: 2003.46 x 5% = 100.173, rendered
`limit=100.17`; the currency leg is disabled at 0, so the min over enabled legs is the percent
leg.

Two defects were found in this output and are recorded in section 5a.

The session ran ACTIVE unbroken for 3 h 48 m. Final LIFE line before kill 2:

```
22:39:32.206  LIFE|state=ACTIVE|seconds_in_state=13708|waiting_on=-|anchor=2026.08.07 01:00:00|realized=0.00|floating=0.00|base=2003.46|limit=100.17|pnl_vs_limit=0.00 vs -100.17
```

`seconds_in_state=13708` counts back to the 18:51:04 ACTIVE entry to the second, and the
numbers are stable across the whole span.

### Kill 2 and relaunch 2, loading the amended build

`taskkill /F /IM terminal64.exe` at 22:40:33, output `SUCCESS: The process "terminal64.exe"
with PID 9592 has been terminated.` Verified after: no process, and the halt file again
BYTE-UNTOUCHED at md5 `D79397D1CDEE04FE29F4C268B6F2101E`, mtime still 18:51:01, so OnDeinit
again did not run. Chain safety before the kill: previous init 18:51:01 against a new init
about 13000 s later, far outside the 300 s bound, so the chain stays at 1.

Relaunch and its verification: section 5c below.

## 5a. Two defects found in relaunch 1's output, fixed the same session

Both were verified in source before being claimed, per the standing rule, and both are
recorded with the live line that exposed them.

**Build label wrong.** `AccountGuardian.mq5:259` hardcoded `init|build=Phase0`, so the Phase 1
image announced itself as Phase 0, quoted from the live line above. Standing rule 7 names
runtime journal behaviour as the only measure of what is actually running, so a build that
misreports its identity in that channel undermines the one instrument this project has.
Corrected to `Phase1`.

**Spurious rollover line at session start.** `g_ag_last_logged_anchor` initialised to 0, so
the first ACTIVE pass satisfied `window_anchor > 0` and logged a rollover that never happened,
quoted above as `old_anchor=1970.01.01 00:00:00|jump=1786064400s`. Observability only, so not
an arithmetic fault, but it asserts an event that did not occur and it pollutes the exact
artifact the P1-A row closes on, since a scan for rollover lines would otherwise return one
per restart. Fixed with the seeded-flag pattern the Q8 latch already used in the same
codebase: the latch is seeded silently on the first ACTIVE pass.

## 5b. The Q8 defect, the finding that justified the whole redeploy

Found by SOURCE READ while confirming the rollover defect, before the condition could fire,
and roughly six hours ahead of the reopen at which it would have fired. Recorded in full
because the reasoning, not the symptom, is what generalises.

Every step source-verified rather than taken from the design prose:

1. `g_ag_high_anchor` is seeded on the first ACTIVE pass (`Clock.mqh:69-75`). This session
   seeded it to `2026.08.07 01:00:00`, confirmed on the live LIFE line.
2. The weekend freeze pins `TimeCurrent` at `2026.08.07 23:57:59`, measured live.
3. The A8 harvest measured the reopen at Monday 01:00:20 server, at which `AgDayAnchor`
   returns `2026.08.10 01:00:00`.
4. `fresh - g_ag_high_anchor` = 259200 s against the 86400 bound at `Clock.mqh:81`, so control
   reached the halt branch at `Clock.mqh:87-92`.
5. That branch did NOT advance the high mark, and self-clearing required `fresh` to fall BACK
   within one day of the retained mark (`Clock.mqh:76-80`). A resumed clock only moves
   forward, so the condition was PERMANENT until restart.
6. `AccountGuardian.mq5:155-156` returned early on that branch, so from the reopen onward
   there would have been no rollover line, no recompute, and frozen numbers.
7. `AgAlertEvent` (`Log.mqh:43-47`) had no cadence cap, unlike the Q2 breach ALERT, and
   `OnTimer` runs at `SweepPeriodSeconds=1`, so one modal popup per second, unbounded. Run 1
   of the vectors demonstrated that popup live.

Deterministic, not probabilistic, and recurring every weekend for any instance running across
the reopen. The code was faithful to Q8; Q8 was wrong against a weekend freeze the same plan
document had measured and described in 2.3 as producing exactly a Friday-to-Monday advance.
Two FINAL rulings collided, so it went to the owner as a ruling question rather than being
fixed unilaterally.

Owner ruling 2026-08-09, alert-and-advance plus the cadence cap, recorded FINAL in LEDGER
DECISIONS. Implemented in commit `301fc85`. The announcement moved out of `Clock.mqh` to the
caller because the cap needs the local clock and `TimeLocal` is forbidden in that file by its
own header and by the Stage 3 static acceptance row. Verified after the edit that `Clock.mqh`
and `Pnl.mqh` still contain zero `TimeLocal`, `TimeGMT` and `TimeTradeServer` references, and
that zero references to the removed `g_ag_anchor_waiting_on` survive anywhere in the tree.

Redeploy and recompile after the fix, all verified:

| File | md5, worktree and terminal, pairwise MATCH |
|---|---|
| `Include/AccountGuardian/Clock.mqh` | `31BAD26357DDF6E973DFAA1D49C337DB` |
| `Experts/AccountGuardian/AccountGuardian.mq5` | `EB646E20A17BF806C803C12A4C6878F4` |
| `Scripts/AccountGuardian/AgPhase1ClockVectors.mq5` | `8C815DC6CD6CA205D08E2437FC86FC3D` |

`Persist.mqh`, `Sweep.mqh`, `Log.mqh`, `Pnl.mqh` and `State.mqh` all re-verified unchanged.

```
AccountGuardian.mq5        Result: 0 errors, 0 warnings, 670 ms elapsed, cpu='X64 Regular'
AgPhase1ClockVectors.mq5   Result: 0 errors, 0 warnings, 420 ms elapsed, cpu='X64 Regular'
```

Fresh ex5 at 2026-08-09 19:10:59 and 19:11:01. Exit codes were 1 on both and are ignored per
standing rule 6.

## 5c. Relaunch 2 verification, the amended build in memory

Relaunch at 22:45:14, pid 11028. Journal sequence, verified from the file:

```
22:45:19.032  INFO|init|build=Phase1|account=1200252169|server=JustMarkets-Demo3
22:45:19.032  WARN|stale mutex heartbeat (287s), taking over crashed-instance mutex
22:45:19.033  INFO|mutex acquire|id_set=1|id_exists=1|hb_set=1|hb_exists=1|hb_value=1786315519
22:45:19.036  DEBUG|crash-loop check|chain=1/3 consecutive unclean, gap bound 300s
22:45:19.036  TRANSITION|BOOT->SYNCING|boot|weekly=on|timer=1s
22:45:19.036  INFO|timer armed|period=1s
22:45:20.045  LIFE|state=SYNCING|seconds_in_state=1|waiting_on=history stability poll not yet run this session
22:45:22.036  TRANSITION|SYNCING->ACTIVE|history stable|polls=3/3
22:45:50.027  LIFE|state=ACTIVE|seconds_in_state=28|waiting_on=-|anchor=2026.08.07 01:00:00|realized=0.00|floating=0.00|base=2003.46|limit=100.17|pnl_vs_limit=0.00 vs -100.17
```

Both fixes are proven live, each by the artifact that exposed the defect:

**Build label.** The init line reads `build=Phase1`. The same line read `build=Phase0` at
18:51:01 on the identical code path, so the field now discriminates the builds it is supposed
to discriminate.

**Rollover seeding.** A grep for `day rollover` across the WHOLE day's journal returns exactly
ONE line, the 18:51:05.197 spurious one from relaunch 1. Relaunch 2 emitted NONE. This is the
strong form of the check rather than the weak one: not "the line looked right" but "the line
that should not exist does not exist anywhere in the file", while its predecessor from the
unfixed build is still present three hours earlier for contrast. The next `day rollover` line
written on this account will therefore be a genuine one, which is what P1-A closes on.

Build identity, established on all three instruments standing rule 7 permits rather than on
the ex5 hash, which that rule forbids as identity:

- Source md5, deployed and verified pairwise against the worktree (section 5b table).
- ex5 modification timestamp: the loaded binary is `AccountGuardian.ex5` at mtime
  2026-08-09 19:10:59, md5 `AC19EAEA1A65E3C4D052E151C21502E9`, which is the post-amendment
  compile; MT5 loads from disk at attach.
- Runtime behaviour in the journal: `build=Phase1` present, spurious rollover line absent.
  Both are behaviours only the amended image can produce.

Cross-witnesses again independent of the narrative:

- Halt file 267 to 283 bytes, md5 `96440737734328DBE095BDC476898C83`, new record
  `S|1786315519|0`, 15 records, halt flag still `H|0||0`.
- `1786315519` in that record equals `hb_value` on the mutex-acquire line exactly.
- Stale-mutex age `287s` against kill 22:40:33 and init 22:45:19, which is 286 s of wall clock
  plus the up-to-one-second age the heartbeat already carried at the moment of the kill, since
  it refreshes on a 1 s timer.
- `chain=1/3` agrees with the backward walk over the file's own records: the newest three are
  unclean but the newest adjacent gap is 14058 s against the 300 s bound, so the walk stops at
  one. Three consecutive unclean records now sit in the file and the chain is still 1, which
  is the pairwise-gap primitive doing exactly what R1 specifies.

SYNCING exit timing replicated: 22:45:19.036 to 22:45:22.036 is 3.000 s for `polls=3/3` at the
1 s timer, against 2.993 s for the same transition on relaunch 1. The row is now observed
twice on two different builds rather than once.

The anchor still reads `2026.08.07 01:00:00` with `base=2003.46` and `limit=100.17`, unchanged
across a kill, a code change, a recompile and a relaunch, which is the restart-reconstruction
property P1-C asserts. P1-C is NOT claimed closed on it, because the row requires deals present
and this window has none; recorded as supporting evidence only.

## 6. Owner GUI reads, symbol session tables (Q7)

NOT DONE this session. Q7's ruling is that the read rides the owner's next terminal session
and that it is corroboration rather than a gate, blocking nothing. It is still owed, and the
A8 corroboration debt it also settles is still open.

## 7. Live rows, status after this session

| Row | Status | Basis |
|---|---|---|
| P1-M anchor sanity (Q8, amended) | CLOSED on synthetic evidence, live half standing | 26/26 vector run 22:30:07.433 including the Friday-to-Monday replay; run 1 retains the original build's halt-path record |
| P1-J SYNCING exit | CLOSED | `SYNCING->ACTIVE|history stable|polls=3/3` observed twice, 18:51:04.195 and 22:45:22.036, with the SYNCING LIFE line naming the live poll condition |
| P1-D zero-deal day | PARTIAL | `realized=0.00`, `pnl_vs_limit=0.00` and `floating=0.00` hold across 3 h 48 m of ACTIVE lines, so PnL equals floating and realized is zero. The `base = balance` half needs an owner reading of the account balance to confirm 2003.46; not read this session |
| P1-A first rollover | OPEN, unblocked | the spurious line is gone, so the next `day rollover` line is genuine. It arrives at the Monday reopen, not at a local midnight, because the server clock is frozen |
| P1-B weekend absorption | OPEN | needs a full weekend harvest; this session observed only the held-Friday half |
| P1-C restart reconstruction | OPEN | needs deals present; the zero-deal invariance above is supporting evidence only |
| P1-E, P1-F, P1-G | OPEN | need a personal-area deposit |
| P1-H, P1-I, P1-L, P1-N | OPEN | need manual trades |
| P1-K, P1-O | OPEN | need a deliberate disconnect |

### The Monday reopen is the standing live test, and it now tests three rows at once

At the reopen `TimeCurrent` steps from the frozen `2026.08.07 23:57:59` to about
`2026.08.10 01:00:20`, and the anchor advances from Friday `2026.08.07 01:00:00` to Monday
`2026.08.10 01:00:00`, a jump of 259200 s. Expected, and all four points are falsifiable:

1. Exactly ONE ALERT naming both anchors, `previous_high=2026.08.07 01:00:00`,
   `accepted=2026.08.10 01:00:00`, `jump=259200s`, cadence-capped so it cannot repeat inside
   30 s, and in practice not repeating at all because the condition clears on the same pass.
2. The matching INFO line carrying the same note.
3. A genuine `day rollover` line, `old_anchor=2026.08.07 01:00:00`,
   `new_anchor=2026.08.10 01:00:00`, `jump=259200s`, which is P1-A's artifact.
4. The next ACTIVE LIFE line computing fresh against the Monday anchor, with `waiting_on=-`
   and the note gone.

On the ORIGINAL build the same instant would have produced an unbounded 1 Hz popup, no
rollover line, and a window pinned to Friday until restart. That contrast is what makes the
reopen a real acceptance test rather than a formality.

## 8. Close-out

Deploy, compile, vectors and relaunch rows are closed on the artifacts above. The branch
carries the work; nothing is merged and nothing is pushed. The running instance stays running
at session end, carrying the amended build, so the reopen is observed rather than staged.

## 6. Owner GUI reads, symbol session tables (Q7)

PENDING, owner GUI action.

## 7. Quick live rows

PENDING.

## 8. Close-out

PENDING.
