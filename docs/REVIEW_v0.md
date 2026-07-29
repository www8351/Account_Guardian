# AccountGuardian, Charter Review and Spec v0.1 Skeleton

## Context

Greenfield MT5 account-level lockout EA. Single JustMarkets terminal on Windows. The owner supplied a charter of pre-ruled decisions. This document is the architecture review deliverable: adversarial findings against the charter, a spec skeleton, and open questions for the owner. No code is written here. A separate execution session implements after the owner freezes the spec. Note for the execution session: this session ran in plan mode, so LEDGER.md was not updated; log this review as a dated ACTIONS entry when work starts.

One LEDGER decision (FINAL) constrains everything below: maximum enforcement is closing positions and deleting pending orders. The EA cannot close the terminal, disconnect, or preventively block order placement. All "blocking" in this design is reactive closing.

---

## 1. Adversarial Charter Review

Severity: BLOCKER = contradiction or platform impossibility, charter must amend before spec freeze. DESIGN = charter survives but the spec must carry a specific obligation. NOTE = consequence to pin down so it stays intentional.

### F1. BLOCKER. Percent-limit base violates the deposit-neutrality acceptance test

Charter: "Percent-limit base = current balance minus realized." Balance-type deals are excluded from realized but included in current balance, so the base moves with deposits and withdrawals.

Scenario A: limit 5%, day-start balance 10,000, limit 500. Owner deposits 10,000 midday. Base becomes about 20,000, limit jumps to about 1,000. Headroom doubled by a deposit. Scenario B: owner withdraws midday while daily PnL sits near the old limit. Base shrinks, limit shrinks, breach fires with zero new trading loss, and the guardian flattens healthy positions. Both directions violate the permanent acceptance test, and Scenario B is the guardian acting as the hazard.

Minimal amendment: base = current balance minus the sum of ALL deals since the day anchor, trading and balance types alike. Algebraically this equals the balance at the day anchor, reconstructed live from history with no caching. Deposits and withdrawals cancel exactly, in both directions.

### F2. BLOCKER. "Flatten within seconds" is promised unconditionally, but MQL5 cannot trade in disallowed states

OrderSend is impossible when: the AutoTrading button is off (TERMINAL_TRADE_ALLOWED false), the EA's own algo-trading permission is unchecked (MQL_TRADE_ALLOWED false), the broker disables trading account-side (ACCOUNT_TRADE_ALLOWED or ACCOUNT_TRADE_EXPERT false), the session is an investor-password login, or the symbol is in a closed session or close-only mode.

Bypass scenario inside the stated threat model: owner breaches, toggles AutoTrading off without killing the terminal, then trades manually or from mobile while locked. The guardian sees every position and can close none of them.

Minimal amendment: reclassify all trade-disallowed states as kill-equivalent, detect-only. While LOCKED and unable to trade, the guardian raises a continuous loud alert (journal + Alert popup + chart banner) and sweeps immediately the moment trading is restored. The spec must enumerate each state and log it distinctly.

### F3. DESIGN. Daily breach lock duration is undefined

CORRUPT_STATE duration is defined (until next rollover). The DAILY_BREACH lock has a locked_until but no rule for computing it. This single ruling drives the persistence design and the entire bypass-defense story (see F4). Recommendation: locked_until = next day anchor. Ruled in Q1.

### F4. DESIGN. State file is a single point of bypass; the daily lock must be derivable from broker history

Scenario: owner deletes the state file, or edits it and recomputes the checksum (the algorithm is readable in source), then detaches and re-attaches the EA without killing the terminal. A missing file reads as fresh unlocked state. The charter says detach never clears a lock, but as written the lock lives only in the file.

Amendment: lock is derived state first, file second. Boot rule: LOCKED = (valid state file says locked) OR (GlobalVariable mirror says locked) OR (derived breach from history). Derived breach = current daily PnL breaches the limit, OR the running minimum of cumulative realized PnL replayed deal-by-deal since the day anchor ever touched the limit. The replay matters: after a flatten, the realized loss is burned into server history permanently, so later profitable swept trades cannot erase the breach evidence within the day. Residual gap, accepted: a floating-only breach that could not be flattened (market closed) and then recovered leaves no history witness; file and GV cover it. Server history is the authority; file and GV are witnesses. Full coverage requires the lock to expire at or before next rollover (Q1).

