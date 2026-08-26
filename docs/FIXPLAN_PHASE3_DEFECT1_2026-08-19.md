# Fix plan, defect 1, the expiry straddle

Dated 2026-08-19. Written on branch `worktree-phase3-defect-fixes` at HEAD `f9b8b47`, before any
source file was changed. NO CODE WAS WRITTEN, NO COMPILE WAS RUN AND NOTHING WAS DEPLOYED.

## Scope and what this document is not

Defect 1 is the first of four in the fix order ruled 2026-08-19 and FINAL in DECISIONS of that
date. A ruled order is not an instruction to build, so this document is a plan and not a fix.

**NO SHAPE IS RECOMMENDED HERE.** The owner reserves the design. Two shapes are named in the
ISSUES entry for this defect and both are laid out below side by side, with a third that is
mechanically distinct from both. Each is described, sized against the source, and given post fix
predictions. The choice is the owner's and the executor makes none.

Predictions continue the numbering of `docs/PREDICTIONS_PHASE3_DEFECTS_2026-08-19.md`, which
ended at P24, so this document runs P25 onward and the numbering does not restart per shape.
Notation matches that document: `<...>` marks a field whose value depends on the run, and a
prediction of ZERO occurrences is a prediction about a whole named window, not about a sample,
and closes only on a count over that window.

## The defect, restated against the source

Three facts, each checkable on its own.

`g_ag_resyncing`, declared at `AccountGuardian.mq5:50`, is written true in exactly one place,
the `TERMINAL_CONNECTED` guard at the head of `AgEvaluateActive`, `AccountGuardian.mq5:528-534`,
and cleared in exactly one place, the coherence gate at `AccountGuardian.mq5:547-556`. Neither
runs while the state is LOCKED, because `OnTimer` dispatches LOCKED to `AgEvaluateLocked` at
`AccountGuardian.mq5:947-948`.

Lock expiry runs `AgTransition(AG_STATE_ACTIVE, "lock expired", "")` at
`AccountGuardian.mq5:457`, entering ACTIVE DIRECTLY. The SYNCING stability polls at
`AccountGuardian.mq5:913-943` therefore never run either.

The coherence gate is written `if(g_ag_resyncing)` at `AccountGuardian.mq5:547`, so with the
flag false the first post expiry pass reaches the computation at `AccountGuardian.mq5:600` and
the breach tail at `AccountGuardian.mq5:628-662` with no history stability check of any kind
between the transition and its eligibility to declare a breach.

LIVE EVIDENCE OF THE PRECONDITION, `docs/evidence/journal-20260819-stage7-lock-expiry.txt`,
2026-08-19, build `74D666E9`: the server clock sat frozen for 61 minutes 32 seconds straight
across the anchor, then advanced an hour in one tick and expiry fired one second later. That
file carries exactly three non LIFE lines, the expiry INFO, the `LOCKED->ACTIVE` TRANSITION and
the ratchet reseed, and not one of them is a SYNCING or a RESYNC line.

THE CONSEQUENCE IS NOT OBSERVED. 2026-08-19 was harmless because the account was flat, zero
positions and zero deals in the new window. One difference from the chain as first written is
recorded rather than smoothed over: that instance arrived through a FROZEN QUOTE WHILE CONNECTED
and not through a disconnect, so the gate had nothing to arm it rather than being bypassed. The
hazard is the same and the route to it is wider than a disconnect alone. THAT DIFFERENCE IS
DECISIVE FOR SHAPE B AND IS THE REASON THE TWO SHAPES ARE NOT INTERCHANGEABLE.

## Shape A, route expiry through SYNCING

### Exact functions and line ranges touched

| File | Range | Change |
| --- | --- | --- |
| `MQL5/Experts/AccountGuardian/AccountGuardian.mq5` | `:457` | `AgTransition(AG_STATE_ACTIVE, "lock expired", "")` becomes `AgTransition(AG_STATE_SYNCING, "lock expired", ...)` |
| `MQL5/Experts/AccountGuardian/AccountGuardian.mq5` | `:442-459` | the surrounding expiry block gains whatever reset the new destination needs, and the comment block at `:406-417` naming the unlock path is rewritten |

