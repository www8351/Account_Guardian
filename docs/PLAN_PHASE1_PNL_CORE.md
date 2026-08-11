# Phase 1 Kickoff Plan: Daily PnL Core

Planner output, 2026-08-08, second pass same day, third pass 2026-08-09. Delivered in plan mode as a session plan file and captured into the repo on explicit owner authorization, the fourth such capture after docs/REVIEW_v0.md, docs/PLAN_PHASE0.md and docs/DESIGN_PHASE1_2.md. This copy is the governance record; implementation is measured against it. Planning only across all three passes: no code was written and no source file outside this document and LEDGER.md was touched. The second pass verified the first pass's context alignment against an unmerged branch this plan had not read, corrected a SPEC amendment numbering collision, updated one open question, recorded a process divergence, and added three new open questions. The third pass banks all ten owner rulings (the original seven plus the three the second pass added), FINAL in LEDGER DECISIONS, translates the three mechanism-only rulings (Q8, Q9, Q10) into exact primitives with SPEC wording and acceptance rows, and records that the branch carrying the Phase 0 remainder has since merged to main (937c604) with the last-used gate independently closed by owner reading, so Phase 0 is closed in full and this plan's own sequencing question (6) is resolved. None of the three passes reopens the kickoff ruling itself, which stands FINAL, and this pass reopens nothing FINAL either; it records rulings, it does not make them.

**All ten questions are RULED FINAL as of 2026-08-08/09; see LEDGER DECISIONS for the verbatim rulings. Section 7 below is kept as the historical record of the questions asked, each annotated with its ruling and a pointer to where the mechanism lives in sections 4 and 5. Phase 0 is CLOSED; section 7's question 6 is resolved. Implementation still awaits a separate, later owner instruction per section 8.**

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

### 4.1 Clock.mqh, anchor rework (Q1, RULED FINAL 2026-08-08)

`AG_DAY_ANCHOR_OFFSET_SECONDS = 3600` as a compile-time constant, deliberately not an input: an input that moves the day boundary would let a mid-day change reset the daily window, which is the same inflation-adjacent surface the ratchet ruling exists to close, and the AG_LIFE_INTERVAL/AG_MUTEX_STALE precedent (FINAL) is that a value able to disable a guarantee is core or nowhere. Q1 ruled this the fixed 01:00-server operationalization (option a of section 7 item 1 below), confirmed a compile-time constant, with a scheduled REVISIT after the 2026-10-25 to 2026-11-01 harvest measures the broker's actual DST calendar.

```
AgDayAnchor(t)     = t - ((t - OFFSET) % 86400)        // last 01:00-server boundary <= t
AgNextDayAnchor(t) = AgDayAnchor(t) + 86400            // Q1 stays derivable
```

Both stay pure functions of TimeCurrent, recomputed every evaluation, never persisted (SPEC 4.1 charter clause unchanged).

### 4.1a Anchor high-water-mark sanity check (Q8, RULED FINAL 2026-08-08)

**AMENDED 2026-08-09 by owner ruling: alert-and-advance.** The original Q8 ruling below halted the pass; that is superseded. A forward jump of more than one day now raises the loud ALERT naming both anchors, then ACCEPTS the fresh anchor and advances the high-water mark, so evaluation continues and the condition self-clears after one pass. No pass is ever halted, and the ALERT is cadence-capped at `AG_LIFE_INTERVAL_SECONDS` like the Q2 breach ALERT while the journal line still writes on every occurrence. Ground: the halt could not self-clear against a forward-only clock, since self-clearing required `fresh` to fall BACK within one day of the retained mark; the measured weekend freeze advances the anchor three days at the Monday reopen (2.3), so any weekend-spanning instance stalled evaluation permanently while emitting an uncapped popup every tick. Owner's ground for the direction: a guardian that stops computing is fail-open and worse than a widened window, per the A4 precedent that the system errs toward staying live and loud. Found by source read during the Stage 5 deploy of 2026-08-09, hours before the reopen it would have fired at.

Original ruling, kept for the record: keep the highest anchor observed in memory; if a fresh computation yields an anchor more than one day above it, HALT the evaluation loudly with an ALERT naming both anchors, never silently narrow the window. The latch is in-memory only, never persisted, per the never-loaded-never-written decision and Phase 1 persisting nothing; a restart clears it, accepted because a restart re-derives everything from history with no anchor yet to sanity-check against. Everything in that ruling except the halt survives the amendment unchanged.