### F5. DESIGN. Expiry time source is forgeable via the local clock

TimeTradeServer() is estimated from the local clock plus a stored offset. Setting the Windows clock forward moves it, unlocking early without touching the terminal. TimeCurrent() advances only with genuine server data and cannot be forged locally.

Amendment: all expiry and anchor decisions use TimeCurrent (last-known server time), never TimeTradeServer, never TimeLocal. Consequence: with zero ticks (dead weekend) an expiry waits for the next server update. That deviation is in the safe direction. Ruled in Q7 because it changes observable unlock timing.

### F6. DESIGN. Boot with incomplete history can misread the day

MT5 loads trade history lazily. Right after terminal start or reconnect, HistorySelect can return true while deals are still streaming in. Undercounting hides a breach (fail-open). A gap can also overstate net loss and trigger a spurious lock and flatten (guardian as hazard).

Amendment: add a SYNCING boot state. In SYNCING the guardian enforces any persisted or GV lock (sweeping allowed) but makes no unlock decision and no new-breach decision until TERMINAL_CONNECTED is true and HistoryDealsTotal is stable across N consecutive polls. Entry and exit are logged.

### F7. DESIGN. Limit-input inflation while locked

Scenario: locked at a 5% limit. Owner edits the input to 90% and re-inits. The derived recompute from F4 finds no breach at the new limit. Unlocked.

Amendment: at breach time, persist a snapshot of the limit and base actually used. While inside the locked window, derived recompute uses the snapshot, never live inputs. A limit-input change while locked is logged loudly. Residual, accepted as friction not prevention: destroying file and GV and inflating the input together defeats it; the threat model documents this explicitly.

### F8. DESIGN. Single-instance mutex can brick the guardian after a crash

A GlobalVariable mutex held by a crashed instance makes every new instance refuse init. The account then runs unprotected while looking configured.

Amendment: mutex = GV carrying a heartbeat timestamp refreshed every timer tick. Takeover is permitted when the heartbeat is stale beyond a threshold. A second live instance refuses init with an Alert and a visible chart state. GlobalVariablesFlush after writes. The 4-week GV lifetime is irrelevant at 1 s refresh.

### F9. DESIGN. Malformed core config fails open (challenge to a charter clause)

Charter: malformed config means feature fully off plus WARN. For the daily limit itself that leaves the account completely unprotected behind one journal line nobody reads. Scenario: a typo in the limit input, weeks of unguarded trading.

Amendment: split config into classes. Core (daily limit, lock behavior): malformed means OnInit returns INIT_PARAMETERS_INCORRECT and the EA visibly refuses to run. Optional (weekly reporting, cosmetics): malformed means off plus WARN, exactly as chartered. This modifies a clause, so it is Q4.

### F10. DESIGN. "Flatten everything" needs a defined retry and impossibility policy

Partial fills, requotes, closed sessions, close-only symbols, trade-context busy, and broker throttling under retry storms are all real. "Within seconds" is per-symbol impossible when that symbol's session is closed.

Obligation: the sweep engine runs a pass over all open positions every timer tick while LOCKED, with per-position backoff, a distinct log line per failure retcode, and no unbounded tight retry. "Within seconds" is redefined as: within seconds of the platform being able to accept a close for that symbol.

### F11. NOTE. A carried position's loss can count against two consecutive days

A position at minus 500 floating at midnight counts against Monday (floating) and again against Tuesday when it closes (full DEAL_PROFIT realized Tuesday). This is a direct consequence of banning day-start-equity caching. It is conservative, not a contradiction. Obligation: pin it with an acceptance test so nobody later "fixes" it into a balance-delta.

### F12. NOTE. The realized-deal whitelist must be explicit

"Balance-type deals excluded by construction" needs the whitelist stated: count only DEAL_TYPE_BUY and DEAL_TYPE_SELL (this covers close-by exits). Everything else is excluded: balance, credit, charge, correction, bonus, commission adjustments, dividends, interest. Consequence: CFD dividends never move headroom. Consistent with the neutrality philosophy, but state it so it is a decision, not an accident.

### F13. NOTE. Architecture must be timer-driven, never tick-driven

OnTick starves on quiet charts and dead sessions. Sweep, breach evaluation, and expiry all run from EventSetTimer(1) set in OnInit. OnTradeTransaction is acceleration only, since delivery is not guaranteed by the platform. The chart symbol the EA sits on is irrelevant to correctness.

