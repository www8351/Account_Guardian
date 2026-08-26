# P2-A observation procedure

Dated 2026-08-19. The owner performs this at the terminal on the demo account. The executor performs no part
of it and writes nothing under the MetaTrader Terminal data folder at any point, per RULE A.

## What this row is and what it is not

P2-A is **not a code defect**. It is an acceptance row that has never been witnessed. The row asks for one
`TRANSITION|ACTIVE->LOCKED` line carrying the breach arithmetic, produced by the ACTIVE evaluation tail. On
2026-08-18 the running path reached the breach, deferred one pass exactly as question NINE requires, and was
then torn down two seconds later by a chart period change before the second pass could run. The replacement
session caught the same breach independently through the boot derivation three seconds later, so the account
locked correctly by a different route and the row's own artifact was never emitted.

The three lines that record that, quoted from `docs/evidence/journal-20260818-stage7-forced-kill.txt`:

```
AG|2026.08.18 13:02:37|WARN|breach deferred one pass: no new deal visible, count=21
AG|2026.08.18 13:02:39|INFO|deinit|reason=3|session marked clean|timer_armed=1|timer_ticks=5586
AG|2026.08.18 13:02:42|TRANSITION|SYNCING->LOCKED|boot derivation: DAILY_BREACH|locked_until=2026.08.19 01:00:00
```

`ACTIVE->LOCKED` appears ZERO times in that whole day. `SYNCING->LOCKED` appears four times.

**This row is not provable by reading source and no attempt is made here to prove it that way.** The
deferral, the transition and the arithmetic are all reachable in `AccountGuardian.mq5`, and reading them
would establish that the code contains the path, which is not the question. The question is whether the path
runs to completion on a live account when nothing interrupts it, and only a run answers that.

**Status stays OPEN** until this procedure produces the artifact.

## What it costs, stated before the preconditions

This procedure deliberately breaches a live demo account. Under ruling TWO of 2026-08-18 the guardian sends
no order, so the losing position stays open until the owner closes it by hand, and the floating loss keeps
moving in the meantime. Under question ONE the lock then holds until the next 01:00 server anchor and there
is no unlock path other than expiry. Plan for the account to be locked for the remainder of the trading day.

## Preconditions

Set every one of these before the window opens. Once the window opens, none of them may change.

**Inputs.** Set them, click OK, and then do not touch the properties dialog again for any reason. Each input
change reloads the EA, which is the very thing this row cannot survive.

| Input | Value | Why it matters here |
| --- | --- | --- |
| `DailyLossPercent` | `5.0` | the ruled default, and it fixes the limit at five percent of base |
| `DailyLossCurrency` | `0.0` | disabled, so the percent leg is the only enabled leg and the limit is unambiguous |
| `SweepPeriodSeconds` | `1` | the timer period, and therefore the length of the question NINE deferral |
| `CrashLoopMaxInits` | `3` | ruled default, unrelated to this row and set so nothing else moves |
| `CrashLoopWindowSeconds` | `300` | ruled default, same reason |
| `HistoryStablePolls` | `3` | ruled default, same reason |
| `WeeklyReportEnabled` | `true` | ruled default, same reason |
| `LogVerbosity` | `Normal` | every line this row needs is ungated, so Verbose adds noise and no evidence |

**State of the guardian before the window.** Confirm all of these from the running journal, not from memory:

1. The EA is in ACTIVE. The most recent LIFE line reads `state=ACTIVE` with `waiting_on=-` and a full
   numbers group.
2. The LIFE lattice is unbroken at its 30 second cadence for at least the preceding ten minutes.
3. The `limit=` field on that line equals five percent of the `base=` field on the same line, to the cent.
   That is the confirmation that `DailyLossPercent=5.0` actually reached the running image. Do not take it
   from the dialog.
4. The account is not already locked and no `state_<login>.dat` write is pending.

**Things that must not happen at any point between the first losing position and the first LOCKED LIFE
line.** Each of these produces a re init, and a re init voids the run.