Nothing else is touched. The SYNCING branch at `:914-944` already exists, already polls
`AgHistoryStable(HistoryStablePolls)` at `:916`, already calls `AgBootDerivation` at `:926`, and
already transitions to ACTIVE at `:937` on stability. The whole of `AgEvaluateActive` is
untouched, including both gates. `Pnl.mqh`, `State.mqh`, `Clock.mqh` and `Persist.mqh` are
untouched.

### What it changes on the running path

Every lock expiry, whatever caused it, enters SYNCING instead of ACTIVE. The EA then spends
`HistoryStablePolls` passes, three at the ruled default against a one second timer, polling
`AgHistoryStable` at `Pnl.mqh:253-276`, which itself returns false while `TERMINAL_CONNECTED`
is false and resets its counter on any change in `HistoryDealsTotal()`. Only after three
consecutive stable polls does `AgBootDerivation` run and the EA reach ACTIVE. The first ACTIVE
pass is therefore the first pass eligible to declare a breach, and it is preceded by the same
stability discipline every cold boot already uses.

Because the hop is unconditional, it covers BOTH straddle routes, the disconnect and the frozen
quote while connected, without inspecting either.

`AgBootDerivation` at `:199-317` now runs at every expiry. On a flat account it returns 0 and
emits no witness line. On an account still carrying a loss that clears the new day's enforced
limit, its live disjunct at `:284` fires and the EA re enters LOCKED through
`AgEnterLockFromBoot` at `:377-404` rather than through `AgDeclareLock` at `:656`.

### What it does NOT change

The expiry comparison itself, `now_server >= g_ag_locked_until` at `:442`, is untouched, and it
still reads `AgServerNow`, which is `TimeCurrent`. `locked_until` arithmetic is untouched. The
state file reset and write at `:446-451` are untouched. The Q9 baseline resets at `:455-456` are
untouched. `g_ag_resyncing`, `g_ag_obs_connected` and `g_ag_obs_resync_prev` are all untouched,
so no Stage 6 global is read or written by this shape. The RESYNC event lines at `:960-968`
never fire from this shape, because the flag they observe never moves.

### Interaction with FINAL rulings

- DECISIONS, Q7, owner ruling 2026-07-29, TimeCurrent is the only permitted clock in an expiry
  decision. UNAFFECTED. The comparison and its clock source are byte identical; only the
  destination state changes.
- DECISIONS, Q1, owner ruling 2026-07-29, `locked_until` is the next day anchor. UNAFFECTED.
- DECISIONS, owner ruling 2026-08-18, the stale quote ruling. NOT CONTRADICTED, and the reason
  is worth stating rather than asserting. That entry bars the quote freshness mechanism from
  suppressing, delaying or gating a decision. Shape A conditions the hop on nothing at all, not
  on quote age and not on connection state, so no freshness mechanism gates anything. It does
  delay the first post expiry decision by about three seconds unconditionally. The nearest thing
  on the record to an objection is part four of the four part proposal of 2026-08-14, which
  warned against exactly a three second RESYNC delay at the 01:00 boundary, and that part was
  declared MOOT by this same stale quote ruling, so it is not a live constraint.
- DECISIONS, owner ruling 2026-08-18, Phase 2 open question SIX, observability. UNAFFECTED.
  Shape A reads and writes no Stage 6 global, so the stage's static acceptance row still holds
  as written.
- DECISIONS, owner ruling 2026-08-18, Phase 2 open question FIVE, total exposure. NOT
  CONTRADICTED. That ruling makes re locking each day on a held loser INTENDED. Shape A does not
  change whether the re lock happens, it changes which path it arrives by.