### F14. NOTE. Disconnection window

Terminal offline: mobile trades run unswept until reconnect. Same class as terminal kill, accepted, detect-only. Obligation: on reconnect, enter SYNCING then sweep immediately, and log the coverage gap with timestamps.

### F15. NOTE. SAFE_HALT visibility and its shadow

SAFE_HALT while LOCKED leaves mobile-opened positions unswept by design (the guardian's own code is presumed broken). Obligation: persistent chart banner plus periodic Alert while halted, halt reason persisted, and a DoD drill proving that a crash-loop halt closes nothing.

### F16. NOTE. Pending orders

Breach flatten and the lock sweep should also delete pending orders, else a resting stop fills straight into a flatten with spread and commission churn. LEDGER already lists deleting pendings inside maximum enforcement (FINAL), so this extends the charter's "flatten" wording, ruled in Q5. Related correction: LEDGER's phrase "blocking new opens" is not literally possible in MQL5; there is no account-wide order interception. All blocking is reactive closing. Spec language must say so.

---

## 2. Spec v0.1 Skeleton

Structure and obligations only. No implementation bodies.

### 2.1 Architecture and file layout

```
MQL5/Experts/AccountGuardian/AccountGuardian.mq5   entry point, event wiring only
MQL5/Include/AccountGuardian/State.mqh             state machine, transitions, reasons
MQL5/Include/AccountGuardian/Pnl.mqh               day/week windows, realized + floating, base
MQL5/Include/AccountGuardian/Sweep.mqh             flatten engine, retry policy
MQL5/Include/AccountGuardian/Persist.mqh           atomic state file, checksum, GV mirror, mutex
MQL5/Include/AccountGuardian/Clock.mqh             server-time source, day/week anchors
MQL5/Include/AccountGuardian/Log.mqh               logging contract implementation
MQL5/Files/AccountGuardian/state_<login>.dat       lock state only
```

Event model: OnInit (mutex acquire, enter SYNCING). OnTimer at 1 s (everything: sync check, PnL, breach, sweep, expiry, weekly measure, heartbeat). OnTradeTransaction (accelerated sweep trigger only). OnTick unused. OnDeinit (release mutex, never touches lock state). Structural rule, statically checkable: Pnl.mqh weekly path and Log.mqh contain no trade calls; only Sweep.mqh includes the trade API.

### 2.2 State machine

States: SYNCING, ACTIVE, LOCKED, SAFE_HALT.

Sweeping is a behavior of LOCKED, not a separate state. lock_reason in {DAILY_BREACH, CORRUPT_STATE}. A sub-condition flag CANNOT_TRADE (F2) is tracked and logged inside LOCKED, not a separate state.

Transitions, each one logged:
- boot -> SYNCING: always.
- SYNCING -> LOCKED: persisted file, GV mirror, or derived breach (F4) says locked.
- SYNCING -> ACTIVE: connected, history stable N polls, no lock witness.
- ACTIVE -> LOCKED(DAILY_BREACH): daily PnL <= negative limit. Actions: snapshot limit and base (F7), persist state, delete pendings (Q5), begin sweep.
- any state -> LOCKED(CORRUPT_STATE): state file fails checksum. locked_until = next rollover, computed at boot, never read from the failed file. Failed file renamed to .bad and quarantined.
- LOCKED -> ACTIVE: TimeCurrent >= locked_until. Never any other cause. Rollover resets counters but unlock happens only via this comparison.
- any state -> SAFE_HALT: init count exceeds crash-loop threshold inside the detection window. Closes nothing, sweeps nothing, excluded from expiry, manual restart only. Not a lock.

### 2.3 Persistence format and corruption policy

Single binary or key-value file: magic, format version, account login, lock_reason, locked_until, breach_time, limit_snapshot, base_snapshot, checksum over all prior fields. Lock state only, nothing else, per charter.

Write path: write tmp file, FileFlush, FileMove with FILE_REWRITE onto the target. Same-folder rename, atomic at filesystem level. FileFlush does not guarantee media fsync; torn writes are exactly what the checksum plus CORRUPT_STATE policy absorbs. Write failure: Alert plus WARN every timer pass, enforcement continues from memory, never silent.

Read policy: checksum fail -> CORRUPT_STATE lock until next rollover, quarantine the file. Missing file -> not trusted as unlocked; run F4 derivation. GV mirror (AG_LOCK_<login> = locked_until) and heartbeat GV (AG_HB_<login>) written each tick, flushed.

### 2.4 Core algorithms (obligations)

- Day anchor: floor of last-known server time (TimeCurrent) to server-day midnight. Recomputed every evaluation, never persisted.
- Week anchor: fixed offset from server time targeting Sunday 00:00 Israel. No DST table, per charter. Deviation up to about 2 h across server and Israel DST shifts, lands in dead market, report-only path, inert. Affirmed, no change.
- Realized(window): HistorySelect(anchor, now). Sum DEAL_PROFIT + DEAL_SWAP + DEAL_COMMISSION over deals whose type is in {DEAL_TYPE_BUY, DEAL_TYPE_SELL} only (F12).
- Floating: sum over open positions of POSITION_PROFIT + POSITION_SWAP. (Position-level commission is not retrievable in MT5; entry commission already lands in realized via the entry deal.)
- Base (amended per F1): current balance minus sum of ALL deals since day anchor. Equals day-anchor balance, no caching.
- Breach: dailyPnL <= -(limit_currency), where limit_currency comes from percent of base and/or fixed input per Q8.
- Sweep: per F10. Positions first, pendings per Q5. Runs whenever LOCKED and anything is open.
- Expiry: TimeCurrent >= locked_until (F5, Q7).
- Weekly: identical PnL formula over the week window. Measure and report only. No trade call reachable from this path (statically enforced by include structure, 2.1).
- Boot derivation: per F4, including the deal-by-deal running-minimum replay of realized PnL since anchor.

### 2.5 Inputs table

| Input | Type | Default | Off-value | Notes |
|---|---|---|---|---|
| DailyLossPercent | double | 5.0 | 0 | Percent of day-anchor base |
| DailyLossCurrency | double | 0 | 0 | Absolute account currency |
| (both zero) | | | | Refuses init per F9/Q4; a guardian with no limit is a config error |
| (both set) | | | | Stricter (smaller headroom) wins, per Q8 |
| WeeklyReportEnabled | bool | true | false | Report-only path |
| SweepPeriodSeconds | int | 1 | none | Clamped 1..5 |
| CrashLoopMaxInits | int | 3 | none | Within CrashLoopWindowSeconds |
| CrashLoopWindowSeconds | int | 60 | none | |
| HistoryStablePolls | int | 3 | none | SYNCING exit condition |
| LogVerbosity | enum | NORMAL | none | Never suppresses transitions |

No symbol filter, no magic filter: charter scope is everything on the account.

### 2.6 Logging contract

- Every state transition is exactly one structured journal line: timestamp (server), from-state, to-state, reason, and the governing numbers (dailyPnL, limit, base, locked_until where relevant).
- Breach line carries the full arithmetic so the drill is auditable from the journal alone.
- Sweep: one line per close attempt with retcode; failure reasons distinct (F10, F2 states enumerated).
- Alert popups mandatory for: breach, lock, unlock, state-write failure, cannot-trade-while-locked, SAFE_HALT.
- Chart banner (Comment or objects) always shows current state, lock reason, locked_until, daily PnL vs limit.
- Heartbeat log at most once per minute in ACTIVE to avoid journal spam.
- No secrets, no credentials, ever. v0 has no network path; the clause stays dormant but tested (log scan in DoD).

### 2.7 Phased build plan with acceptance-test matrices

Phase 0, skeleton, no trading calls compiled in:
- Single-instance: second attach refuses with Alert. Crashed-instance takeover works after heartbeat staleness (F8).
- Crash-loop threshold enters SAFE_HALT, closes nothing, survives restart, manual resume only.
- Timer cadence verified with market closed (F13).
- Input validation matrix: each malformed core input refuses init (per Q4 ruling); malformed optional input logs WARN and disables only itself.

Phase 1, PnL engine, read-only:
- Deposit and withdrawal neutrality, both directions, on demo: headroom and limit unchanged (F1 amendment). The permanent acceptance test.
- Rollover resets counters at server midnight.
- Restart reconstruction: figures before kill equal figures after restart once SYNCING exits (F6).
- Carried-position double-count pinned as expected behavior (F11).
- Deal whitelist matrix: balance, credit, correction deals move nothing (F12).

Phase 2, lock and persistence, still no trading:
- Breach detection: realized-only, floating-only, mixed.
- Lock survives: detach/re-attach, recompile, input change, terminal restart.
- State file deleted while locked -> re-lock from derived history at next init (F4).
- State file corrupted -> CORRUPT_STATE until next rollover, quarantine present.
- Windows clock moved forward -> no early unlock (F5/Q7).
- Limit input inflated while locked -> snapshot holds the lock (F7).

Phase 3, sweep engine:
- Breach flattens EA, manual, and mobile positions; pendings per Q5.
- New mobile position while locked closed within seconds (timer plus OnTradeTransaction path both exercised).
- AutoTrading toggled off while locked -> continuous alert, no crash, sweep resumes on re-enable (F2).
- Closed-session symbol -> bounded retries, distinct logs, no order-storm (F10).
- Partial close and hedging-account matrix.

Phase 4, weekly reporting:
- Week window correct across a server DST shift, drift shown inert.
- Static check: no trade API reachable from the weekly path.

Definition of Done:
- All phase matrices green on demo.
- Controlled breach drill on demo: scripted losing trades cross the limit; observe flatten, lock, alert, journal arithmetic, expiry through a real rollover.
- Bypass drills, each with expected outcome logged: file delete, file forge, AutoTrading toggle, clock change, input inflation, detach/re-attach.
- One-week demo soak with daily reconciliation of guardian PnL vs broker statement within a defined tolerance, plus a journal scan for secrets and spam.
- Only then live.

---

## 3. Open Questions for the Owner

Q1. Daily breach lock duration.
Decision: how is locked_until computed for DAILY_BREACH?
Options: (a) next day anchor, (b) breach time + fixed 24 h, (c) input-configurable.
Recommendation: (a); it makes the lock fully derivable from server history, which is what defeats file deletion and forgery.
Blocks: state machine, persistence format, the entire F4 defense.

Q2. Percent-base amendment (F1).
Decision: accept base = current balance minus sum of ALL deals since anchor?
Options: (a) accept, (b) drop percent limits and go fixed-currency only, (c) keep charter text as written.
Recommendation: (a); (c) provably fails the charter's own permanent acceptance test.
Blocks: breach algorithm, Phase 1 matrix.

Q3. Trade-disallowed states (F2).
Decision: reclassify AutoTrading-off and broker-side disables as kill-equivalent, detect-only with loud alerting and sweep-on-restore?
Options: accept, or reject and restate the flatten promise some other way (no stronger option exists on the platform).
Recommendation: accept; it is a platform ceiling, not a design choice.
Blocks: threat model wording, Phase 3 matrix, DoD drill list.

Q4. Malformed core config (F9).
Decision: core limit malformed -> EA refuses to run visibly, instead of feature-off plus WARN?
Options: (a) refuse init for core, off+WARN for optional, (b) charter as written for everything.
Recommendation: (a); a silent unprotected guardian is the worst failure mode this product can have.
Blocks: Phase 0 input matrix, logging contract.

Q5. Pending orders (F16).
Decision: delete pendings at breach and continuously while locked?
Options: yes / no.
Recommendation: yes; LEDGER's FINAL enforcement decision already includes it.
Blocks: sweep spec, Phase 3 matrix.

Q6. Limit snapshot at breach (F7).
Decision: freeze limit and base into the state file at breach, and judge the locked window by the snapshot?
Options: yes / no (live inputs).
Recommendation: yes; otherwise editing one input defeats the lock.
Blocks: persistence format.

Q7. Expiry time source (F5).
Decision: TimeCurrent only, accepting that an expiry landing in a dead market unlocks at the next server update rather than the exact second?
Options: (a) TimeCurrent only, (b) TimeTradeServer (forgeable via local clock).
Recommendation: (a); the delay is small, rare, and errs locked.
Blocks: expiry algorithm, clock-change drill.

Q8. Dual limit inputs.
Decision: support percent and fixed-currency simultaneously with stricter-wins, 0 disabling each, both-zero refusing init?
Options: (a) as stated, (b) percent only, (c) fixed only.
Recommendation: (a); cheap to build, covers small and large accounts.
Blocks: inputs table, breach formula.

Deferred as spec default, marked REVISIT, no ruling needed now: weekly report channel = journal line at rollover plus chart banner field.
