# AccountGuardian SPEC v0.1

Status: FROZEN 2026-07-29. Amended 2026-07-29 by owner ruling (Amendments A1, A2, A3, see section 9).
Code is measured against this document. Any change requires an owner ruling recorded in the decision log. Source material: docs/REVIEW_v0.md (findings F1-F16) and the owner rulings of 2026-07-29 (Q1-Q8, pinned F11/F12/F13). This spec contains structure and obligations only, no implementation bodies.

## 0. Product statement

Single account-level lockout EA for MetaTrader 5, one JustMarkets terminal, Windows. Daily loss breach: flatten every position and delete every pending order on the account (every symbol, magic, origin, including mobile and manual), then lock until expiry. While locked, anything newly opened is flattened within seconds of the platform accepting a close for that symbol. Weekly PnL is measured and reported only; no weekly code path may lock, close, or sweep. Unlock is time expiry only. No manual override of any kind.

Out of scope v0 (deferred, not deleted): session windows, network visibility (network heartbeat, events, dead-man drill), cooperating-EA contract, account-split hardening, any trading logic.

Naming discipline (owner ruling, 2026-07-29): the bare word "heartbeat" is never used in this document. "Mutex heartbeat" means the AG_HB_<login> GlobalVariable that proves a live instance. "Network heartbeat" means the external dead-man ping, which belongs to the deferred visibility phase and does not exist in v0.

## 1. Architecture and file layout

```
MQL5/Experts/AccountGuardian/AccountGuardian.mq5   entry point, event wiring only
MQL5/Include/AccountGuardian/State.mqh             state machine, transitions, reasons
MQL5/Include/AccountGuardian/Pnl.mqh               day/week windows, realized + floating, base
MQL5/Include/AccountGuardian/Sweep.mqh             flatten engine, pending deletion, retry policy
MQL5/Include/AccountGuardian/Persist.mqh           atomic state file, checksum, GV mirror, mutex
MQL5/Include/AccountGuardian/Clock.mqh             server-time source, day/week anchors
MQL5/Include/AccountGuardian/Log.mqh               logging contract implementation
MQL5/Files/AccountGuardian/state_<login>.dat       lock state only
```

Event model:
- OnInit: acquire single-instance mutex, validate inputs per config classes (section 5), enter SYNCING.
- OnTimer at 1 s: everything runs here. Sync check, PnL evaluation, breach check, sweep, expiry check, weekly measurement, mutex heartbeat refresh.
- OnTradeTransaction: accelerated sweep trigger only. Delivery is not guaranteed by the platform; correctness never depends on it.
- OnTick: unused.
- OnDeinit: release mutex. Never touches lock state.

Static-structure rule, checkable without running: the trade API (OrderSend and relatives) is reachable only from Sweep.mqh. Pnl.mqh, Clock.mqh, Log.mqh, State.mqh, Persist.mqh contain no trade calls. The weekly path is inside Pnl.mqh and therefore provably cannot trade.

Time rule (Q7, FINAL): every expiry and anchor decision uses TimeCurrent exclusively. TimeTradeServer and TimeLocal are forbidden in decision paths. TimeTradeServer is forgeable via the local Windows clock. A dead-market expiry waits for the next server update; errs locked, accepted.

## 2. State machine

States: SYNCING, ACTIVE, LOCKED, SAFE_HALT.
lock_reason in {DAILY_BREACH, CORRUPT_STATE}. Sweeping is a behavior of LOCKED, not a state. CANNOT_TRADE is a tracked and logged sub-condition inside LOCKED (section 4.4), not a state.

Transitions, every one logged (section 6):

| From | To | Trigger | Actions |
|---|---|---|---|
| boot in a fresh image, or the surviving prior state in an in-place re-init (A5) | SYNCING | always | log boot, read state file, read GV mirror |
| SYNCING | LOCKED | state file, GV mirror, or derived breach (4.6) says locked | adopt strictest witness |
| SYNCING | ACTIVE | TERMINAL_CONNECTED true and HistoryDealsTotal stable across HistoryStablePolls consecutive polls and no lock witness | log sync duration |
| ACTIVE | LOCKED (DAILY_BREACH) | daily PnL <= -(limit) | snapshot limit and base into state file (Q6), set locked_until = next day anchor (Q1), persist, delete pendings, begin sweep |
| any | LOCKED (CORRUPT_STATE) | state file fails checksum | locked_until = next rollover, computed at boot, never read from the failed file; rename file to .bad, quarantine |
| LOCKED | ACTIVE | TimeCurrent >= locked_until | log unlock; never any other cause |
| boot | SAFE_HALT | chain trip: more than CrashLoopMaxInits consecutive unclean sessions, each adjacent pair of inits no more than CrashLoopWindowSeconds apart (A4). Only a fresh image reaches this. | close nothing, sweep nothing, banner + one Alert at entry or re-entry, manual restart only |
| any | SAFE_HALT | halt flag persisted from an earlier session, re-entered at init or in-place re-init (section 8, A5). From stays any so SAFE_HALT to SAFE_HALT conforms. | close nothing, sweep nothing, banner + one Alert at entry or re-entry, manual restart only |

