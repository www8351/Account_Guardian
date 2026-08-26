# Predictions, the four defects of the next build

Dated 2026-08-19. Written at the Phase 3 opening session, before any code was changed.

## Scope and what this document is not

Every prediction below is a prediction about the **current, unfixed build `74D666E9`**, the binary
`AccountGuardian.ex5` md5 `74D666E90C1749FD24374D0AEF8C8F7D`, 77396 bytes, mtime 2026-08-18 11:27:16,
running on the live instance since the ordered restart at 2026-08-18 11:29:31. Each one states the exact
journal lines that build is expected to emit, or expected not to emit, when the defect is reproduced.

**Post fix predictions are not here.** They come with each fix plan, one plan per defect, in the ruled fix
order. This document exists so that the unfixed behaviour is written down before it is touched, and so that
a later session can tell a fix from a coincidence.

The acceptance row wording under each defect is the row that will close it. It is written now, while the
defect is still reproducible, for the same reason: a row authored after a fix tends to describe the fix
rather than the requirement.

Defects appear in the fix order ruled 2026-08-19. Predictions are numbered P1 to P24 and the numbering does
not restart per defect.

Notation. `<...>` marks a field whose value depends on the run. A prediction of ZERO occurrences is a
prediction about a whole named window, not about a sample, and closes only on a count over that window.

---

## Defect 1, the expiry straddle

**Reproduction.** A lock is live. A disconnect, or a frozen quote while connected, spans `locked_until`.
The clock then advances past `locked_until` and expiry fires within a tick or two of that advance. The
2026-08-19 night is the observed instance of the precondition: the server clock froze at
`2026.08.18 23:57:59` for 61 minutes 32 seconds, jumped to `2026.08.19 01:00:01`, and the lock expired one
second later.

**P1.** Exactly one expiry line, of the form
`AG|<server>|INFO|lock expired|locked_until=<locked_until>|server=<server>`.

**P2.** Exactly one transition line, `AG|<server>|TRANSITION|LOCKED->ACTIVE|lock expired|`, carrying the
same server stamp as P1 and emitted within the same timer pass. The trailing pipe with an empty detail
field is part of the line and is expected.

**P3.** ZERO `TRANSITION|LOCKED->SYNCING` lines and ZERO `TRANSITION|SYNCING->ACTIVE` lines anywhere between
the last LOCKED LIFE line and the first ACTIVE LIFE line. Expiry enters ACTIVE directly, so no SYNCING pass
exists to be counted.

**P4.** ZERO `RESYNC entered` lines and ZERO `RESYNC exited` lines in the same window. These are the Stage 6
edge triggered event lines, so their absence is a genuine negative rather than a sampling miss.

**P5.** No LIFE line anywhere in the window carries `waiting_on=RESYNC: polls=<n>/<required>`. The gate
never arms, so the string that reports it never renders.

**P6.** The first LIFE line after P2 reads `state=ACTIVE` with `waiting_on=-` and the full numbers group,
`anchor=`, `realized=`, `floating=`, `base=`, `limit=` and `pnl_vs_limit=`, and it lands within one
`AG_LIFE_INTERVAL_SECONDS` of P2. That pass has already been eligible to declare a breach.

**P7.** If the straddle was a genuine DISCONNECT rather than a frozen quote, the LOCKED LIFE lines inside it
carry the Stage 6 field `DEGRADED: disconnected` from `AgObservabilityNote`, and the first ACTIVE LIFE line
after expiry carries NO `DEGRADED` marker on its numbers group. The two markers come from different globals:
`g_ag_obs_connected` is sampled every tick in every state, while `g_ag_degraded` is set only inside
`AgEvaluateActive`, which has not run yet at that point.

**P8.** The state file is rewritten exactly once at expiry, to the reset model, `L|0|0|0`, and its md5 moves.
If the expiry crosses a day anchor, one `INFO|ratchet reseeded at rollover|old_anchor=<a>|new_anchor=<b>|old_floor=<x>|new_floor=<y>`
line accompanies it. Neither of these is a defect and both are listed so a reader does not mistake the file
write for evidence that a gate ran.

**Acceptance row that closes defect 1.**

