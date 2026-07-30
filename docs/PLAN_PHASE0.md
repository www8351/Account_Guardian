# Phase 0 Completion Plan

Planner output, 2026-07-30, amended same day with the owner's evidence discipline additions. Captured in the repo as docs/PLAN_PHASE0.md; that copy is the governance record the execution is measured against. Executor: a Sonnet session running on auto. Deliverable: all remaining Phase 0 acceptance rows (A1 through A10) closed with named evidence, ledger current, minimum owner contacts.

Stage order assertion, confirmed on owner request: Stage 1 (overnight evidence backup, decode, harvest) strictly precedes the first test that writes the halt file (Stage 3a). Stage 2 writes only .set files under MQL5\Presets, which no init path reads unprompted and which are not lock or halt artifacts.

## Context

Phase 0 skeleton is built and deployed. Static rows S1, S2, S3, C1 are PASS. Ten attach rows are pending. A SAFE_HALT bypass was found by source read: on build 694d570, OnDeinit after a refused OnInit writes a never loaded halt model over halt_1200252169.dat, erasing session records and enabling a false RESUMED_FROM_SAFE_HALT. The fix is committed at 72ed960 but deliberately not compiled or deployed: the owner's sequence requires demonstrating the bug against 694d570 first. The machine also shut down uncleanly overnight (2026-07-29/30) while the EA was attached, leaving fresh evidence in the halt file that must be preserved before any test writes it.

## Binding rules for the executor

1. Read LEDGER.md in full before starting. Every DECISIONS entry marked FINAL is a hard constraint. Never reopen, reframe, or argue against one.
2. Builds are identified by commit hash only: 694d570 (deployed at start, unfixed) and 72ed960 (fixes committed, not deployed at start). Never "old build" or "new build".
3. Prove the SAFE_HALT bypass against 694d570 before deploying 72ed960. Never reorder this.
4. Kill sequencing: at least AG_MUTEX_STALE_SECONDS + 5 = 15 seconds between process death and relaunch (constant is 10 s at Persist.mqh:18). Use 20 s. A faster relaunch produces a mutex refusal, and on 694d570 a refused init erases the halt file.
5. Never launch the terminal through scripts/agtest.ps1 Start-Terminal or Invoke-AgRun. The /config startup attach path is defective, cause unknown, frozen, and its diagnosis is out of scope. Relaunch is always a plain `Start-Process "C:\Program Files\MetaTrader 5\terminal64.exe"`. The EA restores from the saved chart profile. Stop-Terminal, Get-AgLogMark, Get-AgLogSince from that script are usable.
6. The executor never deletes and never overwrites a lock artifact or a halt artifact, for any reason, including cleanup between rows. Absolute in auto mode. The single sanctioned halt file deletion in the whole matrix is A6, performed by the owner's hand. When a row requires the halt file to change, the executor backs it up first with a fresh md5 and keeps every backup, labelled by event. Restoring a backup over the halt file counts as an overwrite and gets the same treatment: back up the current file first.
7. Standing observation rules (FINAL): external reads of bases\gvariables.dat are never evidence while the terminal runs; F3 dialog readings are admissible only as open, read, fully close, wait, reopen, read; absence of log output is evidence only after verifying the emitting line is unsuppressed at the active verbosity. Relevant verifications already done at planning time: the takeover line routes through AgWarn (Log.mqh:28, unsuppressed at NORMAL); the crash loop count line routes through AgVerbose and IS suppressed at NORMAL, so never infer counts from its absence, decode the halt file instead.
8. Hard stops that halt the entire sequence: any row fails, any behavior contradicts a FINAL decision, anything needs an unplanned SPEC amendment, or any situation whose only way forward would delete or overwrite a lock or halt artifact outside rule 6. On hard stop: preserve evidence, write the ledger, contact the owner. The planned rulings R1 through R4 below are not hard stops, they are scheduled gates.
9. Ledger sync at the end of every stage: dated ACTIONS entry (newest first, append only), ISSUES updates, matrix row states. English only. No em dashes and no hyphens as stylistic separators in prose, docs, or commit messages. Commit after every meaningful change. Never push. Phase 1 work and the frozen harness diagnosis are out of scope.
10. The executor never escalates a question it can answer from disk, logs, or source. A row is never marked green unless the named evidence exists on disk at the stated path; no row closes on reasoning alone. Every closed row's ledger record carries three things: the result, the commit hash of the build it ran against, and the evidence pointer.