- DECISIONS, Q6, owner ruling 2026-07-29, and the Q6 clarification, owner ruling 2026-07-30.
  THIS IS THE ONE INTERACTION THAT COSTS SOMETHING AND IT IS NOT A CONTRADICTION OF THE SHAPE
  BUT A WIDENING OF DEFECT 3. `AgEnterLockFromBoot` at `:393` passes the existing model values
  into `AgStateSetBreach`, so a lock declared through the boot derivation persists an empty Q6
  snapshot and a zero breach timestamp. That is defect 3, which the fix order of 2026-08-19
  places THIRD. Shape A makes the boot derivation the routine path for expiry time re locks, so
  it converts a class of re locks that today would take the ACTIVE tail and a correct snapshot
  into re locks that take the boot path and an empty one. Between shipping shape A and shipping
  the defect 3 fix, that window is open. Stated, not ruled.
- The SPEC transition table. Amendment A7 is DRAFTED AND NOT COMMITTED to `docs/SPEC_v0.1.md`,
  per the ACTIONS entries of 2026-08-18, so no session may cite it as applied. Its drafted row
  reads LOCKED to ACTIVE on expiry, which shape A would replace with LOCKED to SYNCING. Recorded
  so the wording is settled with the owner when A7 is ruled, and no SPEC edit follows from this
  document.

### Post fix predictions, shape A

**P25.** Exactly one expiry line, unchanged from P1,
`AG|<server>|INFO|lock expired|locked_until=<locked_until>|server=<server>`.

**P26.** Exactly one `AG|<server>|TRANSITION|LOCKED->SYNCING|lock expired|<detail>` line, and
ZERO `TRANSITION|LOCKED->ACTIVE` lines anywhere in the expiry window. This line replaces P2 and
its absence in the presence of P25 would mean the change did not reach the running binary.

**P27.** Exactly one `AG|<server>|TRANSITION|SYNCING->ACTIVE|history stable|polls=3/3` line,
landing three seconds after P26 at the one second timer, carrying `polls=3/3` and never
`polls=<n>/3` for n below 3. P26 and P27 together are the whole of the artifact this shape
produces and the row closes on them.

**P28.** ZERO LIFE lines carrying `state=SYNCING` are predicted in this window, AND THIS IS A
PREDICTION ABOUT THE SAMPLER RATHER THAN ABOUT THE STATE. The SYNCING occupancy is about three
seconds against a thirty second LIFE cadence, so the expected count is about 0.1 per event, the
same one in ten blindness the P1-O ruling of 2026-08-17 already measured on the RESYNC prefix. A
run that does show one is not a failure and a run that does not is not evidence of absence. The
row must never be written to close on a LIFE line.

**P29.** ZERO `RESYNC entered` and ZERO `RESYNC exited` lines in the window, and ZERO LIFE lines
carrying `waiting_on=RESYNC: polls=<n>/<required>`. Shape A closes the defect without ever
arming the RESYNC gate, so the acceptance row P3-1 is satisfied by its first evidence form and
not its second.

**P30.** On a FLAT account, meaning no open position and no deal since the new anchor, ZERO
`boot witness` lines of any kind at the SYNCING exit, counted over the session. `AgBootDerivation`
returns 0 and emits nothing when no witness fires.

**P31.** On an account carrying an open loss that clears the new day's enforced limit at the
moment of expiry, exactly one
`AG|<server>|INFO|boot witness DERIVED fired|live=1|replay=<0|1>|realized=<r>|floating=<f>|running_min=<m>|limit_cmp=<L>|tier=<snapshot|floor|live>|bounded=<t>`
line and exactly one
`AG|<server>|TRANSITION|SYNCING->LOCKED|boot derivation: DAILY_BREACH|locked_until=<t>` line,
INSTEAD OF P27. The state file written by that pass is predicted field by field as
`AGSTATE|1|<login>`, `L|1|<locked_until as epoch>|0`, `N|0.00000000|0.00000000`, `C|<crc>`, with
a zero `breach_at` and both snapshot fields zero, which is defect 3 arriving on a path shape A
newly makes routine.

**P32.** `ACTIVE->LOCKED` count stays ZERO across the whole expiry window under shape A even
when P31 fires, because every expiry time re lock arrives as `SYNCING->LOCKED`. Shape A
therefore supplies no control for P2-A and leaves that row exactly where it stands.

