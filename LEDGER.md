# LEDGER

## ISSUES

Issue:  RESOLVED, and it supersedes the hard stop below. The SAFE_HALT bypass is DEMONSTRATED against 694d570. At 22:26:37 a fresh Navigator attach inherited the both-zero inputs MT5 retains as last-used, refused on the config check, and its OnDeinit wrote a default-constructed model over the halt file: six session records reduced to zero, then reseeded by the next healthy attach at 22:26:54. Nobody staged it, and no evidence was lost, because the pre-state was already backed up, the journal recorded it, and the post-state proves the wipe. The discriminator is measured rather than argued: the erasing refusal logged timer_armed=0 and timer_ticks=0, an image whose globals had never been touched, while the harmless 22:35:29 input-edit refusal logged timer_armed=1 and timer_ticks=514 in an inherited running image, same inputs and same alert text, opposite consequence. Evidence: docs/evidence/bypass-demo-2026-07-30.md addendum, backups halt_1200252169.dat.after-config-refusal-2026-07-30 (pre, md5 3209ABA4) and halt_1200252169.dat.post-erasure-reseeded-2026-07-30 (post, md5 3A98CFF4). Erasure half only, per the standing scope limit.
Action: The re-sequencing ruling the entry below asks for is no longer needed for the config path. 72ed960 deployed and compiled at 22:39:30, 0 errors 0 warnings, but the running instance still carries the 694d570 image because MT5 does not hot-reload an externally recompiled .ex5, so the fix proof needs a removal and a fresh attach. The SPEC threat-model wording was ruled by the owner on 2026-07-30 and applied to section 7 and to the section 9 threat-model addition: erasure requires a refusal inside a fresh program image, a refusal in an inherited image is harmless, the timer_armed and timer_ticks discriminator is stated in the wording so the boundary stays testable, the fresh-image routes are enumerated, and the original trigger sentence is kept because it was always the fresh-load case.
Status: DONE

Issue:  Fresh-load audit, ordered by the owner and delivered in docs/evidence/bypass-demo-2026-07-30.md. Governing rule, now measured: an input-change re-init reuses the loaded image and its globals survive, while a fresh attach, a recompile, and a terminal restart all reset globals, and MT5 seeds a fresh attach from last-used inputs that persist across restarts via the chart profile. Exposed rows: A1 (a malformed second chart refuses at the config check before ever reaching the mutex, testing nothing), A2, A3, A4, A6 and A7 (all restore inputs from the chart profile, and since AgHaltAppendSession sits downstream of every refusal return, a malformed profile makes crash counting unable to accumulate at all), A8 (only through its starting attach), and A9 in the opposite direction: a malformed row driven by editing a RUNNING instance inherits a populated model, so the fix's skip branch never executes and the row proves the refusal without proving the fix.
Action: Adopted for the rest of the matrix: every attach instruction names the exact input values to confirm before OK, the executor takes the halt baseline BEFORE the attach rather than after, and each A9 row runs as a fresh load beginning from a removal.
Status: FINAL

Issue:  SUPERSEDED by the entry above, kept for the record. HARD STOP, contact 1 halted after step 2. The bypass demonstration did not reproduce, and the reason narrows the bypass itself. On 694d570 the owner set both daily limits to zero in the properties dialog at 22:08:42; the refusal fired verbatim as predicted, but the halt file was NOT erased: all six session records survived and record 6 flipped clean=0 to clean=1, the legitimate outcome of the outgoing session's clean deinit. Measured cause: timer_ticks=40714 is identical in the reason=5 deinit and the reason=8 deinit, so the program image was never unloaded between them. An input change runs OnDeinit then OnInit inside the same loaded program, globals intact, so the refused init inherited the model loaded at 10:50:08 and the unconditional AgHaltSave wrote a POPULATED model rather than a default-constructed one. Erasure requires genuinely fresh globals, which means a fresh program load that then refuses. Evidence: docs/evidence/bypass-demo-2026-07-30.md, backup halt_1200252169.dat.after-config-refusal-2026-07-30 md5 3209ABA485948D39872B0181C06BE2D6. The SPEC threat-model trigger sentence (attach a second instance, let the mutex refuse it) is the fresh-load case and stands; what is measured false is the ledger's framing of a properties-dialog edit as a demonstration vector.
Action: Owner ruling needed on two things before the batch resumes. First, the re-sequencing: demonstrate the erasure on 694d570 via a genuine fresh-load refusal, either a second-chart mutex refusal (the SPEC's own trigger, and A1's setup) or an EA removal followed by a fresh Navigator attach carrying a malformed core input. Second, the wording precision in the SPEC threat model and in the bypass ISSUES entry, which is a SPEC change and therefore owner-ruled. The live halt file was deliberately NOT restored from backup: nothing was destroyed, and record 6's new clean flag is information a restore would overwrite.
Status: BLOCKED on owner

Issue:  Dependency logged 2026-07-30 by owner order, before it can surprise the matrix. All twelve a9_*.set vectors encode CrashLoopWindowSeconds=60, which is correct against the currently deployed builds and is accepted for tonight because no crash-loop row runs. The moment the ruled 300 default lands with the R1 implementation, every vector is stale. Regenerating them is not enough on its own: a running terminal never enumerates files added to its data folder after it started, so the regenerated vectors stay invisible until a restart.
Action: Folded into plan Stage 5a as step 5a-bis, in order: implement the ruled primitive, regenerate all twelve vectors against the new default, then restart the terminal, taking that restart from the first A3 kill cycle rather than spending a separate one. Visibility verified in the Load browser before any A9 row runs.
Status: OPEN

Issue:  Executor error, logged for symmetry with the owner-side errors recorded this round. Having just delivered the fresh-load audit naming last-used-input persistence as the hazard behind six acceptance rows, the executor then failed to apply it to the end state of the night: a bad-input attach leaves last-used at both zero, so an overnight terminal relaunch could restore a refusing EA and collect nothing for A8. The owner caught it. The corrected sequence keeps a healthy instance running on the first chart throughout by running the fix proof on a second chart, and ends by resetting last used back to the defaults.
Action: Standing lesson: an audit is not applied until it has been walked forward to the state the system is left in, not just the state each step passes through.
Status: FINAL

