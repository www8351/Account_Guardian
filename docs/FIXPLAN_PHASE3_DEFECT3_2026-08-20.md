# Fix plan, defect 3, the empty Q6 snapshot on a boot derived lock

Dated 2026-08-20. Written on branch `worktree-phase3-defect-fixes` at HEAD `0a4c86b`, which is the
commit that landed defect 1 shape A, and every line citation below is against that commit rather
than against the pre shape A tree. NO CODE WAS WRITTEN FOR DEFECT 3, NO COMPILE WAS RUN AND
NOTHING WAS DEPLOYED.

## Scope and what this document is not

Defect 3 is third in the fix order ruled 2026-08-19 and FINAL in DECISIONS of that date. The owner
ruling of 2026-08-20, also FINAL, couples it to the same deployment as defect 1 and keeps the order
unchanged, so defect 1 is implemented first and defect 3 second, in one build. A ruled order and a
ruled coupling are still not an instruction to build this one, and it is not built here.

**NO SHAPE IS RECOMMENDED HERE.** Two candidate shapes are laid out side by side. They agree on
everything except one field's meaning, and that one disagreement is the whole of the choice, so it
is isolated rather than buried. Two further variants are named and explicitly NOT proposed, each
with the reason. The choice is the owner's and the executor makes none.

Predictions continue the numbering of `docs/FIXPLAN_PHASE3_DEFECT1_2026-08-19.md`, which ended at
P46, so this document runs P47 onward. Notation is unchanged: `<...>` marks a field whose value
depends on the run, and a prediction of ZERO occurrences is a prediction about a whole named window
and closes only on a count over that window.

## The defect, restated against the source

Three facts, each checkable on its own.

`AgEnterLockFromBoot` at `AccountGuardian.mq5:377-404` takes exactly two arguments, a reason and a
`locked_until`. Its DAILY_BREACH branch at `:393` calls
`AgStateSetBreach(until, g_ag_state_breach_time, g_ag_state_limit_snap, g_ag_state_base_snap)`,
passing THE EXISTING MODEL VALUES back into the setter that writes them.

Those existing values are a genuine earlier snapshot ONLY when the FILE witness supplied them. The
file witness at `:211` fires on `g_ag_state_reason != AG_LOCK_NONE && g_ag_state_locked_until > now`,
and `AgStateLoad` at `Persist.mqh:470` is what populated the model in `OnInit`. When the file is
missing, the model is default constructed at `Persist.mqh:69-73`, so `g_ag_state_breach_time` is 0,
`g_ag_state_limit_snap` is 0.0 and `g_ag_state_base_snap` is 0.0, and `:393` writes those zeros to
disk as though they were a snapshot.

THE DERIVATION HAD THE CORRECT NUMBERS IN HAND AT THAT MOMENT AND DISCARDS THEM. Inside
`AgBootDerivation`, `:276-281` computes `live_limit` and then the three tier cascade into
`limit_cmp`, `:252` computes `base` through `AgDayBase`, and `:283-285` computes `floating` and both
disjuncts. The witness line at `:290-298` PRINTS `limit_cmp` to the journal. Nothing carries any of
it out of the function: the signature at `:199` returns only `reason_out` and `until_out`.

LIVE EVIDENCE, `docs/evidence/state_1200252169.dat.live-breach-2026-08-18`, the file the live lock
wrote at 2026-08-18 13:02:42 under build `74D666E9`, 79 bytes, quoted whole: `AGSTATE|1|1200252169`,
`L|1|1787101200|0`, `N|0.00000000|0.00000000`, `C|2087926071`. Set against the witness line that
produced it, in `docs/evidence/journal-20260818-stage7-live-breach.txt`:
`AG|2026.08.18 13:02:42|INFO|boot witness DERIVED fired|live=1|replay=0|realized=574.00|floating=-920.50|running_min=-7.00|limit_cmp=106.66|tier=floor|bounded=2026.08.19 01:00:00`.
The journal carries `limit_cmp=106.66` and the file carries `0.00000000`, from the same pass, three
lines apart.

## What is actually lost, and what is not

This is where the fix gets scoped, so the consumers are ENUMERATED rather than characterised. A tree
wide grep for the three fields returns every site below and no others.

