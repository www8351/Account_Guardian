# Phase 1 Kickoff Plan: Daily PnL Core

Planner output, 2026-08-08, second pass same day. Delivered in plan mode as a session plan file and captured into the repo on explicit owner authorization, the fourth such capture after docs/REVIEW_v0.md, docs/PLAN_PHASE0.md and docs/DESIGN_PHASE1_2.md. This copy is the governance record; implementation is measured against it. Planning only: no code was written and no source file was touched in either pass. The second pass verified the first pass's context alignment against an unmerged branch this plan had not read, corrected a SPEC amendment numbering collision, updated one open question, recorded a process divergence, and added three new open questions; none of it reopens the kickoff ruling itself, which stands FINAL.

Planning session only. No code written, no source touched. Everything below was re-derived this session from LEDGER.md (read in full, 434 lines), SPEC_v0.1.md, docs/DESIGN_PHASE1_2.md, docs/PLAN_PHASE0.md, and the seven MQL5 sources. Repo state derived fresh: main at `2291a3b` ("chore: token usage badge"), working tree clean except `.gitignore` modified, four worktrees present (`a9-phantom-audit` 461c415, `phase0-close` 5a1772a, `phase0-plan-capture` 3e18c48, `stage5a-crashloop` 3cdcec9). No commit has touched `MQL5/` since merge `28c29a4`, so the deployed-source lineage statement in the A10 sweep still holds.

---

## 1. Context alignment

### FINAL decisions touching Phase 1, quoted from LEDGER DECISIONS

Every entry below is closed. Nothing in this plan reopens or argues any of them.

* **Q1 (2026-07-29):** "DAILY_BREACH locked_until = next day anchor." Phase 1 owns `AgNextDayAnchor`, which Phase 2 expiry consumes, so the anchor rework must keep Q1 derivable.
* **Q2/F1 (2026-07-29):** "Percent-limit base = current balance minus the sum of ALL deals since the day anchor, trading and balance types alike, which equals the day-anchor balance reconstructed live, no caching."
* **Q4/F9 (2026-07-29):** core config malformed or both limits zero refuses init; optional malformed is off plus WARN. `AgValidateLimits` (Pnl.mqh:37) already enforces this.
* **Q6 (2026-07-29) + Q6 clarification (2026-07-30):** snapshot governs the locked window; live-input fallback only when no valid snapshot exists. Phase 2 material, quoted here because the Phase 1 seam must not preclude it.
* **Q7/F5 (2026-07-29):** "All expiry and anchor decisions use TimeCurrent exclusively. Never TimeTradeServer, never TimeLocal." Governs the whole anchor design below.
* **Q8 (2026-07-29):** "Dual limits, percent and fixed currency, stricter wins, 0 disables each, both zero refuses init." Min over enabled candidates only (design doc item 2 names the naive-min trap).
* **F11 (2026-07-29):** "A position carried across the rollover counts its floating loss against day N and its full realized result against day N+1. Deliberate conservative double-count, protected by a permanent acceptance test."
* **F12 (2026-07-29):** "Realized whitelist = DEAL_TYPE_BUY and DEAL_TYPE_SELL only... balance-type deals participate only in the Q2 base reconstruction."
* **F13 (2026-07-29):** timer-driven, EventSetTimer(1), OnTradeTransaction acceleration only, OnTick unused.
* **Clock exemption (2026-07-29, ratified):** crash-loop session timestamps, mutex heartbeat, proof-of-life interval, seconds-in-state use the local clock. Phase 1 adds no new exemption and touches none of these.
* **Never-loaded-never-written (2026-07-29):** "A persistence model that was never loaded is never written." Phase 1 persists nothing, so the obligation is honored vacuously; stated so nobody widens Phase 1 persistence casually.
* **Lock artifacts quarantined, never deleted (2026-07-29).** Phase 1 test procedure keeps the Phase 0 backup discipline for the halt file during kill/relaunch rows.
* **Epsilon (2026-07-30):** "Acceptance-test float comparisons... flat 0.01 account-currency-unit epsilon. The live breach comparison... must err toward breach: total <= -limit + epsilon is acceptable."
* **Market Watch composition (2026-08-01):** "Market Watch is XAUUSD.ecn, US100.ecn and XAGUSD.ecn only. BTCUSD.ecn is removed and never returns. All subscribed instruments are 24/5, so the weekend close is a reliable no-tick window by design." Consequence quoted with the ruling: the frozen-upper-bound finding is "a Phase 1 correctness obligation, not closed."
* **A4 negative gap (2026-08-04):** backward clock step counts as inside the crash-chain bound, "the chain therefore errs toward tripping in both clock directions." Precedent for direction-of-error choices under a misbehaving clock, and the Stage 5a precedent that removed TimeLocal from comparisons entirely.
* **Merge gate (2026-08-03):** "A branch merges to main when the work in that branch is complete and proven... 'the work in that branch' means all of it." Owner instruction still required. Merge mechanics unchanged.
* **Remote state (2026-08-04):** executor never pushes; no ledger claim about remote position as durable fact.
* **Ratchet build decision (2026-07-30):** FINAL to build, Phase 2, mechanism UNRULED. Phase 1 takes no dependency on it.

