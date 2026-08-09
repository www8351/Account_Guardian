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

## 4. Clock vectors, P1-M evidence

PENDING, owner GUI action.

## 5. Kill and relaunch

PENDING, owner GUI action.

## 6. Owner GUI reads, symbol session tables (Q7)

PENDING, owner GUI action.

## 7. Quick live rows

PENDING.

## 8. Close-out

PENDING.