**P33.** The first LIFE line after P27 reads `state=ACTIVE` with `waiting_on=-` and the full
numbers group, `anchor=`, `realized=`, `floating=`, `base=`, `limit=` and `pnl_vs_limit=`, and
carries no `DEGRADED` prefix. During the SYNCING window, `AgPnlNumbersString` at
`AccountGuardian.mq5:138-149` returns empty because the state is not ACTIVE, so any SYNCING LIFE
line that does land carries no numbers, which is the defect 4 shape appearing for three seconds
in a second state.

## Shape B, arm `g_ag_resyncing` from the connection observer, independent of state

### One form of this shape is not proposed, and it is named first

The ISSUES entry names this shape as arming the flag from the Stage 6 connection observer that
samples `g_ag_obs_connected` every tick. `g_ag_obs_connected` is declared at
`AccountGuardian.mq5:110` under a comment stating that every Stage 6 global is written by the
timer, read by the logger and read by nothing else, and that this is the stage's own static
acceptance row rather than a convention. `g_ag_resyncing` is a gating flag. Making the
observability global feed it turns an observability global into a decision input.

Whether that contradicts a FINAL turns on how one sentence is read. DECISIONS, owner ruling
2026-08-18, Phase 2 open question SIX, says of the observability items that "it may log, and it
may never suppress, delay or gate a decision". The subject of that sentence in its own context
is the quote age note, which is the item the preceding clause names. Under the NARROW reading
the sentence binds the quote age note only, and the connection observer is unbound. Under the
BROAD reading it binds all three items, and arming a gate from `g_ag_obs_connected` contradicts
it outright.

The plan does not need that reading resolved, because the collision is removable. The form laid
out below reads `TerminalInfoInteger(TERMINAL_CONNECTED)` FRESH at the same point in `OnTimer`
and never reads `g_ag_obs_connected` at all. It is otherwise identical in behaviour. THE FORM
THAT READS THE STAGE 6 GLOBAL IS NAMED HERE AND IS NOT PROPOSED, because under the broad reading
it contradicts a FINAL and because it breaks the Stage 6 static acceptance row as that row is
written, regardless of the reading.

### Exact functions and line ranges touched

| File | Range | Change |
| --- | --- | --- |
| `MQL5/Experts/AccountGuardian/AccountGuardian.mq5` | `:895` | after the existing connection sample, add a state independent arm: when the fresh `TERMINAL_CONNECTED` read is false, set `g_ag_resyncing = true` |
| `MQL5/Experts/AccountGuardian/AccountGuardian.mq5` | `:50` | the comment on the `g_ag_resyncing` declaration is rewritten, since the flag is no longer set only inside `AgEvaluateActive` |

Nothing else is touched. `AgEvaluateActive` at `:525-663` is untouched, including the existing
arm at `:531` which becomes redundant but harmless and the gate at `:547-556` which is the
consumer. `AgEvaluateLocked` at `:418-460` is untouched and the expiry transition at `:457`
still enters ACTIVE directly. The RESYNC edge detector at `:960-968` is untouched and picks up
the new arming edges for free.

### What it changes on the running path

A disconnect observed in ANY state, including LOCKED and SYNCING, arms the coherence gate. After
expiry the EA still enters ACTIVE directly, but the first ACTIVE pass now finds
`g_ag_resyncing` true, takes the gate at `:547`, and returns early with
`waiting_on=RESYNC: polls=<n>/3` until `AgHistoryStable(HistoryStablePolls)` passes.

TWO CONSEQUENCES BEYOND THE STRADDLE, both of which follow from where the flag is cleared. The
flag is cleared only at `:555`, inside `AgEvaluateActive`, which does not run while LOCKED. So a
disconnect that begins AND ends entirely inside a locked window, hours before expiry, arms the
flag and it STAYS ARMED until the first ACTIVE pass after expiry. The gate therefore fires at
expiry for any disconnect anywhere in the locked window, not only for one that straddles it.
And the `RESYNC entered` event line is emitted at the moment of the disconnect while the state
is still LOCKED, which is a new line in a new place.

