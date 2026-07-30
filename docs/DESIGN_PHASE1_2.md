# AccountGuardian, Phase 1/2 Design: PnL Engine and Derived-Lock Defense

Context: SPEC v0.1 is FROZEN, amended by A1-A3. This document designs the obligations SPEC sections 4.2, 4.3, 4.6, 3, and 4.7 state but do not algorithmically specify. Structure and obligations only, no implementation bodies, matching SPEC's own stated form. A separate execution session implements after the owner rules on this. This session ran in plan mode: no file was written, LEDGER.md was not touched. Log this design review as a dated ACTIONS entry when work starts, and record any ruling below as a DECISIONS entry, mirroring how REVIEW_v0.md's own delivery was handled.

FINAL decisions this design builds on and does not reopen: Q1 (locked_until = next day anchor), Q2/F1 (base amendment), Q3/F2 (trade-disallowed kill-equivalent), Q4/F9 (config classes), Q6/F7 (snapshot governs locked window), Q7/F5 (TimeCurrent exclusively), Q8 (dual limits, stricter wins), F11 (carried-position double-count), F12 (realized whitelist), F13 (timer-driven, trade API confined to Sweep.mqh), the never-loaded-never-written obligation, and lock artifacts are quarantined not deleted. Everything below is designed to compose with these, not around them.

Phase 0 is untouched. Where this design's obligations extend an existing Phase 0 pattern (the halt file's load-discipline, the mutex heartbeat's per-tick refresh), it is cited by file:line as precedent, not modified.

---

## 1. Realized PnL reconstruction (Phase 1)

**Window:** `from = AgDayAnchor(AgServerNow())`, `to = AgServerNow()` (Clock.mqh:24,18, both TimeCurrent-based, Q7-compliant). Call `HistorySelect(from, to)`. Its return value is an obligation, not a formality: `false` means history is not evaluable this tick. The caller must not treat that as "zero deals, therefore zero realized" — that is exactly the F6 fail-open hazard. It must be treated as a stability failure: log loudly, and do not let this evaluation justify a SYNCING→ACTIVE transition or a fresh unlock decision.

**Whitelist (F12, FINAL):** after `HistorySelect` succeeds, iterate `HistoryDealsTotal()` deals via `HistoryDealGetTicket(i)`. For each ticket, read `DEAL_TYPE`. Only `DEAL_TYPE_BUY` and `DEAL_TYPE_SELL` contribute to realized; every other type (balance, credit, charge, correction, bonus, commission-adjustment, dividend, interest) is excluded from realized and participates only in base reconstruction (item 2).

**Per-deal value:** for each whitelisted deal, `DEAL_PROFIT + DEAL_SWAP + DEAL_COMMISSION`. Sum across all whitelisted deals in the window = `AgRealized(from, to)`.

**Swap/commission handling:** entry commission is charged on the opening deal, exit commission (broker-dependent) on the closing deal — both are BUY/SELL deals, so both land in realized automatically via the per-deal formula, no special-casing. Swap accrues on open positions (`POSITION_SWAP`, counted in floating) and crystallizes into `DEAL_SWAP` on the deal that closes or reduces the position (counted in realized). A partial close generates a BUY/SELL deal carrying only that portion's crystallized swap/profit/commission, while the remaining open portion keeps accruing floating separately — the realized/floating split is partial-close-safe by construction; no special-casing needed, but it earns its own acceptance row (P1-7) because Phase 3's matrix already flags partial closes as a hazard class.

