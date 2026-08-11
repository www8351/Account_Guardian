# Phase 1 manual-trades acceptance, 2026-08-11

Joint owner-executor session, owner at the terminal for every GUI action, executor verifying
every resulting claim from artifacts. Every figure below is re-derived from the two journals
and from the owner's specification reads, never from a session report, per the FINAL ruling of
2026-08-05 that a session report is not evidence for anything.

## 1. State re-derived before anything

* Repository: `main` at `6be8d534784d2b68ab9f2f3faf66877cbede722e`. Working tree carried one
  modified file before this session's writes, `.gitignore`, the known bot-appended block left
  untouched per the 2026-08-11 merge entry.
* Commit-msg hook first bytes `23 21 2f 62 69 6e 2f 73`, BOM free.
* Running process: `terminal64` pid 4816, StartTime `2026-08-11 14:22:58`.
* Loaded binary: `AccountGuardian.ex5`, mtime `2026-08-09 19:10:59`, md5
  `AC19EAEA1A65E3C4D052E151C21502E9`, the post-Q8-amendment build.
* All seven terminal sources md5-match the repository tree pairwise, `AccountGuardian.mq5` at
  `EB646E20A17BF806C803C12A4C6878F4` and `Clock.mqh` at `31BAD26357DDF6E973DFAA1D49C337DB`.

Build identity therefore rests on the three instruments standing rule 7 permits, source md5
against the tree, the ex5 timestamp, and runtime behaviour in the journal, and on none it
forbids.

## 2. Artifacts banked

Both copied through a shared-read handle, because the running terminal holds them open, and
decoded UTF-16LE explicitly per standing rule 5. Both carry a `.txt` extension deliberately:
`.gitignore` matches `*.log`, so a `.log` copy would be ignored and this document would cite a
path no future session could retrieve. Convention set by `compile-log-pre-phase1.txt` and by
`journal-20260810-monday-reopen.txt`.

| Artifact | Bytes | md5 |
|---|---|---|
| `docs/evidence/journal-20260811-manual-trades.txt` (EA journal) | 165966 | `6D013CC77F8685A3DB3085C0D43EBB38` |
| `docs/evidence/terminal-journal-20260811-manual-trades.txt` (terminal journal) | 9416 | `95836779C50E7BB6B6006FE8C2BD5F4E` |

EA journal snapshot: 289 non-empty lines spanning local `14:23:02.951` to `16:44:03.936`. The
snapshot is a stated instant, not the whole day; the instance was left running and the
2026-08-12 rollover lands in the same log file, to be banked separately by the next session.

## 3. Boot, and one struck claim

```
AG|2026.08.11 14:23:04|INFO|init|build=Phase1|account=1200252169|server=JustMarkets-Demo3
AG|2026.08.11 14:23:04|INFO|mutex acquire|id_name=AG_ID_1200252169|id_set=1|id_exists=1|hb_name=AG_HB_1200252169|hb_set=1|hb_exists=1|hb_value=1786458182
AG|2026.08.11 14:23:04|DEBUG|crash-loop check|chain=1/3 consecutive unclean, gap bound 300s
AG|2026.08.11 14:23:04|TRANSITION|BOOT->SYNCING|boot|weekly=on|timer=1s
AG|2026.08.11 14:23:07|TRANSITION|SYNCING->ACTIVE|history stable|polls=3/3
```

BOOT to SYNCING to ACTIVE in three seconds at `polls=3/3`. Anchor seeded fresh to
`2026.08.11 01:00:00` with zero ALERT lines, zero anchor-jump notes and zero rollover lines
anywhere in the day, which is the ruled first-pass behaviour of plan 4.1a: the high-water mark
seeds to the first anchor computed this session and is never checked backward, so a restart
re-derives everything with no false positive.

**STRUCK: the session instruction's claim of a "mutex takeover over yesterday's stale
heartbeat".** No takeover occurred. Established three ways rather than asserted:

1. The takeover discriminator is `Persist.mqh:280`,
   `AgWarn("stale mutex heartbeat (" + ... + "s), taking over crashed-instance mutex")`.
   The whole day's journal carries ZERO WARN lines and ZERO occurrences of "stale".