### Phase 0 obligation carried into Phase 1, quoted from ISSUES

"Phase 1 obligation: the history select upper bound must not be a frozen clock." Grounds in the same entry: SPEC 4.2 selects history over (anchor, now); a frozen `TimeCurrent` upper bound truncates the window, which is fail-open under-counting, and the measured 25 h backward step (2026-08-01, 23:26:38 reconnect rewound TimeCurrent from 2026.08.01 23:02:41 to 2026.07.31 23:57:59) truncates it further in the same fail-open direction. In scope, closed by Stage 3 below.

### Kickoff ruling to record

Owner ruling 2026-08-05, recorded FINAL in DECISIONS at kickoff, after this plan's investigation is accepted as delivered: **day-anchor base = account Balance, trading day starts 01:00 Israel time.** The base clause is consistent with Q2 as already frozen (the base is the anchor-moment balance, reconstructed live from Balance minus the all-deals sum, never Equity, never cached). The 01:00 Israel clause replaces SPEC 4.1's "floor of TimeCurrent to server-day midnight" and requires a SPEC amendment, numbered A6 (see the 2026-08-08 correction note in section 4.6: worktree-a9-phantom-audit already carries amendment A5, ruled and applied 2026-08-05 for the A10 transition-table findings, unmerged to main as of this writing).

---

## 2. Stage 1, blocking investigation (delivered here, banked as evidence when work starts)

Facts with method. Nothing below is an assumption; where a fact is not yet measurable it is flagged as exactly that.

### 2.1 Israel-to-server clock mapping

* **Which clock computes "01:00 Israel": TimeCurrent, with a fixed offset constant, and nothing else.** Q7 (FINAL) forbids TimeTradeServer and TimeLocal in anchor decisions; TimeGMT is TimeLocal-derived (local Windows clock minus the OS timezone offset), forgeable the same way, and is treated as banned by the same reasoning.
* **Where each clock source stands in the design** (grep of the current tree this session):
  * `TimeCurrent`: anchor and window arithmetic (Clock.mqh:18 `AgServerNow`), display timestamps. Phase 1 adds: one sample per evaluation pass feeds anchor, window, sums, and comparison, so a mid-pass clock move cannot split an evaluation (see 4.2).
  * `TimeLocal`: zero uses in any Phase 1 decision path. Remains only in the FINAL-exempted Phase 0 uses: halt session timestamps (Persist.mqh:213, 259), mutex heartbeat (Persist.mqh:277, 286, 318), life-line pacing (Log.mqh:69), seconds-in-state (State.mqh:64, 74), and two display-only banner strings. The Stage 5a precedent (TimeLocal removed from the chain-walk comparison, A4) is respected: no Phase 1 comparison mixes clocks, ever.
  * `TimeGMT`: zero occurrences in the codebase (grep, this session). Stays at zero.
  * `TimeTradeServer`: zero occurrences except the prohibition comment (Clock.mqh:5). Stays at zero.