The arm does not survive a restart. `g_ag_resyncing` is in memory and initialises false at
`:50`, so a cold boot inside a locked window loses it. That path is already covered by the
SYNCING stability the boot itself runs, so it is a gap in the flag rather than in the coverage.

### What it does NOT change

THE FROZEN QUOTE ROUTE IS NOT COVERED AT ALL, AND THAT IS THE OBSERVED ROUTE. On 2026-08-19 the
terminal was CONNECTED throughout the 61 minute 32 second freeze, so a connection based arm
never fires and the artifact is byte for byte what the unfixed build produces. Shape B closes
the disconnect straddle and leaves the frozen quote straddle exactly where it is.

Widening the arming condition to the quote age measure, `AgQuoteFrozen` at
`AccountGuardian.mq5:168-173` or the note at `:499-513`, WOULD close that route and WOULD
CONTRADICT a FINAL: DECISIONS, owner ruling 2026-08-18, the stale quote ruling, states that the
mechanism may log and may never suppress, delay or gate a decision, and gating the first post
expiry evaluation on quote age is precisely a delay conditioned on quote freshness. THAT
VARIANT IS NAMED HERE AND IS NOT PROPOSED.

Also unchanged: the expiry comparison and its clock, `locked_until` arithmetic, the state file
write at expiry, the transition string `LOCKED->ACTIVE`, `AgBootDerivation`, which never runs on
this path, and every Stage 6 global.

### Interaction with FINAL rulings

- DECISIONS, Q10, owner ruling 2026-08-08, and the Q10 reconnect coherence amendment, owner
  ruling 2026-08-09. SQUARELY INSIDE THE RULING'S OWN PURPOSE. The amendment exists to hold the
  first post disconnect breach decision until history stability is re established, and shape B
  makes that hold reachable from a disconnect the current code cannot see because it happened in
  another state. It does not amend either ruling, it extends where the existing gate can be armed
  from.
- DECISIONS, owner ruling 2026-08-18, the stale quote ruling. NOT CONTRADICTED BY THE PROPOSED
  FORM, which arms on connection state and never on quote age. CONTRADICTED BY THE WIDENED
  VARIANT, which is why that variant is not proposed.
- DECISIONS, owner ruling 2026-08-18, Phase 2 open question SIX. NOT CONTRADICTED BY THE
  PROPOSED FORM, which reads `TERMINAL_CONNECTED` fresh and touches no Stage 6 global.
  CONTRADICTED UNDER THE BROAD READING BY THE FORM THAT READS `g_ag_obs_connected`, which is why
  that form is not proposed.
- DECISIONS, Q7, owner ruling 2026-07-29, and Q1, owner ruling 2026-07-29. UNAFFECTED. Neither
  the expiry comparison nor `locked_until` is touched.
- DECISIONS, Q6, owner ruling 2026-07-29, and the Q6 clarification, owner ruling 2026-07-30.
  UNAFFECTED, and this is where shape B costs less than shape A. Expiry time re locks continue to
  arrive through the ACTIVE breach tail and `AgDeclareLock` at `:656`, which writes a full
  snapshot, so shape B does not widen defect 3.

### Post fix predictions, shape B

**P34.** DISCONNECT ROUTE. Exactly one `AG|<server>|INFO|RESYNC entered|reconnect coherence gate
armed, evaluation waits for history stability before the first post-disconnect breach decision`
line, emitted on the first tick after the connection sample reads false, WHILE THE STATE IS
STILL LOCKED. That placement, a RESYNC entry line sitting above LOCKED LIFE lines rather than
ACTIVE ones, is the single cheapest discriminator between shape B and the unfixed build.

**P35.** DISCONNECT ROUTE. The LOCKED LIFE lines inside the disconnect are UNCHANGED from the
unfixed build and still read
`AG|<server>|LIFE|state=LOCKED|seconds_in_state=<n>|waiting_on=expiry: TimeCurrent >= locked_until|DEGRADED: disconnected|server=<server>|local=<local>`,
because `AgObservabilityNote` at `:499-513` is untouched.