2. `Persist.mqh:265` records that a mutex heartbeat of 0 is a deliberate release by a clean
   OnDeinit, and the takeover branch is gated at `:275` on `hb > 0.5`. Yesterday's final line is
   `AG|2026.08.10 14:12:44|INFO|deinit|reason=9|session marked clean|timer_armed=1|timer_ticks=25`,
   a clean release roughly 24 hours earlier.
3. `terminal64` started at `14:22:58`, four seconds before the EA init, so this was a cold
   terminal start onto a released mutex, not a relaunch racing a live holder.

`id_exists` and `hb_exists` are read AFTER the writes at `Persist.mqh:293,295`, so they say
nothing about the prior state and must not be read as evidence of a pre-existing holder.

The anchor-reseed observation is unaffected and stands. It corroborates the restart path only:
P1-C requires a kill "with deals present", and this restart had zero deals, so base equals
balance reduces identically and proves nothing about the minus-all-deals arithmetic. Same
boundary the 2026-08-10 entry drew for P1-D.

## 4. The eight deals

All from the terminal journal, which the EA does not write.

| # | Local | Deal | Action | Price |
|---|---|---|---|---|
| 1 | 15:19:49.256 | `#251330873` | sell 0.01 XAUUSD.ecn | 4395.87 |
| 2 | 15:20:14.901 | `#251333949` | buy 0.01 XAUUSD.ecn, closes `#410612721` | 4395.46 |
| 3 | 15:26:53.681 | `#251394323` | buy 0.01 XAUUSD.ecn | 4390.90 |
| 4 | 15:27:19.100 | `#251396880` | sell 0.01 XAUUSD.ecn, closes `#410733581` | 4391.10 |
| 5 | 16:22:53.273 | `#251754278` | buy 0.02 XAGUSD.ecn | 65.081 |
| 6 | 16:25:23.718 | `#251774078` | sell 0.01 XAGUSD.ecn, PARTIAL close | 64.896 |
| 7 | 16:27:52.537 | `#251789582` | sell 0.01 XAGUSD.ecn, closes remainder | 64.911 |
| 8 | 16:40:34.506 | `#251916522` | buy 0.01 XAUUSD.ecn, LEFT OPEN (P1-H carry) | 4399.90 |

## 5. Full-day audit of AgRealized, built from no EA-written input

Inputs: broker fill prices from the terminal journal, contract sizes from the owner's
specification reads (XAU 100, XAG 5000), and the commission rate from the same reads
(7 USD per lot on both metals).

```
gold #1   -0.07 comm  + (4395.87-4395.46) x   1 oz  = +0.41   ->  +0.34
gold #2   -0.07 comm  + (4391.10-4390.90) x   1 oz  = +0.20   ->  +0.13
silver    -0.14 comm  + (64.896 - 65.081) x  50 oz  = -9.25
                      + (64.911 - 65.081) x  50 oz  = -8.50   -> -17.89
                                                       total  = -17.42
carry #8  -0.07 comm                                          -> -17.49
```

The EA reads `realized=-17.42` from 16:28:04, and `realized=-17.49` from 16:41:04 once the carry
opens. Every deal and every commission reconciles to the cent.

**Commission is round-turn, charged wholly at entry. Measured, not assumed.** The specification
reads "instant by deal volume", which at a glance suggests a per-deal charge, but deal 2 moved
realized by exactly `+0.41`, which gross profit alone accounts for, so its commission was zero.
Replicated on deals 4 and 7, and confirmed in the opposite direction on entries 1, 3, 5, 8 where
`0.01 x 7 = 0.07` and `0.02 x 7 = 0.14` land exactly.

## 6. Rows closed

### P1-I, partial-close continuity: CLOSED

```
16:25:04  realized=0.33 |floating=-18.50|base=2003.46|limit=100.17|pnl_vs_limit=-18.17 vs -100.17
16:25:34  realized=-8.92|floating=-9.00 |base=2003.46|limit=100.17|pnl_vs_limit=-17.92 vs -100.17
```