`g_ag_state_limit_snap` IS A BEHAVIOUR GATE. `have_snapshot` at `:273-275` tests
`g_ag_state_limit_snap > 0.0` as its third conjunct, and tier 1 of the cascade at `:279` is the only
consumer of the value. With zeros persisted, `have_snapshot` is FALSE on every future boot for that
lock, so tier 1 is unreachable for the entire class of boot derived locks and the cascade always
drops to tier 2, the ratchet floor, or tier 3, the live limit. That is the silently disabled
protection half of the severity.

`g_ag_state_breach_time` IS READ BY NOTHING IN THE RUNNING LOGIC. Its only consumers are
`AgStateSerialize` at `Persist.mqh:357`, which writes it, `AgStateLoad` at `Persist.mqh:531`, which
reads it back into the model, and the vector assertions. No branch anywhere tests it. Losing it is
therefore a pure loss of RECORD and not of enforcement, and the plan says so rather than inflating it.

`g_ag_state_base_snap` IS ALMOST RECORD ONLY. Its single consumer outside persistence is the Q6
input change WARN at `:451-452`, which prints it to the operator inside
`the locked window is judged by the breach snapshot limit=<l> base=<b>`. So a boot derived lock
today produces a WARN reading `limit=0.00 base=0.00`, which tells the operator the opposite of the
truth about what governs their locked window. That is the third distinct cost and it is
operator facing rather than internal.

NOT AN ENFORCEMENT HOLE TODAY, and this is unchanged from the ISSUES entry. The file witness at
`:211` re fires on reason plus an unexpired `locked_until` and never consults the snapshot, so the
lock itself survives restarts on the zeros. Tier 2 supplies the same 106.66 on this account, which
is why the live instance behaved correctly.

## The shape A interlock

THIS SECTION IS THE REASON THE TWO DEFECTS ARE COUPLED TO ONE DEPLOYMENT, and it is stated before
the shapes because it constrains both equally.

Shape A landed at `0a4c86b`. Expiry now runs `AgTransition(AG_STATE_SYNCING, "lock expired", ...)`
at `:489`, so the SYNCING branch and therefore `AgBootDerivation` run at EVERY expiry, where before
they ran only at a boot.

AT AN EXPIRY, THE DERIVED WITNESS IS THE ONLY ONE THAT CAN FIRE, and this is forced by the expiry
block itself rather than being a probability. `g_ag_locked_until = 0` at `:463` and
`AgStateResetModel()` at `:464` both run before the transition, so by the time the SYNCING exit
evaluates the witnesses three polls later:

- the FILE witness at `:211` cannot fire, because `AgStateResetModel` at `Persist.mqh:380-387` set
  `g_ag_state_reason` to `AG_LOCK_NONE`;
- the GV witness at `:224` cannot fire, because `OnTimer` rewrites the mirror from memory on every
  tick at `:918` and memory now holds 0, so the `(datetime)(long)gv_raw > now` test fails;
- the DERIVED witness at `:283-305` is the only one left.

And `have_snapshot` at `:273-275` is FALSE for the same reason the file witness is silent. So EVERY
EXPIRY TIME RE LOCK IS A DERIVED WITNESS LOCK WITH NO SNAPSHOT, which is precisely the case defect 3
gets wrong.

**BEFORE THE DEFECT 3 FIX, WHICH IS THE STATE OF THIS BRANCH RIGHT NOW.** Shape A has converted a
class of re locks that previously took `AgDeclareLock` at `:328-362` and wrote a correct snapshot
into re locks that take `AgEnterLockFromBoot` and write zeros. The defect 1 plan predicted this at
P31 and named it as a widening; it is now real on the branch rather than predicted. The window is
open from `0a4c86b` until defect 3 ships, and the owner ruling of 2026-08-20 is what closes it by
requiring one deployment rather than two.

**AFTER THE DEFECT 3 FIX, WHICH IS WHAT THE INSTRUCTION ASKS THIS PLAN TO STATE.** Under either
shape below, an expiry time re lock persists, field by field: reason `AG_LOCK_DAILY_BREACH`, which
is 1; `locked_until` equal to the `until_out` the derivation computed, which is
`AgApplyLatchFloor(AgNextDayAnchor(now))` from `:289`; `limit_snap` equal to the derivation's own
`limit_cmp` from `:276-281`; `base_snap` equal to the derivation's own `base` from `:252`; and a NON
ZERO `breach_time` whose meaning is the one thing the two shapes disagree about. The zeros are gone
from that path.