Issue:  RESOLVED, preset visibility, reopened and re-closed with the correct cause on the owner's correction. The twelve a9_*.set vectors were written at about 12:47 to the terminal Presets folder while the terminal had been running since 10:50:03, so that process never enumerated them and the Load browser did not list them. The terminal was incidentally restarted later during the owner's own preset check, pid changing 4068 to 9056, and the new process enumerated the folder at startup, after which all 23 files including the ten AG_*.set from the deleted prior project were visible and selectable. Cause: startup enumeration, settled by the incidental restart.
Action: The executor's startup-scan explanation was correct and the owner's NOT A DEFECT framing is STRUCK. The counter-argument that a Windows file dialog reads the directory live is sound in isolation but was applied to a dialog already running post-restart, so it proved nothing about the pre-restart state. Logged plainly at the owner's instruction as the third owner-side error this round, alongside the withdrawn item 0 accusation and the superseded "23:45" market-close figure. Operational consequence for the rest of the matrix: files written into the terminal data folder are not visible to an already-running terminal, so any future vector, preset, or profile must be written before a start or verified after one. Encoding is eliminated as a visibility cause and remains untested for parsing until a loaded vector is seen in the grid.
Status: DONE

Issue:  SUPERSEDED by the entry above, kept for the record. A9 vector delivery is broken. The twelve a9_*.set files are on disk in the terminal Presets folder, the same folder holding ten AG_*.set files from the deleted prior project, but they do not appear in the EA properties Load browser. Terminal has run since 10:50:03 and the files were written about 12:47, after that start.
Action: Diagnose before the A9 rows run, per owner instruction, do not fix yet. Discriminator: whether the pre-existing AG_*.set files appear in that same browser. If they do, it is a startup enumeration or refresh problem and a terminal restart settles it. If they do not, the dialog opens elsewhere. Third candidate: these files are ASCII while MT5 writes .set as UTF-16LE, so a re-save is the cheap fallback. If none works, A9 degrades to twelve manual input edits and the batch needs re-planning.
Status: OPEN

Issue:  SAFE_HALT BYPASS, found by source read on 2026-07-29 before any acceptance row ran. OnDeinit runs after a refused OnInit (reason 8) and saved the halt model unconditionally at AccountGuardian.mq5:234. On that path AgHaltLoad never executed, so the model was default-constructed empty, and writing it erased all session records and cleared the persisted halt flag on disk. GV AG_HALT_<login> still read 1, so the next init saw GV-set against file-clear and logged RESUMED_FROM_SAFE_HALT: a malfunctioning guardian back in service with no human act, violating the manual-restart-only ruling. Trigger needs no privilege: attach a second instance and let the mutex refuse it. Every config-refusal return at AccountGuardian.mq5:92-113 reaches the same path, so the A9 input matrix would have destroyed evidence too. Blocks A1, A2, A3, A4, A6, A9. Classified as a bypass, not data loss.
Action: Fixes written, not yet compiled or deployed, pending step 1 of the owner's sequence which must demonstrate the bug against the unfixed build first. Fix 1: g_ag_halt_loaded in Persist.mqh, set at every exit of AgHaltLoad, checked in OnDeinit, with an INFO line on the skip so it is never silent. Gating on g_owns_mutex was rejected as conflating mutex ownership with model validity, and it would have masked the config-refusal case. Fix 2 (A8, same build): TimeCurrent and TimeLocal on the LIFE line. Recorded in the SPEC threat model with the general obligation and the best-effort caveat on manual-resume detection. Halt file backed up first, two copies, md5 0f40c49bc67a3767b22b9491910e1ade.
Status: IN PROGRESS

Issue:  Scope limit on the bypass demonstration, recorded by owner order so the ledger never implies a complete demonstration. The contact 1 demos (both-limits-zero and SweepPeriodSeconds=9) demonstrate the erasure half only: a refused init on 694d570 wiping session records from the halt file. The dangerous half, a cleared halt flag turning into a false RESUMED_FROM_SAFE_HALT, needs a persisted SAFE_HALT first, which needs A3, which runs only on the fixed build. That half therefore stays source-read-only permanently.
Action: Record the A9 refusal rows and the bypass demo with this scope limit attached. No further action possible by design.
Status: FINAL

Issue:  Next best action, needs the owner and is blocking everything else. Step 1 of the approved sequence: prove OnDeinit runs after a refused OnInit against the CURRENT unfixed build. Attach path: the /config startup attach is defective, so this needs a manual properties-dialog edit on the live chart.
Action: Owner sets DailyLossPercent = 0 and DailyLossCurrency = 0 in the EA properties dialog and clicks OK. That is the earliest refusal, before mutex acquire, so it isolates the config path. Expect: ALERT "refusing to run, core config invalid", then a deinit line with reason=8, and halt_1200252169.dat reduced to zero session records. Then the executor restores the backup, the owner sets the inputs back, and step 2 lands the fixes.
Status: BLOCKED on owner

Issue:  A8 scheduling. The clock question is settled by measurement (R3, see the 2026-07-30 ACTIONS entry): server clock equals machine clock, broker GMT+3, offset about zero, so the earlier UTC-offset framing of this entry is void. The no-tick window was then measured in the wild: TimeCurrent frozen from 23:00:51 to 00:53:13 local on 2026-07-29/30, about 112 minutes, LIFE cadence unbroken throughout on build 694d570. Evidence: docs/evidence/halt_1200252169.post-shutdown-decode.md.
Action: Confirm the official XAUUSD.ecn session times from the symbol specification at contact 1 as corroboration, then run A8 on build 72ed960 inside the nightly window, 30 or more LIFE lines, timer_ticks at deinit as the independent second measure.
Status: IN PROGRESS

Issue:  SPEC internal inconsistency found during the owner's pre-batch verification 1. The section 5 input table says SweepPeriodSeconds is "clamped 1..5" (and the input's source comment at AccountGuardian.mq5:21 repeats it), but the code refuses out-of-range values at AccountGuardian.mq5:104-109 with INIT_PARAMETERS_INCORRECT, which is what the Q4 config-class rule and the section 8 malformed definition ("out of documented range") require. The behavior is correct; the table cell and the comment carry stale wording.
Action: Owner wording ruling requested at contact 1: fix the SPEC table cell (and the comment with the next code change) to say "out of range refuses init". One word each, editorial, but SPEC changes are owner-ruled by definition.
Status: OPEN