Deal 6 closed 0.01 of the open 0.02, leaving 0.01. `(64.896 - 65.081) x 50 oz = -9.25`, and
realized moved `0.33 -> -8.92`, delta `-9.25`, exact.

The row closes on margin rather than on tolerance, and both failure modes are enumerated:

* double-count, the closed half counted in realized AND still in floating, would read about `-27.4`
* gap, the closed half's result lost entirely, would read about `-8.7`
* measured `-17.92`, against `-18.17` one 30-second sample earlier

The two failure modes sit roughly 9 currency units away in opposite directions; the observed
drift between the bracketing samples is 0.25, which is genuine silver movement. Discrimination
margin is about 37x the sampling noise. Floating halved correctly, `-18.50 -> -9.00`, tracking
the remaining 0.01 alone.

Full close, deal 7: `(64.911 - 65.081) x 50 oz = -8.50`, realized `-8.92 -> -17.42`, delta
`-8.50`, exact, floating to `0.00`.

### Q2 base identity, measured non-degenerately for the first time

`base=2003.46` and `limit=100.17` held unchanged across EVERY state today: 113 flat lines, both
gold round trips, the silver open, the partial close, the full close, and the carry open.
Balance moved on eight deals underneath them and base did not move once, because the all-deals
sum moved by exactly the same amount each time.

The 2026-08-10 entry drew the boundary explicitly: "with zero deals the reconstruction reduces
to base equals balance identically, so this proves the REDUCTION and not the minus-all-deals
arithmetic, which still needs deals present." Deals are now present, eight of them, and the
identity holds through all of them.

### Q3 per-deal formula, three of four terms live

* `DEAL_PROFIT`: exercised on deals 2, 4, 6, 7, each matching the fill-price derivation exactly.
* `DEAL_COMMISSION`: exercised on entries 1, 3, 5, 8 at `-0.07`, `-0.07`, `-0.14`, `-0.07`, each
  matching `volume x 7 USD/lot` from the specification.
* `DEAL_SWAP`: NOT exercised. No position was held across a broker rollover this session. The
  P1-H carry is expected to produce the first non-zero value tomorrow.
* `DEAL_FEE`: NOT exercised, and INFERRED zero rather than READ zero. Neither specification
  carries a fee line, only commission, and every deal decomposes completely into profit plus
  commission with nothing left over. What would upgrade this to a read: the MT5 History tab with
  the Fee column enabled, which was requested this session and not supplied.

## 7. Q7 symbol specifications, owner dialog read, CLOSED

Read by the owner from the Symbols specification windows and transcribed. This is the
instrument the plan designates for Q7 in Stage 1, and the same channel that closed the Q6
last-used gate on 2026-08-08. No screenshot reached the executor; the transcription is the
record.

### XAUUSD.ecn
Digits 2, Contract size 100 XAU, Spread floating, Stops level 0, Margin currency XAU, Profit
currency USD, Calculation Forex, Minimal volume 0.01, Maximal volume 100, Volume step 0.01.
Commissions: instant by deal volume, 0-1000: 7 USD per lot (min 0.01). Margin rates notional,
market buy and sell both 1.0 initial and maintenance, about 219.54 usd/lot.

Sessions, Quotes and Trade identical: Sunday none, Monday 01:01-23:58, Tuesday 01:00-23:58,
Wednesday 01:00-23:58, Thursday 01:00-23:58, Friday 01:00-23:58, Saturday none.

### XAGUSD.ecn
Digits 3, Contract size 5000 XAG, Spread floating, Stops level 0, Margin currency XAG, Profit
currency USD, Calculation Forex, Hedged margin 5000, Minimal volume 0.01, Maximal volume 100,
Volume step 0.01. Commissions: instant by deal volume, 0-1000: 7 USD per lot (min 0.01). Margin
rates notional, market buy about 162.38, market sell about 162.33, both 1.0 initial and
maintenance.

Sessions DIFFER between Quotes and Trade. Quotes: Sunday none, Monday through Friday
01:00-23:57, Saturday none. Trade: Sunday none, Monday 01:02-23:57, Tuesday through Friday
01:01-23:57, Saturday none.