TWO CONSEQUENCES OF THAT WHICH ARE WORTH WRITING DOWN BECAUSE THEY ARE NOT OBVIOUS.

ONE, THE NEXT BOOT AFTER AN EXPIRY TIME RE LOCK BEHAVES DIFFERENTLY, AND CORRECTLY. With a non zero
`limit_snap` on disk, `have_snapshot` at `:273-275` is TRUE at that boot, so tier 1 governs and the
witness line at `:296-297` reads `tier=snapshot` where today it reads `tier=floor` or `tier=live`.
That is the Q6 protection restored for the whole class, and it is observable in one journal field.

TWO, THE SNAPSHOT WRITTEN AT AN EXPIRY TIME RE LOCK IS THE NEW DAY'S ENFORCED LIMIT AND NOT THE OLD
DAY'S, and that is correct rather than a leak across the anchor. The derivation computes `limit_cmp`
against `anchor = AgDayAnchor(now)` at `:242`, which after an 01:00 expiry is the new day's anchor,
and `AgFloorEffectiveLimit` at `Persist.mqh:713` declines a floor whose stored day anchor is stale,
so the ratchet contributes the new day's floor or nothing. A day 2 lock therefore snapshots a day 2
limit. Recorded because the opposite, a day 1 limit surviving into a day 2 locked window, would be a
real defect and a reader checking this fix should know which of the two they are looking at.

## What both shapes share

Stated once so the shapes differ by exactly one thing and the choice is clean.

Both widen the interface between `AgBootDerivation` and `AgEnterLockFromBoot`, because the values
exist in the first and are needed in the second and there is no third place to get them. Both
therefore touch:

| File | Range | Change |
| --- | --- | --- |
| `MQL5/Experts/AccountGuardian/AccountGuardian.mq5` | `:199` | `AgBootDerivation`'s signature gains outputs for the derivation's own `limit_cmp` and `base`, plus a flag saying whether the DERIVED witness is the one that supplied the winning duration |
| `MQL5/Experts/AccountGuardian/AccountGuardian.mq5` | `:283-305` | the derived witness block populates those outputs when it fires |
| `MQL5/Experts/AccountGuardian/AccountGuardian.mq5` | `:377` | `AgEnterLockFromBoot`'s signature gains the same values |
| `MQL5/Experts/AccountGuardian/AccountGuardian.mq5` | `:393` | the DAILY_BREACH branch chooses between preserving the loaded snapshot and writing the derivation's own |
| `MQL5/Experts/AccountGuardian/AccountGuardian.mq5` | `:926` region | the single call site in the SYNCING branch passes the new values through |
| `MQL5/Experts/AccountGuardian/AccountGuardian.mq5` | `:364-376` | the header comment on `AgEnterLockFromBoot`, which currently states the old behaviour as if it were the intent, is rewritten |

THE CHOICE AT `:393` IS EXPLICIT AND MUST NOT BE A BLANKET OVERWRITE. When `have_snapshot` was true
the derivation set `limit_cmp = g_ag_state_limit_snap` at `:279`, so writing `limit_cmp` back would
happen to be a no op for the limit, but `base` and the breach time would still be overwritten with
freshly computed values, and Q6 forbids exactly that substitution: a valid snapshot governs
unconditionally. Both shapes therefore branch on the same `have_snapshot` condition the cascade
already uses, preserving the loaded triple when it holds and writing the derivation's own when it
does not.

WHAT NEITHER SHAPE TOUCHES. The CORRUPT_STATE branch at `:390-391` keeps calling `AgStateSetCorrupt`
at `Persist.mqh:412-419`, which deliberately zeroes all three fields, because a corrupt state lock
has no trustworthy snapshot and claiming one would be worse than admitting none. `Persist.mqh` is
untouched entirely: the model, the serializer at `:352-359`, the setters and the loader all stay
byte identical, and the fix lives in the EA that calls them. `AgDeclareLock` at `:328-362` is
untouched, since the ACTIVE breach path already persists a correct snapshot and is not the defect.
`Pnl.mqh`, `State.mqh`, `Clock.mqh` and `Sweep.mqh` are untouched. No Stage 6 global is read or
written.