Issue:  CORRECTION to the entry below, dated 2026-07-29. The root cause recorded there ("the terminal-side algo-trading gate") is STRUCK as unproven. It was asserted as fact on inference, not evidence, and the owner reports algo trading was already enabled. What is actually established: under a manual attach at 14:09:40 the EA executes correctly, so the defect is in the harness launch path, not in the code and not in the terminal as a whole. Candidate causes still open, none proven: (1) the per-EA algo permission checkbox inside the EA properties dialog, which is independent of the toolbar button and is not set by startup-config keys; (2) the global algo-trading state at the time of the harness runs, for which the only timestamped evidence is the Experts-log line "automated trading is disabled" at 14:09:26 today, 24 minutes AFTER the last harness run, so it does not establish the state at 13:38-13:45. Eliminated by evidence: different data directory (the journal prints the same path D0E8209F...), a second terminal instance (one process only, and our own mutex refusal would have logged an ALERT), reading the wrong log (Print does go to MQL5\Logs, which is exactly where I looked, and no file existed for today until the manual attach created one at 14:09:43), and the profile layout overriding the startup-config attach (the journal shows AG_Probe loaded via that path, so it does apply). Cause: UNKNOWN pending a live test.
Action: Do not re-run the harness until the cause is settled. Next diagnostic is to attach manually with the EA properties dialog visible and compare its algo-permission checkbox against a startup-config attach.
Status: OPEN

Issue:  CLOSED AS PHANTOM. No defect was ever demonstrated. The reported blocker rested on two independent observation failures that together produced a convincing picture of a dead timer: the old build's liveness line routed through AgVerbose and was suppressed at NORMAL verbosity, so silence was guaranteed regardless of execution; and the F3 dialog does not refresh while it is open, so a variable that was updating the whole time displayed as frozen. Sampled correctly (open, read, fully close, wait, reopen, read) the mutex heartbeat advances by the elapsed seconds. The behaviour of build 3627886 is UNKNOWN and unprovable in retrospect, and no cause is backfilled here.
Action: The change set was still worth landing on its own merits, independent of the phantom: the EventSetTimer return was unchecked at all three call sites, and SYNCING was a state the EA could occupy indefinitely while emitting nothing. Amendment A3 is the reason the question became answerable at all. Corroboration from MQL5\Logs\20260729.log: 15 LIFE lines, spacing a consistent 30 s to within 10 ms, seconds_in_state advancing 1, 31, 61, 91, and deinit reporting timer_armed=1 with timer_ticks=212 across a 213-second session, which is one tick per second sustained.
Status: DONE

Issue:  Standing observation rules, learned the hard way, binding on every future session.
Action: (1) External reads of bases\gvariables.dat are never evidence while the terminal runs. (2) The F3 dialog is a snapshot; a GV reading is admissible only as open, read, fully close, wait, reopen, read. (3) Absence of log output is never evidence of absence of execution unless the emitting line is known to be unsuppressed at the active verbosity; verify the emission path before concluding anything from silence. (4) Added by owner order 2026-07-30: journal lines emitted at OS shutdown can be lost unflushed even when the code that printed them ran to completion, so the halt file, not the journal, is the authoritative witness for shutdown behavior; measured on the 2026-07-29/30 overnight event, where OnDeinit provably ran (clean flag written, mutex zeroed) and its deinit lines do not exist in the log.
Status: FINAL

Issue:  SUPERSEDED, kept for the record. Reported as a blocker on the owner's F3 reading: the timer never fired. AG_HB_1200252169 exists in the live store with the value written at acquire (Persist.mqh:251) and frozen since, and AgMutexRefresh has never executed. Mechanism, and it is inverted from what was logged before: a frozen mutex heartbeat always reads stale, and staleness authorizes takeover under F8, so every second instance takes the mutex unconditionally. Single-instance protection does not exist in the 3627886 build. Acceptance rows A1 and A2 are both broken, not merely untestable. Static findings that pin the cause to timer arming rather than to an early return: EventSetTimer had three call sites (AccountGuardian.mq5:139, 152, 161), each immediately before a return INIT_SUCCEEDED, and the journal's boot transition proves the line-161 path was the one taken with g_timer_seconds=1; between OnTimer entry and the refresh write there was exactly one guard, g_owns_mutex, set true at line 113 on that same path; inside AgMutexRefresh the only guard compares the instance GV to g_ag_instance_id and logs an ALERT when it fires, and no such line exists. So no early return can account for the freeze, and the return value of EventSetTimer was never checked.
Action: See the phantom-closure entry above. The changes shipped and are verified; the premise did not survive.
Status: DONE

Issue:  SUPERSEDED by the entry above, kept for the record. Mutex heartbeat GV AG_HB_1200252169 did not appear in an external read of bases\gvariables.dat while the EA was attached and initialized, although AG_ID_1200252169 did. The claim "this is an absence, not a read artifact" was overstated and is withdrawn: that file is a snapshot owned by the running process, and a constant length across samples is equally consistent with a file that is simply not being refreshed. Static source read settles two candidates and clears both: every write uses GlobalVariableSet, the persistent form, and GlobalVariableTemp appears nowhere in the build, so the temporary-GV explanation is out; GlobalVariablesFlush is called on all five write paths including the per-tick refresh at Persist.mqh:265, so the missing-flush explanation is out. The leftover-from-an-earlier-session explanation for AG_ID is also out: the stale prior-project globals are unsuffixed, AG_ID_1200252169 carries our account suffix, and the only session of ours that ever executed is the 14:09:40 manual attach, which wrote it at Persist.mqh:250, one line before the mutex heartbeat write.
Action: Waiting on the owner's F3 reading of the live store, which is authoritative. No fix proposed until then. If F3 shows the mutex heartbeat live and incrementing, the defect was the external read method, and this entry closes with the standing rule that external gvariables.dat reads are never evidence while the terminal runs.
Status: OPEN

Issue:  External reads of bases\gvariables.dat while the terminal is running are unreliable as evidence, in both directions: the file is a snapshot the process owns, absence there does not prove absence in the live store, and a stale length does not prove a stable variable set. One wrong conclusion has already been drawn from it.
Action: Never cite that file as evidence again. The live store is read through the terminal F3 dialog or from inside MQL5 via GlobalVariableCheck and GlobalVariableGet.
Status: OPEN

Issue:  SYNCING has no exit condition implemented in Phase 0, so it is terminal in this build. That is expected, the sync check lands in Phase 1, but before amendment A3 it was invisible: the state emitted nothing and looked identical to healthy waiting.
Action: The proof-of-life line now names the unimplemented condition explicitly (AgWaitingOn in State.mqh). Closes when Phase 1 implements the exit.
Status: OPEN

Issue:  NOTE for the record, so nobody later reads it as a spec violation: the EA carries #property version "1.00" rather than a 0.x version matching SPEC v0.1. The MQL5 Market version format rejects a zero major and emits warning 68, which would have left the build permanently one warning short of clean. The phase is carried in #property description instead.
Action: None. Revisit at the first release that is genuinely 1.0.
Status: FINAL