### US100.ecn, NASDAQ 100 Index
Digits 1, Contract size 1, Spread floating, Stops level 0, Margin currency USD, Profit currency
USD, Calculation CFD Index, Tick size 0.1, Tick value 0.1, Hedged margin 1, Chart mode by bid
price, Trade full access, Execution Market, GTC mode good till cancelled, Filling Fill or Kill,
Expiration All, Orders All, Minimal volume 0.01, Maximal volume 100, Volume step 0.01.
Commissions: instant by deal volume, in deals, 0-1000: 1.25 USD per lot (min 0.01). Margin rates
notional, market buy and sell both 0.0020000 initial and maintenance, about 59.22 usd/lot.

Sessions, Quotes: Sunday none, Monday through Friday 01:00-23:58, Saturday none.
Sessions, Trade: Sunday none, Monday through Friday 01:02-23:58, Saturday none.

The A8 corroboration debt is discharged by these three tables.

## 8. FINDING: plan section 2.3's nightly-freeze figure is measured false

Placing the three quote sessions side by side under the FINAL Market Watch composition:

| Symbol | Quotes | Last quote | First quote |
|---|---|---|---|
| XAUUSD.ecn | Mon 01:01-23:58, Tue-Fri 01:00-23:58 | 23:58 | 01:00 (Mon 01:01) |
| XAGUSD.ecn | Mon-Fri 01:00-23:57 | 23:57 | 01:00 |
| US100.ecn | Mon-Fri 01:00-23:58 | 23:58 | 01:00 |

NO SUBSCRIBED SYMBOL BRIDGES MIDNIGHT. The nightly no-quote window runs 23:58 to 01:00, about
62 minutes, every weeknight, and it ends exactly on the anchor second.

Plan section 2.3 states the opposite: "The 5.4-minute midnight freeze (measured 00:00:18-00:04:48
local pinned at 23:59:56) sits a clear 55 minutes below the 01:00 anchor and does not span it
while server time tracks Israel." Nothing in the ruled composition quotes at 23:59:56, so that
figure cannot be reproduced today and is treated as a legacy measurement from a composition that
still carried a midnight-bridging instrument; BTCUSD.ecn was 24/7 and was removed 2026-08-01
under the FINAL Market Watch ruling.

Consequence, structural rather than cosmetic: EVERY WEEKNIGHT ROLLOVER FIRES AT A RESUME
BOUNDARY, exactly like the Monday reopen, differing only in jump width, 86400 s against
259200 s. The plan's claim that the anchor sits clear of the nightly freeze does not hold.

Second, narrower finding. The Monday reopen tick at server `2026.08.10 01:00:00` cannot have come
from gold, whose Monday quote session opens 01:01. It came from XAGUSD.ecn or US100.ecn, both of
which open Monday 01:00. This does not identify which, but it excludes the chart symbol the EA
runs on, and it gives the measured reopen instant a mechanism instead of a coincidence.

Both findings are directly testable on tonight's journal and neither needs staging.

## 9. Rows NOT closed, with the reason

* **P1-H, F11 double-count: day-N leg opened, row open.** Deal 8 is the carry, buy 0.01
  XAUUSD.ecn at 4399.90, left open. The row cannot close in an afternoon session by construction:
  the `2026.08.11 01:00:00` anchor had already passed and the next is `2026.08.12 01:00:00`.
  Closes tomorrow when the owner closes the position after 01:00.
* **P1-N, Q9 breach deferral: OPEN, and gated on P1-L rather than merely coincident with it.**
  Established by source read at `AccountGuardian.mq5:217-223`: the emit sits strictly inside
  `if(breach_now)`, so no breach means no deferral line can ever be written. Small trades cannot
  produce one. P1-N cannot be closed without first crossing the limit, which is P1-L.
* **P1-L, breach arithmetic: not attempted, out of the session's scope by owner instruction.**
  Would require roughly 100 currency units of manufactured demo loss against `limit=100.17`.
* **P1-C: not closed.** Today's restart carried zero deals. Now cheap to close, since deals are
  present and a position is open: a deliberate kill and relaunch tomorrow would do it.