**P36.** DISCONNECT ROUTE. At expiry, exactly one `INFO|lock expired` line and exactly one
`AG|<server>|TRANSITION|LOCKED->ACTIVE|lock expired|` line, both unchanged from P1 and P2, and
ZERO `LOCKED->SYNCING` and ZERO `SYNCING->ACTIVE` lines in the window.

**P37.** DISCONNECT ROUTE. Exactly one `AG|<server>|INFO|RESYNC exited|history stable again,
evaluation resumes` line, landing about three seconds after P36. P34 and P37 together are the
whole of the artifact and the row closes on them.

**P38.** DISCONNECT ROUTE. The expected count of LIFE lines carrying
`waiting_on=RESYNC: polls=<n>/3` is about 0.1 per event, for the same thirty second sampler
reason as P28, so ZERO such lines is the expected observation and is not evidence that the gate
did not arm. The event lines are the instrument, exactly as the Stage 6 comment at `:950-959`
already argues.

**P39.** FROZEN QUOTE ROUTE, WHICH IS THE OBSERVED 2026-08-19 INSTANCE. ZERO `RESYNC entered`
and ZERO `RESYNC exited` lines anywhere in the window, ZERO LIFE lines carrying
`waiting_on=RESYNC:`, and an expiry window whose non LIFE lines are exactly the same three the
unfixed build emitted, the expiry INFO, the `LOCKED->ACTIVE` TRANSITION and the ratchet reseed.
Shape B is predicted to change NOTHING on this route, and this prediction is the falsifiable
statement of that limit.

**P40.** DISCONNECT WHOLLY INSIDE THE LOCKED WINDOW, ending hours before expiry. One
`RESYNC entered` line at the disconnect, ZERO `RESYNC exited` lines until after expiry, and then
exactly one `RESYNC exited` line about three seconds after the `LOCKED->ACTIVE` transition. The
elapsed time between the two event lines is predicted to equal the whole remaining locked
window and not the length of the disconnect, which is the latch behaviour stated above appearing
in the artifact.

**P41.** A cold boot anywhere inside the locked window resets the flag, so a straddling
disconnect that is interrupted by a terminal restart is predicted to produce ZERO `RESYNC
entered` lines after that restart. The boot's own SYNCING stability covers the same ground by a
different route, so this is a hole in the flag and not in the coverage, and it is listed so a
run containing an unplanned restart is not read as a failed fix.

## Shape C, gate the DECLARATION rather than the pass

This shape is included because it is mechanically distinct from both of the above and not
because it is preferred. It is not a blend: it neither changes the route into ACTIVE, which is
shape A's whole mechanism, nor changes what arms `g_ag_resyncing`, which is shape B's whole
mechanism. It leaves both alone and instead conditions the one act the defect actually endangers.

### Exact functions and line ranges touched

| File | Range | Change |
| --- | --- | --- |
| `MQL5/Experts/AccountGuardian/AccountGuardian.mq5` | new global near `:50` | a per ACTIVE occupancy witness flag, cleared on entry to ACTIVE and set the first time `AgHistoryStable(HistoryStablePolls)` returns true during that occupancy |
| `MQL5/Experts/AccountGuardian/AccountGuardian.mq5` | `:457` and `:937` | the two `AgTransition(AG_STATE_ACTIVE, ...)` call sites clear the new flag, `:937` additionally seeds it true since SYNCING has just proven stability |
| `MQL5/Experts/AccountGuardian/AccountGuardian.mq5` | `:628-662` | the breach tail gains one condition: while the witness is unset, poll `AgHistoryStable` and WITHHOLD the declaration with a loud WARN, rather than skipping the pass |

`AgEvaluateActive`'s region above the breach tail, `:525-627`, stays byte identical, which is the
same scoped diff row every Phase 2 stage has used. `AgEvaluateLocked` keeps its direct
`LOCKED->ACTIVE` transition. `g_ag_resyncing` and every Stage 6 global are untouched.

### What it changes on the running path