* **Measured server-to-Israel offset:** R3 (LEDGER ACTIONS 2026-07-30): "server clock equals machine clock, broker GMT+3, offset about zero," established by an identity chain of process start, journal stamp, TimeCurrent body, TimeLocal record, file mtimes. The machine runs Israel civil time, so in Israel summer (IDT, UTC+3) server time equals Israel time to within the measured 2 s skew (2026-08-03 banner proof: every LIFE line carried server = local + 2 s). **Therefore 01:00 Israel = 01:00 server while the server tracks Israel's offset, which is the measured state today.**
* **Behavior under the frozen clock (measured ~48 h weekly):** an anchor that floors TimeCurrent does not move while TimeCurrent is frozen. The anchor holds the last pre-freeze day and adopts the new day at the first advancing evaluation. Weekend measurements (A8 harvest, 2026-08-03): freeze from Friday 23:57:59 server (gold close stamp, 2026-07-31 was a Friday) to Monday 01:00:20 server (first advancing LIFE line). Consequences derived in 2.3.
* **Behavior under the measured 25 h backward step:** a stateless floor recomputes a lower anchor, the window widens backward, realized and base re-derive over the wider window, which double-counts nothing inside one pass and errs strict (prior-day losses count against today until the clock recovers). The one edge-triggered artifact Phase 1 adds (the day-rollover journal line) is latched monotonic: it fires only when the freshly computed anchor exceeds the last logged anchor, so a backward step can neither double-log a day nor skip one (a forward jump across several anchors logs once, naming the jump width). No stored anchor participates in any windowing decision; the latch is observability only.

### 2.2 DST divergence windows