Issue:  RESOLVED. Cosmetic logging defect: the boot transition printed "SYNCING->SYNCING" because the state global is initialized to SYNCING and AgTransition then reports from-state equal to to-state. The SPEC section 6 contract wants a meaningful from-state.
Action: AG_STATE_BOOT pseudo-state added in State.mqh, so the first transition now reads BOOT->SYNCING. Folded into the timer fix rather than shipped on its own.
Status: DONE

Issue:  NOTE, deferred phase. common.ini carries WebRequest=1 with the URL whitelist stored as an opaque 534-character encoded blob that cannot be decoded from outside the terminal. v0 has no network path, so it is inert now.
Action: Leave it. Re-examine when the deferred visibility phase opens, together with the fresh network-heartbeat check and its new UUID.
Status: OPEN

Issue:  RESOLVED. Prior-project residue found in the terminal, beyond the .bak already flagged. Four stale global variables with no account suffix, matching the old naming scheme: AG_ACCOUNT=1200252169, AG_HALT=0, AG_LOCKED_UNTIL=0, AG_STATE=1. Also a lock-state file from the old project at Common\Files\AccountGuardian\state_1200252169.dat dated 2026-07-27, 110 bytes, containing v=1, account, state=1, reason=0, locked_at=0, locked_until=0, saved_at, crc. Note it sits in the COMMON files folder, while SPEC v0.1 places our state file in the terminal-local folder, so the two do not collide by path.
Action: The four stale globals were deleted by the owner through the F3 dialog, AG_ID_1200252169 left untouched. The old state file was quarantined per the owner's ruling, not deleted: moved to docs/residue/state_1200252169.dat.residue with a README recording where it came from, and the Common\Files\AccountGuardian folder it sat in is now empty.
Status: DONE

Issue:  Phase 0 demo-attach matrix cannot run: experts load on the chart but never execute. No OnInit output, no files created, no folder writes, verified with a throwaway probe EA that only prints and writes one file. Journal shows "expert AccountGuardian (EURUSD,M1) loaded successfully" and nothing further. Cause is the terminal-side algo-trading gate, which is not reachable from the command line: startup-config keys [Experts] Enabled=1 and AllowLiveTrading=1 are accepted by the launcher (journal confirms "successfully initialized from start config") but do not flip it, and config\common.ini has [Experts] Enabled=1 with no AllowLiveTrading key, plus Account=1 (disable automated trading when the account changes), which fires on the login that follows chart load. Editing common.ini directly was blocked by the sandbox classifier.
Action: Owner action needed, one of: (a) click the Algo Trading button in the terminal toolbar once and leave it on, then the whole matrix can run headless, or (b) authorize the executor to edit config\common.ini ([Experts] AllowLiveTrading=1, Account=0), a backup already sits in the job tmp directory. Static and compile rows are green and logged below; nine attach rows are pending this gate.
Status: BLOCKED

Issue:  The commit-msg hook at .git/hooks/commit-msg is rewritten with a UTF8 BOM and CRLF endings by the Start-ClaudeWorkspace PowerShell profile function on every run, and git cannot spawn a hook that starts with a BOM ("Exec format error", blocks every commit). Found broken on 2026-07-30 with a file timestamp of that morning, after having been fixed once on 2026-07-29. It will recur every time the profile reprovisions it.
Action: Rewrote the hook BOM free with LF endings and verified it strips an attribution line from a test file. Durable fix needs the profile function changed to write without a BOM (Set-Content -Encoding UTF8 emits one under Windows PowerShell 5.1), which is the owner's file, outside this repo.
Status: OPEN

Issue:  A prior, unrelated AccountGuardian implementation exists inside the terminal data folder, outside this repo: MQL5\Experts\AccountGuardian_foreign.mq5.bak dated 2026-07-24, plus metaeditor.log references from 2026-07-25 to an AccountGuardian.mq5 and three AG_* scripts that are no longer on disk. The charter declares this project greenfield and any reference to prior implementations invalid by definition.
Action: Not read, not used, not deleted. Flagged for the owner. Nothing in this build derives from it.
Status: OPEN

---

## ACTIONS

2026-07-30: Contact 1 opened and halted at step 2. Baseline recorded first: journal mark 869 lines, halt md5 3E7AE7CA, 139 bytes, healthy instance 13411 s in SYNCING on 694d570. Owner performed the both-limits-zero refusal manually rather than from a preset, because the prepared .set vectors do not appear in the Load browser, logged as a separate open issue. The refusal alert matched the predicted text exactly, the EA detached, and the config path was confirmed to return before AgMutexAcquire by the absence of any mutex acquire line. The erasure did not occur, and the measured reason narrows the bypass to fresh-load refusals only; full write-up in docs/evidence/bypass-demo-2026-07-30.md, halt state preserved as halt_1200252169.dat.after-config-refusal-2026-07-30. The live halt file was deliberately not restored, since nothing was destroyed and a restore would overwrite record 6's newly written clean flag. Side observation supporting A7 ahead of its own run: an input-change re-init produced a clean session record, exactly as the crash-loop design requires. Also answered the owner's V1 classification question from source: SweepPeriodSeconds is classified core in the SPEC table, and four core inputs reach a refusal return while having a safe clamp available (SweepPeriodSeconds, CrashLoopMaxInits, CrashLoopWindowSeconds, HistoryStablePolls), while only the two daily limits genuinely lack a safe default; for the crash-loop pair the safe clamp direction is toward the default rather than an early trip, matching the A1 corruption policy precedent of failing toward the guardian running. SPEC wording left untouched per ruling, refuse-versus-clamp deferred to post Phase 0. Corrected reporting discipline on owner instruction: an attempted-and-blocked action is reported as blocked, never in language implying it happened.