Nothing about evaluation. The numbers are computed on every pass, the LIFE lines carry the full
numbers group from the first ACTIVE pass, and no pass returns early. Only `AgDeclareLock` at
`:656` is withheld, and only until history stability is witnessed for the current ACTIVE
occupancy, bounded at `HistoryStablePolls` passes.

It covers both straddle routes, because the witness is keyed on the ACTIVE occupancy and not on
what caused it. It covers one route neither other shape does: any entry into ACTIVE, from any
cause added later, is gated by construction rather than by an arming site somebody has to
remember to add.

### What it does NOT change

The expiry comparison and clock, `locked_until`, the state file write at expiry, the transition
string, `AgBootDerivation`, which still does not run at expiry, the RESYNC gate and its event
lines, and every Stage 6 global.

ON A FLAT ACCOUNT SHAPE C IS INVISIBLE. No breach evaluates true, so nothing is withheld and no
new line is emitted. The 2026-08-19 style run, flat account across a frozen straddle, cannot
distinguish shape C from the unfixed build at all. That is stated as a property of the shape and
is what P44 predicts.

### Interaction with FINAL rulings

- DECISIONS, Q9, owner ruling 2026-08-08. THIS IS THE INTERACTION THAT NEEDS THE OWNER. Q9's
  entry states that its deferral is one pass and one pass only, so a real breach is delayed by at
  most one timer tick and never suppressed, and the mechanism paragraph says the bound is
  guaranteed. Shape C adds a SECOND, independent withholding of the declaration, bounded at
  `HistoryStablePolls` passes, which are three at the ruled default. Read narrowly, Q9's bound
  governs Q9's own mechanism and shape C amends nothing. Read as a statement about the total
  delay from a true breach to its declaration, shape C takes that total to four passes on the
  first post expiry pass and collides with the ruling. THE READING IS THE OWNER'S AND IS NOT
  TAKEN HERE. Recorded so it is not discovered after implementation.
- DECISIONS, Q6, owner ruling 2026-07-29, and the Q6 clarification, owner ruling 2026-07-30.
  UNAFFECTED. Declarations still arrive through `AgDeclareLock` with a full snapshot, so defect 3
  is not widened.
- DECISIONS, owner ruling 2026-08-18, the stale quote ruling. NOT CONTRADICTED. The witness is
  keyed on history stability, which is a history property and not a quote freshness property, and
  it is the same primitive Q10's own amendment already uses.
- DECISIONS, owner ruling 2026-08-18, Phase 2 open question SIX. UNAFFECTED, no Stage 6 global is
  read or written.
- DECISIONS, Q7 and Q1, owner rulings 2026-07-29. UNAFFECTED.

### Post fix predictions, shape C

**P42.** Exactly one `INFO|lock expired` line and exactly one
`AG|<server>|TRANSITION|LOCKED->ACTIVE|lock expired|` line, both unchanged from P1 and P2, and
ZERO `LOCKED->SYNCING`, ZERO `SYNCING->ACTIVE`, ZERO `RESYNC entered` and ZERO `RESYNC exited`
lines anywhere in the expiry window.

**P43.** The first LIFE line after the transition reads `state=ACTIVE` with `waiting_on=-` and
the full numbers group, identical in form to the unfixed build's P6 line. Shape C produces no
new `waiting_on` string at all.

**P44.** ON A FLAT ACCOUNT, ZERO new lines of any kind across the whole expiry window. The
artifact is byte for byte the unfixed build's. This is the shape's own negative and it means the
acceptance row cannot be closed on a flat run.

**P45.** ON A BREACH ELIGIBLE ACCOUNT, meaning an open loss that clears the new day's enforced
limit on the first post expiry pass, between one and `HistoryStablePolls` occurrences of a new
WARN of the form
`AG|<server>|WARN|breach declaration withheld: history not yet stable since entering ACTIVE, polls=<n>/3`,
emitted on consecutive one second passes, and then exactly one
`AG|<server>|TRANSITION|ACTIVE->LOCKED|<reason>|<arithmetic>` line landing within four seconds
of the expiry transition. The count of WARNs is bounded at 3 and a run showing 4 or more falsifies
the bound.

