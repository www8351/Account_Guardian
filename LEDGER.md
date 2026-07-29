# LEDGER

## ISSUES

Issue:  CORRECTION to the entry below, dated 2026-07-29. The root cause recorded there ("the terminal-side algo-trading gate") is STRUCK as unproven. It was asserted as fact on inference, not evidence, and the owner reports algo trading was already enabled. What is actually established: under a manual attach at 14:09:40 the EA executes correctly, so the defect is in the harness launch path, not in the code and not in the terminal as a whole. Candidate causes still open, none proven: (1) the per-EA algo permission checkbox inside the EA properties dialog, which is independent of the toolbar button and is not set by startup-config keys; (2) the global algo-trading state at the time of the harness runs, for which the only timestamped evidence is the Experts-log line "automated trading is disabled" at 14:09:26 today, 24 minutes AFTER the last harness run, so it does not establish the state at 13:38-13:45. Eliminated by evidence: different data directory (the journal prints the same path D0E8209F...), a second terminal instance (one process only, and our own mutex refusal would have logged an ALERT), reading the wrong log (Print does go to MQL5\Logs, which is exactly where I looked, and no file existed for today until the manual attach created one at 14:09:43), and the profile layout overriding the startup-config attach (the journal shows AG_Probe loaded via that path, so it does apply). Cause: UNKNOWN pending a live test.
Action: Do not re-run the harness until the cause is settled. Next diagnostic is to attach manually with the EA properties dialog visible and compare its algo-permission checkbox against a startup-config attach.
Status: OPEN

Issue:  CLOSED AS PHANTOM. No defect was ever demonstrated. The reported blocker rested on two independent observation failures that together produced a convincing picture of a dead timer: the old build's liveness line routed through AgVerbose and was suppressed at NORMAL verbosity, so silence was guaranteed regardless of execution; and the F3 dialog does not refresh while it is open, so a variable that was updating the whole time displayed as frozen. Sampled correctly (open, read, fully close, wait, reopen, read) the mutex heartbeat advances by the elapsed seconds. The behaviour of build 3627886 is UNKNOWN and unprovable in retrospect, and no cause is backfilled here.
Action: The change set was still worth landing on its own merits, independent of the phantom: the EventSetTimer return was unchecked at all three call sites, and SYNCING was a state the EA could occupy indefinitely while emitting nothing. Amendment A3 is the reason the question became answerable at all. Corroboration from MQL5\Logs\20260729.log: 15 LIFE lines, spacing a consistent 30 s to within 10 ms, seconds_in_state advancing 1, 31, 61, 91, and deinit reporting timer_armed=1 with timer_ticks=212 across a 213-second session, which is one tick per second sustained.
Status: DONE

Issue:  Standing observation rules, learned the hard way, binding on every future session.
Action: (1) External reads of bases\gvariables.dat are never evidence while the terminal runs. (2) The F3 dialog is a snapshot; a GV reading is admissible only as open, read, fully close, wait, reopen, read. (3) Absence of log output is never evidence of absence of execution unless the emitting line is known to be unsuppressed at the active verbosity; verify the emission path before concluding anything from silence.
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

Issue:  A prior, unrelated AccountGuardian implementation exists inside the terminal data folder, outside this repo: MQL5\Experts\AccountGuardian_foreign.mq5.bak dated 2026-07-24, plus metaeditor.log references from 2026-07-25 to an AccountGuardian.mq5 and three AG_* scripts that are no longer on disk. The charter declares this project greenfield and any reference to prior implementations invalid by definition.
Action: Not read, not used, not deleted. Flagged for the owner. Nothing in this build derives from it.
Status: OPEN

---

## ACTIONS

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

Decision: (executor proposal 2026-07-29, awaiting owner ratification) AG_LIFE_INTERVAL_SECONDS stays a compile-time constant at 30 s and does not become an input.
Reason: It is an observability invariant, not a tuning knob. Exposing it lets someone set it to an hour and recreate exactly the blind spot that cost this project a day, and a config value that can disable the fail-visible guarantee belongs to the core class or nowhere. Nowhere is simpler.
Status: PROPOSED

Decision: (owner ruling 2026-07-29) Proof of life, SPEC amendment A3. Every state, SYNCING and LOCKED included, emits a periodic proof-of-life journal line at a fixed interval carrying current state, seconds in state, and the specific condition being waited on where the state is transitional. Supersedes the section 6 scoping of that line to ACTIVE.
Reason: A state the EA can occupy indefinitely while emitting nothing violates fail-visible. This exact gap hid a dead timer for hours: a stuck guardian and a healthy one looked identical from outside.
Status: FINAL