## 10. Carry direction, reasoning recorded

Direction was chosen on swap grounds and NOT on any price expectation, which the executor
declines to dress as reasoning. F11 requires a losing position at the rollover; price direction
is unpredictable, while swap is charged deterministically at the broker's nightly rollover and
pushes the position toward loss on whichever leg carries it negative. The same choice exercises
`DEAL_SWAP`, Q3's third and only remaining measurable term.

The instruction given was BUY unless the specification's `Swap short` was more negative than
`Swap long`. THE SWAP VALUES WERE REQUESTED AND NEVER SUPPLIED, so the choice rests on the
convention that long gold carries the negative swap, not on a read. Recorded as
convention-selected rather than swap-selected; these are different evidentiary claims and this
document states which one applies. Tomorrow's closing deal settles it: a non-zero negative
`DEAL_SWAP` confirms the convention held on this broker.

Gold was chosen over silver for the carry on exposure grounds, measured this session rather than
argued: 0.01 gold is 1 oz and needs a 100-unit move to breach, while 0.01 silver is 50 oz and
needs only about 2 units, and silver was observed covering a tenth of that in three minutes.

## 11. Falsifiable expectations for the 2026-08-12 01:00:00 rollover

Recorded before the event, per the practice the Stage 5 deploy document set for the Monday
reopen. Carry entry price 4399.90, so items 4 and 7 are absolute.

| # | Expectation |
|---|---|
| 1 | Exactly ONE `day rollover\|old_anchor=2026.08.11 01:00:00\|new_anchor=2026.08.12 01:00:00\|jump=86400s`, whole-file count |
| 2 | ZERO ALERT lines and zero anchor-jump notes, `waiting_on=-` throughout. `86400` is not MORE THAN the 86400 bound, so control takes the ordinary-advance branch. Deliberate contrast with Monday's 259200 s |
| 3 | Through the freeze, LIFE lines keep landing every 30 s while the `server=` field sits frozen at about 23:58 and `local=` keeps advancing. Roughly 124 such lines. This is what falsifies the 5.4-minute figure of section 8 |
| 4 | At the rollover `realized` drops to `0.00`, `base` moves `2003.46 -> 1985.97`, `limit` moves `100.17 -> 99.30`. First time either figure has moved in this project. Balance is `2003.46 - 17.49`; with no deals inside the new window base collapses to Balance, and `1985.97 x 5% = 99.2985` renders `99.30` |
| 5 | `floating` carries across unbroken, now including accrued swap. This is F11's day-N half |
| 6 | ZERO `init` and ZERO `TRANSITION` lines, state stays ACTIVE, provided the terminal is left running |
| 7 | On close after 01:00, the closing deal carries gross P&L PLUS a non-zero `DEAL_SWAP`. The entry commission of `-0.07` stays in TODAY's window, stamped before the new anchor, so tomorrow's realized is the position result WITHOUT its entry commission. "Full realized result against day N+1" is true of the closing deal, not of the round trip |

Items 3 and 4 are conditional on no further deals before 01:00 and on swap accruing to the
position rather than to Balance. If either assumption is wrong the figures shift, and that shift
is itself the finding.

Breach headroom at session end: `82.68` before the rollover, gold to 4317.22; resetting to
`99.30` after, gold to 4300.61. A breach would fire the Q2 interim posture only, ALERT plus
journal arithmetic line capped at 30 s, state stays ACTIVE, no enforcement, demo funds.

## 12. Session limitations, stated rather than omitted

* Two reads requested and not supplied: the History tab decomposition, which leaves `DEAL_FEE`
  inferred rather than read, and the gold swap values, which leaves the carry direction
  convention-selected rather than swap-selected.
* The owner's reports and the artifacts diverged three times during the session, each caught by
  verification before it entered the record: trade 1 reported closed while the executor's
  snapshot predated it by 16 seconds, trade 2 reported closed while the terminal journal showed
  it open, and the carry reported open before the order had landed. None reached this document.
  Recorded as the standing rule working as designed, not as a fault.
* No source file was modified this session. The EA was never stopped, never reconfigured, and
  the halt file was not touched.