**P46.** The state file written by that declaration carries a NON ZERO `breach_at` in the third
field of its `L` record and NON ZERO limit and base in its `N` record, because the declaration
took `AgDeclareLock` and not `AgEnterLockFromBoot`. Shape C is therefore the only one of the
three whose expiry time re lock produces the P2-A artifact and the defect 3 negative control at
the same time, which is recorded as a factual consequence and not as a reason to prefer it.

## The reproduction the owner performs

ONLY THE PRECONDITION HAS BEEN OBSERVED LIVE. The consequence, a breach decision taken on an
ungated first post expiry pass, has never been exercised, and every prediction above that
depends on it is written against a run that does not yet exist. This section is what produces
that run. The executor performs none of it and writes nothing under the Terminal data folder,
per RULE A of 2026-08-17.

THE CONSEQUENCE HAS TWO HALVES AND THEY ARE NOT EQUALLY REACHABLE. Half one, that the gate does
not arm, is provable on any straddle including the nightly frozen quote, and it is already
proven on 2026-08-19. Half two, that a wrong decision follows from a history read that is not
yet settled, needs the history to be genuinely unsettled at the expiry instant, which only a
reconnect produces. Half two may not be producible on demand, and no run below is claimed to
guarantee it.

### Preconditions, all owner side

1. The account is genuinely LOCKED with `locked_until` at the next 01:00 anchor, and the running
   binary is `74D666E9` unless a fix has been ruled and deployed by then.
2. An open losing position is carried across the anchor, sized so that its floating loss clears
   the NEW day's enforced limit at 01:00. THE SIZING IS THE OWNER'S AND IS NOT DICTATED HERE:
   the Q7 symbol specification tables are still unread and still carry the A8 corroboration debt,
   so the executor has no per symbol tick value or contract size to compute from and will not
   invent one. The owner reads the figures at the terminal.
3. The chart, the timeframe, the properties dialog, the template and the terminal are left
   untouched from before the lock until the post expiry LIFE lines are running steadily. This is
   the P2-A lesson applied: on 2026-08-18 a chart period change inside a two second window tore
   down the session mid deferral and the pass the deferral was waiting for never ran.

### The run, disconnect route

4. At about server 00:58, disconnect the network adapter, the same action already performed for
   P2-C on 2026-08-18.
5. Hold the disconnect across 01:00, so the freeze straddles `locked_until`.
6. Reconnect at about 01:02, after `locked_until` has passed in wall clock terms. The server
   clock then jumps past the anchor and expiry fires within a tick or two of the resume.
7. Touch nothing until the LIFE lines have been running steadily for several minutes, whatever
   state they report.
8. Tell the executor the run is complete. The executor reads the journal read only afterwards.

### The run, frozen quote route

The frozen quote route needs no staging at all, because it recurs every trading night: the
nightly break froze the server clock for 61 minutes 32 seconds across the anchor on 2026-08-19
and is expected to do so again. Steps 1 to 3 and step 7 apply unchanged, and steps 4 to 6 are
replaced by leaving the machine alone across 01:00. This route is what distinguishes shape B
from the other two, per P39, and it is the cheaper of the two runs.

### Negatives that make either run valid

Counted over the window from the last pre disconnect LIFE line to the first steady post expiry
LIFE line, all four must hold or the run is contaminated and is discarded rather than
interpreted:

- ZERO `INFO|deinit` lines.
- ZERO `INFO|init` lines.
- ZERO `TRANSITION` lines other than those the shape under test predicts.
- `seconds_in_state` advancing continuously within each state occupancy, with no reset that no
  transition explains.

### What the run decides

It decides nothing about which shape is right, and it is not run to choose between them. It
produces the one artifact class this defect has never had, an expiry straddle with an account
that was actually eligible to decide a breach on the far side of it, so that the predictions
above have something to be measured against.

## What closes none of this

No prediction here closes by reading source. Each names a journal line, a file content or a count
over a named window, and closes on the artifact only, which is the standing evidence rule of
2026-08-05 applied in advance. And no part of this document authorises writing code: the fix
order is ruled, the shape is not, and neither is a build instruction.