2026-07-30: Owner ruled R1 as option (d) and absorbed R2 (CrashLoopWindowSeconds default 300, redefined as the pairwise gap bound), both recorded FINAL in DECISIONS; implementation lands in Stage 5a on 72ed960 lineage with the corresponding SPEC A1 rewording, a planned amendment under the ruling. Ran the owner's two pre-batch source verifications against the deployed 694d570 files. Verification 1: SweepPeriodSeconds=9 genuinely refuses, AccountGuardian.mq5:104-109 returns INIT_PARAMETERS_INCORRECT on out-of-range, so the R4 second refusal row stands as planned; found in passing that the SPEC section 5 table cell "clamped 1..5" and the source comment at :21 contradict the coded and section-8-specified refusal behavior, logged as an open wording issue for the owner. Verification 2: the mutex refusal return sits at AccountGuardian.mq5:131, before AgHaltLoad at :136, so the bypass applies on that path and the contact 1 step 8 fix proof is meaningful, not vacuous. Corrected the executor's option (b) reasoning on the record: under (b) a clean session DOES reset the consecutive count, so the reported "fourth isolated power cut in a month" false disarm was wrong; the true (b) residual is the narrower case of repeated unclean deaths with no intervening clean session. The correction does not disturb the (d) ruling, whose recorded grounds never relied on the erroneous claim. Item 0 answered: .claude/settings.json does not exist and never did; the Write attempt was rejected by the isolation guard and the shell attempt was denied by the permission classifier before any file was created, so the opt-out never took effect and there is nothing to remove; the untracked .claude/ directory on main contains only worktrees/, created by the sanctioned worktree tool. Recorded the bypass demo scope limit and standing observation rule 4 by owner order. Hook issue stays OPEN pending the owner's PROFILE fix.

2026-07-30: Stage 2 of docs/PLAN_PHASE0.md executed. Twelve A9 test vectors written to the terminal Presets folder as a9_*.set (defaults, both_zero, neg_percent, neg_currency, percent_over_100, sweep_zero, sweep_over, crash_max_zero, window_zero, polls_zero, nonfinite, optional_bad), each a complete input set with one field off default, ASCII encoded; the owner visually confirms loaded values in the dialog before OK, and if Load shows garbage the fallback is a UTF-16 re-save. The commit-msg hook was found BOM-broken a second time at 12:43 local, minutes into this session, confirming the recurrence mechanism in the open hook issue; repaired identically. Execution stopped at the contact 1 gate per the plan: the next steps need the owner at the terminal (bypass demos on 694d570 per R4, deploy and fix proof of 72ed960, A1, XAUUSD.ecn specification read, A9 rows) and the R1 ruling stays open with the fourth option now costed in the contact 1 report.

2026-07-30: Stage 1 of docs/PLAN_PHASE0.md executed, build 694d570 confirmed compiled into the terminal by diffing all seven deployed sources against git (they differ from 72ed960 on exactly the three fix files, ordering constraint intact). Halt file backed up before anything touched the terminal: docs/evidence/halt_1200252169.dat.post-shutdown-2026-07-30, md5 3e7ae7ca5c3fc5680970242244c20d3e, distinct from the pretest backup 0f40c49b, both retained and labelled. Full decode in docs/evidence/halt_1200252169.post-shutdown-decode.md. Three measured findings. One, the R1 measurement the owner ordered: a routine Windows shutdown marks its session CLEAN, so the overnight event was not an unclean death, no takeover evidence exists because none should, and the delta-2 harvest closes empty by measurement, not by failure; the shutdown deinit journal lines were lost unflushed, so the halt file is the reliable shutdown witness. Two, R3 measured: server clock equals machine clock, broker GMT+3, offset about zero, established by the identity chain process start, journal stamp, TimeCurrent body, TimeLocal record, and file mtime all agreeing within seconds; this CORRECTS the 2026-07-29 ACTIONS claim "server UTC, machine UTC+3", which is struck as resting on an unsupported wall-clock assertion, and reinstates the first audit's GMT+3. Three, the A8 no-tick window measured in the wild: 23:00:51 to 00:53:13, about 112 minutes, LIFE cadence unbroken across it on 694d570. Also appended CLAUDE.md.bak* to .gitignore (record hygiene item 4). No terminal process was started, killed, or reconfigured; the terminal was already running since 10:50:03.

2026-07-30: Captured the Phase 0 execution plan into the repo as docs/PLAN_PHASE0.md on the owner's instruction, after it was delivered outside version control, the third governance artifact to start life outside the repo after the review and the harness. The owner's evidence discipline additions were folded in before capture: lock and halt artifacts are never deleted or overwritten by the executor in any mode, a restore counts as an overwrite and requires a fresh labelled backup first, and a row closes only on evidence present on disk at the stated path, its ledger record carrying result, build hash, and evidence pointer. Gitignore audit ordered by the owner: the negation docs/*.md does not cross directory boundaries, so future markdown under docs/evidence or docs/residue would have been silently ignored. No loss occurred: docs/residue/README.md is tracked, and check-ignore --no-index shows it was never ignored at all, because the bare !README.md negation matches a README.md at any depth. Fix landed: negation widened to docs/**/*.md. The fix newly tracks nothing that exists today; it protects the evidence markdown the plan will create. Work committed on branch worktree-phase0-plan-capture, pending the owner's merge to main; the session's isolation guard does not permit direct commits to the main working copy.

2026-07-29: Correction-2 investigation, ordered before the kill rows, found a SAFE_HALT bypass by source read rather than by test. AG_MUTEX_STALE_SECONDS is 10 s. A refused init appends no session record: OnInit returns INIT_FAILED at :131, while AgHaltLoad is at :136 and AgHaltAppendSession at :163, both downstream. Worse than the owner's framing: OnDeinit then wrote the empty model over the halt file and the GV mirror turned that into a false manual resume. Recorded in the SPEC threat model as prevented, with the general never-loaded-never-written obligation and a best-effort caveat on manual-resume detection. Both fixes written, neither compiled nor deployed, held for step 1 of the sequence so the bug is demonstrated against the unfixed build. Halt file backed up to scratchpad and to docs/evidence/ before anything touched it. Ratified AG_LIFE_INTERVAL_SECONDS to FINAL and logged AG_MUTEX_STALE_SECONDS as a deliberate non-input. A5 stands as PASS-BY-CONSTRUCTION, not PASS: no trade API exists in this build, so the row proves nothing about Phase 3 and carries forward to the sweep engine. Withdrew the earlier proposal to run A3 at CrashLoopWindowSeconds = 600 on the owner's correction: it is kept only as a diagnostic fallback to separate a broken mechanism from a window too tight, and the real default is ruled after measurement. Clock offset established from the session records: server UTC, machine UTC+3.

2026-07-29: Owner re-sampled F3 correctly and the blocker collapsed: the mutex heartbeat advances by the elapsed seconds, so the timer runs. Closed as a phantom with no cause backfilled for the old build. Journal corroborates: 15 LIFE lines at a consistent 30 s, seconds_in_state 1/31/61/91, timer_ticks=212 over a 213-second session. Recorded three standing observation rules. Halt file checked: five session records, the four completed sessions all marked clean, the live one unclean as it should be, so crash counting is not biased unsafe. Quarantined the prior-project state file into docs/residue/ with a README, moved the test harness into scripts/ with a header warning that its /config attach path is defective and unusable until diagnosed, and logged the WebRequest blob as a deferred-phase note. Proposed keeping the proof-of-life interval a constant rather than an input, pending ratification.