> P3-1 | lock expiry reached across a straddling disconnect or frozen quote | the first post expiry pass
> takes no breach decision until history stability is re established, evidenced EITHER by
> `TRANSITION|LOCKED->SYNCING` followed by `TRANSITION|SYNCING->ACTIVE|history stable|polls=<n>/<n>`,
> OR by an ACTIVE entry whose first passes log `waiting_on=RESYNC: polls=<n>/<required>` bracketed by
> `RESYNC entered` and `RESYNC exited`; ZERO breach declarations and ZERO `ACTIVE->LOCKED` transitions
> between expiry and the gate clearing; the gate clears without operator action | journal scan over the
> expiry window, quoted lines and counts

---

## Defect 2, the GV lock mirror self erase

**Reproduction.** The account is genuinely locked, with a valid `state_<login>.dat` and a valid
`AG_LOCK_<login>` global variable holding an unexpired `locked_until`. The terminal is then killed hard,
`taskkill /F /IM terminal64.exe`, and relaunched. The negative control is a memory preserving reload of the
same locked account, which is what an EA input change through the properties dialog produces.

**P9.** On the cold boot the transition reads `AG|<server>|TRANSITION|BOOT->SYNCING|boot|weekly=on|timer=1s`.
`BOOT` rather than `LOCKED` or `ACTIVE` in the From position is the discriminator that the program image was
genuinely fresh and its globals were reinitialised.

**P10.** At the SYNCING exit of that cold boot, `AG|<server>|INFO|boot witness FILE fired|reason=<reason>|raw=<t>|bounded=<t>`
and `AG|<server>|INFO|boot witness DERIVED fired|live=<0|1>|replay=<0|1>|realized=<r>|floating=<f>|running_min=<m>|limit_cmp=<L>|tier=<snapshot|floor|live>|bounded=<t>`
both appear.

**P11.** ZERO `boot witness GV fired` lines on that cold boot, counted over the whole session and not
sampled. This is the defect. The witness is not merely late, it cannot fire, because `OnTimer` has already
flushed a zero over the mirror before the read at `AccountGuardian.mq5:926` is reached.

**P12.** On the memory preserving reload the transition reads `TRANSITION|LOCKED->SYNCING|boot|weekly=on|timer=1s`,
with `LOCKED` in the From position, and ALL THREE witness lines appear in one block, FILE, GV and DERIVED,
the GV line reading `AG|<server>|INFO|boot witness GV fired|raw=<t>|bounded=<t>`. P11 and P12 taken together
are the whole proof and neither is sufficient alone.

**P13.** The lock survives both boots regardless, `TRANSITION|SYNCING->LOCKED|boot derivation: <reason>|locked_until=<t>`
in each case, because the file and derived witnesses carry it. No unlock, no state change and no SAFE_HALT
is predicted. The defect costs a recovery path and does not cost today's lock.

**P14.** Reading the live global through the terminal F3 dialog after a cold boot is predicted to show the
mirror holding 0 rather than the pre kill `locked_until`, sampled per standing observation rule 2, open,
read, fully close, wait, reopen, read. This prediction is offered as corroboration only. The journal
evidence of P11 and P12 stands without it, and no session may read `bases\gvariables.dat` from outside the
terminal to test it, per standing observation rule 1.

**Acceptance row that closes defect 2.**

> P3-2 | terminal killed hard and relaunched while the account is genuinely locked, with the state file and
> the GV mirror both intact | the cold boot transition reads `BOOT->SYNCING` AND `boot witness GV fired`
> appears in the same witness block as FILE and DERIVED, carrying the pre kill `locked_until` in its `raw`
> field; the memory preserving reload control still fires all three; ZERO cold boots in the run fire fewer
> than three witnesses | journal scan across at least two cold boots and one reload, quoted lines and counts

---

## Defect 3, the empty Q6 snapshot on a boot derived lock

**Reproduction.** A breach is declared through the DERIVED boot witness on an account carrying NO state file,
which is the clean account case. The 2026-08-18 13:02:42 lock is the observed instance and reached that path
because a chart change tore down the session mid deferral.

**P15.** `AG|<server>|DEBUG|no lock state file, first session on this account` at init, establishing that the
model is default constructed and no earlier snapshot exists to preserve.

**P16.** `AG|<server>|INFO|boot witness DERIVED fired|live=<0|1>|replay=<0|1>|realized=<r>|floating=<f>|running_min=<m>|limit_cmp=<L>|tier=<snapshot|floor|live>|bounded=<t>`
with `<L>` NON ZERO. The witness computes the enforced limit and prints it, which is what makes the loss on
the next line a loss rather than an absence.