- No chart opened and no chart closed, on any symbol.
- No chart symbol change and **no chart timeframe change**. This is the one that destroyed the 2026-08-18
  attempt.
- No template applied, and no template saved.
- No EA input change, and the properties dialog is not opened at all.
- No EA removed, re attached or dragged from the Navigator.
- No terminal restart, no terminal close, and no MetaEditor compile of any AccountGuardian file. A compile
  makes the terminal reload the EA by itself the moment the new `.ex5` is written, which was observed twice
  on 2026-08-18 at 01:59:56 and 11:26:04 and which nobody ordered.
- No machine sleep, no reboot, no Windows Update restart. Active hours 02:00 to 20:00 and the
  `NoAutoRebootWithLoggedOnUsers` policy are already set, so this is a check rather than a change.
- No network adapter change, no deliberate disconnect. A disconnect sets DEGRADED and blocks every breach
  decision, so the pass this row needs would simply not run.

Nothing else is restricted. Placing and closing trades is what the procedure is for.

## The window

1. Note the `base=` and `limit=` values from the current ACTIVE LIFE line. Call the limit `L`.
2. Open a losing position on `XAUUSD.ecn` large enough that its floating loss will exceed `L` on an ordinary
   move. Sizing guidance, derived from one measured data point on this account and not from a symbol
   specification: on 2026-08-14 a 0.01 lot XAUUSD.ecn position moved 52.25 in profit for 52.25 of adverse
   price movement, so 0.01 lot is roughly one account unit per one unit of price, and 0.50 lot is roughly
   fifty. At `L` near 106.65 a 0.50 lot position needs about 2.2 of adverse price movement. This is
   arithmetic on a past observation, not a contract size fact: the question SEVEN symbol specification
   tables are still unread and still carry the A8 corroboration debt, so confirm the sizing at the terminal
   rather than trusting this paragraph.
3. Leave everything alone and watch the `pnl_vs_limit` field on the LIFE lines walk toward `-L`.
4. Do not touch anything when it crosses. The declaration needs at most two consecutive one second passes,
   and the whole failure of 2026-08-18 was two seconds wide.
5. Stop when LIFE lines are reading `state=LOCKED`. Then confirm by hand whether the positions are still
   open, which is the ruling TWO check the journal cannot answer.

## Predicted journal lines, in order, for build `74D666E9`

These predict the CURRENT build. Where a string has never been observed it is described rather than quoted,
and it is marked as such, because pre quoting an unobserved line is how a reader is trained to see what the
document said instead of what the terminal wrote.

**Step 1, the approach.** ACTIVE LIFE lines at the 30 second cadence, each of the form

```
AG|<server>|LIFE|state=ACTIVE|seconds_in_state=<n>|waiting_on=-|anchor=<anchor>|realized=<r>|floating=<f>|base=<b>|limit=<L>|pnl_vs_limit=<p> vs -<L>|server=<server>|local=<local>
```

with `<p>` falling toward `-<L>`.

**Step 2, the deferral, and it has two conforming branches.** On the first one second pass where
`realized + floating` clears `-L`:

- If the deal count is UNCHANGED from the prior pass, exactly one line
  `AG|<server>|WARN|breach deferred one pass: no new deal visible, count=<n>` appears, and no declaration
  happens on that pass. This is the branch observed on 2026-08-18.
- If a NEW deal is visible on that pass, the deferral does not arm and the declaration happens immediately.

Both are question NINE working as ruled. Exactly one deferral line per breach is the bound.

**Step 3, the declaration, and this is the row's artifact.** On the next pass, about one second later:

- `AG|<server>|TRANSITION|ACTIVE->LOCKED|<reason>|locked_until=<t>`. The From state must read `ACTIVE`. The
  exact reason string is UNOBSERVED and is not quoted here. `<t>` is predicted to be `AgNextDayAnchor` of the
  breach instant, subject to the ruling THREE frozen quote floor and the ruling FOUR latch floor.
