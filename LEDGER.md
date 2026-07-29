# LEDGER

## ISSUES

Issue:  Phase 0 not started. Spec is frozen (docs/SPEC_v0.1.md, 2026-07-29); code is measured against it and changes require an owner ruling.
Action: Next step is Phase 0 build (file skeleton, static-structure rule, heartbeat mutex, crash-loop SAFE_HALT, timer cadence, input validation) per SPEC section 8. Phase 0 work plan presented to owner; implementation blocked until approval.
Status: BLOCKED

---

## ACTIONS

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

Decision: (Amendment 1, owner ruling 2026-07-29) LEDGER.md is tracked in git as a governance record. Supersedes the inherited local-only policy for this one file. CLAUDE.md stays local: configuration, not record.
Reason: LEDGER holds the FINAL decisions code is measured against; a single untracked copy is a governance single point of failure. Owner has ruled this question before: governance records are tracked.
Status: FINAL

Decision: (Amendment 2a/2b, owner ruling 2026-07-29, home proposed by executor per the amendment, pre-authorized shape) SAFE_HALT evidence lives in a separate halt_<login>.dat, not in the state file. Contents: format version, login, session records (init timestamp, clean-exit flag), halt flag, halt reason, halt time, checksum. Same atomic-write and loud-failure semantics as the state file. Crash count = unclean sessions inside the window, so clean re-inits (input change, chart change, recompile) never accumulate toward SAFE_HALT and a malfunctioning guardian cannot be revived by reboot.
Reason: The state file is charter-constrained to lock state only and SAFE_HALT is explicitly not a lock; a separate file keeps that constraint intact instead of quietly widening it.
Status: FINAL

Decision: (Amendment 2c, owner ruling 2026-07-29, mechanism pre-approved as acceptable in the amendment) Manual resume from SAFE_HALT = deleting halt_<login>.dat by hand, documented as the official procedure in SPEC and logged as such by the EA when it boots after a deletion. No input toggle, no automatic clearing.
Reason: Resumption must be a deliberate human act; inputs are accident-prone and already treated as suspect while locked.
Status: FINAL

Decision: (Amendment 2 clock exemption, executor, 2026-07-29) Crash-loop session timestamps and the heartbeat-mutex timestamp use the local clock, explicitly exempt from the Q7 TimeCurrent-only rule.
Reason: Q7 governs expiry and anchor decisions; SAFE_HALT is not a lock and mutex staleness is not an expiry. TimeCurrent freezes in dead markets, which would make a healthy instance look stale (false takeover) and crash timestamps unrecordable offline. Clock manipulation here can at worst avoid entering SAFE_HALT, a state the owner can already exit manually.
Status: FINAL