SAFE_HALT is not a lock: excluded from expiry, cleared only by manual restart. SAFE_HALT while a lock exists leaves the account unswept by design (guardian code presumed broken); this shadow is documented and drilled, not hidden.

Rollover resets counters; it never unlocks by itself. Unlock happens only through the TimeCurrent >= locked_until comparison. For DAILY_BREACH those two instants coincide because locked_until = next day anchor (Q1, FINAL).

## 3. Persistence format and corruption policy

Single file MQL5/Files/AccountGuardian/state_<login>.dat carrying lock state only:
magic, format version, account login, lock_reason, locked_until, breach_time, limit_snapshot, base_snapshot, checksum over all prior fields.

Write path: write tmp file, FileFlush, FileMove with FILE_REWRITE onto the target (same-folder rename, atomic at filesystem level). FileFlush does not guarantee media fsync; torn writes are absorbed by the checksum plus CORRUPT_STATE policy. Write failure: Alert plus WARN repeated every timer pass, enforcement continues from memory, never silent.

Read policy:
- Checksum fail: CORRUPT_STATE lock until next rollover, quarantine the file as .bad.
- Missing file: never trusted as unlocked. Run the derivation of 4.6.

GlobalVariable mirror: AG_LOCK_<login> = locked_until, AG_HB_<login> = mutex heartbeat timestamp, both written each timer tick and flushed with GlobalVariablesFlush. The 4-week GV lifetime is irrelevant at 1 s refresh.

Authority order: broker history is the authority; file and GV are witnesses (accelerators). Lock at boot = OR over all three.

## 4. Core algorithms (obligations)

### 4.1 Anchors
- Day anchor (A6, Q1 FINAL): floor of TimeCurrent to the last 01:00-server boundary, `AG_DAY_ANCHOR_OFFSET_SECONDS = 3600`, a compile-time constant, never an input. Recomputed every evaluation, never persisted. During the twice-weekly freeze the anchor holds the last pre-freeze boundary and adopts the new one at the first advancing evaluation; a backward clock step recomputes a lower anchor and the window widens, erring strict. REVISIT scheduled after the 2026-10-25 to 2026-11-01 broker DST-peg measurement.
- Anchor high-water-mark sanity check (A6, Q8 FINAL, amended 2026-08-09 to alert-and-advance, 4.1a): the highest anchor observed this session is retained in memory. A freshly computed anchor exceeding it by more than 86400 seconds is announced loudly, with a journal line on every occurrence and an ALERT naming both the previous high anchor and the accepted one, capped at `AG_LIFE_INTERVAL_SECONDS` exactly as the Q2 breach ALERT is; the fresh anchor is then ACCEPTED and the high-water mark advances to it, so the pass proceeds normally and the condition clears itself on that same pass. No evaluation pass is ever halted. A backward step or same-day recompute is unaffected and the retained anchor never recedes. In-memory only, never persisted; a restart re-seeds on its first pass.
- Week anchor: fixed offset from server time targeting Sunday 00:00 Israel. No DST table. Deviation up to about 2 h across server and Israel DST shifts lands in a dead market and only touches the report-only path. Inert, affirmed.

### 4.2 Daily PnL
- Realized(window): HistorySelect(anchor, AG_HISTORY_SELECT_TO), a clock-independent far-future constant (A6, `D'3000.01.01'`), never TimeCurrent-derived, so neither a frozen nor a backward-stepping clock can truncate the window. Sum DEAL_PROFIT + DEAL_SWAP + DEAL_COMMISSION + DEAL_FEE (A6, Q3 FINAL) over deals whose type is DEAL_TYPE_BUY or DEAL_TYPE_SELL only (F12, FINAL). All balance, credit, charge, correction, bonus, dividend, interest deals excluded from realized. Boundary convention (A6, Q4 FINAL): DEAL_TIME >= anchor counts to the new day, matching HistorySelect's own inclusive-from semantics; no separate comparison is needed. HistorySelect returning false is a loud stability failure, never read as zero deals (F6).
- Floating: sum over open positions of POSITION_PROFIT + POSITION_SWAP. Position-level commission is not retrievable in MT5; entry commission already lands in realized via the entry deal.
- Daily PnL = realized + floating. Never a balance-delta, never a cached day-start equity.
- Pinned behavior (F11, FINAL): a position carried across the rollover counts its floating loss against day N and its full realized result against day N+1. Deliberate conservative double-count, protected by a permanent acceptance test.