AN EXISTING VECTOR CONSTRAINT, checked rather than assumed, and it cuts both ways. The vectors that
assert on these fields all exercise the `Persist.mqh` model layer and not the EA caller:
`c5_roundtrip_breach_time`, `c6_roundtrip_limit_snapshot` and `c7_roundtrip_base_snapshot` at
`AgPhase2StateVectors.mq5:200-202`, `c8_limit_snapshot_keeps_sub_cent_precision` at `:204-207`,
`e4_corrupt_carries_no_breach_time` through `e6_corrupt_carries_no_base_snapshot` at `:237-239`, and
`g4_foreign_lock_values_were_not_adopted` at `:287-289`. Since neither shape touches `Persist.mqh`,
ALL EIGHT SHOULD PASS UNCHANGED, and a run where any of them moves means the fix reached further
than it was meant to. The other edge: for the same reason, NO EXISTING VECTOR EXERCISES THE FIX AT
ALL. `AgEnterLockFromBoot` and `AgBootDerivation` are EA functions and a script cannot include an
EA, which is the same reachability problem Stage 3 hit and which owner ruling C of 2026-08-18 solved
by moving the two bound helpers into `Clock.mqh`. Whether defect 3 gets the same treatment, a move
into an include so a vector can reach it, is a design question this plan raises and does not answer,
because it would widen the diff well beyond the ranges above and that is the owner's call.

## Shape 1, breach time is the derivation instant

### What it writes

`breach_time` takes `now`, the `AgServerNow()` value read at `:203` and used throughout the
derivation. Semantically that is WHEN THE LOCK WAS DERIVED, not when the loss crossed the limit, and
the shape's honesty rests on saying so rather than on the field's name.

### What it changes beyond the shared table

Nothing. The value is already in scope at `:283-305` and needs no new computation, no second history
walk and no change to `Pnl.mqh`.

### What it does NOT change

The replay itself. `AgRealizedFold` at `Pnl.mqh:84` keeps its current signature and its current two
outputs, the realized sum and the running minimum, so `AgRealized` at `Pnl.mqh:152` and every Phase 1
figure it has ever produced are untouched by construction.

### The cost, stated plainly

The field records an instant that can be arbitrarily later than the event. A breach that happened at
13:02 and is derived at a boot at 16:01 records 16:01. On the expiry time re lock path the two are
close, since the derivation runs three seconds after the anchor, but on a restart after a crash the
gap is however long the terminal was down. A later session reading `breach_at` from a state file
must therefore read it as a derivation stamp on this path and as a true breach stamp on the
`AgDeclareLock` path, and the field does not say which it is. That ambiguity is the whole of shape
1's cost and shape 2 exists to remove it.

## Shape 2, breach time recovered from the replay where one exists

### What it writes

When the REPLAY disjunct at `:285` is what fired, `breach_time` takes the `DEAL_TIME` of the deal at
which the running minimum first crossed `-limit_cmp`, which is a genuine breach instant recoverable
from broker history. When only the LIVE disjunct at `:284` fired, there is no deal to point at,
because the loss is floating and no deal has closed, so `breach_time` falls back to `now` exactly as
in shape 1.

### What it changes beyond the shared table

| File | Range | Change |
| --- | --- | --- |
| `MQL5/Include/AccountGuardian/Pnl.mqh` | `:84` | `AgRealizedFold` gains an output carrying the `DEAL_TIME` at which the running minimum reached its recorded value, or a second walk is added in the EA to recover it |

THIS IS THE ONE PLACE EITHER SHAPE REACHES OUTSIDE THE EA, and it reaches into the file Phase 1
froze and that carries its own static acceptance row. Two sub variants exist and neither is
preferred here: widen `AgRealizedFold`, which touches the single shared fold that `AgRealized` at
`:152` also calls and therefore puts the Phase 1 realized path under the change; or add a second,
separate walk in the EA that recomputes the crossing instant, which leaves `Pnl.mqh` byte identical
at the cost of walking the day's deals twice at boot. The first is smaller and riskier, the second
is larger and safer, and the difference matters enough that it should be settled before the code is
written rather than during.

