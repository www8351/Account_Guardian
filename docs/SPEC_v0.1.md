# AccountGuardian SPEC v0.1

Status: FROZEN 2026-07-29.
Code is measured against this document. Any change requires an owner ruling recorded in the decision log. Source material: docs/REVIEW_v0.md (findings F1-F16) and the owner rulings of 2026-07-29 (Q1-Q8, pinned F11/F12/F13). This spec contains structure and obligations only, no implementation bodies.

## 0. Product statement

Single account-level lockout EA for MetaTrader 5, one JustMarkets terminal, Windows. Daily loss breach: flatten every position and delete every pending order on the account (every symbol, magic, origin, including mobile and manual), then lock until expiry. While locked, anything newly opened is flattened within seconds of the platform accepting a close for that symbol. Weekly PnL is measured and reported only; no weekly code path may lock, close, or sweep. Unlock is time expiry only. No manual override of any kind.

Out of scope v0 (deferred, not deleted): session windows, network visibility (heartbeat, events, dead-man drill), cooperating-EA contract, account-split hardening, any trading logic.

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
- OnTimer at 1 s: everything runs here. Sync check, PnL evaluation, breach check, sweep, expiry check, weekly measurement, heartbeat.
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
| boot | SYNCING | always | log boot, read state file, read GV mirror |
| SYNCING | LOCKED | state file, GV mirror, or derived breach (4.6) says locked | adopt strictest witness |
| SYNCING | ACTIVE | TERMINAL_CONNECTED true and HistoryDealsTotal stable across HistoryStablePolls consecutive polls and no lock witness | log sync duration |
| ACTIVE | LOCKED (DAILY_BREACH) | daily PnL <= -(limit) | snapshot limit and base into state file (Q6), set locked_until = next day anchor (Q1), persist, delete pendings, begin sweep |
| any | LOCKED (CORRUPT_STATE) | state file fails checksum | locked_until = next rollover, computed at boot, never read from the failed file; rename file to .bad, quarantine |
| LOCKED | ACTIVE | TimeCurrent >= locked_until | log unlock; never any other cause |
| any | SAFE_HALT | init count > CrashLoopMaxInits within CrashLoopWindowSeconds | close nothing, sweep nothing, banner + periodic Alert, manual restart only |

SAFE_HALT is not a lock: excluded from expiry, cleared only by manual restart. SAFE_HALT while a lock exists leaves the account unswept by design (guardian code presumed broken); this shadow is documented and drilled, not hidden.

Rollover resets counters; it never unlocks by itself. Unlock happens only through the TimeCurrent >= locked_until comparison. For DAILY_BREACH those two instants coincide because locked_until = next day anchor (Q1, FINAL).

## 3. Persistence format and corruption policy

Single file MQL5/Files/AccountGuardian/state_<login>.dat carrying lock state only:
magic, format version, account login, lock_reason, locked_until, breach_time, limit_snapshot, base_snapshot, checksum over all prior fields.

Write path: write tmp file, FileFlush, FileMove with FILE_REWRITE onto the target (same-folder rename, atomic at filesystem level). FileFlush does not guarantee media fsync; torn writes are absorbed by the checksum plus CORRUPT_STATE policy. Write failure: Alert plus WARN repeated every timer pass, enforcement continues from memory, never silent.

Read policy:
- Checksum fail: CORRUPT_STATE lock until next rollover, quarantine the file as .bad.
- Missing file: never trusted as unlocked. Run the derivation of 4.6.

GlobalVariable mirror: AG_LOCK_<login> = locked_until, AG_HB_<login> = heartbeat timestamp, both written each timer tick and flushed with GlobalVariablesFlush. The 4-week GV lifetime is irrelevant at 1 s refresh.

Authority order: broker history is the authority; file and GV are witnesses (accelerators). Lock at boot = OR over all three.

## 4. Core algorithms (obligations)

### 4.1 Anchors
- Day anchor: floor of TimeCurrent to server-day midnight. Recomputed every evaluation, never persisted.
- Week anchor: fixed offset from server time targeting Sunday 00:00 Israel. No DST table. Deviation up to about 2 h across server and Israel DST shifts lands in a dead market and only touches the report-only path. Inert, affirmed.

### 4.2 Daily PnL
- Realized(window): HistorySelect(anchor, now); sum DEAL_PROFIT + DEAL_SWAP + DEAL_COMMISSION over deals whose type is DEAL_TYPE_BUY or DEAL_TYPE_SELL only (F12, FINAL). All balance, credit, charge, correction, bonus, dividend, interest deals excluded from realized.
- Floating: sum over open positions of POSITION_PROFIT + POSITION_SWAP. Position-level commission is not retrievable in MT5; entry commission already lands in realized via the entry deal.
- Daily PnL = realized + floating. Never a balance-delta, never a cached day-start equity.
- Pinned behavior (F11, FINAL): a position carried across the rollover counts its floating loss against day N and its full realized result against day N+1. Deliberate conservative double-count, protected by a permanent acceptance test.