### 4.3 Base and limit (Q2 amendment, FINAL)
- Base = current balance minus the sum of ALL deals since the day anchor, trading and balance types alike, same per-deal formula as 4.2 including DEAL_FEE (A6, Q3 FINAL). Algebraically equal to the day-anchor balance, reconstructed live, no caching. Deposits and withdrawals cancel exactly in both directions.
- limit_currency = min of the two legs (Q8 FINAL, D1f FINAL 2026-09-03): percent limit = DailyLossPercent% of base; fixed limit = DailyLossCurrency. Stricter wins. Both legs are mandatory list inputs; a value off either list refuses init (section 5).
- Permanent acceptance test: a deposit or withdrawal moves loss headroom in neither direction.

### 4.4 Breach and sweep
- Breach: daily PnL <= -(limit_currency), epsilon 0.01 account-currency units errs toward breach. On breach: snapshot, persist, lock, delete all pending orders, flatten all positions. **Phase 1 interim posture (A6, Q2 FINAL):** enforcement lands in Phase 2; the deployed Phase 1 build takes no lock action on breach. It raises a loud ALERT plus a per-pass journal arithmetic line, repeated at `AG_LIFE_INTERVAL_SECONDS` (30 s) while the condition holds, and stays ACTIVE. Owner-sanctioned no-enforcement window.
- Breach-declaration deferral (A6, Q9 FINAL): a pass where the result crosses the limit with no new deal visible in the selected history (HistoryDealsTotal() unchanged from the prior pass) defers its declaration by exactly one timer pass; the following pass declares unconditionally regardless of deal count. Guards Balance-versus-history coherence; never suppresses two passes running.
- DEGRADED (A6, Q10 FINAL, amended by the 2026-08-09 owner ruling below): while TERMINAL_INFO_CONNECTED is false, ACTIVE performs no breach evaluation and raises no breach ALERT; the LIFE line and banner mark the state DEGRADED, prefixing the governing-numbers field group itself with `DEGRADED|` (not only the waiting_on field), and continue showing the last-known figures. The instant the connection returns, evaluation does not resume immediately: it re-enters gated on history stability, the same discipline as the SYNCING exit condition (2026-08-09 owner ruling, reconnect coherence). No state transition; the LIFE line shows the live poll count prefixed RESYNC while gated, distinct from initial SYNCING. Q9's one-pass coherence deferral is unchanged and applies only once evaluation has resumed.
- Sweep (behavior of LOCKED): every timer tick while anything is open, one pass over all positions and pendings; per-position backoff; a distinct log line per failure retcode; no unbounded tight retry.
- Trade-disallowed states (Q3, FINAL), each enumerated and logged distinctly: TERMINAL_TRADE_ALLOWED false, MQL_TRADE_ALLOWED false, ACCOUNT_TRADE_ALLOWED false, ACCOUNT_TRADE_EXPERT false, investor-password login, symbol session closed or close-only. All are kill-equivalent: detect-only, continuous loud alerting (journal + Alert + chart banner), immediate sweep the moment trading is restored. The formal promise: flattened within seconds of the platform accepting a close for that symbol.
- Disconnection: mobile trades run unswept while the terminal is offline. Kill-equivalent, accepted. On reconnect: SYNCING, then immediate sweep, and the coverage gap logged with timestamps.

### 4.5 Expiry
- TimeCurrent >= locked_until. No other unlock path exists. While locked, the window is judged by the persisted limit_snapshot and base_snapshot, never live inputs (Q6, FINAL). A limit-input change while locked is logged loudly.

### 4.6 Boot derivation (F4 defense)
LOCKED at boot = (valid state file says locked) OR (GV mirror says locked) OR (derived breach), where derived breach = current daily PnL breaches, OR the running minimum of cumulative realized PnL, replayed deal-by-deal since the day anchor, ever touched the limit. Post-flatten the realized loss is burned into server history, so later profitable swept trades cannot erase the breach evidence within the day. Derived recompute inside a locked window uses the snapshot values when available.
Residual gaps, accepted and documented in the threat model (section 7): a floating-only breach that could not be flattened and then recovered leaves no history witness (file and GV cover it); destroying file and GV combined with input inflation defeats the snapshot (accepted friction).

### 4.7 Weekly measurement
Identical PnL formula over the week window. Measure and report only: journal line at rollover plus a chart banner field (REVISIT default). No trade call reachable from this path, enforced by the static-structure rule of section 1.

## 5. Inputs

Config classes (Q4, FINAL):
- Core class (daily limits, lock behavior): a value that is not a member of its own list (D1f FINAL 2026-09-03) means OnInit returns INIT_PARAMETERS_INCORRECT and the EA visibly refuses to run.
- Optional class (weekly reporting, cosmetics): malformed means that feature fully off plus WARN, never half-enforced.

| Input | Type | Default | Off-value | Class | Notes |
|---|---|---|---|---|---|
| DailyLossPercent | enum, 22 members 0.25 to 5.50 step 0.25 | 5.50 | none | core | percent of day-anchor base; off-list refuses init |
| DailyLossCurrency | enum, 48 members 1 to 10 step 1 then 15 to 200 step 5 | 200 | none | core | account currency; stricter of the two wins; off-list refuses init |
| WeeklyReportEnabled | bool | true | false | optional | report-only path |
| LogVerbosity | enum | NORMAL | none | optional | never suppresses transitions |