### What it does NOT change

Everything the shared section already lists, plus: the running minimum itself, the F12 whitelist and
the Q3 per deal formula, all of which stay exactly where they are. The added output is an
observation of the existing walk, not a change to what it computes.

### The cost, stated plainly

ONE FIELD CARRIES TWO MEANINGS AND THE ARTIFACT DOES NOT DISTINGUISH THEM. A shape 2 `breach_at` is
a true breach instant when the replay disjunct fired and a derivation instant when only the live
disjunct did, and a reader holding only the state file cannot tell which. That is arguably worse
than shape 1's single consistent meaning, because shape 1 is uniformly approximate while shape 2 is
sometimes exact and sometimes not, with no marker. The journal does distinguish them, since the
witness line at `:290-291` prints `live=<0|1>|replay=<0|1>`, but the state file does not, and the
state file is the artifact that outlives the journal.

## Two variants named and NOT proposed

**Writing the snapshot from `AgBootDerivation` itself** rather than passing values out to
`AgEnterLockFromBoot`. It would keep both signatures unchanged, which looks like a smaller diff. It
is not proposed because it puts a persistence side effect inside a function whose entire contract
today is to evaluate witnesses and report, and that function also returns 2 on either NOT EVALUABLE
path, `:250` when the replay's `HistorySelect` fails and `:257` when the day base read fails, where
the EA stays in SYNCING and nothing should have been written at all. A writer that runs on a pass which does not lock is a defect waiting to be found by someone
else.

**Redefining `have_snapshot` at `:273-275` so it no longer tests `limit_snap > 0.0`**, treating the
defect as a reader problem rather than a writer problem. It is not proposed because it does not fix
anything: with zeros on disk there is no snapshot value for tier 1 to use even if the test admitted
one, so the change would make `limit_cmp` read 0.0 and turn a missing protection into a wrong one.
It is named because it is the shape a later session might reach for on seeing that `limit_snap`
gates the cascade, and the reason it fails is worth having on the record.

## Post fix predictions

Common to both shapes unless a prediction names one.

**P47.** COLD BOOT, DERIVED WITNESS ONLY, NO STATE FILE. Exactly one
`AG|<server>|INFO|boot witness DERIVED fired|live=<0|1>|replay=<0|1>|realized=<r>|floating=<f>|running_min=<m>|limit_cmp=<L>|tier=<floor|live>|bounded=<t>`
line, UNCHANGED IN EVERY FIELD from what the current build emits, because neither shape touches the
derivation's arithmetic or its logging. A field that moves here means the fix reached the cascade,
which it must not.

**P48.** Exactly one `AG|<server>|TRANSITION|SYNCING->LOCKED|boot derivation: DAILY_BREACH|locked_until=<t>`
line, also unchanged, and ZERO `TRANSITION|ACTIVE->LOCKED` lines in that window.

**P49.** THE STATE FILE, FIELD BY FIELD, AND THIS IS THE ROW THE WHOLE FIX CLOSES.
`state_<login>.dat` written by that pass reads `AGSTATE|1|<login>`, then
`L|1|<locked_until as epoch>|<breach_time as epoch>` with the third field NON ZERO, then
`N|<limit>|<base>` with BOTH fields non zero and rendered at eight decimals, then `C|<crc>`. The
`<limit>` equals the `limit_cmp` printed on P47's own line to the cent, and `<base>` equals the base
the same pass computed. The current build writes `L|1|<until>|0` and `N|0.00000000|0.00000000` on
this path, so the discriminator is a single byte comparison against the 2026-08-18 artifact.

**P50.** SUB CENT PRECISION SURVIVES. `<limit>` in P49 is the full double and not the printed cent,
so on this account a limit of 106.6565 is stored as `106.65650000` and NEVER as `106.66000000`. This
is the same property `c8_limit_snapshot_keeps_sub_cent_precision` asserts at the model layer, now
asserted on the boot derived path, and it matters because Q6 makes the snapshot the enforced value
for the whole locked window.