### 4.3 Base and limit (Q2 amendment, FINAL)
- Base = current balance minus the sum of ALL deals since the day anchor, trading and balance types alike. Algebraically equal to the day-anchor balance, reconstructed live, no caching. Deposits and withdrawals cancel exactly in both directions.
- limit_currency = min headroom of the enabled limits (Q8, FINAL): percent limit = DailyLossPercent% of base; fixed limit = DailyLossCurrency. Stricter wins. 0 disables each. Both zero refuses init (section 5).
- Permanent acceptance test: a deposit or withdrawal moves loss headroom in neither direction.

### 4.4 Breach and sweep
- Breach: daily PnL <= -(limit_currency). On breach: snapshot, persist, lock, delete all pending orders, flatten all positions.
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
- Core class (daily limits, lock behavior): malformed value, or both limits zero, means OnInit returns INIT_PARAMETERS_INCORRECT and the EA visibly refuses to run.
- Optional class (weekly reporting, cosmetics): malformed means that feature fully off plus WARN, never half-enforced.

| Input | Type | Default | Off-value | Class | Notes |
|---|---|---|---|---|---|
| DailyLossPercent | double | 5.0 | 0 | core | percent of day-anchor base |
| DailyLossCurrency | double | 0 | 0 | core | absolute account currency; stricter of the two wins; both zero refuses init |
| WeeklyReportEnabled | bool | true | false | optional | report-only path |
| SweepPeriodSeconds | int | 1 | none | core | clamped 1..5 |
| CrashLoopMaxInits | int | 3 | none | core | within CrashLoopWindowSeconds |
| CrashLoopWindowSeconds | int | 60 | none | core | |
| HistoryStablePolls | int | 3 | none | core | SYNCING exit condition |
| LogVerbosity | enum | NORMAL | none | optional | never suppresses transitions |

No symbol filter, no magic filter. Scope is everything on the account. Single instance per account enforced at init (heartbeat mutex, stale takeover).

## 6. Logging contract

- Every state transition is exactly one structured journal line: server timestamp, from-state, to-state, reason, governing numbers (daily PnL, limit, base, locked_until where relevant).
- The breach line carries the full arithmetic so the drill is auditable from the journal alone.
- Sweep: one line per close or delete attempt with retcode; failure reasons distinct; trade-disallowed states enumerated by name.
- Alert popups mandatory for: breach, lock, unlock, state-write failure, cannot-trade-while-locked, SAFE_HALT.
- Chart banner always shows: current state, lock reason, locked_until, daily PnL vs limit.
- Heartbeat journal line at most once per minute in ACTIVE.
- No secrets, no credentials, ever. v0 has no network path; the clause stays dormant but is tested by a journal scan in the DoD.

## 7. Threat model summary

Prevented (with layered witnesses): state file deletion, state file forgery, input inflation while locked (snapshot), local clock manipulation (TimeCurrent only), detach and re-attach, recompile, input change, terminal restart.
Kill-equivalent, detect-only, loudly alerted: terminal kill, terminal offline, AutoTrading off, per-EA algo permission off, broker-side trade disable, investor login, closed or close-only symbol sessions.
Accepted residuals, documented: floating-only unflattenable breach that recovers before any deal leaves no history witness (file and GV cover); file plus GV destruction combined with input inflation (accepted friction); owner editing the EA source (out of threat model).
The guardian must never be the hazard: no spurious flatten from deposits or withdrawals (4.3), no flatten from a half-loaded history (SYNCING), no order storms (bounded retries), SAFE_HALT closes nothing.

## 8. Phased build plan and acceptance matrices

### Phase 0, skeleton, no trading calls compiled in
- Single instance: second attach refuses with Alert; crashed-instance takeover works after heartbeat staleness.
- Crash loop: threshold enters SAFE_HALT, closes nothing, survives restart, manual resume only.
- Timer cadence verified with market closed.
- Input validation matrix: each malformed core input refuses init with INIT_PARAMETERS_INCORRECT; malformed optional input logs WARN and disables only itself; both limits zero refuses init.

### Phase 1, PnL engine, read-only
- Deposit and withdrawal neutrality, both directions, on demo: headroom and limit unchanged. The permanent acceptance test.
- Rollover resets counters at server midnight.
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