- Exactly one `|ALERT|` line for the declaration. Its wording is UNOBSERVED on this path. It is predicted to
  state, as the boot derivation ALERT already does, that no order is sent and open positions stay open until
  the owner closes them by hand.
- One `Alert:` echo line from MT5, which is the same event surfacing as a modal popup and is not a second
  declaration.
- The arithmetic that justified the declaration should be readable from the artifact. Whether it rides the
  TRANSITION line, a separate journal line, or the last ACTIVE LIFE line is UNOBSERVED, and which of those
  it turns out to be is part of what this row is measuring.

**Step 4, after the declaration.**

- `state_<login>.dat` is written once and its md5 moves.
- LIFE lines switch to `AG|<server>|LIFE|state=LOCKED|seconds_in_state=<n>|waiting_on=expiry: TimeCurrent >= locked_until|server=<server>|local=<local>`,
  carrying no numbers. That is defect 4 and it is expected here rather than being a finding of this run.

**Step 5, the negatives that make the run valid.** Across the whole window, from the first losing position to
the first LOCKED LIFE line, all of these must count ZERO:

- zero `INFO|init` lines and zero `INFO|deinit` lines
- zero `TRANSITION|BOOT->SYNCING`, `ACTIVE->SYNCING` or `LOCKED->SYNCING` lines
- zero `boot witness` lines of any kind
- zero `TRANSITION|SYNCING->LOCKED` lines
- zero `DEGRADED` markers and zero `RESYNC` lines

If any of these is non zero, the run was interrupted. It is VOID and is repeated, not salvaged. That
distinction is the entire lesson of 2026-08-18: the account locked correctly that day and the row still did
not close, because the artifact came from the wrong path.

## What converts this into a numbered defect

Any of the following, observed on a valid run, stops being an unwitnessed row and becomes a defect with its
own numbered entry in ISSUES.

1. **No declaration at all.** Two or more consecutive passes evaluate `realized + floating` clearing `-L`,
   with no re init between them, and no `ACTIVE->LOCKED` line ever appears. This is a fail open guardian and
   is the most serious possible outcome of this procedure.
2. **An unbounded deferral.** More than one `breach deferred one pass` line for the same breach. Question
   NINE bounds the delay at exactly one pass and one pass only, so a second deferral is a violation of a
   FINAL ruling rather than a slow declaration.
3. **A partial declaration.** The ALERT fires but no `ACTIVE->LOCKED` transition is written, or the
   transition is written but the state file is not, or the state file is written but the LIFE lines do not
   move to `state=LOCKED`. Any of the three means the declaration is not atomic and a restart could land
   between its halves.
4. **A wrong `locked_until`.** The value is not `AgNextDayAnchor` of the breach instant, and is not explained
   by the ruling THREE frozen quote floor or the ruling FOUR latch floor. An already past value is the
   severe form and unlocks instantly.
5. **An empty snapshot on this path too.** The state file written by the ACTIVE declaration carries
   `breach_at` of `0` or `N|0.00000000|0.00000000`. That would widen defect 3 from the boot derived class to
   every lock the guardian can declare, and it is the reason this run is also the negative control that
   defect 3's prediction P20 asks for.
6. **Arithmetic that does not reconcile.** The figures carried by the declaration do not match the last
   ACTIVE LIFE line before it within the ruled 0.01 epsilon, or the declaration fires while
   `realized + floating` has not in fact cleared `-L`.
7. **A trade API call.** Any order, close, modify or pending deletion attributable to the EA. Phase 2 holds
   zero trade API calls and ruling TWO is explicit that positions stay open. This is listed last because it
   is the least likely and would be the most serious.

An outcome not on this list, and not matching the predictions above, is recorded as an observation and
brought to the owner. It is not classified as a defect by the executor.

## After the run

The owner reports that the window is closed. The executor then verifies read only from the journal, copies
the artifact out to `docs/evidence/` with a `.txt` extension per the naming convention, records the md5 and
the line count, and updates the P2-A entry in ISSUES on the artifact rather than on the report. Per the
FINAL of 2026-08-05 the owner's own account of the run is not evidence for any of it.