**P51.** FILE WITNESS CASE, THE PRESERVATION NEGATIVE. On a boot where the FILE witness fires and
carries a valid snapshot, the state file written by `AgEnterLockFromBoot` carries the SAME
`breach_time`, `limit_snap` and `base_snap` the file already held, byte for byte, with only
`locked_until` permitted to move. A run where those three change on this path falsifies the fix by
showing it overwrote a snapshot Q6 requires it to preserve.

**P52.** CORRUPT_STATE CASE, THE UNTOUCHED NEGATIVE. A lock entered with reason CORRUPT_STATE still
writes `L|2|<until>|0` and `N|0.00000000|0.00000000`. ZERO change on this path, and the three
existing vectors `e4`, `e5` and `e6` still pass.

**P53.** THE NEXT BOOT AFTER A BOOT DERIVED LOCK READS `tier=snapshot`. On the first boot following
a lock written under P49, the witness line's tier field reads `tier=snapshot` where the current
build makes it structurally impossible to read anything but `tier=floor` or `tier=live` on this
path. ONE FIELD, ONE WORD, AND IT IS THE CHEAPEST PROOF THAT TIER 1 IS REACHABLE AGAIN.

**P54.** THE Q6 OPERATOR WARN STOPS LYING. An input change during a locked window entered by boot
derivation now emits
`AG|<server>|WARN|input changed while LOCKED and is being IGNORED (Q6): percent <a>-><b>, currency <c>-><d>; the locked window is judged by the breach snapshot limit=<L> base=<B>`
with `<L>` and `<B>` NON ZERO, where the current build prints `limit=0.00 base=0.00`. Recorded as a
prediction rather than a nicety because it is the only place either snapshot value reaches a human
in normal operation, and because P2-H is not closable by code per the FINAL of 2026-08-19, so this
line will be seen only if an input change happens to land in a locked window for other reasons.

**P55.** SHAPE A INTERLOCK, THE EXPIRY TIME RE LOCK. On an expiry where the account still carries a
loss clearing the new day's enforced limit, the sequence is exactly P25 through P26 of the defect 1
plan followed by P47, P48 and P49 of this one, and the state file written carries non zero limit,
base and breach time. This is the prediction that closes the coupling the owner ruling of 2026-08-20
made: it cannot be observed without both fixes in the same build, and on a build carrying shape A
alone it is predicted to FAIL at P49 with zeros, which is the open window this plan names above.

**P56.** SHAPE 1 ONLY. `breach_time` in P49 equals the server time on the `SYNCING->LOCKED`
transition line to within the one second timer, because it is the same `now` the pass read. So
`breach_at` and the transition stamp agree, and a reader can verify the field with no other artifact.

**P57.** SHAPE 2 ONLY, REPLAY DISJUNCT. When P47's line reads `replay=1`, `breach_time` equals the
`DEAL_TIME` of a deal that exists in the account's own history, is STRICTLY EARLIER than the
transition stamp, and is at or after the day anchor the same pass used. All three are checkable
against the terminal's history tab without trusting the guardian.

**P58.** SHAPE 2 ONLY, LIVE DISJUNCT. When P47's line reads `live=1|replay=0`, `breach_time` equals
the derivation instant exactly as in P56, and NO deal in the day's history corresponds to it. This
is the shape's two meanings appearing in the artifact, and it is written as a prediction so the
ambiguity is measured rather than argued.

**P59.** NO REGRESSION ON THE ACTIVE PATH. A breach declared through `AgDeclareLock` at `:328-362`
writes exactly what it writes today, and the scoped diff proves it before any run: that function is
predicted BYTE IDENTICAL by sha256 across the fix. Its own P46 from the defect 1 plan is unaffected.

**P60.** THE EIGHT EXISTING VECTORS NAMED ABOVE ALL PASS UNCHANGED, and the summary line moves from
`AGVEC|SUMMARY|84/84` only by however many new checks are added, never by a FAIL. ZERO lines
matching FAIL anywhere in the run.

## What closes none of this

No prediction here closes by reading source. Each names a journal line, a state file field or a count
over a named window, and closes on the artifact only, which is the standing evidence rule of
2026-08-05 applied in advance. P49 and P53 are the two that carry the fix; everything else is a
negative or a corroboration. And no part of this document authorises writing code: the fix order is
ruled, the coupling to one deployment is ruled, the shape is not, and none of the three is a build
instruction.