2026-07-29: Owner's F3 reading settled the diagnosis: the mutex heartbeat GV exists but is frozen at its acquire-time value, so the timer never fired and single-instance protection was absent, not merely degraded. Applied the combined change set. AgArmTimer is now the single timer arming point with a checked return, an INFO line on success and an Alert on failure. AgMutexRefresh is the first unconditional statement of OnTimer in every state. Proof-of-life line added per A3 at a 30-second interval, carrying state, seconds in state, and the waited-on condition, with SYNCING naming its unimplemented Phase 1 exit outright. Mutex writes instrumented: literal GV names, GlobalVariableSet return values, and a GlobalVariableCheck readback all logged at acquire. AG_STATE_BOOT pseudo-state added, so the first transition reads BOOT->SYNCING. Code comments brought into line with the A2 naming. Deinit now reports whether the timer was armed and how many ticks it saw. Compiles clean at 0 errors, 0 warnings; deployed to the terminal at 16:43. SPEC gained amendment A3 and two threat-model entries (clock manipulation forcing a false SAFE_HALT, and common.ini [Experts] Account=1 disarming automated trading on a login switch). Governance corrected: only the owner marks FINAL, and the clock exemption is re-sourced to the owner as ratified.

2026-07-29: Recorded the owner's naming ruling and the external dead-man residue note. Applied the terminology to docs/SPEC_v0.1.md (amendment A2, editorial) and to the ISSUES and DECISIONS sections here. ACTIONS entries above this line keep their original wording: this section is append-only by protocol, and docs/REVIEW_v0.md likewise keeps the wording it was delivered with. Also withdrew the overstated part of the mutex heartbeat finding after a static source read cleared both of the owner's candidates.

2026-07-29: Owner corrected the harness root-cause claim. Read-only verification of the manually attached instance: OnInit output present in the Experts log at 14:09:40 on XAUUSD.ecn M1, halt file written with one unclean session record and halt flag 0, five global variables in the store of which one (AG_ID_1200252169) is ours. Deleted MQL5\Experts\AccountGuardian_foreign.mq5.bak unread. Struck the algo-gate cause in the ISSUES section rather than editing it silently, and logged three new open issues found during the check: the missing heartbeat GV, the SYNCING->SYNCING boot log, and the stale prior-project globals plus old state file. WebRequest is enabled in common.ini with the URL whitelist stored as an opaque 534-character encoded blob that cannot be decoded from outside the terminal.