## Key paths and facts

- Data dir: `%APPDATA%\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075`
- Halt file: `<DataDir>\MQL5\Files\AccountGuardian\halt_1200252169.dat`
- EA journal: `<DataDir>\MQL5\Logs\YYYYMMDD.log` (Unicode); terminal journal in `<DataDir>\logs\`
- Existing backup: `docs/evidence/halt_1200252169.dat.pretest-2026-07-29`, md5 0f40c49bc67a3767b22b9491910e1ade. It PREDATES the overnight shutdown. Never restore it over post shutdown state. Both backups are kept, labelled by event.
- Account 1200252169, JustMarkets-Demo3, demo confirmed. Chart XAUUSD.ecn M1.
- Halt file layout: derive it from AgHaltSave/AgHaltLoad in Persist.mqh before decoding. Session timestamps are naive local epoch seconds (clock exemption, FINAL).
- Takeover line, exact source string: `stale mutex heartbeat (` N `s), taking over crashed-instance mutex` (Persist.mqh:263).
- Fix 1 skip line: `deinit|halt file NOT written: the halt model was never loaded this session` (AccountGuardian.mq5, 72ed960 only).
- AgValidateLimits (Pnl.mqh:37) rejects non finite, negative, and percent above 100, so A9 expectations are grounded in source.

## Classification of all pending work

| Item | Class | Note |
|---|---|---|
| A1 second attach refuses | GUI | owner attaches a second chart |
| A2 stale mutex takeover after kill | AUTO | overnight harvest is supporting evidence only, deliberate run still required |
| A3 crash loop by hard kills | AUTO run, gated on RULING R1/R2 | fed by AUTO cycle measurement |
| A4 SAFE_HALT survives restart | AUTO | immediately after A3 |
| A5 SAFE_HALT closes nothing | AUTO record | PASS-BY-CONSTRUCTION, carries to Phase 3 |
| A6 manual resume via deletion | GUI | owner deletes the halt file |
| A7 clean re-inits do not accumulate | AUTO | repeated recompile of identical deployed source |
| A8 timer with market closed | WINDOW | needs 15 min or more with no ticks; requires 72ed960 (Fix 2) |
| A9 input matrix | GUI | owner loads prepared .set files; both zero row lands at contact 1 |
| A10 transition lines match SPEC sec 6 | AUTO | journal audit over all runs |

Rulings (owner decisions, never assumed by the executor):

- R1: crash loop primitive, time window versus N consecutive unclean sessions.
- R2: CrashLoopWindowSeconds default, if the window primitive is kept.
- R3: server offset. First audit recorded broker GMT+3; later evidence says server UTC, machine UTC+3. Load bearing: the day anchor is broker server midnight and Q7 rests on it. Resolve by measurement, owner ratifies the correction.
- R4: whether a second refusal row demonstrates the bypass with a malformed but nonzero core input in addition to both limits zero.

Owner contacts planned: exactly three (contact 1 GUI plus rulings R3/R4, contact 2 ruling R1/R2, contact 3 GUI). A8 needs no owner, only a calendar window.

---

## Stage 1: Evidence preservation and overnight harvest (AUTO)

Preconditions, verify from disk:
- `git rev-parse HEAD` is 72ed960; working tree clean except CLAUDE.md.bak-20260728-132146.
- Pretest backup present with md5 0f40c49bc67a3767b22b9491910e1ade.
- Deployed source in `<DataDir>\MQL5` matches `git show 694d570:` for AccountGuardian.mq5 and all six .mqh files. If it matches 72ed960 the ordering constraint is already broken: hard stop. If it matches neither: hard stop.

Work, in order:
1. Check terminal64 process state and StartTime. Do not launch or kill anything yet.
2. Back up the halt file to `docs/evidence/halt_1200252169.dat.post-shutdown-2026-07-30`. Compute md5 (Get-FileHash -Algorithm MD5). Record it. Keep the pretest backup untouched.
3. Decode the halt file using the layout read from Persist.mqh. Write hex dump plus a decoded session table to `docs/evidence/halt_1200252169.post-shutdown-decode.md`.
4. If the terminal is not running, plain launch it now (backup already taken; the new session record it appends is expected and harmless). If it is running, note the uptime and whether it started after the overnight shutdown.
5. Harvest the takeover evidence: search `<DataDir>\MQL5\Logs\20260730.log` (and 20260729.log) for `stale mutex heartbeat` lines. If the launch in step 4 just happened, search after it settles.
6. Measure the server offset for R3: capture local wall clock and the newest journal line timestamp inside the same second window; the difference is the offset. Cross check against the decoded overnight session record (local epoch seconds) for the same init. Record as measurement, not conclusion.
7. Record hygiene item: append `CLAUDE.md.bak*` to .gitignore. Do not delete the file. Commit.
8. Ledger: ACTIONS entry for the overnight event and harvest; update the halt evidence ISSUES entry. Commit.

SELF-CHECK before exiting the stage:
- Both backups exist with distinct md5s. If the post shutdown md5 EQUALS the pretest md5, the file has not changed since 2026-07-29 despite later sessions having run, which contradicts the known write path: stop and investigate before proceeding.
- Decode interpretation, two legitimate branches:
  - Last overnight record unclean: unclean death confirmed. A takeover line is then expected at the first post shutdown start.
  - Last overnight record clean: Windows closed the terminal gracefully before power off, OnDeinit ran, mutex was zeroed. No takeover line will exist. This is a valid outcome: record it, downgrade the delta 2 harvest to "no evidence produced", do not escalate, do not force it. A2 still gets its deliberate run.
- Takeover line interpretation: present means A2 supporting evidence, quote the line verbatim with file and timestamp. Absent while the last record was unclean AND a post shutdown start has occurred is an anomaly that contradicts F8 expectations: hard stop with evidence. Absent because no start has occurred yet: check again after step 4's launch.
- Offset measurement recorded with arithmetic shown.

Exit gate: AUTO, continue to Stage 2.

## Stage 2: Contact 1 preparation (AUTO)

Work:
1. Prepare A9 .set files in `<DataDir>\MQL5\Presets` (ASCII, key=value): a9_both_zero, a9_neg_percent (DailyLossPercent=-5), a9_neg_currency (DailyLossCurrency=-100), a9_percent_over_100 (150), a9_sweep_zero (SweepPeriodSeconds=0), a9_sweep_over (SweepPeriodSeconds=9), a9_crash_max_zero (CrashLoopMaxInits=0), a9_window_zero (CrashLoopWindowSeconds=0), a9_polls_zero (HistoryStablePolls=0), a9_nonfinite (DailyLossPercent=nan), a9_optional_bad (LogVerbosity=99), a9_defaults (all defaults). Note in the briefing: whether MT5 parses the literal `nan` from a .set into a true NaN is unverified; the SPEC names the .set route as the vector, so run it and record the actual behavior. If it degenerates to 0.0 the row collapses into the both zero row; record that honestly.
2. Write the contact 1 briefing: the exact owner click sequence (below), the expected journal evidence per step, ruling R3 (present the Stage 1 measurement, the two candidate readings, one line recommendation, and note the environment audit entry to be corrected), ruling R4 (options: yes, one extra dialog demo at contact 1, or no; one line recommendation; nothing else is blocked by it), and the request to read the XAUUSD.ecn specification session and break times, in server time, from the Symbols window.
3. Ledger and commit.

SELF-CHECK: every planned owner action has a named expected journal line; both rulings carry measurement, options, a one line recommendation, and a blocked list; .set files exist and re-read correctly.

Exit gate: GUI. Contact the owner for contact 1.

## Stage 3: Contact 1 (GUI batch, owner at the terminal, executor verifying live)

Order is fixed. The executor verifies each step's evidence before the owner moves on.

3a. Step 1, bypass proof against 694d570:
- Executor: Get-AgLogMark, record current halt file md5.
- Owner: EA properties dialog on the live chart, set DailyLossPercent = 0 AND DailyLossCurrency = 0, click OK.
- Expected: ALERT `refusing to run, core config invalid`, deinit line with reason=8, and the halt file rewritten to an empty model: zero session records, halt flag 0, md5 changed.
- Executor verifies and records: quoted lines, fresh decode, before and after md5s. This is the bypass DEMONSTRATED. Note: the refusal unloads the EA from the chart; that is expected.
- If R4 was ruled yes: owner repeats once with a malformed but nonzero core input (load a9_sweep_over). Same expectations. Then continue.
- Executor: first back up the post demo halt file (the erased, zero record one) to `docs/evidence/halt_1200252169.dat.bypass-demo-2026-07-30` with its md5, it IS the bypass evidence; then restore the halt file from the POST SHUTDOWN backup (never the pretest one) and verify md5 equals that backup.

3b. Deploy 72ed960 (AUTO while the owner waits):
- Working tree is 72ed960: copy AccountGuardian.mq5 and the six includes into `<DataDir>\MQL5`. Compile with the same metaeditor64 /compile invocation that produced the C1 PASS. Require `0 errors, 0 warnings`. Verify the .ex5 timestamp is fresh.

3c. Fix proof, config refusal path, against 72ed960:
- Owner: re-attach the EA, load a9_both_zero, OK.
- Expected: same ALERT refusal, deinit reason=8, PLUS the INFO skip line `halt file NOT written: the halt model was never loaded this session`, and the halt file md5 UNCHANGED (still equal to the post shutdown backup).
- Executor verifies. Fix 1 proven on the config path. A9 both zero row green.

3d. Healthy attach:
- Owner: re-attach with a9_defaults, OK.
- Expected: init, BOOT->SYNCING transition, `timer armed` INFO, LIFE lines now carrying TimeCurrent and TimeLocal (Fix 2 visible). Capture one LIFE line for the R3 cross check.

3e. A1, second attach:
- Owner: open a second chart, attach AccountGuardian, OK.
- Expected: ALERT `refusing to run: another AccountGuardian instance is live on account 1200252169`, REFUSED banner on the second chart, first instance's LIFE cadence uninterrupted, halt file md5 unchanged, INFO skip line again (fix proven on the mutex refusal path too).
- Owner removes the second chart's EA. A1 green.

3f. Owner reads the XAUUSD.ecn specification (Symbols window) and reports quote and trade session times verbatim. Executor records them in the ledger as server time figures.

3g. A9 remainder, in this same visit if the owner has time (preferred, it removes work from contact 3): owner loads each remaining .set in sequence. Per core row: refusal ALERT naming the offending input (strings per AgValidateLimits and the OnInit checks), INFO skip line, halt file untouched. For a9_optional_bad: WARN `optional config invalid: LogVerbosity unrecognised`, init PROCEEDS. After the last row, owner re-attaches a9_defaults.
- Executor verifies each row before the next .set is loaded. If deferred, A9 remainder moves to contact 3.

3h. Executor closeout: verify a healthy instance (SYNCING, LIFE cadence), write ledger (A1 green, A9 rows green or carried, R3 and R4 recorded in DECISIONS as owner rulings), commit per meaningful chunk.

SELF-CHECK: every green row has quoted journal evidence plus an md5 trail; the running instance is healthy on defaults; the bypass demo and both fix proofs are in the ledger with evidence. A missing expected line means stop and check the emission path in source first (standing rule); escalate only what evidence cannot answer.

Exit gate: AUTO if all verified, else hard stop.

## Stage 4: A2 deliberate run, A7, A3 calibration (AUTO)

Preconditions: 72ed960 deployed and live, healthy instance, halt baseline md5 recorded.

4a. A2:
- Get-AgLogMark. Hard kill (Stop-Process -Force). Wait 20 s. Plain relaunch. Wait for init.
- Expected: WARN `stale mutex heartbeat (Ns), taking over crashed-instance mutex` with N of roughly 20 or more, then a successful init and BOOT->SYNCING, LIFE resumes. Halt decode: the killed session's record stays unclean, a new record appended.
- A2 green (deliberate run), with the Stage 1 overnight harvest attached as supporting evidence only if it was actually found.

4b. Cycle measurement for R1/R2:
- Two more kill cycles, spaced MORE than 60 seconds apart. Reason: the unclean count includes the live session; back to back cycles stack unclean records inside the 60 s window and could trip SAFE_HALT prematurely, contaminating A3. Spacing above the window caps the in-window count at 2 against a trip threshold of more than 3.
- Per cycle record: kill timestamp, relaunch timestamp (gap 20 s enforced), init line timestamp. Cycle time = init to init minimum achievable.
- Compute the minimum window W in which 4 unclean inits (3 killed plus the tripping live one) can land by real kills: W = 3 x cycle_min plus margin. This number is the R1/R2 measurement.

4c. A7:
- With the healthy instance running, recompile the deployed 72ed960 source in place, byte identical, 4 times in tight succession. Each recompile forces a clean deinit and re-init. Verify each init line and each `session marked clean` deinit line.
- Evidence: halt decode showing 4 or more records marked clean inside the observed span, and NO SAFE_HALT transition line in the journal (admissible absence: the transition line is unsuppressible by design). Do not rely on the crash loop check line, it is verbose suppressed.
- If SAFE_HALT trips here, clean records are accumulating as unclean: that is a real A7 FAILURE, hard stop.
- A7 green. Record the actual re-init spacing achieved.

4d. Ledger, commit, then write the R1/R2 briefing for contact 2:
- The measurement table and W.
- Option A: keep the window primitive, raise the CrashLoopWindowSeconds default to a value covering W (input default change, SPEC input table amendment).
- Option B: change the primitive to N consecutive unclean sessions, no window. Structurally immune to slow relaunches and to the clock compression residual already accepted in the threat model. Larger delta: counting logic, SPEC A1 amendment wording, input retirement.
- Option C: keep the 60 s default and test A3 only at a dialog set window (600 s diagnostic fallback, already withdrawn as a real default by the owner, kept as diagnostic only). Include for completeness.
- Exactly one recommendation, one line, chosen from the measurement.
- Blocked until ruled: A3, A4, A6 (A4 and A6 consume the SAFE_HALT that A3 produces).

SELF-CHECK: A2 evidence quoted; three cycle data points with arithmetic; A7 decode archived to docs/evidence; no unintended SAFE_HALT; a healthy instance left running.

Exit gate: RULING. Contact 2 (message only, the owner is not needed at the terminal).

## Stage 5: Implement the ruling, A3, A4, A5 (AUTO after the ruling)

Precondition: R1/R2 ruled, recorded in DECISIONS, owner sourced.

5a. If the ruling changes code or SPEC: implement exactly the ruled option, add the dated owner attributed SPEC amendment, compile to 0 errors 0 warnings, deploy, commit. This amendment is scheduled, not a hard stop.

5b. A3: hard kill cycles at the fastest cadence the 20 s gap allows, per the ruled primitive, until the trip init. Expected trip: the init where the unclean count exceeds CrashLoopMaxInits under the ruled arithmetic (under the current window primitive that is the 4th init: 3 killed sessions plus the live one). On trip: SAFE_HALT transition line, ALERT, halt flag persisted to file and GV, halted banner, LIFE lines continue in SAFE_HALT (amendment A3). Verify the arithmetic against the halt decode; a mismatch between the decode count and the trip point is a row failure, hard stop. A3 green.

5c. A4: with SAFE_HALT active, restart once more. Prefer a graceful close (`taskkill /IM terminal64.exe` without /F) to also show a CLEAN exit does not clear the halt; if it does not exit within 30 s, hard kill and note the variant. Wait 20 s, plain relaunch. Expected: `SAFE_HALT persists across restart` transition and ALERT, halted banner, timer armed, halt decode shows flag still set. The row's core claim is survival across restart; the graceful variant is a bonus observation, never a failure cause by itself. A4 green.

5d. A5: record PASS-BY-CONSTRUCTION. Evidence: S1/S2 static greps (no trade API in the build) plus the journal across the whole SAFE_HALT period showing zero close or sweep attempts. Annotate in the matrix: carries forward as a real row to the Phase 3 sweep matrix. This is record hygiene item 1.

5e. Leave the EA in SAFE_HALT deliberately: A6 requires it. Ledger, commit, prepare the contact 3 briefing (exact A6 procedure plus the A9 remainder if any).

SELF-CHECK: SAFE_HALT evidence complete (transition, ALERT, decode with flag set, LIFE lines while halted); A4 restart evidence; trip arithmetic shown; the EA is still halted.

Exit gate: GUI. Contact 3. (If the A8 calendar window arrives first, Stage 7 may run before Stage 6; the two are independent. A8 does not need the halted state and SAFE_HALT does not stop the timer, but prefer running A8 on a healthy instance; if scheduling forces A8 while halted, note the state on every LIFE line and proceed, the row measures timer cadence, not state.)

## Stage 6: Contact 3 (GUI): A6, then A9 remainder

6a. A6, the documented manual resume:
- Executor: stop the terminal (the procedure requires the EA stopped). Record the halt md5.
- Owner: deletes `<DataDir>\MQL5\Files\AccountGuardian\halt_1200252169.dat` by hand. The executor never touches it.
- Executor: wait 20 s, plain relaunch. Expected: init finds no halt file while GV AG_HALT_1200252169 reads 1, logs `RESUMED_FROM_SAFE_HALT`, clears the GV, seeds a fresh halt file with the current session, transitions BOOT->SYNCING, healthy.
- Negative control: cite A4 (a restart WITHOUT deletion stayed halted) as the "only via deletion" half of the row. A6 green.

6b. A9 remainder, if any survived contact 1: run the remaining .set rows exactly as in 3g, ending on a9_defaults.

6c. Verify healthy instance on defaults. Ledger, commit.

SELF-CHECK: RESUMED line quoted; GV behavior evidenced from the EA's own journal lines, never from gvariables.dat; every A9 row has its named line; final state healthy.

Exit gate: WINDOW if A8 still open, else AUTO to Stage 8.

## Stage 7: A8, timer with the market closed (WINDOW, then AUTO)

Preconditions: 72ed960 live (Fix 2 is what makes this row measurable), XAUUSD.ecn session times recorded at contact 1, R3 offset measurement recorded.

- Compute the no tick window in LOCAL time from the spec's server time schedule plus the measured offset. Require at least 15 contiguous minutes without ticks. If the daily break is shorter than 15 minutes, use the weekend: Friday close 2026-07-31 into Saturday. Never assume the schedule, use the recorded spec figures.
- Before the window: confirm a healthy instance and LIFE cadence.
- Across the window: collect 30 or more LIFE lines (30 s interval). Expected: unbroken cadence; TimeCurrent on the LIFE line frozen or crawling while TimeLocal advances; seconds_in_state advancing by wall clock.
- Independent second measure: after the window, restart and read the deinit line's timer_ticks against session wall seconds (about one tick per second).
- The frozen TimeCurrent against advancing TimeLocal also closes R3 empirically; add it to the R3 measurement record in the ledger.

SELF-CHECK: count the LIFE lines in the journal across the window; spacing 30 s within tolerance; any gap above 60 s is a timer stall and a row FAILURE, hard stop. Verify the no tick premise itself before claiming anything: if ticks flowed (schedule misread), the run is void, reschedule, do not claim the row.

Exit gate: AUTO.

## Stage 8: A10 and closeout (AUTO)

- A10: collect every transition line from every run in Stages 1 through 7 (per stage journal marks were recorded). Verify against SPEC section 6: exactly one structured line per transition carrying timestamp, from state, to state, reason, and the governing numbers where relevant; mandated Alert popups present (SAFE_HALT, refusals); LIFE lines never suppressed. Any deviation is a row failure, hard stop (fixing it would need a SPEC measure or a code change, either way an owner decision).
- Journal secrets scan (section 6 dormant clause): grep the collected excerpts for anything credential shaped. Cheap, do it, record the null result.
- Record hygiene checklist, verify each item landed and land whatever is missing:
  1. A5 annotated in the ledger matrix as PASS-BY-CONSTRUCTION, carried to Phase 3.
  2. AG_MUTEX_STALE_SECONDS = 10 as a deliberate non input: the DECISIONS entry was sighted at planning time; confirm it is present and committed.
  3. The SAFE_HALT bypass in the SPEC threat model with the general never loaded never written obligation: sighted in SPEC section 9 at planning time; confirm present and committed, and move the bypass ISSUES entry to ACTIONS as DONE with the demo plus fix proof evidence.
  4. CLAUDE.md.bak-20260728-132146: ignored via .gitignore in Stage 1; confirm, and note it in the ledger.
- Update the matrix to final states with evidence pointers. Close the step 1 blocker entry and the A8 clock entry (DONE, with the R3 ruling reference).
- Final ledger entry and commits. Nothing pushed.

## Definition of Done, Phase 0

Phase 0 is done when every line below holds with evidence on disk:
- S1, S2, S3, C1 PASS (already logged).
- A1, A2, A3, A4, A6, A7, A8, A9, A10 green, each with quoted journal evidence, and halt file decodes plus md5 trails in docs/evidence where the row touches the halt file.
- A5 recorded as PASS-BY-CONSTRUCTION and explicitly carried to the Phase 3 matrix.
- The SAFE_HALT bypass demonstrated against 694d570 and proven fixed on 72ed960 on both refusal paths, config and mutex.
- R1 through R4 recorded in DECISIONS as owner rulings; any resulting SPEC amendment dated and applied; FINAL markings only by the owner.
- Both halt file backups retained, labelled by event; no lock or halt artifact deleted by the executor at any point; the single A6 deletion performed by the owner and logged.
- LEDGER.md current in all three sections, all work committed locally, nothing pushed.

## What remains after Phase 0

Phase 0 green means the skeleton is trustworthy: single instance enforcement, crash halt, timer spine, logging, and persistence hygiene all hold under kills and refusals. The guardian still protects nothing. Phase 1 builds the PnL engine with the deposit neutrality acceptance test, rollover, and restart reconstruction. Phase 2 builds the lock itself: breach detection, derived lock defense, corruption policy, and the clock drills. Phase 3 builds the sweep engine, where A5 finally gets its real test. Phase 4 adds weekly reporting. After all four matrices, the Definition of Done still requires the controlled breach drill on demo through a real rollover, the full bypass drill suite, and the one week demo soak with daily reconciliation against the broker statement. Only after all of that does live come up for discussion.