SweepPeriodSeconds 1, HistoryStablePolls 3, CrashLoopMaxInits 3 and CrashLoopWindowSeconds 300 are compile-time constants from R10 (D7b, D11a FINAL 2026-09-03).

No symbol filter, no magic filter. Scope is everything on the account. Single instance per account enforced at init (mutex heartbeat, stale takeover).

## 6. Logging contract

- Every state transition is exactly one structured journal line: server timestamp, from-state, to-state, reason, governing numbers (daily PnL, limit, base, locked_until where relevant).
- The breach line carries the full arithmetic so the drill is auditable from the journal alone.
- Sweep: one line per close or delete attempt with retcode; failure reasons distinct; trade-disallowed states enumerated by name.
- Alert popups mandatory for: breach, lock, unlock, state-write failure, cannot-trade-while-locked, SAFE_HALT.
- Chart banner always shows: current state, lock reason, locked_until, daily PnL vs limit.
- Proof-of-life journal line in every state at a fixed interval (amendment A3, which supersedes the earlier ACTIVE-only scoping). In ACTIVE it additionally carries the governing numbers (A6, 4.5): anchor, realized, floating, base, limit, pnl_vs_limit. The day-rollover journal line logs old anchor, new anchor, and jump width; its latch is seeded silently on the session's first ACTIVE pass, so a session start never reports a rollover that did not happen (2026-08-09 owner finding). The DEGRADED marker (A6, Q10) is part of these existing LIFE-line and banner fields, not a new state.
- No secrets, no credentials, ever. v0 has no network path; the clause stays dormant but is tested by a journal scan in the DoD.

## 7. Threat model summary

Prevented (with layered witnesses): state file deletion, state file forgery, input inflation while locked (snapshot), local clock manipulation (TimeCurrent only), detach and re-attach, recompile, input change, terminal restart.
Kill-equivalent, detect-only, loudly alerted: terminal kill, terminal offline, AutoTrading off, per-EA algo permission off, broker-side trade disable, investor login, closed or close-only symbol sessions.
Prevented as of the 2026-07-29 threat-model addition in section 9, corrected 2026-07-30 by measurement: SAFE_HALT bypass by a refused init in a FRESH program image erasing the halt file, which the GV mirror then read back as a manual resume.
Accepted residuals, documented: floating-only unflattenable breach that recovers before any deal leaves no history witness (file and GV cover); file plus GV destruction combined with input inflation (accepted friction); owner editing the EA source (out of threat model).
The guardian must never be the hazard: no spurious flatten from deposits or withdrawals (4.3), no flatten from a half-loaded history (SYNCING), no order storms (bounded retries), SAFE_HALT closes nothing.

## 8. Phased build plan and acceptance matrices

### Phase 0, skeleton, no trading calls compiled in
- Single instance: second attach refuses with Alert; crashed-instance takeover works after mutex heartbeat staleness. OnDeinit releases the mutex by zeroing the mutex heartbeat GV (deliberate-release marker), so the takeover row is exercised via hard kill, where the mutex heartbeat stays non-zero and goes stale.
- Crash loop (per Amendments A1 and A4): the process is hard-killed, not gracefully re-inited, CrashLoopMaxInits + 1 times in a row, with each adjacent pair of inits no more than CrashLoopWindowSeconds apart. Show: SAFE_HALT entered, halt file persisted, SAFE_HALT survives a further terminal restart, EA closes nothing throughout, and service resumes only via the documented manual deletion of the halt file.
- Clean re-inits (input change, chart symbol change, recompile) repeated inside the window do NOT accumulate toward SAFE_HALT.
- Timer cadence verified with market closed.
- Input validation matrix: each malformed core input refuses init with INIT_PARAMETERS_INCORRECT; malformed optional input logs WARN and disables only itself; both limits zero refuses init. Malformed is defined concretely: negative where a magnitude is required, zero where a positive value is required, out of documented range (e.g. percent above 100), and non-finite doubles injected via a .set file (NaN or infinity are not reachable through normal MT5 input parsing, so the .set route is the test vector).

### Phase 1, PnL engine, read-only
- Deposit and withdrawal neutrality, both directions, on demo: headroom and limit unchanged. The permanent acceptance test.
- Rollover resets counters at the day anchor (A6: 01:00 server, not server midnight).
- Restart reconstruction: figures before kill equal figures after restart once SYNCING exits.
- Carried-position double-count pinned as expected behavior (F11).
- Deal whitelist matrix: balance, credit, correction deals move realized by nothing and base reconstruction by the exact deal amount.