**Deal ordering (needed by item 3, declared here since it's a property of the same replay):** where multiple deals share a `DEAL_TIME` second, sum them in `(DEAL_TIME, DEAL_TICKET)` ascending order, ticket as the tiebreak. Ticket assignment reflects true broker-side sequencing even when wall-clock seconds tie; this matters for the running-minimum in item 3, where transient ordering can change whether an intra-second dip is visible.

**SYNCING exit condition (F6), concrete:** maintain a poll counter, reset to 0 whenever `HistoryDealsTotal()` (post-`HistorySelect(from, to)`) differs from the previous tick's count, or whenever `TerminalInfoInteger(TERMINAL_CONNECTED)` is false on that tick. Increment when both connected and count is unchanged from the prior tick. SYNCING→ACTIVE is eligible once the counter reaches `HistoryStablePolls` (default 3) **and** no lock witness fires (item 4). This reuses the existing 1s `OnTimer` cadence (F13) — no separate polling timer. `AgWaitingOn()` for SYNCING (State.mqh:88-89) should report the live poll count against `HistoryStablePolls` once implemented, so the proof-of-life line (A3) stays meaningful instead of static.

**Where this lives:** `Pnl.mqh` already declares `AgRealized`, `AgFloating`, `AgDayBase`, `AgLimitCurrency` as Phase 1 obligations (Pnl.mqh:14-30). The stability counter belongs alongside them as a new function, e.g. `bool AgHistoryStable(int required_polls)`, since it is intrinsically a property of the same history read.

---

## 2. Base and limit (Q2 amendment, FINAL)

**Definition:** `Base = CurrentBalance - Σ(deal_effect(d_i))` for every deal `d_i` since the day anchor, **all types**, where `deal_effect(d) = DEAL_PROFIT + DEAL_SWAP + DEAL_COMMISSION` uniformly (for non-trade deals, MT5 carries the amount in `DEAL_PROFIT`; swap/commission are 0 for those, so the same formula applies without a type branch).

**Algebraic proof it equals the anchor balance:** Let `B0` = balance at the day anchor. Balance only ever changes via deals, by construction of the platform's own ledger — this is the terminal's accounting axiom, not something derived. So after `m` deals since anchor:

```
CurrentBalance = B0 + Σ(i=1..m) deal_effect(d_i)
```

Therefore:

```
Base = CurrentBalance - Σ(i=1..m) deal_effect(d_i) = B0
```

exactly, regardless of how many deposits, withdrawals, or trades occurred since — as long as the sum runs over **all** deal types, not just BUY/SELL. This is the whole fix: the charter text summed only realized (BUY/SELL), which is why F1 broke. This same identity is why, within a single day, Base is not merely deposit/withdrawal-invariant but invariant to trading activity too — it is always exactly the day-anchor balance, full stop, until the next day anchor. That property is load-bearing for the ratchet design (see the 2026-07-30 addendum at the end of this document).

**Cancellation, both directions, at the instant of the transaction:**

Deposit `X` at time `t`: it is itself one of the `d_i`, contributing `deal_effect = +X`. `CurrentBalance_after = CurrentBalance_before + X`.
```
Base_after = (CurrentBalance_before + X) - (Σ_prior + X) = CurrentBalance_before - Σ_prior = Base_before
```
Withdrawal `Y`: `deal_effect = -Y`, `CurrentBalance_after = CurrentBalance_before - Y`.
```
Base_after = (CurrentBalance_before - Y) - (Σ_prior - Y) = Base_before
```
Both cancel exactly and immediately — Base is deposit/withdrawal-invariant continuously, not just as an end-of-day artifact, because it is recomputed live from current balance and current deal sum every evaluation, never cached (charter requirement, restated).

**Limit (Q8, FINAL), the min-of-enabled trap:** `percent_limit = DailyLossPercent% × Base / 100` if `DailyLossPercent > 0`, else disabled. `fixed_limit = DailyLossCurrency` if `> 0`, else disabled. `limit_currency = min` over the **set of enabled candidates only**. This must not be `min(percent_limit, fixed_limit)` taken naively when one is legitimately 0 — that would make `limit_currency` always 0 (instant breach) whenever exactly one limit is disabled. The set is guaranteed non-empty post-init since both-zero already refuses init (Q4/F9).

**Deposit-neutrality acceptance test, executable:**

- **DN-1 (deposit):** ACTIVE, quiet moment (no open positions), `DailyLossPercent=5, DailyLossCurrency=0`. Record `Base_0`, `limit_0` from banner/journal. Deposit a fixed test amount on demo. Within one `SweepPeriodSeconds` tick, read `Base_1`, `limit_1`. Assert `Base_1 == Base_0` and `limit_1 == limit_0` within epsilon (OQ4 below), and daily PnL unchanged.
- **DN-2 (withdrawal):** identical steps, withdrawal instead of deposit. Same assertions.
- **DN-3 (the dangerous direction, F1 Scenario B):** run a losing trade to bring daily PnL close to but under the limit. Withdraw. Assert **no breach fires** from the withdrawal alone — this is the scenario where the charter's original text would have flattened healthy positions with zero new trading loss.

---

## 3. Derived lock from history (F4, Phase 2, the hard one)

**Replay:** over the whitelisted BUY/SELL deals since the day anchor, ordered per item 1's tiebreak, define cumulative realized `R_k = R_{k-1} + deal_effect(d_k)`, `R_0 = 0`, and running minimum `M_k = min(M_{k-1}, R_k)`, `M_0 = 0`. This is a single linear fold; no need to store the whole deal array, just two running scalars.

**Why a post-flatten realized loss cannot be erased:** `M_k` is monotonically non-increasing by construction (`M_k <= M_{k-1}` always). Once it dips below `-limit` at some deal `k`, `M_n` (the final value, `n` = last deal so far) stays `<= -limit` no matter what later deals do to `R_n`. Worked example: base 10,000, limit 500. By deal 5, `R_5 = -600` (`M_5 = -600`, breach). The EA flattens, generating its own closing deals. Later, mobile trades opened while locked (accepted residual, item 4 covers detection of those separately) net `+800` by deal 12, so `R_12 = +200`. A check using **only** "current daily PnL" (`realized + floating = 200 + 0 = 200`) would see no breach. But `M_12 = min(R_0..R_12) = -600 <= -500`. The running minimum is what disjunct 2 checks; it is why the ledger's dip survives the recovery.

**Which comparison, snapshot vs live (Q6, FINAL, clarified 2026-07-30, see addendum):** if a valid, unexpired (`locked_until > TimeCurrent`) DAILY_BREACH snapshot exists in the state file, `limit_for_comparison = limit_snapshot`. If no valid snapshot exists (file missing, corrupt, or says unlocked — exactly the F4 attack surface), `limit_for_comparison` falls back to the **live** `AgLimitCurrency(AgDayBase())` computed from current inputs. This is deliberate, not a gap-filler: it is what makes file/GV deletion **alone** (inputs untouched) fully defended — the live-computed limit equals the original limit when nothing was tampered, so `M_n <= -limit_for_comparison` still fires correctly from history alone, with no snapshot needed. Only deletion **combined with** input inflation defeats it, which is the already-accepted residual.

**Derived breach, full formula:**
```
derived_breach = (AgRealized(anchor, now) + AgFloating() <= -limit_for_comparison)   // disjunct 1: live
               OR (M_n <= -limit_for_comparison)                                      // disjunct 2: replay
```
**Scope, performance-relevant:** disjunct 1 runs every ACTIVE tick regardless (it *is* section 4.4's live breach check — no extra cost). Disjunct 2 (the full replay) only needs to run **at boot**, as part of the SYNCING→LOCKED derivation (section 4.6 says "at boot" for a reason). Once a fresh breach is caught live during steady ACTIVE operation, it persists through the normal ACTIVE→LOCKED path, not through this derivation — the derivation is the boot-time safety net for when file/GV integrity is in question, not a per-tick full-history replay forever. Worth stating explicitly: an unbounded O(n) replay every second on a high-volume account would be a real, self-inflicted performance problem, and it isn't required by the spec's own wording.

**Residual gaps, precisely:**
- **Floating-only, unwitnessed breach:** applies specifically when the EA process itself was not alive/observing (killed, or terminal offline) for the **entire** duration of a floating excursion that both crossed the limit and fully recovered before the EA resumed observing, with no closing deal generated during the excursion. If the EA was alive (even mid trade-disallowed state, per Q3), disjunct 1 catches the live breach the instant it crosses the limit and persists file+GV then, per section 4.4 — detect-and-persist is decoupled from whether the flatten can actually execute. The gap is narrower than "any floating-only breach"; it requires the EA's own absence for the whole excursion.
- **File+GV destruction + input inflation together:** already accepted friction (section 4.6, 4.7 threat model). Confirmed above: destruction *alone* does not defeat the design.
- **Forgery is equivalent to deletion, not stronger:** the state file's checksum (FNV-1a, Persist.mqh:50-61) is a torn-write detector, not tamper defense (already documented in the code's own comment, Persist.mqh:47-49). A locally-recomputed forged-but-valid checksum claiming `lock_reason=NONE` is, from the derivation's perspective, indistinguishable from "file witness abstains" — it does not defeat anything beyond what plain deletion already would, since defense in that case rests on GV and derived-history exactly as it does for deletion.

---

## 4. Boot lock derivation and SYNCING interaction (Phase 2)

**The OR (F4, section 4.6):** `LOCKED at boot = file_witness OR gv_witness OR derived_witness`. Each witness independently abstains-or-fires; the OR can only add `true`, never subtract it. There is no path by which any witness un-locks — unlock is exclusively the `TimeCurrent >= locked_until` comparison (section 4.5), never a conclusion drawn from an absence of derived evidence.

**Authority order, and why:** broker deal history cannot be forged or deleted by a local-machine-only attacker — it is server-side and the client terminal only caches it (confirmed in the adversarial pass below). File and GV live entirely on the local machine and are locally writable, hence "witnesses (accelerators)," not authority: they exist so a lock is recognized instantly without a full replay, and so recognition works even before history-stability is established. History is the authority precisely because it's the one input this attacker class cannot touch.

**Per-witness definition (all use `locked_until > TimeCurrent`, not just `lock_reason != NONE`, so an expired lock's stale record is self-correcting rather than needing an explicit clear-on-unlock — a stored `locked_until` that has already passed simply reads as not-locked without any rewrite required):**
- **File witness:** checksum fails → fires as CORRUPT_STATE with `locked_until = AgNextDayAnchor(AgServerNow())` (computed now, never read from the failed file — this is already the SPEC's explicit rule, restated precisely). Checksum passes, parses, login matches, `lock_reason != NONE`, `locked_until > now` → fires with the file's own reason and `locked_until`.
- **GV witness:** `AG_LOCK_<login>` holds a bare `locked_until` timestamp, no reason. Fires (reason defaults to DAILY_BREACH, since GV carries no CORRUPT_STATE concept) if `value > now`, subject to the clamp below.
- **Derived witness:** per item 3. Fires with reason DAILY_BREACH, `locked_until = AgNextDayAnchor(now)` — which is numerically identical to what Q1 would have produced from the actual breach day, since `AgDayAnchor` is a floor function constant across any moment within the same calendar day.

**Clamp obligation (ratified 2026-07-30, closes an adversarial finding below):** any witness-supplied `locked_until` is capped at `AgNextDayAnchor(AgServerNow())` at evaluation time. Q1 (FINAL) guarantees the system itself never legitimately produces a value further out than tomorrow's anchor; a GV value further out is definitionally not one the system wrote. Clamping (not discarding) preserves the OR-only-adds-lock property while bounding the outage a forged or fat-fingered GV value can inflict to at most one day-cycle instead of unbounded.

**GV self-healing against live tampering:** per section 3, `AG_LOCK_<login>` is rewritten from the authoritative in-memory lock state every timer tick, unconditionally — mirroring the existing mutex-heartbeat refresh pattern already in the codebase (Persist.mqh:293-306, `AgMutexRefresh`, called unconditionally first in `OnTimer`, AccountGuardian.mq5:195-196). This means a GV cleared via the terminal's Global Variables window while the EA stays alive self-heals within one tick, with no separate periodic re-derivation needed. The state **file** is not rewritten every tick (only at breach and at CORRUPT_STATE handling, matching the halt file's event-triggered write pattern) — deleting the file while the EA is alive and LOCKED does not affect enforcement, since the in-memory state doesn't need the file until a restart, and restart-recovery is exactly what item 3's derivation covers.

**SYNCING interaction:** a persisted lock (file or GV witness firing) is enforced immediately on entering SYNCING — no reason to delay protection waiting for history stability. A **new** breach conclusion (derived witness firing when file/GV are both silent) and any **unlock** conclusion both require `HistoryStablePolls` consecutive stable polls first (item 1) — this is enforced structurally by the transition table itself: SYNCING→ACTIVE requires both stability **and** no lock witness, so "no breach found" can never be acted on before stability is reached; it's simply not yet eligible to leave SYNCING.

---

## 5. State file contents, checksum, corruption policy (Phase 2)

**Home:** `Persist.mqh`, alongside the existing halt-file logic — matches the architecture's own file-layout comment (section 1: "Persist.mqh: atomic state file, checksum, GV mirror, mutex"). No new file.

**Fields (SPEC section 3, restated with obligations):**

| Field | Type | Obligation |
|---|---|---|
| magic | string literal | Distinct from the halt file's `AGHALT` magic (e.g. `AGSTATE`), so the two formats can never cross-read even if paths were swapped by mistake |
| format version | int | `AG_STATE_FORMAT_VERSION`, mirroring `AG_HALT_FORMAT_VERSION` |
| account login | long | Must equal `AccountInfoInteger(ACCOUNT_LOGIN)` at load time. A mismatch is treated as invalid (see below) — this is a distinct check from the checksum, catching an internally-valid file that simply belongs to a different account (the exact class of bug LEDGER already hit once with foreign residue in the Common folder) |
| lock_reason | enum | Reuses the existing `ENUM_AG_LOCK_REASON` (State.mqh:20-25), no new enum |
| locked_until | datetime | **TimeCurrent basis, never TimeLocal** — this is the one place a future implementer might reflexively copy the halt file's TimeLocal pattern (Persist.mqh:213, 224, 242, all under the A1 exemption) by analogy. That exemption does not extend here: Q7 governs this field explicitly |
| breach_time | datetime | Same TimeCurrent basis, for the same reason — it feeds `AgNextDayAnchor` |
| limit_snapshot | double | Meaningful only when `lock_reason = DAILY_BREACH`; unset/0 for CORRUPT_STATE |
| base_snapshot | double | Same conditional meaning as limit_snapshot |
| checksum | uint | Reuses `AgChecksum` (FNV-1a, Persist.mqh:50-61) verbatim — no new checksum algorithm |

**Never-loaded-never-written (binding per the FINAL general obligation):** mirror `g_ag_halt_loaded` (Persist.mqh:36) exactly with a new `g_ag_state_loaded`, set `true` at every legitimate exit of the load function — valid load, missing file, or corrupt-then-quarantine-then-reset — before the file-exists check, exactly where `g_ag_halt_loaded = true` sits at Persist.mqh:126. Any function that writes the state file must refuse (loud log, not silent) if this flag is false, mirroring the `OnDeinit` gate at AccountGuardian.mq5:238-246.

**Corruption policy:** checksum fail → quarantine current file to `.bad` (reuse the `FileMove` pattern at Persist.mqh:187-188), loud WARN, **then** write a fresh valid file with `lock_reason = CORRUPT_STATE`, `locked_until = AgNextDayAnchor(AgServerNow())`, breach_time/limit_snapshot/base_snapshot unset. This write is legitimate under the never-loaded-never-written rule because `g_ag_state_loaded` was just set true in the same call — this is the "reset after quarantine" deliberate-initialization branch, exactly mirroring `AgHaltLoad`'s existing corrupt branch (Persist.mqh:185-196). On a later restart still inside that window, this fresh file is itself valid and loads cleanly — no re-corruption loop. Missing file → not corrupt, not trusted as unlocked; loaded=true, in-memory model defaults to `NONE`/0, and the OR-of-three-witnesses formula (item 4) still independently checks GV and derived history.

**Login mismatch → CORRUPT_STATE-equivalent** (ratified 2026-07-30, see OQ2 in the addendum): a parseable, checksum-valid file for the wrong account is treated the same as a corrupt one — quarantine, loud WARN, fresh file, lock via CORRUPT_STATE — rather than silently adopting a lock (or non-lock) that belongs to a different account.

---

## 6. Weekly measurement, report-only (Phase 4 dependency surface)

**Structural proof, two parts:**

1. **No trade call.** `AgWeeklyPnl()` (and the week-anchor helper) lives in `Pnl.mqh`, which is already statically grep-verified in Phase 0 to contain zero trade-API references (LEDGER 2026-07-29, rows S1/S2: PASS, static grep, zero hits). This guarantee carries forward for free as long as the Phase 4 implementation calls nothing in `Sweep.mqh`.
2. **No lock write** — this is a needed *addition* to the existing Phase 4 matrix row, which currently only names the trade-API check (SPEC section 8, Phase 4: "Static check: no trade API reachable from the weekly path"). The weekly path must also never reference `g_ag_lock_reason`, `g_ag_locked_until`, or call the state-file save path. Concrete check: grep the weekly-specific functions for writes to those three symbols, expect zero hits. Reading `AccountInfoDouble`/`HistorySelect`/`Comment`/`Alert` for the journal line and chart-banner field is permitted and expected (section 4.7); the proof is scoped to trade calls and lock mutation, not to all side effects.

**Week anchor:** same shape as `AgDayAnchor` (Clock.mqh:24) — a fixed-constant offset applied to `TimeCurrent`, 7-day modulus instead of 1-day, targeting Sunday 00:00 Israel. No DST table (charter, affirmed). The specific offset constant is a broker/geography fact (LEDGER already established server=UTC, machine=UTC+3; Israel is UTC+2/+3 seasonally), not a design decision — left as an implementation input, consistent with "no implementation bodies" here.

---

## Acceptance-test matrix, Phase 1

| # | Obligation | Test | Evidence that closes it |
|---|---|---|---|
| P1-1 | Deposit neutrality (F1/Q2) | DN-1 above | Base/limit unchanged within epsilon across a demo deposit |
| P1-2 | Withdrawal neutrality (F1/Q2) | DN-2 above | Base/limit unchanged within epsilon across a demo withdrawal |
| P1-3 | Withdrawal near limit does not spuriously breach (F1 Scenario B) | DN-3 above | No LOCKED transition logged from the withdrawal alone |
| P1-4 | Rollover resets counters at server midnight | Hold a position across a server-midnight rollover on demo | Day anchor advances, realized/floating windows recompute from the new anchor, journal shows no spurious transition |
| P1-5 | Restart reconstruction (F6) | Kill and relaunch mid-session with open positions and prior deals today | Daily PnL figure before kill equals the figure after restart, once SYNCING exits |
| P1-6 | Carried-position double-count pinned (F11, FINAL) | Carry a losing position across midnight, close it day N+1 | Floating loss counted against day N, full realized counted again against day N+1 in the journal arithmetic — asserted as expected, not a bug |
| P1-7 | Partial close continuity | Partially close a position, verify total | realized+floating sum is continuous across the partial-close boundary (no double-count, no gap) |
| P1-8 | Deal whitelist (F12, FINAL) | Deposit, apply a manual credit/correction on demo | Realized moves by exactly 0 for each; base reconstruction moves by the exact deal amount for each |
| P1-9 | SYNCING exit condition, concrete | Restart with recent trading history; observe polls | `HistoryStablePolls` consecutive stable+connected polls before SYNCING→ACTIVE; `AgWaitingOn` line names the live poll count meanwhile |
| P1-10 | HistorySelect failure not treated as zero | Force a `HistorySelect` false return (simulate disconnect mid-evaluation) | Loud log distinct from a normal zero-deals day; no ACTIVE/unlock conclusion drawn from that tick |

## Acceptance-test matrix, Phase 2

| # | Obligation | Test | Evidence that closes it |
|---|---|---|---|
| P2-1 | Breach detection: realized-only, floating-only, mixed | Three demo scenarios crossing the limit each way | LOCKED with correct lock_reason and correct governing numbers logged for each |
| P2-2 | Lock survives detach/re-attach, recompile, input change, restart | Each action while LOCKED | State unchanged through all four; journal shows re-derivation, not a fresh unlock |
| P2-3 | State file deleted while locked → re-lock at next init | Delete file, restart | LOCKED restored from derived history (item 3/4), file recreated |
| P2-4 | State file corrupted → CORRUPT_STATE until next rollover | Corrupt file bytes, restart | CORRUPT_STATE, `locked_until` = next rollover, `.bad` quarantine file present, fresh valid file written |
| P2-5 | Windows clock moved forward → no early unlock (F5/Q7) | Move local clock forward past a fake `locked_until` while genuinely locked | No unlock; `TimeCurrent` unaffected by local clock |
| P2-6 | Limit input inflated while locked → snapshot holds (F7/Q6) | Inflate `DailyLossPercent` while LOCKED | Derived recompute uses `limit_snapshot`, not the inflated live input; loud log of the input change |
| P2-7 | Post-flatten recovery cannot erase breach evidence (core F4 property, file intact) | Reproduce the worked example in item 3 on demo | Derived breach still true from the running minimum even though live current PnL has recovered above the limit |
| P2-8 | Foreign/mismatched-login state file rejected | Place a valid-checksum file for a different login at the expected path | Treated as CORRUPT_STATE-equivalent: quarantined, loud WARN, fresh file written, not silently adopted |
| P2-9 | Never-loaded-never-written, state file | Force a refused-init-equivalent path before state load, verify no write | State file untouched; loud log naming the skip, mirroring AccountGuardian.mq5:238-246 |
| P2-10 | GV-only witness isolates correctly | Delete file, leave GV intact, restart | LOCKED from GV witness alone |
| P2-11 | File-only witness isolates correctly | Clear GV, leave file intact, restart | LOCKED from file witness alone |
| P2-12 | Derived-only witness, pure history resilience (key F4 property) | Delete file **and** clear GV, leave inputs unchanged, restart | LOCKED from derived history alone, `limit_for_comparison` falls back to live inputs and still matches |
| P2-13 | Combined file+GV destruction with input inflation (accepted residual, drilled not defended) | Delete file, clear GV, inflate input, restart | Documented as an expected-fail row: no lock derived. Confirms the accepted gap is exactly this narrow, not broader |
| P2-14 | CORRUPT_STATE fresh file is itself valid on a later restart | Corrupt, restart (writes fresh file), restart again within the same window | Second restart loads the fresh file cleanly, no second quarantine, same `locked_until` |
| P2-15 | SYNCING enforces persisted lock immediately, but not new-breach/unlock | Boot with a persisted lock and simultaneously unstable history | Lock enforced from tick one; if history briefly looks clean before stabilizing, no unlock occurs before `HistoryStablePolls` is satisfied |
| P2-16 | GV clamp bounds a griefed/forged timestamp | Manually set `AG_LOCK_<login>` to a far-future value via the terminal's Global Variables dialog | Lock enforced but `locked_until` clamped to `AgNextDayAnchor(now)`, not the forged value |

---

## Adversarial pass (local machine access, terminal not killed)

Threat model slice: attacker can read source, edit local files, use the terminal's F3 Global Variables dialog, and run other scripts/EAs on the same terminal — but does not kill the terminal or the EA process.

| Severity | Scenario | Closure |
|---|---|---|
| NOTE (confirmed closed) | Attacker reads `Persist.mqh` source (fully local, fully readable) and hand-forges the state file with a matching recomputed FNV-1a checksum | Equivalent in effect to plain deletion, not stronger — defense already rests on GV + derived history in that case (item 3). No new obligation needed beyond what F4 already provides |
| NOTE (confirmed closed) | Attacker places trades via a different script/EA on the same terminal, or manually, hoping to evade this guardian | Deal history is account-wide, not per-EA/per-magic (SPEC: "no symbol filter, no magic filter... everything on the account"); `HistorySelect` picks up every deal regardless of origin |
| NOTE (confirmed closed) | Attacker attempts to inject or alter historical deals from the client side | Not reachable: deal history is broker-server-authoritative; the local terminal only caches it. This is the actual justification for "broker history is the authority" in item 4 — it's the one input a local-machine-only attacker cannot touch |
| NOTE (considered, closed by design) | Full-history running-minimum replay running every tick forever on a high-volume account, as an unintended performance/DoS surface | Closed by scoping disjunct 2 to boot-time derivation only (item 3); not a per-tick cost |
| DESIGN, closed by the clamp obligation (ratified 2026-07-30) | Attacker (or an accidental fat-finger) sets `AG_LOCK_<login>` via F3 to a far-future timestamp, extending the account's own lock arbitrarily (griefing/availability harm against the account owner, not a bypass) | Clamp `locked_until` to `AgNextDayAnchor(now)` for any witness (item 4); P2-16 |
| DESIGN, closed by the added obligation (ratified 2026-07-30) | Attacker (or residue from a different project, as already happened once per LEDGER) places a valid-checksum state file for a **different** login at the expected path | Explicit login-field validation, treated as CORRUPT_STATE-equivalent (item 5); P2-8 |
| DESIGN (owner overruled the executor's dismissal, see addendum) | Input inflation while ACTIVE and **not yet breached** — raising `DailyLossPercent` before any loss, so a subsequent real loss never crosses the (now larger) limit | Executor initially closed this as out of scope. Owner rejected that reasoning: the product's premise is precisely that the owner cannot be trusted to hold a limit under pressure. Ratchet defense costed in the 2026-07-30 addendum, owner to rule |

---

## Open questions for the owner (ruled 2026-07-30, see addendum)

**OQ1. GV-witness clamp ceiling.** RULED: (a) clamp to `AgNextDayAnchor(now)` for any witness.

**OQ2. State-file login mismatch.** RULED: (a) treated as CORRUPT_STATE-equivalent.

**OQ3. Weekly chart-banner field content.** RULED: (a) raw weekly PnL currency figure only.

**OQ4. Floating-point comparison epsilon.** RULED: (a) flat epsilon for test assertions, with a direction requirement added by the owner — see addendum.

---

## Addendum, 2026-07-30: owner rulings and open items from first review

This addendum was appended after the owner's first-pass review of the design above. It does not edit the sections above; it rules on the open questions they raised and opens two new items.

**Marking convention (owner ruling 2026-07-30):** unruled content in a committed document carries an explicit UNRULED marker and a date, and is not cited as authority by any session, including this one, until ruled. Once ruled, the marker is replaced by the ruling reference. Applied throughout this addendum and to every addendum after it.

### Rulings (FINAL, owner ruling 2026-07-30)

- **OQ1:** clamp `locked_until` to `AgNextDayAnchor(now)` for any witness, per item 4's clamp obligation above. Reason: preserves OR-only-adds-lock, bounds a griefed value to one day-cycle.
- **OQ2:** a login-mismatched state file is CORRUPT_STATE-equivalent, per item 5's obligation above. Reason: errs locked and loud; this project has already been bitten once by foreign residue sitting at an expected path.
- **OQ3:** the weekly chart-banner field shows the raw weekly PnL currency figure only, nothing else. Reason: option (b), a ratio against the daily limit scaled ×5, invents a reference point the charter never asked for and risks reading as a weekly enforcement threshold that does not exist.
- **OQ4:** flat 0.01 currency-unit epsilon for test assertions (Base/limit comparisons in DN-1/DN-2/DN-3 and similar). For the **breach comparison itself**, which is not a test assertion but a live enforcement decision, any epsilon must err toward breach, never away from it: `total <= -limit + epsilon` is the acceptable form (a marginal case still locks); `total <= -limit - epsilon` is not (it would let a real breach slip through as within-tolerance). This direction requirement is a distinct obligation from the test-assertion epsilon and must be stated explicitly wherever the breach comparison is implemented, so no implementer picks the unsafe sign.

### Q6 clarification (RATIFIED, owner ruling 2026-07-30)

Q6 (FINAL) states the locked window is judged by the snapshot, never live inputs. That rule presumes a snapshot exists to read. Item 3 above adds a fallback for the case Q6's own wording left silent: no valid snapshot available (file missing, corrupted, or login-mismatched — precisely F4's own defense scenario). Ratified wording, re-sourced to the owner:

> Q6 clarification (owner ruling 2026-07-30, drafted by the executor): Q6's snapshot rule governs the locked window once a valid snapshot exists. It does not by itself state what governs the derived-breach comparison (SPEC 4.6) when no valid snapshot is available to read. In that specific case, the derived comparison falls back to the limit computed live from current inputs and the live-reconstructed base (SPEC 4.2/4.3), not to any cached or assumed value. This does not weaken Q6: a valid snapshot, once available, still governs unconditionally and always wins over live inputs, exactly as ruled. The fallback only ever activates in the absence of a snapshot to read, which is precisely the condition under which Q6's original rule has nothing to apply to. Consequence, stated plainly: this fallback is what makes file+GV deletion alone (inputs untouched) fully defended by derived history; it is also why file+GV deletion combined with input inflation remains an accepted residual gap (SPEC 4.6) at tier 3 of the cascade below, since the fallback then reads the inflated input as if it were legitimate. Extended, not superseded, by the ratchet fold-in below, which inserts a tier 2 between the snapshot and this live-input fallback.

Status: FINAL.

### Active-state limit inflation: ratchet defense

**Decision (RULED, owner ruling 2026-07-30):** build it. Scope: Phase 2. Implemented only after Phase 0 is green. Grounds for the ruling, stated for the record: this product's entire posture is friction, not prevention, already, since killing the terminal always works and is conceded everywhere else in this design, so "friction not prevention" disqualifies nothing here either. The named threat is impulsive loosening under pressure; a deliberate multi-step requirement is exactly the defense against impulse.

**UNRULED, 2026-07-30, mechanism only, pending owner ratification of the correction below. Not cited as authority by any session until ratified.**

**Mechanism, corrected.** The first pass ratcheted the two raw inputs independently and treated disabling a leg to 0 as loosening. Wrong under Q8's min-of-enabled: a leg that was never the binding constraint can be disabled with zero effect on the enforced limit, and the independent-input version blocks that as a false positive. Worked case that exposed it (owner's): base 2000, `DailyLossPercent=5` gives leg value 100, `DailyLossCurrency=50` gives leg value 50, effective limit 50, currency leg binds. Disabling the percent leg changes nothing, the currency leg still binds at 50, yet the independent-input ratchet would have blocked the disable as if it were a loosening.

Corrected mechanism: ratchet the **derived `limit_currency`**, not the raw inputs. Well-defined intraday because Base is invariant intraday (item 2's proof), so `limit_currency` only moves when an input actually moves the effective value, and the ratchet re-baselines cleanly at the day anchor regardless of which leg moved. Maintain a single scalar, `floor_currency`, as a running minimum: at the first evaluation after each day anchor, seed `floor_currency := limit_currency` (live-computed, current inputs, Q8's min-of-enabled). Every tick thereafter, `floor_currency := min(floor_currency, limit_currency)`. The value enforced everywhere the design reads "the limit" during ACTIVE is `floor_currency`, not the raw live computation. This subsumes the disable-as-loosening case for free, no special-casing required: disabling a non-binding leg does not move `limit_currency`, so it does not move `floor_currency` either. Re-deriving the worked case: floor seeded/held at 50, percent disabled, live `limit_currency` recomputes to 50, currency leg unchanged, `floor_currency = min(50, 50) = 50`, no block, no false positive.

**Persistence, home, and discipline (revised):** still its own file, `floor_<login>.dat`, same reasoning as before: Amendment 2a's precedent is that a separate concern gets a separate file rather than widening the charter-constrained lock state file (lock state only, nothing else, per charter). Fields, revised to match the single-scalar mechanism: `floor_day_anchor` (datetime, which day this floor belongs to), `floor_currency` (double, the running minimum), checksum, one fewer field than the first pass since there is now one tracked quantity, not two. Same atomic-write path, same `AgChecksum` reuse, same never-loaded-never-written discipline via `g_ag_floor_loaded`, mirroring `g_ag_halt_loaded` and `g_ag_state_loaded`.

**GV-mirrored, reasoning unchanged:** yes, mirrored every tick like `AG_LOCK`. The lock has three independent witnesses, one of which, broker history, cannot be forged locally. The floor has at most two, both locally writable, because an input value is never a deal and leaves no trace in broker history. No third leg is possible for this artifact on this platform, so the redundancy between file and GV carries more weight here than it does for the lock, not less.

**Interaction with the breach snapshot:** unchanged from the first pass, still none needed. The ratchet governs pre-breach ACTIVE, Q6's snapshot governs post-breach LOCKED, the phases stay disjoint. `limit_snapshot` taken at breach is automatically `floor_currency` at that instant, since the floor is what ACTIVE enforces throughout, no extra obligation.

**Interaction with the Q6 fallback, missed in the first pass, folded in per owner instruction 2026-07-30:** item 3's `limit_for_comparison` cascade for the boot-time derived-breach reconstruction gains a tier. Restated in full:

1. Valid, unexpired state-file snapshot exists, use `limit_snapshot` (Q6, unchanged, still highest priority).
2. No valid snapshot, but a valid same-day floor exists (`floor_<login>.dat` loads, checksums, login matches, and `floor_day_anchor` equals today's day anchor, a floor file left over from a prior day, never re-seeded because the EA has not run a tick since rollover, is stale and does not count as valid here), use `min(live_limit_currency, floor_currency)`. In practice this resolves to `floor_currency`, since the floor is itself a running minimum already incorporating every live value observed up to the EA's last evaluation. `min` is stated explicitly anyway so the formula degrades correctly regardless of exact tick alignment, rather than asserting an equivalence that depends on it.
3. Neither snapshot nor valid floor, use `live_limit_currency` alone, unchanged from the original fallback.

**Residual, re-sized honestly, not oversold.** Two distinct residuals, not one; the fold-in improves only the second:

- **The ratchet's own residual, unchanged from the first pass:** destroying both the floor file and the floor GV, no input inflation even required, resets `floor_currency` to whatever the live input says on the next seed. Nothing narrows this specifically: still roughly three to four deliberate steps (dialog, value, clear floor file, clear floor GV, confirm) against the ratchet's own pre-breach protection, and still a hard platform ceiling, not a design shortfall, since input values leave no trace in broker history on this platform, ever.
- **The F4 derived-lock residual, this is what narrows:** before the fold-in, state file destroyed plus lock GV destroyed plus input inflated was sufficient to defeat the boot-time derived reconstruction (old tier 2, now tier 3, live input alone, inflated). After the fold-in, that combination is no longer sufficient as long as either the floor file or the floor GV survives, tier 2 picks up the surviving floor and `min()` correctly ignores the inflated live value. Defeating the derived-lock reconstruction now requires all four persisted witnesses gone (state file, lock GV, floor file, floor GV) together with input inflation, not two. That is the honest size of the improvement: two additional artifacts an attacker must also destroy, not a claim that the gap is closed. It is narrower, not closed.

**Acceptance-row consequences:** P2-13 (Phase 2 matrix, combined file+GV destruction with input inflation) is now incompletely worded as originally stated, since it no longer reliably defeats the design once a floor exists. Revise it and add the row that documents the true remaining boundary:

| # | Obligation | Test | Evidence that closes it |
|---|---|---|---|
| P2-13 (revised) | State file+lock GV destruction with input inflation, floor intact | Delete state file, clear lock GV, inflate input, leave floor file+GV untouched, restart | Derived breach still true via tier 2 (`min(live, floor)`); confirms the fold-in, not the old 3-condition failure |
| P2-17 | Fully compromised residual, honestly documented | Same as P2-13 (revised), but also delete the floor file and clear the floor GV, then restart | Documented expected-fail row: no lock derived. Confirms the narrowed residual is exactly these five conditions together, not fewer |

**Alternative, costed: log loudly and accept.** Unchanged from the first pass: zero new files, zero new persisted state, zero new GV, zero new load/save/corruption path, zero new acceptance rows. Detect-only, the same posture already accepted for Q3/F2, extended rather than invented fresh.

**Recommendation, mechanism only, awaiting ratification:** build it as corrected above. The decision to build is already ruled; this section restates the mechanism the owner flagged as buggy and re-derives every downstream consequence, persistence fields, the Q6-fallback interaction, the residual size, the acceptance rows, from the corrected version. Nothing here is binding for implementation until ratified.