* **Israel side, statutory and hardcodable (method: Israeli law, fixed rule since 2013):** DST starts the Friday before the last Sunday of March at 02:00, ends the last Sunday of October at 02:00. Concretely: ends 2026-10-25, starts 2027-03-26, ends 2027-10-31.
* **Server side (method: vendor documentation plus own measurement, not yet measured across a transition):** JustMarkets help center states server time is GMT+2 in winter, GMT+3 in summer ([time zone article](https://get.justmarkets.help/hc/en-us/articles/14298246774428-How-to-%D0%A1hange-a-Time-Zone-in-MetaTrader), [trading hours article](https://get.justmarkets.help/hc/en-us/articles/14206580923420-What-Are-the-Trading-Hours-on-JustMarkets)). The industry-standard peg for GMT+2/+3 seasonal servers is the US DST calendar (server day boundary tracks the 17:00 New York close). Own measurement is consistent with a New York peg: the measured Monday reopen at 01:00:20 server equals Sunday 18:00 New York under GMT+3/EDT, the metals-session convention. **The peg is not yet a measured fact.** The first measurable transition is 2026-10-25 to 2026-11-01; a standing measurement obligation is logged in Stage 1 to capture, from the journal's dual-clock LIFE lines, exactly when the server offset moves relative to the machine clock.
* **Divergence windows, per candidate policy** (server minus Israel, outside these windows the offset is 0):
  | Server policy | Autumn 2026 | Spring 2027 | Elsewhere |
  |---|---|---|---|
  | US calendar (best supported) | +1 h for 2026-10-25 → 2026-11-01 | +1 h for 2027-03-14 → 2027-03-26 | 0 |
  | EU calendar | ~0 (same Sunday in 2026) | −1 h for 2027-03-26 → 2027-03-28 | 0 |
  | Fixed GMT+3 year-round | +1 h for the whole Israel winter | same window | 0 in Israel summer |
* **What the anchor does inside a divergence window** depends on the open ruling Q1 below. With the recommended fixed `01:00 server` anchor: during a +1 h window the anchor fires at 00:00 Israel civil, one hour early; day bucketing shifts by one hour; nothing else moves. With a US-pegged server the Monday anchor stays aligned with the weekend reopen year-round, because both are pinned to the same server hour. An Israel-civil-corrected anchor would instead need the server policy as a fact, which does not exist yet as a measurement.
* **Server DST transitions are invisible to TimeCurrent by construction:** US and EU transitions land on Sundays, inside the weekend freeze on this Market Watch (FINAL composition, all 24/5), so the server clock step happens while no quote arrives; TimeCurrent never visibly steps from a server DST change, the Monday reopen simply stamps at the new offset. Israel's own autumn transition (repeated 01:00-02:00 hour) also lands on a Sunday inside the freeze. Israel's spring transition is a Friday 02:00, after Friday's 01:00 anchor has passed, and skips 02:00-03:00, which contains no anchor.

### 2.3 Weekend freeze overlap

* **Yes, 01:00 Israel lands inside the weekend freeze, twice every week.** Measured freeze span: Saturday ~00:00 server to Monday 01:00:20 server (A8 harvest, quoted above). Saturday 01:00 and Sunday 01:00 both fall inside it. Monday 01:00 coincides with the reopen boundary itself, measured 20 s before the first advancing line.
* **What the anchor does:** during the freeze the anchor holds Friday 01:00 (the last boundary at or below the frozen stamp of Friday 23:57:59). Saturday's and Sunday's anchors are never observed; they are absorbed as zero-deal spans inside the Friday-anchored window. At the Monday reopen the floor lands directly on Monday 01:00, so the trading week opens with a fresh day and Friday's results stay in Friday's window. No trading deal can execute inside the freeze on this account (24/5 instruments only, FINAL), so the long window mis-attributes nothing. Balance operations can be server-stamped inside a freeze; they are covered by the Stage 3 upper-bound fix and cancel out of Base by the Q2 identity regardless of which day's window they land in.
* **The 5.4-minute midnight freeze** (measured 00:00:18-00:04:48 local pinned at 23:59:56) sits a clear 55 minutes below the 01:00 anchor and does not span it while server time tracks Israel. Inside a +1 h divergence window the anchor maps to 00:00 Israel civil; whether that touches per-symbol dead zones is exactly what the symbol-specification session tables corroborate (owner read, Stage 1).

---

## 3. Phase 1 scope

Per SPEC section 8, Phase 1 is the PnL engine, read-only. In scope: the day anchor per the kickoff ruling, realized and floating and base and limit computation, the SYNCING exit condition, breach arithmetic and its observability, restart reconstruction. Out of scope: LOCKED transitions, state file, GV lock mirror, snapshots, expiry, sweep, ratchet (Phases 2 and 3). Phase 1 writes no persistence artifact at all.

## 4. Design summary

### 4.1 Clock.mqh, anchor rework (pending ruling Q1)

`AG_DAY_ANCHOR_OFFSET_SECONDS = 3600` as a compile-time constant, deliberately not an input: an input that moves the day boundary would let a mid-day change reset the daily window, which is the same inflation-adjacent surface the ratchet ruling exists to close, and the AG_LIFE_INTERVAL/AG_MUTEX_STALE precedent (FINAL) is that a value able to disable a guarantee is core or nowhere.

```
AgDayAnchor(t)     = t - ((t - OFFSET) % 86400)        // last 01:00-server boundary <= t
AgNextDayAnchor(t) = AgDayAnchor(t) + 86400            // Q1 stays derivable
```

Both stay pure functions of TimeCurrent, recomputed every evaluation, never persisted (SPEC 4.1 charter clause unchanged).

### 4.2 Evaluation discipline

One `AgServerNow()` sample per timer pass feeds anchor, window, sums, and comparison. No comparison mixes clocks (Stage 5a precedent). The rollover journal line uses the monotonic latch from 2.1. All Phase 1 state is in-memory, derived, and disposable; a restart re-derives everything from TimeCurrent and broker history.

### 4.3 Pnl.mqh, the engine

* `AgRealized(anchor)`: `HistorySelect(anchor, AG_HISTORY_SELECT_TO)` with `AG_HISTORY_SELECT_TO = D'3000.01.01'`, a clock-independent constant. Proof it cannot exclude deals: selection excludes only deals stamped after the bound; the server cannot stamp a deal beyond real time; the bound exceeds any reachable real time for the life of the product and depends on no clock, so neither a frozen nor a backward-stepping TimeCurrent can move it. (MQL5 datetime domain ends 3000.12.31, platform-documented.) In-loop filter: whitelist per F12, per-deal value per SPEC 4.2, `(DEAL_TIME, DEAL_TICKET)` ordering per the design doc. `HistorySelect` returning false is a loud stability failure, never "zero deals" (design doc item 1, F6).
* `AgDealsSumAll(anchor)` and `AgDayBase()`: the Q2 identity, all deal types, same per-deal formula.
* `AgFloating()`: `POSITION_PROFIT + POSITION_SWAP` over open positions.
* `AgLimitCurrency(base)`: min over enabled candidates only (Q8, naive-min trap avoided).
* `AgHistoryStable(required_polls)`: poll counter per design doc item 1, reset on count change or disconnection, SYNCING exits at `HistoryStablePolls` consecutive stable connected polls.

### 4.4 Wiring and the state seam

OnTimer keeps the existing order: mutex refresh, proof of life, banner, SAFE_HALT early return. **Daily PnL logic never runs in SAFE_HALT** (today's early return at AccountGuardian.mq5:221-222 is kept; the banner keeps showing the halt reason). After it, a per-state dispatch: SYNCING runs the stability check and transitions to ACTIVE when stable (lock witnesses land in Phase 2; the SPEC's "no lock witness" conjunct is vacuously true in a build with no witnesses, stated in a comment naming Phase 2); ACTIVE runs the evaluation and breach arithmetic; LOCKED is an explicit empty case with a comment naming Phase 2, so Phase 2 adds expiry and witness code without touching the SYNCING/ACTIVE branches. `AgWaitingOn` (State.mqh:88-89) starts reporting the live poll count.

### 4.5 Observability (SPEC section 6 extension, part of A6)

The ACTIVE proof-of-life line gains the governing numbers: `anchor`, `realized`, `floating`, `base`, `limit`, `pnl_vs_limit`. The banner replaces the Phase 0 "n/a" with the same numbers. The day-rollover INFO line logs old anchor, new anchor, and jump width. These fields are what let the weekend and freeze rows below close from journal artifacts alone.

### 4.6 SPEC amendment A6 (one block, owner-ruled)

**Correction, 2026-08-08, second pass.** Numbered A6, not A5. Verified this session, against the object store directly, not against any report: `worktree-a9-phantom-audit` (tip `461c415`) carries a FINAL owner ruling of 2026-08-05 on the A10 transition-table findings, applied to `docs/SPEC_v0.1.md` as amendment A5 in commit `669d1ff`, three section 2 table edits unrelated to Phase 1: the boot-to-SYNCING From cell widened, the any-to-SAFE_HALT row split into a boot row and an any row, and the SAFE_HALT action cell corrected. That branch is not merged to main (main is `bb956b2`; `669d1ff` is not an ancestor of main, confirmed by `git merge-base --is-ancestor`; `docs/SPEC_v0.1.md` differs between main and the branch by 15 insertions and 2 deletions, verified by `git diff --stat`). Taking A5 for this plan's amendment would collide the moment that branch merges. Every "A5" reference elsewhere in this document is A6.

**Ordering, corrected 2026-08-08, third pass.** The number is right; the earlier note said nothing about order and that gap is closed here. Main's `docs/SPEC_v0.1.md` is a strict prefix of the branch's copy (the same 15/2 diff above, a plain addition, not a conflict), so writing A6 onto main's SPEC before the branch merges would leave main jumping A4 straight to A6 and would put the future merge conflict directly inside the amendment block, exactly the collision the LEDGER's split-files entry exists to flag in advance. Phase 1 is already blocked on Phase 0 closing and merging (question 6). The order is therefore: the branch merges first, landing A5 on main; A6 is written afterward, onto a SPEC that already carries A5. This plan writes no amendment to any file at this stage; Stage 2 and Stage 3 below assume A5 is already on main when they run.

1. 4.1: day anchor = 01:00 Israel per the kickoff ruling, operationalized per ruling Q1 below; weekend and frozen-clock behavior as in 2.3.
2. 4.2: history selection upper bound is the far-future constant, never a clock-derived value; plus rulings Q3 (DEAL_FEE) and Q4 (boundary second) below.
3. Section 6: LIFE-line and banner field additions of 4.5.
4. Section 8, Phase 1 row: "Rollover resets counters at server midnight" reworded to "at the day anchor."

## 5. Stages

Branch: new worktree `worktree-phase1-pnl-core` from main. Commits per meaningful change. Merge only under the gate ruling on the branch's own proven work, only on owner instruction. Never push.

**Divergence recorded, 2026-08-08 second pass:** the plan's own governing rule was not followed at kickoff. The plan-mode session that wrote this plan committed the LEDGER updates in section 8 directly to main as `bb956b2`, not to a `worktree-phase1-pnl-core` branch, because no code existed yet to isolate and the session treated LEDGER-only bookkeeping the same way prior sessions treated it (the 2026-08-04 and 2026-08-05 ledger-only entries also landed on main directly). Stated for the record rather than corrected retroactively: the branch is created at Stage 2, the first stage that touches a source file.

### Stage 1: Investigation banked, ruling recorded
Goal: bank section 2 as evidence, close the two open measurables, record the kickoff ruling.
Steps: LEDGER ACTIONS entry carrying section 2 with methods; owner reads the session/break tables for XAUUSD.ecn, US100.ecn, XAGUSD.ecn from the Symbols window (GUI, read-only, also still owed to A8 as corroboration); broker DST policy citation recorded; ISSUES entry logging the 2026-10-25 → 2026-11-01 transition-measurement obligation (harvest the dual-clock LIFE lines across it); kickoff ruling recorded FINAL in DECISIONS dated 2026-08-05.
Acceptance rows: ledger entries exist with quoted sources; session tables quoted in the ledger; DECISIONS entry present. Rollback: none needed, ledger-only.

### Stage 2: Clock primitives plus synthetic vectors
Goal: anchor rework proven against synthetic datetimes before anything live consumes it.
Surfaces: Clock.mqh; new test script `MQL5/Scripts/AccountGuardian/AgPhase1ClockVectors.mq5` (repo copy committed, terminal copy deployed per the vectors sync-direction ruling). SPEC A6 items 1 and 4 written.
Vectors (script prints PASS/FAIL per case to the journal): boundary second, one second before and after; frozen input (same t twice); backward step across the boundary (25 h class and 1 s class); forward jump across three anchors; latch behavior for each; `AgNextDayAnchor` equals anchor plus 86400 everywhere.
Evidence: journal lines from one owner double-click of the script, quoted into docs/evidence/ per established practice; compile log 0 errors 0 warnings.
Rollback: revert branch commits, nothing deployed.

### Stage 3: History engine
Goal: Pnl.mqh bodies per 4.3, discharging the frozen-upper-bound obligation.
Surfaces: Pnl.mqh only. SPEC A6 item 2 written.
Acceptance rows (static, from the repo tree): grep zero trade-API references in Pnl/Clock (S1/S2 class re-run); grep zero TimeLocal/TimeGMT/TimeTradeServer in Clock.mqh and Pnl.mqh; grep zero `HistorySelect` calls whose upper bound derives from any clock call; compile 0 errors 0 warnings (Result line plus fresh ex5 mtime per standing rule 6/7, exit code ignored).
Rollback: revert branch commits.

### Stage 4: Wiring, states, observability
Goal: 4.4 and 4.5 in AccountGuardian.mq5, State.mqh, Log.mqh.
Acceptance rows (static plus journal-format): SYNCING→ACTIVE emits exactly one TRANSITION line matching the SPEC section 2 row; LIFE line carries the A6 field list; SAFE_HALT path provably unchanged (diff scoped review, no PnL call reachable from the SAFE_HALT branch); interim breach posture per ruling Q2 wired exactly as ruled.
Rollback: revert branch commits.

### Stage 5: Deploy and live acceptance
Deploy per the standing procedure (owner gate; halt file backed up first with md5; sources copied, all verified by md5 against the tree; compile in terminal tree; kill/relaunch with the 15 s stale-mutex margin). Rows, each closing only on named on-disk evidence with build hash:

| Row | Test | Artifact |
|---|---|---|
| P1-A anchor live | first post-deploy day rollover at 01:00 server | rollover INFO line plus LIFE lines bracketing it |
| P1-B weekend absorption | one weekend harvest: anchor holds Friday through the freeze, adopts Monday at reopen, no Sat/Sun rollover lines | journal scan, quoted lines |
| P1-C restart reconstruction (P1-5) | kill mid-day with deals present, relaunch | PnL figures equal before and after within 0.01, LIFE lines quoted |
| P1-D zero-deal day | any deal-free day | LIFE lines: realized 0, base = balance, PnL = floating |
| P1-E deposit/withdrawal neutrality (DN-1/2/3, P1-1/2/3) | demo balance ops, pending Q5 | base and limit unchanged within 0.01 across each |
| P1-F freeze-window balance op | deposit inside the nightly 00:00-00:05 freeze or the weekend freeze | base unchanged, deal present in the sum despite frozen TimeCurrent, proving the upper bound |
| P1-G whitelist (P1-8) | balance op moves realized by exactly 0 and the base sum by the exact amount | journal arithmetic |
| P1-H F11 double-count | carry a losing manual position across 01:00, close next day | floating against day N, full realized against day N+1, asserted expected |
| P1-I partial close (P1-7) | manual partial close | realized plus floating continuous across the boundary |
| P1-J SYNCING exit (P1-9) | restart with history | poll count visible in AgWaitingOn, exit after HistoryStablePolls stable polls |
| P1-K HistorySelect false (P1-10) | disconnect mid-session | loud WARN distinct from zero-deals, no ACTIVE transition from that tick |
| P1-L breach arithmetic | manual losing trades cross the limit on demo | posture per Q2 ruling observed, arithmetic line carries full numbers |

Rollback: redeploy prior sources from main (`MQL5/` unchanged since `28c29a4` lineage), recompile, kill/relaunch.

### Stage 6: Close-out
LEDGER sync (rows with evidence pointers and build hash), SPEC A6 committed as ruled, merge request to owner under the gate ruling. Never push.

## 6. Mandatory edge-case coverage

| Edge case | Status | Behavior |
|---|---|---|
| EA offline at 01:00 Israel | Decided | Anchor is a pure floor of TimeCurrent recomputed per pass; late start derives the same anchor; full-day reconstruction from history behind the SYNCING stability gate; no memory consulted |
| Backward step crossing anchor | Decided | Stateless recompute widens the window, errs strict; monotonic latch means no double rollover line and no skipped day; vectors in Stage 2 |
| Frozen clock spanning anchor | Decided | Anchor flips at first advancing evaluation; no trading deal can exist inside a freeze on this account (FINAL composition); balance ops covered by the constant upper bound |
| HistorySelect upper bound | Decided | `D'3000.01.01'` constant, proof in 4.3; static row: zero clock-derived bounds; live row P1-F |
| History not synced at init | Decided | Stability counter per design doc item 1; HistorySelect false is loud and concludes nothing; SYNCING blocks ACTIVE until stable |
| Balance ops in history | Decided | F12: excluded from realized, included in base sum; deposit never profit, withdrawal never loss by the Q2 identity; boundary second pending Q4; DEAL_FEE pending Q3 |
| Partial closes, swaps, commissions, fees | Decided except fees | Per-deal formula plus design doc item 1 partial-close analysis; row P1-I; DEAL_FEE pending Q3 |
| Zero-deal day | Decided | Empty fold: realized 0, base = current balance, PnL = floating; row P1-D |
| Breach comparison semantics | Decided definition, open interim posture | SPEC 4.2 quoted: "Daily PnL = realized + floating. Never a balance-delta, never a cached day-start equity." SPEC 4.4: "Breach: daily PnL <= -(limit_currency)". Floating included per F11. Evaluated once per timer tick in ACTIVE from a single TimeCurrent sample; epsilon errs toward breach (FINAL). Interim action on true is Q2 |
| Breach exactly at anchor boundary | Decided for Phase 1 scope | Single-sample rule makes anchor, window, and comparison agree within one pass; at t equal to the anchor the window is empty except per Q4's convention; lock semantics are Phase 2 |
| SAFE_HALT today, LOCKED seam | Decided | PnL logic never runs in SAFE_HALT (early return kept); LOCKED is an explicit empty dispatch case so Phase 2 adds without refactoring |
| Restart mid-day | Decided | Nothing persisted, nothing trusted from memory; anchor and sums re-derived every pass; row P1-C |

## 7. Open questions for owner ruling (nothing here resolves them)

1. **"01:00 Israel" operationalization.** (a) Fixed `01:00 server` anchor, compile-time constant, accepting the divergence-window drift enumerated in 2.2 (the week-anchor precedent in SPEC 4.1 accepts exactly this class of drift, and it keeps the Monday anchor aligned with the reopen under a US-pegged server), or (b) Israel-civil-corrected anchor via the statutory Israel DST rule, which additionally requires the server DST peg as a fact that cannot be measured before 2026-10-25, or (c) another owner definition. Also confirm the offset stays a compile-time constant, not an input.
2. **Interim breach posture in the Phase 1 deployed build.** Enforcement lands in Phase 2, so a real breach during the Phase 1 window cannot lock. Options: (a) loud ALERT plus journal arithmetic line, state stays ACTIVE, repeated at a bounded cadence while the condition holds, or (b) silent computation only. Either way the deployed guardian does not enforce until Phase 2; the owner must sanction that window explicitly.
3. **DEAL_FEE.** MQL5 carries a fourth per-deal money field, DEAL_FEE, absent from SPEC 4.2's three-property formula. The Q2 identity needs every deal's full balance effect, so the recommendation is profit+swap+commission+fee everywhere the formula appears. SPEC wording change, owner rules.
4. **Anchor-boundary second.** A deal stamped exactly at the anchor second: recommended convention is DEAL_TIME >= anchor counts to the new day (base then equals the balance just before the anchor second). SPEC precision, owner rules.
5. **Demo balance operations.** P1-E/F/G need deposits or withdrawals on JustMarkets demo 1200252169. Owner confirms the personal-area capability; if unavailable, those rows need alternate vectors and the plan flags them incomplete rather than closing them by reasoning.
6. **Sequencing versus Phase 0 remainder. DOES NOT CLOSE, still blocking, updated 2026-08-08.** Re-checked against the object store directly rather than against any report. On `main` (`bb956b2`) the Phase 0 remainder is unchanged: A7, A9, and the two A10 rulings are open. On the unmerged branch `worktree-a9-phantom-audit` (tip `461c415`), which this plan's first pass never read, artifact evidence shows more progress and one new blocker: A7 is proven, A9 is proven whole (twelve of twelve vectors), and A10 is ruled and applied as that branch's own amendment A5 (renumbered A6 collision noted in section 4.6). But a 2026-08-06 attempt to close Phase 0 on that branch was itself held open on one gate: whether last-used EA inputs were restored to the ruled defaults is unverified, because the attach that was supposed to write it never happened, and the branch is explicit that the phase is "deliberately not closed and the branch deliberately not merged." So Phase 0 is not closed on any branch, the 2026-07-30 ordering instruction still binds, and this question stays open regardless of which branch's numbers are used. Two governance facts sharpen it further: that branch also carries a FINAL 2026-08-05 ruling that a session report is not evidence for anything, only artifacts are, binding on this plan's own future sessions once merged; and that branch's LEDGER.md and README.md both diverge from main's copies and need a hand union resolve at the next merge, per the ce6964d precedent, before any of this can be read as one file.
7. **Stage 1 scheduling.** The symbol-specification read (GUI, read-only, also owed to A8) and whether it rides the same owner session as the pending A7/A9 batch. Partly overtaken by 2026-08-06 events on the unmerged branch (A8 was reconfirmed closed there on 2026-08-06 without that read, ruled not needed), but the read is still owed as corroboration until the branch merges and the ledger agrees on one copy.
8. **Forward clock jump and the window's lower bound, added 2026-08-08.** The far-future upper-bound constant discharges the frozen-upper-bound obligation on the *upper* bound only. The *lower* bound is the anchor itself, derived from `TimeCurrent`. Section 2.1's backward-step analysis (widen, err strict) does not cover a forward jump: a forward jump advances the anchor and excludes real deals of the current day from the window, which is fail-open under-counting, the same failure class the Phase 0 obligation exists to close. The plan currently treats a forward jump only as a rollover-journal-line concern (section 4.1's monotonic latch), not as a correctness one. Owner rules whether a forward jump needs its own defense (for example, latching the anchor's lower bound to the last-observed anchor rather than recomputing it unconditionally downward-only in the jump direction) or is accepted as a documented residual.
9. **Balance-versus-history coherence within one evaluation pass, added 2026-08-08.** The Q2 identity subtracts a deal sum from a live Balance. If Balance has already updated for a deal that has not yet reached local history (a timing gap between account-info refresh and history sync), Base is wrong by exactly that deal's amount for that one pass, and the limit moves with it. `AgHistoryStable` (design doc item 1) gates only the SYNCING-to-ACTIVE exit, once, not every ACTIVE timer pass. Owner rules whether a per-pass coherence check is needed in Phase 1 (for example, comparing `HistoryDealsTotal()` against the previous pass's count before trusting that pass's Base) or is accepted as a bounded, self-correcting-next-tick residual.
10. **Floating PnL under a stale quote, added 2026-08-08.** `POSITION_PROFIT` is quote-derived. During an intraday disconnect (not the weekend freeze, where nothing is open on a 24/5-only account by the FINAL Market Watch composition), the floating leg can stand still on a stale quote while the realized leg keeps moving from history, so the two halves of one sum come from different instants. Owner rules whether this needs its own detection (for example, gating the floating leg on `TERMINAL_INFO_CONNECTED` the same tick it gates history) or is accepted as within the existing kill-equivalent/detect-only posture for disconnection (SPEC 4.4).

## 8. After approval

Record the kickoff ruling FINAL in DECISIONS (dated 2026-08-05, done, `bb956b2`), log this plan in LEDGER (ACTIONS entry; ISSUES entries for the open questions and the October measurement obligation, done, `bb956b2`), and stop. Second pass, 2026-08-08: context alignment re-run against `worktree-a9-phantom-audit` per the correction above, three new ledger-verified findings folded in (A5-versus-A6 numbering, Phase 0 not closed on any branch, the LEDGER/README split needing a hand union resolve), three new open questions appended (8, 9, 10). Nothing in this second pass reopens or argues the kickoff ruling itself, which remains FINAL. Implementation begins only on a later, separate owner instruction, and not before Phase 0 closes and merges for real.