### Phase 2, lock and persistence, still no trading
- Breach detection: realized-only, floating-only, mixed.
- Lock survives: detach and re-attach, recompile, input change, terminal restart.
- State file deleted while locked: re-lock from derived history at next init.
- State file corrupted: CORRUPT_STATE until next rollover, quarantine file present.
- Windows clock moved forward: no early unlock.
- Limit input inflated while locked: snapshot holds the lock.

### Phase 3, sweep engine
- Breach flattens EA, manual, and mobile positions, and deletes pendings.
- New mobile position while locked closed within seconds; both timer and OnTradeTransaction paths exercised.
- AutoTrading toggled off while locked: continuous alert, no crash, sweep resumes on re-enable.
- Closed-session symbol: bounded retries, distinct logs, no order storm.
- Partial close and hedging-account matrix.

### Phase 4, weekly reporting
- Week window correct across a server DST shift, drift shown inert.
- Static check: no trade API reachable from the weekly path.

### Definition of Done
- All phase matrices green on demo.
- Controlled breach drill on demo: scripted losing trades cross the limit; observe flatten, lock, alert, journal arithmetic, and expiry through a real rollover.
- Bypass drills, each with expected outcome logged: file delete, file forge, AutoTrading toggle, clock change, input inflation, detach and re-attach.
- One-week demo soak with daily reconciliation of guardian PnL against the broker statement within a defined tolerance, plus a journal scan for secrets and spam.
- Only then live.

## 9. Amendments

### A1, 2026-07-29, owner ruling: SAFE_HALT persistence and manual resume

Supersedes the Phase 0 plan's in-memory init counter, which could never accumulate across real crashes, and closes the gap where SAFE_HALT would not survive a terminal restart.

- Home: a separate file MQL5/Files/AccountGuardian/halt_<login>.dat. The state file stays charter-constrained to lock state only; SAFE_HALT is explicitly not a lock, so its evidence gets its own file rather than a quiet widening of the state file's scope. Same atomic-write path (tmp, FileFlush, FileMove FILE_REWRITE) and the same loud-failure semantics as the state file.
- Contents: format version, account login, session records (init timestamp, clean-exit flag), halt flag, halt reason, halt time, checksum.
- Crash counting: at init, the EA appends a session record; at clean OnDeinit it marks the record clean. Crash count = the length of the unclean chain ending at the current session, per Amendment A4, which supersedes this bullet's original rolling-window count. Consequence, unchanged: hard kills accumulate, clean re-inits (input change, chart change, recompile) never do, so a healthy guardian cannot SAFE_HALT itself through routine handling.
- SAFE_HALT entry: crash count exceeds CrashLoopMaxInits. Halt flag, reason, and time persisted immediately. On any later init, a set halt flag means SAFE_HALT regardless of restarts. Closes nothing, sweeps nothing, banner plus periodic Alert, excluded from expiry.
- Manual resume, the documented official procedure: a human deletes halt_<login>.dat while the EA is stopped, then restarts. Deliberate act, not a side effect. No input toggle (inputs are accident-prone and already treated as suspect while locked). The EA logs a RESUMED_FROM_SAFE_HALT line when it boots and finds no halt file after having previously halted (detected via the halt flag it last persisted to the GV mirror, best effort).
- Halt-file corruption: checksum fail means quarantine as .bad plus loud WARN, then start a fresh file seeded with the current session. Fails toward the guardian running, because SAFE_HALT means no protection at all; the loud WARN keeps it visible.
- Clock exemption: session timestamps and the mutex heartbeat timestamp use the local clock, exempt from the Q7 TimeCurrent-only rule. Q7 governs expiry and anchor decisions; mutex staleness and crash counting are neither. TimeCurrent freezes in dead markets, which would fake staleness (false takeover) and make crash timestamps unrecordable offline. Worst-case clock manipulation here only avoids entering SAFE_HALT, a state the owner may exit manually anyway.

### A2, 2026-07-29, owner ruling: naming discipline, editorial only

The bare word "heartbeat" is banned from this document and from the ledger. Two distinct things had been sharing it: the AG_HB_<login> GlobalVariable that proves a live instance, now always "mutex heartbeat", and the external dead-man ping of the deferred visibility phase, now always "network heartbeat". The once-per-minute journal line in section 6, which is neither of those, is now the "liveness journal line". No obligation, algorithm, or acceptance row changes; this amendment is terminology only. Code comments still carry the older wording and will be brought into line with the next code change rather than by a change made solely for it. docs/REVIEW_v0.md keeps its original wording: it is the review as delivered and is not rewritten after the fact.

Deferred-phase note carried here so it is not lost: the external healthchecks.io dead-man check belonging to the deleted prior project has been deleted by the owner. When the visibility phase opens, provision a fresh check with a new UUID. The old UUID is never reused.

### A3, 2026-07-29, owner ruling: proof of life

"Every state, including SYNCING and LOCKED, emits a periodic proof-of-life journal line at a fixed interval carrying: current state, seconds in state, and the specific condition being waited on where the state is transitional. A state the EA can occupy indefinitely while emitting nothing violates fail-visible: a stuck guardian and a healthy one must never look identical from outside."