2026-07-29: Phase 0 code written and committed (build 3627886, EA version 1.00, spec phase carried in #property description because the MQL5 Market version format rejects a zero major). Files: Experts/AccountGuardian/AccountGuardian.mq5 plus Include/AccountGuardian/{Log,Clock,State,Persist,Pnl,Sweep}.mqh. Deployed and compiled in the terminal data folder as well. Phase 0 test matrix results, one row each:

  S1 no trade API anywhere in the build            PASS  static grep, only hit is the rule comment inside Sweep.mqh
  S2 trade API confined to Sweep.mqh               PASS  static grep, scaffold in place, zero call sites
  S3 TimeCurrent-only rule in decision paths       PASS  static grep, TimeTradeServer count zero; TimeLocal confined to Persist.mqh under the A1 clock exemption
  C1 compiles clean, zero warnings                 PASS  metaeditor64 /compile, "0 errors, 0 warnings"; first run had warning 68 on the version string, fixed
  A1 second attach refuses with Alert              PENDING blocked by the algo-trading gate
  A2 stale mutex heartbeat takeover after kill     PENDING blocked
  A3 crash loop, 4 hard kills inside 60s           PENDING blocked
  A4 SAFE_HALT survives a further restart          PENDING blocked
  A5 SAFE_HALT closes nothing                      PENDING blocked (no trade code exists in this build, so it holds by construction, but the row still needs its run)
  A6 manual resume only via halt-file deletion     PENDING blocked
  A7 clean re-inits do not accumulate to SAFE_HALT PENDING blocked
  A8 timer fires with the market closed            PENDING blocked
  A9 input matrix, core refuses / optional WARNs   PENDING blocked
  A10 transition log lines match SPEC section 6    PENDING blocked

  Harness built and left in place at the job tmp directory: kills the terminal, relaunches it with a startup config that attaches the EA to EURUSD M1 with a chosen .set file, then diffs the journal. It works end to end; only the execution gate stops it. Test account is the JustMarkets demo 1200252169 on JustMarkets-Demo3, confirmed demo by the journal line "balance management has been disabled - demo account".

2026-07-29: Owner approved the Phase 0 plan with two amendments. Amendment 1: LEDGER.md enters git as a governance record (narrow .gitignore negation added, supersession logged, decision recorded FINAL). Amendment 2: SAFE_HALT evidence persisted in a separate halt_<login>.dat, crash count = unclean sessions in window, manual resume = documented deletion of the halt file; SPEC_v0.1 amended in place with a dated amendment block; Phase 0 crash-loop matrix row changed to hard process kills. Minor notes folded in: OnDeinit releases the heartbeat GV by zeroing it, takeover exercised via hard kill; malformed input defined concretely (negative, zero-when-required, out-of-range, non-finite via .set file).

2026-07-29: Wrote and froze docs/SPEC_v0.1.md from the review skeleton with all rulings folded in (base amendment, trade-disallowed policy, config classes, pendings, snapshot, TimeCurrent, dual limits, locked_until = next day anchor, pinned F11/F12/F13, threat model summary). From this point code is measured against SPEC_v0.1; changes require an owner ruling. Note: LEDGER.md and CLAUDE.md are intentionally untracked by git (.gitignore keeps management MD local); only README and docs/ enter version control.

2026-07-29: Recorded owner rulings on all 8 open questions from the architecture review, plus three pinned findings (F11, F12, F13), as FINAL entries in DECISIONS below. Charter amendments accepted for F1 (percent base), F2 (trade-disallowed states), and F9 (config classes).

2026-07-29: Captured the architecture review into the repo as docs/REVIEW_v0.md. The review session ran in plan mode and could not write this ledger. Review scope: adversarial charter review (2 blockers, 8 design findings, 6 notes), spec v0.1 skeleton, 8 open questions for the owner. Updated .gitignore to track docs/*.md. Fixed the commit-msg hook (was written with a UTF8 BOM, git could not spawn it).

2026-07-28: Bootstrapped protocol v3. Created LEDGER.md (replaces STATUS.md/PROGRESS.md/DECISIONS.md, none of which existed yet so no migration needed). Rewrote README.md to bilingual English-first/Hebrew format with no protocol references.

---

## DECISIONS

Decision: Target stack is MQL5, account-level Expert Advisor (not per-trade, not per-strategy).
Reason: Need single risk backstop across all EAs/manual trades on one account.
Status: FINAL

Decision: EA cannot close terminal or disconnect from broker. Max enforcement is closing positions, deleting pending orders, blocking new opens.
Reason: Platform/API limitation, not a design choice.
Status: FINAL

Decision: Library/framework for MQL5 implementation not yet chosen.
Status: REVISIT

Decision: (Q1, owner ruling 2026-07-29) DAILY_BREACH locked_until = next day anchor.
Reason: Makes the lock fully derivable from server history, enabling the derived-lock defense (REVIEW_v0 F4).
Status: FINAL

Decision: (Q2/F1, owner ruling 2026-07-29) Percent-limit base = current balance minus the sum of ALL deals since the day anchor, trading and balance types alike, which equals the day-anchor balance reconstructed live, no caching. Supersedes the charter text "balance minus realized".
Reason: The original text fails the charter's own deposit-neutrality acceptance test in both directions, including a false-positive lock on withdrawal.
Status: FINAL

Decision: (Q3/F2, owner ruling 2026-07-29) All trade-disallowed states (AutoTrading off, MQL_TRADE_ALLOWED false, ACCOUNT_TRADE_ALLOWED or ACCOUNT_TRADE_EXPERT false, investor login, symbol closed or close-only) are kill-equivalent: detect-only, continuous loud alerting (journal + Alert + chart banner), immediate sweep on restoration, each state enumerated and logged distinctly. The flatten promise is formally: within seconds of the platform accepting a close for that symbol.
Reason: MQL5 cannot trade in these states. Platform ceiling, not a design choice.
Status: FINAL

Decision: (Q4/F9, owner ruling 2026-07-29) Config classes. Core (daily limit, lock behavior) malformed, or both limits zero -> OnInit returns INIT_PARAMETERS_INCORRECT, EA visibly refuses to run. Optional (weekly reporting, cosmetics) malformed -> feature off + WARN. The charter's blanket "malformed = off + WARN" clause now applies to optional config only.
Reason: A silently unprotected guardian is the worst failure mode this product can have.
Status: FINAL

Decision: (Q5/F16, owner ruling 2026-07-29) Breach flatten and the locked sweep delete pending orders as well as positions.
Reason: A resting stop otherwise fills straight into a flatten with spread and commission churn. Already within the FINAL maximum-enforcement decision.
Status: FINAL

Decision: (Q6/F7, owner ruling 2026-07-29) At breach, limit and base are snapshotted into the state file; the locked window is judged by the snapshot, never by live inputs. An input change while locked is logged loudly. Residual bypass (file and GV destruction combined with input inflation) is accepted friction, documented in the threat model.
Reason: Otherwise editing one input defeats the lock.
Status: FINAL

Decision: (Q7/F5, owner ruling 2026-07-29) All expiry and anchor decisions use TimeCurrent exclusively. Never TimeTradeServer, never TimeLocal. A dead-market expiry waits for the next server update.
Reason: TimeTradeServer is forgeable via the local Windows clock. The waiting deviation errs locked.
Status: FINAL

Decision: (Q8, owner ruling 2026-07-29) Dual limits, percent and fixed currency, stricter wins, 0 disables each, both zero refuses init per the config-class decision.
Reason: Cheap to build, covers small and large accounts.
Status: FINAL

Decision: (F11 pinned, owner ruling 2026-07-29) A position carried across the rollover counts its floating loss against day N and its full realized result against day N+1. Deliberate conservative double-count, protected by a permanent acceptance test.
Reason: Direct consequence of banning day-start-equity caching.
Status: FINAL

Decision: (F12 pinned, owner ruling 2026-07-29) Realized whitelist = DEAL_TYPE_BUY and DEAL_TYPE_SELL only. Balance, credit, charge, correction, bonus, dividend, and interest deals are excluded from realized; balance-type deals participate only in the Q2 base reconstruction.
Reason: Makes "balance-type excluded by construction" explicit and deliberate.
Status: FINAL

Decision: (F13 pinned, owner ruling 2026-07-29) Timer-driven architecture, EventSetTimer(1). OnTradeTransaction is acceleration only. OnTick unused.
Reason: OnTick starves on quiet charts and dead sessions; transaction delivery is not guaranteed by the platform.
Status: FINAL

Decision: (owner ruling 2026-07-29) Naming discipline. The bare word "heartbeat" is never used in LEDGER.md or SPEC_v0.1.md. "Mutex heartbeat" = the AG_HB_<login> GlobalVariable proving a live instance. "Network heartbeat" = the external dead-man ping of the deferred visibility phase. The once-per-minute journal line, which is neither, is the "liveness journal line".
Reason: One word was carrying two unrelated meanings across a lock-critical design and a deferred network feature.
Status: FINAL

Decision: (owner ruling 2026-07-29) Lock artifacts are never deleted, only quarantined. Standing principle, applies to state files, lock mirrors, and any future artifact carrying lock state, regardless of which project wrote it.
Reason: Deleting a lock artifact is the exact bypass this product exists to prevent, so the executor must never do it as housekeeping.
Status: FINAL

Decision: (owner note 2026-07-29) The external healthchecks.io dead-man check belonging to the deleted prior project has been deleted by the owner. When the deferred visibility phase opens, provision a fresh check with a new UUID. The old UUID is never reused.
Reason: No network path exists in v0, so there is no impact now; reusing a retired dead-man UUID would silence or misattribute alerts later.
Status: FINAL

Decision: (Amendment 1, owner ruling 2026-07-29) LEDGER.md is tracked in git as a governance record. Supersedes the inherited local-only policy for this one file. CLAUDE.md stays local: configuration, not record.
Reason: LEDGER holds the FINAL decisions code is measured against; a single untracked copy is a governance single point of failure. Owner has ruled this question before: governance records are tracked.
Status: FINAL

Decision: (Amendment 2a/2b, owner ruling 2026-07-29, home proposed by executor per the amendment, pre-authorized shape) SAFE_HALT evidence lives in a separate halt_<login>.dat, not in the state file. Contents: format version, login, session records (init timestamp, clean-exit flag), halt flag, halt reason, halt time, checksum. Same atomic-write and loud-failure semantics as the state file. Crash count = unclean sessions inside the window, so clean re-inits (input change, chart change, recompile) never accumulate toward SAFE_HALT and a malfunctioning guardian cannot be revived by reboot.
Reason: The state file is charter-constrained to lock state only and SAFE_HALT is explicitly not a lock; a separate file keeps that constraint intact instead of quietly widening it.
Status: FINAL

Decision: (Amendment 2c, owner ruling 2026-07-29, mechanism pre-approved as acceptable in the amendment) Manual resume from SAFE_HALT = deleting halt_<login>.dat by hand, documented as the official procedure in SPEC and logged as such by the EA when it boots after a deletion. No input toggle, no automatic clearing.
Reason: Resumption must be a deliberate human act; inputs are accident-prone and already treated as suspect while locked.
Status: FINAL

Decision: (owner ruling 2026-07-29, process) Only the owner marks an entry FINAL. The executor proposes; the owner rules. An executor-authored entry is recorded as a proposal until the owner ratifies it, and is then re-sourced to the owner with "(ratified)".
Reason: An executor marking its own decision FINAL locks the project against the only person entitled to lock it. This already happened once, with the clock exemption below.
Status: FINAL

Decision: (owner ruling 2026-07-29 (ratified), proposed by the executor) Crash-loop session timestamps and the mutex heartbeat timestamp use the local clock, explicitly exempt from the Q7 TimeCurrent-only rule. Amendment A3 extends the same exemption to the proof-of-life interval and the seconds-in-state counter.
Reason: Q7 governs expiry and anchor decisions; SAFE_HALT is not a lock, mutex staleness is not an expiry, and a liveness signal that freezes in a dead market is not a liveness signal. TimeCurrent freezes in dead markets, which would make a healthy instance look stale (false takeover) and crash timestamps unrecordable offline.
Residual, accepted: clock manipulation across repeated hard kills could compress session timestamps into the crash-loop window and force a false SAFE_HALT, disarming the guardian. It requires repeatedly killing the terminal, already conceded as kill-equivalent and detect-only, so it gains the adversary nothing over leaving the terminal dead. Recorded in the SPEC threat model.
Status: FINAL

Decision: (owner ruling 2026-07-29 (ratified), proposed by the executor) AG_LIFE_INTERVAL_SECONDS stays a compile-time constant at 30 s and does not become an input.
Reason: It is an observability invariant, not a tuning knob. Exposing it lets someone set it to an hour and recreate exactly the blind spot that cost this project a day, and a config value that can disable the fail-visible guarantee belongs to the core class or nowhere. Nowhere is simpler.
Status: FINAL

Decision: (owner ruling 2026-07-29) AG_MUTEX_STALE_SECONDS stays a compile-time constant at 10 s and is deliberately not an input, same class of reasoning as the liveness interval. Recorded so it reads as a decision rather than an accident of implementation.
Reason: The value governs when one instance may seize the mutex from another. An input could be set long enough to leave a crashed instance's mutex held indefinitely, or short enough to authorize takeover from a live instance that merely stalled a moment. Accepted for now, revisitable if measurement shows 10 s is wrong for real relaunch times.
Status: FINAL

Decision: (owner ruling 2026-07-29) A persistence model that was never loaded is never written. Any save path must prove the model it holds came from a load or a deliberate initialization, never from default-constructed emptiness. Binding beyond the halt file: applies to the lock state file and any future artifact carrying lock or halt state.
Reason: Generalized from the SAFE_HALT bypass found on 2026-07-29, where OnDeinit after a refused OnInit wrote an empty model over the halt file and returned a malfunctioning guardian to service with no human act.
Status: FINAL

Decision: (owner ruling 2026-07-29) Manual-resume detection is best-effort by construction and is recorded as such, not as a guarantee. It infers a human act from a GV-versus-file mismatch, so any route producing that mismatch produces a false resume.
Reason: After the never-loaded-never-written fix the mechanism is sound for the one known divergence route. Flagged for revisit if another route appears, rather than trusting the inference.
Status: REVISIT

Decision: (owner ruling 2026-07-30) R1, crash-loop primitive: consecutive unclean sessions with a pairwise gap bound. Trip when more than CrashLoopMaxInits consecutive unclean sessions exist and each adjacent pair of inits lies within CrashLoopWindowSeconds. Supersedes the rolling-window counting of amendment A1; the A1 file format is untouched.
Reason: The only option whose shipped default is both demonstrable by real kills and immune to slow-spread false disarms, and it uses init timestamps already persisted, so no new field and no SPEC schema change. Grounded in the 2026-07-30 measurement that routine shutdowns and routine re-inits produce clean records, which reset the chain, so only genuine process deaths accumulate.
Status: FINAL

Decision: (owner ruling 2026-07-30) R2 absorbed into R1, not deferred. CrashLoopWindowSeconds default becomes 300, redefined as the pairwise gap bound. Under the conjunction the discriminating work moves to consecutiveness, so a wide bound is cheap: unrelated unclean deaths are hours or days apart, real crash loops are seconds to minutes apart. 300 catches a slow terminal-level crash-restart loop that 60 would miss, while a measured 30 to 40 s kill cycle sits comfortably inside it. Executor obligation: confirm concurrence in one line against the Stage 4 cycle measurement without stopping; if the measurement shows the A3 procedure cannot trip at 300, report before adjusting anything.
Reason: See R1. The bound's job is to separate regimes that are orders of magnitude apart, not to be tight.
Status: FINAL

Decision: (owner ruling 2026-07-30) R3, server offset, is a measurement and a record correction, not a decision gate. The executor measures, corrects the audit record in the ledger, and continues without stopping; escalation only if the measurement contradicts a FINAL decision.
Reason: Measurements are not rulings; a gate that an executor can answer from evidence is not a real gate.
Status: FINAL

Decision: (owner ruling 2026-07-30) R4, the bypass demonstration on build 694d570 runs both refusal rows at contact 1: both limits zero, and a malformed but nonzero core input.
Reason: One extra minute at the dialog converts the ledger claim that every config-refusal return reaches the bypass path from source-read to demonstrated.
Status: FINAL

Decision: (owner ruling 2026-07-29) Proof of life, SPEC amendment A3. Every state, SYNCING and LOCKED included, emits a periodic proof-of-life journal line at a fixed interval carrying current state, seconds in state, and the specific condition being waited on where the state is transitional. Supersedes the section 6 scoping of that line to ACTIVE.
Reason: A state the EA can occupy indefinitely while emitting nothing violates fail-visible. This exact gap hid a dead timer for hours: a stuck guardian and a healthy one looked identical from outside.
Status: FINAL