Mechanism: `g_ag_high_anchor` (datetime, in-memory, seeded to the first `AgDayAnchor` computed this session; no value to compare against on that first pass, so it is simply accepted and never checked backward). Every ACTIVE-state pass computes `fresh = AgDayAnchor(AgServerNow())` exactly as 4.1 already does, then applies the check before using `fresh` for anything:

```
if fresh <= g_ag_high_anchor:
    // backward step or same day, the unchanged 2.1 behaviour: widen, use fresh, err strict.
    // g_ag_high_anchor does NOT recede.
    window_anchor = fresh
elif fresh - g_ag_high_anchor <= 86400:
    // ordinary single-day advance
    window_anchor = fresh
    g_ag_high_anchor = fresh
else:
    // anomalous forward jump (AMENDED 2026-08-09): announce loudly, then ACCEPT.
    // The pass is never halted. Caller announces, because the cadence cap needs
    // the local clock and TimeLocal is forbidden inside Clock.mqh.
    g_ag_anchor_jump_note = "anchor jump accepted: previous_high=" + g_ag_high_anchor
                            + ", accepted=" + fresh
                            + ", jump=" + (fresh - g_ag_high_anchor) + "s"
    window_anchor    = fresh            // accepted: the window is never pinned to a stale anchor
    g_ag_high_anchor = fresh            // the mark ADVANCES, so the condition clears next pass

// in the caller, AgEvaluateActive:
if g_ag_anchor_jump_note != "":
    AgInfo(g_ag_anchor_jump_note)                          // journal line, every occurrence
    if now_local - g_ag_last_anchor_alert >= AG_LIFE_INTERVAL_SECONDS:
        AgAlertEvent(g_ag_anchor_jump_note + " (jump exceeds one day; evaluation continues)")
        g_ag_last_anchor_alert = now_local                 // popup capped, as Q2 already does
```

Self-clearing (AMENDED 2026-08-09): the mark advances on the anomalous pass itself, so the condition clears on that same pass and the next ordinary pass carries an empty note. No restart is required, and unlike the original rule this holds against a clock that only ever moves forward. LIFE-line note: on the announcing pass the ACTIVE `waiting_on` field carries the jump note, "anchor jump accepted: previous_high=<...>, accepted=<...>, jump=<n>s", so the event is never silent; on every other pass it is empty.

SPEC wording, amendment A6, section 4.1 addition (as amended 2026-08-09): "If a freshly computed day anchor exceeds the highest anchor yet observed by more than 86400 seconds, that pass announces the jump loudly, with a journal line on every occurrence and an ALERT naming both the previous high anchor and the accepted one, capped at `AG_LIFE_INTERVAL_SECONDS`. The fresh anchor is then accepted and the high-water mark advances to it; no evaluation pass is halted. The retained high anchor is in-memory only and is not persisted across a restart."

Acceptance rows, Stage 2 synthetic vectors, `AgPhase1ClockVectors.mq5`, 26 checks total: feed a two-day-plus forward jump after establishing a baseline anchor; expect acceptance (`window_anchor` equals `fresh`, `g_ag_high_anchor` advanced to `fresh`, the note naming both anchors and carrying the previous value); then an ordinary pass, expecting the note to clear with no restart. A further vector confirms the unchanged backward-step path still widens using `fresh`, never substitutes `g_ag_high_anchor`, and sets no note. A fourth vector, added 2026-08-09, replays the exact live signature the original rule stalled on: seed Friday `2026.08.07 01:00:00`, then feed Monday `2026.08.10 01:00:00`, expecting acceptance, the mark advancing, `jump=259200s` named in the note, and the note cleared on the following pass.

### 4.2 Evaluation discipline

One `AgServerNow()` sample per timer pass feeds anchor, window, sums, and comparison. No comparison mixes clocks (Stage 5a precedent). The rollover journal line uses the monotonic latch from 2.1. All Phase 1 state is in-memory, derived, and disposable; a restart re-derives everything from TimeCurrent and broker history.

### 4.3 Pnl.mqh, the engine