This supersedes the section 6 scoping of that line to ACTIVE. Rationale from the incident that produced the ruling: the EA sat in SYNCING with a dead timer and emitted nothing for hours, and the silence was indistinguishable from healthy waiting. The line is never suppressed by verbosity. Seconds-in-state and the interval use the local clock, so they advance in a dead market; the Q7 TimeCurrent rule governs expiry and anchors, which this is not.

Obligations attached: a transitional state must name the condition it waits on, and where that condition is not yet implemented the line says so explicitly rather than reading as an idle wait.

### A4, 2026-07-30, owner ruling: crash-loop primitive and window default

Supersedes the rolling-window counting of Amendment A1. The halt file format is untouched: this changes how existing records are read, not what is written.

- Primitive (R1): SAFE_HALT trips when more than CrashLoopMaxInits **consecutive** unclean sessions exist and **each adjacent pair of inits** lies within CrashLoopWindowSeconds of the other. The count is the length of the unclean chain ending at the current session, found by walking back from the newest record and stopping at the first clean record or the first adjacent init pair further apart than the bound.
- What changed and why it matters: A1 counted every unclean record inside a window anchored on "now", so a clean session did not reset anything and unrelated deaths spread across a window could accumulate. The chain is anchored on adjacent init pairs only and never on the current time, which is precisely what makes one clean record reset it. Grounded in the 2026-07-30 measurement that routine shutdowns and routine re-inits both produce clean records, so only genuine process deaths accumulate.
- CrashLoopWindowSeconds default becomes 300 and is redefined as the pairwise gap bound, not a rolling window (R2, absorbed into R1 rather than deferred). Under the conjunction the discriminating work moves to consecutiveness, so a wide bound is cheap: unrelated unclean deaths are hours or days apart, real crash loops are seconds to minutes apart. 300 catches a slow terminal-level crash-restart loop that 60 would miss, while the measured 30 to 40 second kill cycle sits comfortably inside it.
- Backward clock steps (owner ruling 2026-08-04): a negative gap between two adjacent inits, which is what a backward local clock step produces, counts as inside the bound and does not break the chain. Breaking on a negative gap would let a single clock change disarm the count in one step, which is worse than the timestamp-compression residual the threat model below already accepts. The chain therefore errs toward tripping in both clock directions.

### A5, 2026-08-05, owner ruling: transition-table conformance, table moves and code stands

Found by the A10 conformance sweep of 2026-08-04, which reconciled 24 observed transition lines against section 2 and found two the table could not account for. The behaviour was correct in both cases and is required by section 8; the table simply failed to enumerate the triggers. Nothing in the code changed under this amendment.

Ground, and it is the load-bearing sentence: the from-state of a transition line is the state the program image was actually in. That is BOOT in a fresh image, and the surviving prior state in an in-place re-init. This ground replaces an earlier formulation, that every init is a fresh image from BOOT, which measurement contradicts: the three SYNCING to SYNCING lines observed on the deployed lineage are in-place re-inits, each preceded within 13 milliseconds by a deinit reason=5 carrying timer_armed=1 and tick counts of 1806, 1819 and 14, whereas a fresh image reads zero on both counters. The fresh-versus-inherited discriminator is already FINAL in the section 9 threat model and this amendment is written to agree with it rather than contradict it.

- F1: the boot to SYNCING row's From cell widens to "boot in a fresh image, or the surviving prior state in an in-place re-init". This makes the observed SYNCING to SYNCING line conforming, and with it the unobserved but emittable SAFE_HALT to SYNCING produced by a manual resume executed against an inherited image. No new row is needed.
- F2: the any to SAFE_HALT row splits in two. A boot to SAFE_HALT row carries the chain trip of A4, which only a fresh image can reach. An any to SAFE_HALT row carries re-entry on a halt flag persisted from an earlier session, the obligation section 8 already imposes. The From column of the re-entry row stays "any" deliberately: narrowing it to boot would make SAFE_HALT to SAFE_HALT non-conforming, and that line is emittable through AccountGuardian.mq5:171 when an input edit lands on an already halted chart.
- Third edit, riding along from a side observation recorded with the same sweep: the SAFE_HALT action cell said "periodic Alert" while the code raises one Alert per session at entry or re-entry and none from OnTimer. The cell now reads "one Alert at entry or re-entry". The document was describing behaviour the code never had.

Evidence: docs/evidence/a10-transition-conformance-2026-08-04.md. Note carried for anyone re-deriving this later: only the re-entry line exists in the deployed build's own output, because the 16:37:04 trip session was hard killed before its output flushed, so the trip line rests on the halt file as read back by the next image.

### A6, 2026-08-09, owner ruling: Phase 1 day anchor, PnL engine, interim breach posture