**P17.** `AG|<server>|TRANSITION|SYNCING->LOCKED|boot derivation: <reason>|locked_until=<t>` and exactly one
`|ALERT|` event for the declaration.

**P18.** The state file is written once, and its content is predicted field by field:
`AGSTATE|1|<login>`, then `L|1|<locked_until as epoch>|0`, then `N|0.00000000|0.00000000`, then `C|<crc>`.
The THIRD field of the `L` record, `breach_at`, is `0`, and BOTH fields of the `N` record are `0.00000000`,
despite `limit_cmp=<L>` on the P16 line carrying a non zero value in the same pass.

**P19.** On every later boot while that lock holds, `boot witness FILE fired` fires on reason plus an
unexpired `locked_until`, the lock is restored correctly, and NOTHING reports a snapshot, because
`have_snapshot` tests `g_ag_state_limit_snap > 0.0` and reads false. The tier 1 protection question SIX
exists to provide is therefore absent for the whole class of boot derived locks, not for one instance.

**P20.** Negative control, and it is deliberately not reproducible today. A breach declared through the
ACTIVE tail by `AgDeclareLock` is predicted to write a non zero `breach_at` and non zero `N` fields.
That control is the P2-A row, which has never been witnessed, so defect 3 and P2-A interlock: witnessing
P2-A supplies the control this prediction needs, and the P2-A procedure is the route to it.

**Acceptance row that closes defect 3.**

> P3-3 | breach declared through the DERIVED boot witness on an account with no pre existing state file |
> the persisted `state_<login>.dat` carries a NON ZERO `breach_at` in the third field of its `L` record and
> NON ZERO limit and base in its `N` record, and those values equal the `limit_cmp` and the base the same
> pass computed, to the cent; a subsequent boot on that file reports the snapshot in use rather than falling
> through to a lower tier | read the state file directly and quote it whole, against the witness line of the
> declaring pass

---

## Defect 4, LOCKED LIFE lines carry no numbers

**Reproduction.** Any locked window. No special condition is needed, which is why this defect is fourth in
the order rather than first: it is the cheapest to reproduce and the most expensive to have suffered.

**P21.** Every LIFE line emitted while `state=LOCKED` matches exactly
`AG|<server>|LIFE|state=LOCKED|seconds_in_state=<n>|waiting_on=expiry: TimeCurrent >= locked_until|server=<server>|local=<local>`,
with the only permitted additions being the Stage 6 note fields, `quote_age=<n>s`, `market closed`, or
`DEGRADED: disconnected`.

**P22.** ZERO occurrences of `anchor=`, `realized=`, `floating=`, `base=`, `limit=` or `pnl_vs_limit=` on any
line carrying `state=LOCKED`, counted across the whole locked window. `AgPnlNumbersString` returns empty
whenever the state is not ACTIVE, so this is absence by construction and not by chance.

**P23.** Across a broker liquidation, a deposit, a withdrawal or any other account level event inside the
locked window, consecutive LOCKED LIFE lines are byte identical apart from `seconds_in_state` and the two
clock fields. The event is invisible in the guardian's own record.

**P24.** The gap is not repaired by any other artifact. The state file is event triggered and is not
rewritten during a locked window unless the lock changes, the floor file is untouched while locked, and the
terminal journal records deals without account state. So a reader asking for balance or equity at an instant
inside a locked window has no source at all.

**Acceptance row that closes defect 4.**

> P3-4 | any locked window, with at least one account level event inside it | every LOCKED LIFE line carries
> a numbers group whose fields are individually justified as still meaningful under a lock, at minimum the
> snapshot limit governing the window and the live figures the guardian can still compute; the balance and
> equity at any sampled instant inside the window are readable from the journal alone; ZERO LOCKED LIFE lines
> emitted without the group | journal scan over the whole locked window, quoted lines, plus one owner
> reading of the terminal at a stamped instant reconciled against the line covering it

---

## What closes none of these

No prediction in this document is closed by reading source. Each names a journal line, a file content or a
count over a named window, and closes on the artifact only. That is the standing evidence rule of
2026-08-05 applied in advance rather than after the fact.