* `AgRealized(anchor)`: `HistorySelect(anchor, AG_HISTORY_SELECT_TO)` with `AG_HISTORY_SELECT_TO = D'3000.01.01'`, a clock-independent constant. Proof it cannot exclude deals: selection excludes only deals stamped after the bound; the server cannot stamp a deal beyond real time; the bound exceeds any reachable real time for the life of the product and depends on no clock, so neither a frozen nor a backward-stepping TimeCurrent can move it. (MQL5 datetime domain ends 3000.12.31, platform-documented.) In-loop filter: whitelist per F12, per-deal value per SPEC 4.2 as amended by Q3 (see below), `(DEAL_TIME, DEAL_TICKET)` ordering per the design doc, boundary convention per Q4: `DEAL_TIME >= anchor` counts to the new day, matching `HistorySelect`'s own inclusive-from semantics with no special-cased comparison needed anywhere. `HistorySelect` returning false is a loud stability failure, never "zero deals" (design doc item 1, F6).
* `AgDealsSumAll(anchor)` and `AgDayBase()`: the Q2 identity, all deal types, same per-deal formula, DEAL_FEE included per Q3.
* **Per-deal formula, RULED FINAL 2026-08-08 (Q3):** `DEAL_PROFIT + DEAL_SWAP + DEAL_COMMISSION + DEAL_FEE`, everywhere the formula appears: `AgRealized`, `AgDealsSumAll`/`AgDayBase`, and the design doc item 3 derived-lock replay (Phase 2, cited here since the formula is shared). Supersedes the three-property formula design doc items 1 and 2 stated. SPEC wording, amendment A6, section 4.2: "Per-deal value: DEAL_PROFIT + DEAL_SWAP + DEAL_COMMISSION + DEAL_FEE, uniformly over every deal type the formula touches (realized whitelist per F12, or all types for the Q2 base sum)." Acceptance row, Stage 3: a synthetic or demo deal carrying a non-zero DEAL_FEE moves `AgDayBase` by exactly the fee amount in addition to profit/swap/commission; static row confirms `DEAL_FEE` is read wherever `DEAL_PROFIT` is in the two functions above.
* `AgFloating()`: `POSITION_PROFIT + POSITION_SWAP` over open positions.
* `AgLimitCurrency(base)`: min over enabled candidates only (Q8 of the original architecture review, naive-min trap avoided; unrelated to Phase 1 kickoff's own Q8 anchor ruling in 4.1a, same label from two different rulings, disambiguated here so a later reader does not conflate them).
* `AgHistoryStable(required_polls)`: poll counter per design doc item 1, reset on count change or disconnection, SYNCING exits at `HistoryStablePolls` consecutive stable connected polls.

### 4.3a Breach-declaration deferral (Q9, RULED FINAL 2026-08-08)

Ruling: on any evaluation pass where the computed result moves abruptly with no new deal visible in the selected history, defer the breach declaration by one timer pass and re-evaluate. Guards against Base moving because current Balance already reflects a deal that local history has not synced yet (Balance-versus-history coherence, the gap `AgHistoryStable`'s one-time SYNCING-exit gate does not cover on every later ACTIVE pass).

Mechanism: coherence signal is deal count, `HistoryDealsTotal()` read immediately after the same `HistorySelect` call `AgRealized` already makes, compared against the prior pass's count (`g_ag_last_deal_count`, in-memory). A one-shot flag, `g_ag_breach_deferred_once` (in-memory, reset whenever no breach is pending that pass):

```
current_count = HistoryDealsTotal()          // post-HistorySelect, same call AgRealized uses
breach_now = (AgRealized(anchor) + AgFloating() <= -AgLimitCurrency(base) + EPSILON)
if breach_now:
    if current_count == g_ag_last_deal_count and not g_ag_breach_deferred_once:
        AgInfo/AgWarn: "breach deferred one pass: no new deal visible, count=" + current_count
        g_ag_breach_deferred_once = true
        // do not declare this pass
    else:
        // declare: either a new deal justifies it, or already deferred once
        <Q2 interim posture: ALERT + journal arithmetic line>
        g_ag_breach_deferred_once = false
else:
    g_ag_breach_deferred_once = false
g_ag_last_deal_count = current_count          // every pass
```

The deferral is bounded at exactly one pass by construction: the second consecutive true evaluation always declares regardless of whether the deal count changed, so a real, sustained breach is delayed by at most one `SweepPeriodSeconds` tick (1 s at the default), never suppressed.

SPEC wording, amendment A6, section 4.4 addition: "A breach evaluation that finds the result crossed the limit with no new deal visible in the selected history (deal count unchanged from the prior pass) defers its declaration by exactly one timer pass. If the condition still evaluates true on the next pass, it declares regardless of the deal count. No breach is deferred twice in a row."

Acceptance row, Stage 4: force two consecutive true breach evaluations with an unchanged deal count between them (synthetic override of the comparison inputs, or a live demo sequence where Balance updates a tick ahead of history); expect exactly one deferral logged, then a declaration on the second pass, never a third pass of silence.

### 4.3b Disconnect handling (Q10, RULED FINAL 2026-08-08, amended 2026-08-09)

Ruling: while disconnected, mark the evaluation DEGRADED and take no breach decision from a frozen quote, since no enforcement action is possible without a connection anyway. No ALERT fires from DEGRADED data. **Amended 2026-08-09 (owner review finding 2, reconnect coherence):** on reconnect, evaluation does not resume immediately; it re-enters gated on the same history-stability discipline as the SYNCING exit condition. The original "immediate clean re-evaluation" wording is superseded by "immediate re-entry to evaluation, gated on history stability." Rationale: a disconnect is exactly the condition the stability counter exists for, and Q9's one-pass deferral was ruled for a one-tick sync gap, not a post-disconnect resync.

Mechanism: connection check is `TerminalInfoInteger(TERMINAL_CONNECTED)`, the same signal design doc item 1's `AgHistoryStable` already resets on. When false, the ACTIVE-state evaluation is skipped entirely for that pass: no `AgRealized`/`AgFloating`/`AgDayBase`/`AgLimitCurrency` recompute, no 4.1a anchor check, no 4.3a coherence check, none of it runs, and a new `g_ag_resyncing` flag is set. The LIFE line and banner show the last-known figures with a DEGRADED marker, carried on the numbers field group itself (`DEGRADED|anchor=...`) and not only on `waiting_on`, so a reader of the numbers alone cannot mistake stale for live (2026-08-09 owner finding 1). No ALERT of any kind fires from a DEGRADED pass, including no repeat of a Q2-cadence breach ALERT that was firing before the disconnect. **On reconnect (2026-08-09 amendment):** while `g_ag_resyncing` holds, each pass calls `AgHistoryStable(HistoryStablePolls)`; until it returns true, the pass returns without running any of the computation, `waiting_on` reads `"RESYNC: polls=<n>/<required>"`, state stays ACTIVE (no transition), and `g_ag_degraded` (and therefore the numbers-field prefix) stays true since no fresh computation has landed. Once stable, `g_ag_resyncing` clears and the pass falls through to 4.1a's anchor check exactly as any other ACTIVE pass; Q9's coherence check applies normally from that point on, since disconnection touches neither `g_ag_high_anchor` nor `g_ag_last_deal_count`.

SPEC wording, amendment A6, section 4.4 addition (as amended 2026-08-09): "While `TERMINAL_INFO_CONNECTED` is false, the ACTIVE state performs no breach evaluation and raises no breach ALERT; the LIFE line and banner mark the state DEGRADED, the marker carried on the numbers field group itself, and continue showing the last-known figures. The instant the connection is restored, evaluation does not resume immediately: it re-enters gated on history stability, requiring `AgHistoryStable(HistoryStablePolls)` to pass again before the first post-reconnect evaluation runs; the LIFE line shows the live poll count prefixed RESYNC while gated. No state transition." Also amends section 6 (logging contract): "The DEGRADED marker is part of the existing LIFE line and banner fields, not a new state; SPEC section 2's state machine is unchanged by Q10."

Acceptance row, Stage 5, reusing the existing disconnect procedure already exercised for the A8 weekend harvest and the kill-session work: observe the LIFE line reading DEGRADED throughout a disconnect window (numbers field carrying the `DEGRADED|` prefix), zero ALERTs during it (including zero repeats of a breach ALERT that was firing beforehand), the RESYNC-prefixed poll count on reconnect until `HistoryStablePolls` consecutive stable polls are observed, and exactly one clean evaluation on the first LIFE line after the RESYNC gate clears.

### 4.4 Wiring and the state seam

OnTimer keeps the existing order: mutex refresh, proof of life, banner, SAFE_HALT early return. **Daily PnL logic never runs in SAFE_HALT** (today's early return at AccountGuardian.mq5:221-222 is kept; the banner keeps showing the halt reason). After it, a per-state dispatch: SYNCING runs the stability check and transitions to ACTIVE when stable (lock witnesses land in Phase 2; the SPEC's "no lock witness" conjunct is vacuously true in a build with no witnesses, stated in a comment naming Phase 2); ACTIVE runs the evaluation, in this exact order per pass: 4.3b's connection check first (skip everything below and mark DEGRADED if disconnected), then 4.1a's anchor sanity check (halt this pass's window narrowing if an anomalous forward jump fired), then the normal realized/floating/base/limit computation, then 4.3a's coherence-deferral check on the breach conclusion, then the Q2 interim-posture ALERT if a breach still declares; LOCKED is an explicit empty case with a comment naming Phase 2, so Phase 2 adds expiry and witness code without touching the SYNCING/ACTIVE branches. `AgWaitingOn` (State.mqh:88-89) starts reporting the live poll count, and additionally reports the 4.1a and 4.3b conditions when either holds, per their sections above.

**Q2 interim breach posture, RULED FINAL 2026-08-08, cadence made concrete:** loud ALERT plus a journal arithmetic line on breach, state stays ACTIVE, repeated at a bounded cadence while the condition holds. Executor's translation of "bounded cadence," not a re-opening of the ruling: reuse `AG_LIFE_INTERVAL_SECONDS` (30 s, the existing observability-cadence constant, Log.mqh) as the repeat interval for the breach ALERT specifically, distinct from the 1 s per-pass journal arithmetic line, which still logs every ACTIVE pass a breach holds (the arithmetic line is not an Alert popup and carries no popup-fatigue cost). This reuses an existing FINAL constant rather than inventing a new magic number; flagged here as the executor's implementation choice for the owner to confirm or override, not as a new open question blocking anything.

### 4.5 Observability (SPEC section 6 extension, part of A6)

The ACTIVE proof-of-life line gains the governing numbers: `anchor`, `realized`, `floating`, `base`, `limit`, `pnl_vs_limit`. The banner replaces the Phase 0 "n/a" with the same numbers. The day-rollover INFO line logs old anchor, new anchor, and jump width. These fields are what let the weekend and freeze rows below close from journal artifacts alone.

### 4.6 SPEC amendment A6 (one block, owner-ruled)

**Correction, 2026-08-08, second pass.** Numbered A6, not A5. Verified this session, against the object store directly, not against any report: `worktree-a9-phantom-audit` (tip `461c415`) carries a FINAL owner ruling of 2026-08-05 on the A10 transition-table findings, applied to `docs/SPEC_v0.1.md` as amendment A5 in commit `669d1ff`, three section 2 table edits unrelated to Phase 1: the boot-to-SYNCING From cell widened, the any-to-SAFE_HALT row split into a boot row and an any row, and the SAFE_HALT action cell corrected. That branch is not merged to main (main is `bb956b2`; `669d1ff` is not an ancestor of main, confirmed by `git merge-base --is-ancestor`; `docs/SPEC_v0.1.md` differs between main and the branch by 15 insertions and 2 deletions, verified by `git diff --stat`). Taking A5 for this plan's amendment would collide the moment that branch merges. Every "A5" reference elsewhere in this document is A6.

**Ordering, corrected 2026-08-08, third pass.** The number is right; the earlier note said nothing about order and that gap is closed here. Main's `docs/SPEC_v0.1.md` is a strict prefix of the branch's copy (the same 15/2 diff above, a plain addition, not a conflict), so writing A6 onto main's SPEC before the branch merges would leave main jumping A4 straight to A6 and would put the future merge conflict directly inside the amendment block, exactly the collision the LEDGER's split-files entry exists to flag in advance. Phase 1 is already blocked on Phase 0 closing and merging (question 6). The order is therefore: the branch merges first, landing A5 on main; A6 is written afterward, onto a SPEC that already carries A5. This plan writes no amendment to any file at this stage; Stage 2 and Stage 3 below assume A5 is already on main when they run.

1. 4.1: day anchor = 01:00 Israel per the kickoff ruling, operationalized as fixed 01:00 server per ruling Q1 (RULED, section 7 item 1); weekend and frozen-clock behavior as in 2.3; the high-water-mark sanity check of 4.1a per ruling Q8 (RULED, section 7 item 8).
2. 4.2: history selection upper bound is the far-future constant, never a clock-derived value; per-deal formula gains DEAL_FEE per ruling Q3 (RULED, section 7 item 3); boundary-second convention per ruling Q4 (RULED, section 7 item 4).
3. Section 4.4/6: LIFE-line and banner field additions of 4.5; the DEGRADED marker per ruling Q10 (RULED, section 7 item 10); the breach-deferral note per ruling Q9 (RULED, section 7 item 9).
4. Section 8, Phase 1 row: "Rollover resets counters at server midnight" reworded to "at the day anchor."

All four items above are now fully specified by rulings; nothing in this list is still pending owner input. The amendment is not written to docs/SPEC_v0.1.md in this planning session (per the 2026-08-08 third-pass ordering correction above: A6 lands only after this document's Stage 2 through 4 work actually implements it, not before), but every sentence it will carry is drafted verbatim in sections 4.1, 4.1a, 4.3, 4.3a and 4.3b above.

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
Vectors (script prints PASS/FAIL per case to the journal): boundary second, one second before and after; frozen input (same t twice); backward step across the boundary (25 h class and 1 s class); forward jump across three anchors; latch behavior for each; `AgNextDayAnchor` equals anchor plus 86400 everywhere; plus 4.1a's three Q8 vectors (anomalous two-day-plus jump halts and names both anchors without narrowing, legitimate one-day advance accepts and advances the high-water mark, backward step still widens using fresh and never substitutes the high-water mark).
Evidence: journal lines from one owner double-click of the script, quoted into docs/evidence/ per established practice; compile log 0 errors 0 warnings.
Rollback: revert branch commits, nothing deployed.

### Stage 3: History engine
Goal: Pnl.mqh bodies per 4.3, discharging the frozen-upper-bound obligation, and the Q3/Q4 formula and boundary changes.
Surfaces: Pnl.mqh only. SPEC A6 item 2 written.
Acceptance rows (static, from the repo tree): grep zero trade-API references in Pnl/Clock (S1/S2 class re-run); grep zero TimeLocal/TimeGMT/TimeTradeServer in Clock.mqh and Pnl.mqh; grep zero `HistorySelect` calls whose upper bound derives from any clock call; grep confirms `DEAL_FEE` is read alongside `DEAL_PROFIT`/`DEAL_SWAP`/`DEAL_COMMISSION` in both `AgRealized` and `AgDealsSumAll`/`AgDayBase` (Q3); compile 0 errors 0 warnings (Result line plus fresh ex5 mtime per standing rule 6/7, exit code ignored).
Rollback: revert branch commits.

### Stage 4: Wiring, states, observability
Goal: 4.4 and 4.5 in AccountGuardian.mq5, State.mqh, Log.mqh, including the Q9 coherence-deferral flag and the Q10 DEGRADED dispatch.
Acceptance rows (static plus journal-format): SYNCING→ACTIVE emits exactly one TRANSITION line matching the SPEC section 2 row; LIFE line carries the A6 field list; SAFE_HALT path provably unchanged (diff scoped review, no PnL call reachable from the SAFE_HALT branch); interim breach posture per ruling Q2 wired exactly as ruled, ALERT repeat cadence at AG_LIFE_INTERVAL_SECONDS; the per-pass check order of 4.4 (connection, then anchor sanity, then computation, then coherence deferral) confirmed by a scoped code read rather than assumed from the design prose; Q9's one-shot deferral flag confirmed to reset whenever no breach is pending (static read of every `g_ag_breach_deferred_once` assignment site).
Rollback: revert branch commits.

### Stage 5: Deploy and live acceptance
Deploy per the standing procedure (owner gate; halt file backed up first with md5; sources copied, all verified by md5 against the tree; compile in terminal tree; kill/relaunch with the 15 s stale-mutex margin). Rows, each closing only on named on-disk evidence with build hash:

| Row | Test | Artifact |
|---|---|---|
| P1-A anchor live | first post-deploy day rollover at 01:00 server | rollover INFO line plus LIFE lines bracketing it |
| P1-B weekend absorption | one weekend harvest: anchor holds Friday through the freeze, adopts Monday at reopen, no Sat/Sun rollover lines | journal scan, quoted lines |
| P1-C restart reconstruction (P1-5) | kill mid-day with deals present, relaunch | PnL figures equal before and after within 0.01, LIFE lines quoted |
| P1-D zero-deal day | any deal-free day | LIFE lines: realized 0, base = balance, PnL = floating |
| P1-E deposit neutrality (DN-1, P1-1) | demo deposit, Q5 RULED deposit-only, withdrawals unavailable on this demo | base and limit unchanged within 0.01 |
| P1-E' withdrawal neutrality (DN-2, P1-2) | Q5 RULED: PASS-BY-CONSTRUCTION, not a demo row | closes by the Q2 algebraic identity alone (design doc item 2's derivation is symmetric in sign); no demo evidence exists or is required |
| P1-F freeze-window balance op | deposit inside the nightly 00:00-00:05 freeze or the weekend freeze | base unchanged, deal present in the sum despite frozen TimeCurrent, proving the upper bound |
| P1-G whitelist (P1-8) | balance op moves realized by exactly 0 and the base sum by the exact amount, DEAL_FEE included per Q3 if the deposit carries one | journal arithmetic |
| P1-H F11 double-count | carry a losing manual position across 01:00, close next day | floating against day N, full realized against day N+1, asserted expected |
| P1-I partial close (P1-7) | manual partial close | realized plus floating continuous across the boundary |
| P1-J SYNCING exit (P1-9 design-doc numbering) | restart with history | poll count visible in AgWaitingOn, exit after HistoryStablePolls stable polls |
| P1-K HistorySelect false (P1-10 design-doc numbering) | disconnect mid-session | loud WARN distinct from zero-deals, no ACTIVE transition from that tick |
| P1-L breach arithmetic | manual losing trades cross the limit on demo | posture per Q2 ruling observed, arithmetic line carries full numbers, ALERT repeats at 30 s while sustained |
| P1-M anchor sanity live (Q8, amended 2026-08-09) | the Monday reopen IS the live test, and it arrives free every week: the anchor advances three days from the held Friday boundary, which is exactly the more-than-one-day condition | one ALERT naming both anchors with `jump=259200s`, then acceptance, then a normal rollover line and a fresh Monday computation on the next LIFE line; the note absent from every later pass. Stage 2's 26 synthetic vectors, including the Friday-to-Monday replay, remain the corroborating evidence |
| P1-N breach deferral live (Q9) | demo sequence where a manual close's Balance update is observed to outrace HistoryDealsTotal by one pass, or a forced synthetic override if no such sequence occurs naturally | exactly one deferral logged, declaration on the following pass, never a third pass of silence |
| P1-O DEGRADED live (Q10, amended 2026-08-09) | reuse the existing disconnect procedure (A8 weekend harvest class) | DEGRADED prefix on both the numbers field group and waiting_on throughout the gap, zero ALERTs during it, RESYNC-prefixed poll count on reconnect until HistoryStablePolls consecutive stable polls, exactly one clean evaluation once the RESYNC gate clears (no immediate re-evaluation on the raw reconnect tick) |

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
| Balance ops in history | Decided | F12: excluded from realized, included in base sum; deposit never profit, withdrawal never loss by the Q2 identity; boundary second per Q4 (RULED); DEAL_FEE per Q3 (RULED) |
| Partial closes, swaps, commissions, fees | Decided | Per-deal formula plus design doc item 1 partial-close analysis; row P1-I; DEAL_FEE per Q3 (RULED) |
| Zero-deal day | Decided | Empty fold: realized 0, base = current balance, PnL = floating; row P1-D |
| Breach comparison semantics | Decided in full | SPEC 4.2 quoted: "Daily PnL = realized + floating. Never a balance-delta, never a cached day-start equity." SPEC 4.4: "Breach: daily PnL <= -(limit_currency)". Floating included per F11. Evaluated once per timer tick in ACTIVE from a single TimeCurrent sample; epsilon errs toward breach (FINAL). Interim action on true is Q2 (RULED: loud ALERT plus journal line, ACTIVE stays ACTIVE, 30 s repeat cadence), gated by Q9's one-pass coherence deferral (RULED, 4.3a) and skipped entirely under Q10's DEGRADED condition (RULED, 4.3b) |
| Breach exactly at anchor boundary | Decided for Phase 1 scope | Single-sample rule makes anchor, window, and comparison agree within one pass; at t equal to the anchor the window counts to the new day per Q4 (RULED); lock semantics are Phase 2 |
| SAFE_HALT today, LOCKED seam | Decided | PnL logic never runs in SAFE_HALT (early return kept); LOCKED is an explicit empty dispatch case so Phase 2 adds without refactoring |
| Restart mid-day | Decided | Nothing persisted, nothing trusted from memory; anchor and sums re-derived every pass; row P1-C; 4.1a's high-water anchor and 4.3a's deal-count baseline both reseed from scratch with no false positive on the first pass, since neither check runs until a prior pass's value exists to compare against |
| Forward clock jump narrowing the window (Q8, amended 2026-08-09) | Decided | Anchor high-water-mark latch, section 4.1a; announces loudly (cadence-capped ALERT plus a per-occurrence journal line) then accepts and advances, so no pass is ever halted and the condition clears itself; in-memory only; Stage 2 synthetic vectors plus the weekly Monday reopen as the live row |
| Balance-versus-history coherence (Q9) | Decided | One-pass breach-declaration deferral keyed on unchanged deal count, section 4.3a; bounded at exactly one pass |
| Floating PnL under a stale quote / intraday disconnect (Q10, amended 2026-08-09) | Decided | DEGRADED marker on the numbers field group itself, no breach evaluation and no ALERT while disconnected; on reconnect, re-entry gated on `AgHistoryStable(HistoryStablePolls)` with a RESYNC-prefixed poll count, not an immediate re-evaluation; section 4.3b |

## 7. Questions asked, all ten RULED FINAL 2026-08-08 (see LEDGER DECISIONS for the verbatim text)

Kept as the historical record of what was asked; nothing here is open any longer. Each entry carries its ruling and a pointer to the mechanism.

1. **"01:00 Israel" operationalization. RULED: option (a).** Fixed `01:00 server` anchor, compile-time constant, confirmed not an input. Accepts the divergence-window drift enumerated in 2.2. Owner commits to a REVISIT after the 2026-10-25 to 2026-11-01 harvest measures the broker's actual DST peg. Mechanism unchanged from section 4.1 as originally drafted (option (a) was always the design's own default).
2. **Interim breach posture in the Phase 1 deployed build. RULED: option (a).** Loud ALERT plus journal arithmetic line, state stays ACTIVE, repeated at a bounded cadence while the condition holds; owner explicitly sanctions the no-enforcement window until Phase 2. Cadence made concrete in section 4.4: 30 s repeat via `AG_LIFE_INTERVAL_SECONDS`, the arithmetic line every pass.
3. **DEAL_FEE. RULED.** Added to the per-deal formula everywhere it appears (`DEAL_PROFIT + DEAL_SWAP + DEAL_COMMISSION + DEAL_FEE`). SPEC wording drafted in section 4.3.
4. **Anchor-boundary second. RULED.** `DEAL_TIME >= anchor` counts to the new day, matching `HistorySelect`'s own inclusive-from semantics. No special-cased comparison needed; documented in section 4.3.
5. **Demo balance operations. RULED.** Withdrawals unavailable on demo 1200252169; deposits available via the JustMarkets personal area. Rows P1-E/F/G redesigned deposit-only in Stage 5's table; the withdrawal-neutrality direction (P1-E') closes PASS-BY-CONSTRUCTION on the Q2 algebraic identity alone, no demo evidence needed or possible.
6. **Sequencing versus Phase 0 remainder. RULED CLOSED, resolved twice over.** The branch carrying the Phase 0 remainder (`worktree-a9-phantom-audit`) merged to main as `937c604`, documented and pushed 2026-08-08, carrying A7 proven, A9 proven whole, and A10's amendment A5. Independently, the last-used gate that merge alone could not close on its own artifacts is now closed by the owner's direct dialog reading of the live EA properties, quoted in the Q6 DECISIONS entry: all eight inputs at ruled defaults, `HistoryStablePolls=3` included. Phase 0 is closed in full on main; this question no longer blocks anything.
7. **Stage 1 scheduling. RULED.** The symbol-specification read rides the owner's next terminal session, whenever that falls; it is corroboration, not a gate, and blocks nothing.
8. **Forward clock jump and the window's lower bound. RULED, then AMENDED 2026-08-09.** Anchor high-water-mark latch: retain the highest observed anchor in memory, in-memory only, cleared on restart. The original ruling halted the pass rather than narrowing the window; the 2026-08-09 amendment replaces the halt with alert-and-advance, because the halt could not self-clear against a forward-only clock and would have stalled evaluation permanently at every weekend reopen. Full mechanism, SPEC wording, and Stage 2 acceptance vectors in section 4.1a.
9. **Balance-versus-history coherence within one evaluation pass. RULED.** Defer a breach declaration by exactly one timer pass when the result moved abruptly with no new deal visible (unchanged `HistoryDealsTotal()`), declare unconditionally on the next pass regardless. Full mechanism, SPEC wording, and Stage 4 acceptance row in section 4.3a.
10. **Floating PnL under a stale quote. RULED.** Mark the evaluation DEGRADED and take no breach decision while `TERMINAL_INFO_CONNECTED` is false; immediate clean re-evaluation on reconnect; no ALERT fires from DEGRADED data. Full mechanism, SPEC wording, and Stage 5 acceptance row (reusing the existing disconnect procedure) in section 4.3b.

## 8. After approval

Record the kickoff ruling FINAL in DECISIONS (dated 2026-08-05, done, `bb956b2`), log this plan in LEDGER (ACTIONS entry; ISSUES entries for the open questions and the October measurement obligation, done, `bb956b2`), and stop. Second pass, 2026-08-08: context alignment re-run against `worktree-a9-phantom-audit` per the correction above, three new ledger-verified findings folded in (A5-versus-A6 numbering, Phase 0 not closed on any branch, the LEDGER/README split needing a hand union resolve), three new open questions appended (8, 9, 10). Third pass, 2026-08-08/09: all ten questions banked FINAL in LEDGER DECISIONS; Q8, Q9 and Q10 translated into exact mechanisms, SPEC wording, and acceptance rows across sections 4.1a, 4.3a and 4.3b; `worktree-a9-phantom-audit` merged to main (`937c604`) and the Q6 last-used gate closed by owner reading, so Phase 0 is closed in full and this plan's own question 6 is resolved. Nothing across any pass reopens or argues the kickoff ruling itself, which remains FINAL, and the third pass reopens nothing else either; it records rulings and drafts the mechanisms they require, it does not decide anything an owner has not already decided. Implementation begins only on a later, separate owner instruction; Phase 0 is no longer a precondition standing in its way.