Delivered by the Phase 1 kickoff plan (docs/PLAN_PHASE1_PNL_CORE.md), all ten questions RULED FINAL 2026-08-08/09 (LEDGER DECISIONS). Numbered A6 rather than A5 because A5 (above) already belongs to the unrelated A10 transition-table findings, merged to main first per the ledger's split-files ordering so this amendment lands onto a SPEC that already carries it. Implemented in Stage 2 through 4 of the same plan (worktree-phase1-pnl-core).

- **Q1 (day anchor):** section 4.1's server-midnight floor is replaced by a fixed 01:00-server floor, `AG_DAY_ANCHOR_OFFSET_SECONDS`, a compile-time constant deliberately not an input, per the AG_LIFE_INTERVAL/AG_MUTEX_STALE precedent that a value able to disable a guarantee is core or nowhere. Owner commits to a REVISIT after the 2026-10-25 to 2026-11-01 broker DST-peg harvest.
- **Q8 (anchor sanity, 4.1a):** an in-memory high-water-mark latch added alongside the anchor. A forward jump of more than one day is announced loudly; a backward step is unaffected. Never persisted. The original "halts the pass rather than narrowing the window" behaviour is SUPERSEDED by the 2026-08-09 alert-and-advance amendment below.
- **Q3 (DEAL_FEE):** the per-deal formula in 4.2 and 4.3 gains DEAL_FEE, applied uniformly everywhere DEAL_PROFIT is read.
- **Q4 (boundary second):** DEAL_TIME >= anchor counts to the new day, which is HistorySelect's own inclusive-from semantics; no special-cased comparison was added anywhere.
- **History upper bound:** 4.2's `HistorySelect(anchor, now)` is replaced by `HistorySelect(anchor, AG_HISTORY_SELECT_TO)`, a clock-independent `D'3000.01.01'` constant, discharging the Phase 0 ISSUES obligation that a frozen or backward-stepping clock must never truncate the selection window.
- **Q2 (interim breach posture):** the deployed Phase 1 build takes no lock action on breach; enforcement is Phase 2. Loud ALERT plus a journal arithmetic line, repeated at `AG_LIFE_INTERVAL_SECONDS`, state stays ACTIVE. Owner-sanctioned window, section 4.4.
- **Q9 (coherence deferral):** a breach conclusion with an unchanged `HistoryDealsTotal()` from the prior pass defers its declaration by exactly one pass; the next pass always declares. Section 4.4.
- **Q10 (DEGRADED):** while disconnected, ACTIVE performs no breach evaluation and raises no ALERT; LIFE line and banner show DEGRADED with the last-known figures, the DEGRADED prefix carried on the numbers field group itself and not only on waiting_on (2026-08-09 owner finding). Reconnect does not evaluate immediately: per the 2026-08-09 owner ruling below (reconnect coherence), it re-enters gated on history stability. Section 4.4, and section 6 records the marker as an existing-field addition, not a new state.
- **Reconnect coherence, 2026-08-09 owner ruling, amending Q10's "immediate clean re-evaluation" wording:** recovery from DEGRADED requires the same history-stability discipline as the SYNCING exit condition. On the first connected pass after DEGRADED, breach evaluation does not run until `AgHistoryStable(HistoryStablePolls)` passes again; the LIFE line shows the live poll count while waiting, prefixed RESYNC to read distinctly from initial SYNCING. State stays ACTIVE throughout, no transition. Q9's one-pass coherence deferral is unchanged for the connected steady state; it was ruled for a one-tick sync gap, not a post-disconnect resync, and applies only once evaluation has resumed. Q10's "immediate clean re-evaluation on reconnect, no additional wait" wording is superseded by "immediate re-entry to evaluation, gated on history stability." Rationale: a disconnect is exactly the condition the stability counter exists for.
- **Anchor sanity amendment, 2026-08-09 owner ruling, superseding Q8's halt-the-pass behaviour: alert-and-advance.** A forward jump of more than one day raises the loud ALERT naming both anchors, then ACCEPTS the fresh anchor and advances the high-water mark, so evaluation continues and the condition self-clears after one pass. No pass is ever halted. The ALERT is cadence-capped at `AG_LIFE_INTERVAL_SECONDS`, matching the Q2 breach ALERT, with the journal line still written on every occurrence. Ground, measured live rather than argued: the original rule could not self-clear against a forward-only clock, because self-clearing required the fresh anchor to fall BACK within one day of the retained mark. The measured weekend freeze holds the Friday 01:00 anchor across roughly 48 hours and lands on Monday 01:00 at the reopen, a three-day advance, which is exactly the signature the rule treated as an attack. Any instance running across a weekend would therefore have stalled evaluation permanently until restart, while emitting an uncapped Alert popup every timer tick. Owner's ground for the direction of the fix, on the record: a guardian that stops computing is fail-open and worse than a widened window, per the A4 precedent that the system errs toward staying live and loud. Found on the Stage 5 deploy of 2026-08-09 by source read before the reopen it would have fired at; the amendment shipped in the same session.
- **Rollover-line seeding, 2026-08-09 owner finding.** The day-rollover latch is seeded on the first ACTIVE pass of a session WITHOUT logging a line. Previously the latch initialised to zero, so every session start emitted a rollover that had not happened, naming `old_anchor=1970.01.01 00:00:00` and a jump width measured from the epoch. The line is observability, so the defect was not arithmetic, but it asserted an event that did not occur and it polluted the exact artifact the P1-A acceptance row closes on.
- **Build label, 2026-08-09 owner finding.** The OnInit journal line's `build=` field read `Phase0` in the Phase 1 build and is corrected to `Phase1`. Standing rule 7 names runtime journal behaviour as the only measure of what is actually running, so a build that misreports its own identity in that channel undermines the one instrument this project uses to establish it.
- **Observability (4.5):** the ACTIVE proof-of-life line and the banner gain the governing numbers, anchor/realized/floating/base/limit/pnl_vs_limit; the day-rollover line logs old anchor, new anchor, jump width, and is seeded silently on the session's first ACTIVE pass per the amendment above. Section 6.
- **Section 8:** the Phase 1 "rollover resets counters at server midnight" row is reworded to "at the day anchor," since Q1 moved what the anchor means.

Nothing in this amendment reopens or argues Q5, Q6 or Q7, which touch Phase 1 only as constraints already satisfied by the design above (Q5: the deposit/withdrawal-neutrality acceptance test in 4.3 is unchanged in form; Q6: the LOCKED/snapshot seam this amendment's ACTIVE-only logic does not touch; Q7: every clock decision above uses TimeCurrent exclusively, per the existing Clock.mqh prohibition). Evidence: docs/evidence/phase1-stage2-clock-vectors-2026-08-09.md, docs/evidence/phase1-stage3-pnl-engine-2026-08-09.md, docs/evidence/phase1-stage4-wiring-2026-08-09.md.

### Threat-model additions, 2026-07-29

- Clock manipulation across repeated hard kills could compress session timestamps into the crash-loop window and force a false SAFE_HALT, disarming the guardian. Accepted: it requires repeatedly killing the terminal, which is already conceded as kill-equivalent and detect-only, so the adversary gains nothing over simply leaving the terminal dead.
- SAFE_HALT bypass via a refused init, found 2026-07-29 by source read before any test row ran, and demonstrated against build 694d570 on 2026-07-30. OnDeinit runs after a refused OnInit, and it saved the halt model unconditionally. On that path AgHaltLoad has not executed, so the model is default-constructed empty, and writing it erases every session record and clears the persisted halt flag on disk.

  Precision added 2026-07-30 by owner ruling after measurement, because the boundary is what makes this testable: erasure requires a refusal inside a FRESH program image, not merely a refusal. A refusal in an INHERITED image is harmless. MQL5 re-initializes an EA in place when its inputs change, so OnDeinit and OnInit run inside the still-loaded program with every global intact; the refused init then inherits the halt model its predecessor loaded, and the unconditional save writes that populated model back. A fresh image resets globals, so the same refusal writes emptiness. The discriminator is visible in the journal: the deinit line reports timer_armed=0 and timer_ticks=0 for a fresh image against non-zero values for an inherited one. Measured on 2026-07-30 with both cases in one log, same inputs and same alert text, opposite consequence.

  Fresh-image routes that reach a refusal, all equivalent for this purpose: attaching the EA to a chart from the Navigator, attaching a second instance and letting the mutex refuse it, recompiling the EA, and starting the terminal with the EA restored from a saved chart profile. MT5 seeds a fresh attach from the last-used inputs for that EA and persists them across terminal restarts through the chart profile, so a malformed value set once keeps producing refusals with no further human act. The GV mirror AG_HALT_<login> still reads 1, so the next init sees GV-set against file-clear, concludes a human deleted the halt file, and logs RESUMED_FROM_SAFE_HALT. A malfunctioning guardian therefore returns to service with no human act, violating the manual-restart-only ruling. Trigger is trivial and needs no privilege: attach a second instance and let the mutex refuse it. Every config-refusal return reaches the same path. Classified as a bypass, not data loss. Fixed by the obligation below.
- General obligation, binding beyond the halt file: a persistence model that was never loaded is never written. Any save path must be able to prove the model it holds came from a load or from a deliberate initialization, never from default-constructed emptiness. Applies equally to the lock state file and to any future artifact carrying lock or halt state.
- Manual-resume detection is inherently best-effort: it infers a human act from a GV-versus-file mismatch, and any other route to that mismatch produces the same false positive. After the fix above the mechanism is sound for the known divergence route. Revisit it if another route appears rather than treating the inference as reliable.
- common.ini carries [Experts] Account=1, "disable automated trading when the account changes". A login switch therefore disarms automated trading silently while the EA stays attached, which stops execution without any visible detach. Enumerated here under the Q3/F2 trade-disallowed family. Production posture (Account=0 as a documented requirement, verified in the Definition of Done) is a later ruling, not part of this amendment.
