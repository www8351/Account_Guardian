# A10: transition log lines match SPEC section 6 — conformance sweep, 2026-08-04

Row under test (Phase 0 matrix): `A10 transition log lines match SPEC section 6`.
Executed read-only: source, SPEC, and journals were read; nothing was written to the terminal,
the running instance, or the halt file.

## 1. Build identity

- Deployed source verified against the repository tree today: all seven files MATCH by md5
  (`AccountGuardian.mq5 dbb44af8…`, `Log.mqh 2c7d584e…`, `Clock.mqh 8dfc362b…`,
  `State.mqh a3e35b14…`, `Persist.mqh ba6ab109…`, `Pnl.mqh d858c32b…`, `Sweep.mqh cf7d355a…`).
- No commit has touched `MQL5/` since merge `28c29a4`, so the tree at `1aa216f` carries the same
  source the Stage 5a deploy copied and compiled (deploy entry of 2026-08-04, all seven MATCH then too).
- The running image loaded that ex5 at the 16:00:22 takeover attach on 2026-08-04. Per standing
  observation rule 7, identity rests on source md5, ex5 timestamp, and runtime behaviour, not ex5 size.

## 2. Method and decoder positivity

Source of observed lines: Experts journals of terminal `D0E8209F77C8CF37AD8BF550E51FF075`,
files `MQL5\Logs\20260728.log` through `20260804.log`, eight files, full sweep, no sampling.
Decoder: ripgrep with UTF-16 decoding; positivity confirmed per standing observation rule 5:

| file | total `AG\|` lines | `init` lines | refusal events | TRANSITION lines |
|---|---|---|---|---|
| 20260728 | 0 (687 raw lines read, EA code did not exist yet) | 0 | 0 | 0 |
| 20260729 | 459 | 5 | 0 | 5 |
| 20260730 | 1998 | 13 | 9 | 4 |
| 20260731 | 2880 | 0 | 0 | 0 |
| 20260801 | 2901 | 5 | 4 | 1 |
| 20260802 | 2880 | 0 | 0 | 0 |
| 20260803 | 2686 | 10 | 8 | 2 |
| 20260804 | 2288 | 13 | 1 | 12 |

Refusal events are counted as `refusing to run` line pairs divided by two: every refusal prints
both the structured ALERT journal line and the Alert popup echo line, verified on the 2026-08-03
proof session where eight refusals produced sixteen matches.

Reconciliation, exact on every day: TRANSITION lines = init lines − refusal events
(5−0=5, 13−9=4, 5−4=1, 10−8=2, 13−1=12). Every successful init emitted exactly one transition
line and every refused init emitted none, satisfying the section 6 "exactly one structured journal
line" clause with no duplicates and no silent successes. The one known init with no journal lines at
all, the 16:37:04 tripping session, is absent from both sides of the equation consistently
(hard-killed before flush, standing observation rule 4).

## 3. Required set, from SPEC

SPEC section 2 transition table rows reachable in Phase 0 (SYNCING is terminal in this build,
tracked as its own open ISSUES entry, so the five Phase 1/2 rows are expected absent):

```
| boot | SYNCING | always | log boot, read state file, read GV mirror |
| any | SAFE_HALT | more than CrashLoopMaxInits consecutive unclean sessions, each adjacent pair
  of inits no more than CrashLoopWindowSeconds apart (A4) | close nothing, sweep nothing,
  banner + periodic Alert, manual restart only |
```

SPEC section 6 line contract: "Every state transition is exactly one structured journal line:
server timestamp, from-state, to-state, reason, governing numbers (daily PnL, limit, base,
locked_until where relevant)."

## 4. Emittable set, from source

Exactly three `AgTransition` call sites exist, all funneling through the single choke point
`State.mqh:70` → `Log.mqh:52`, format `AG|<server ts>|TRANSITION|FROM->TO|reason|numbers`.
From-state is the surviving `g_ag_state` global, so it differs between a fresh image (BOOT) and
an inherited image (whatever the prior session left):

| call site | to-state | reason | possible from-states |
|---|---|---|---|
| `AccountGuardian.mq5:195` | SYNCING | `boot` | BOOT (fresh image); SYNCING (inherited-image re-init); SAFE_HALT (manual resume executed inside an inherited image, never yet observed) |
| `AccountGuardian.mq5:171` | SAFE_HALT | `halt flag persisted from an earlier session` | BOOT (restart while halted, observed); SAFE_HALT (re-init while halted in an inherited image, never yet observed) |
| `AccountGuardian.mq5:92` (`AgEnterSafeHalt`, called only from the trip branch at `:187`) | SAFE_HALT | `crash loop: …` | BOOT in practice (an inherited image cannot trip: its prior session was just marked clean, so the chain reads 1) |

Format conformance is a property of the choke point and therefore holds for all three call sites,
including the one whose line has never been observed (section 7).

## 5. Observed set, all 24 lines, attributed and judged

Era boundaries from the ledger: build 3627886 until the 2026-07-29 16:43 deploy; the timer-fix
lineage then 694d570 through 2026-07-30 22:39; 72ed960 from the 22:50:17 attach (carried across
the 2026-08-01 terminal update to build 6090); e136858 from the 2026-08-03 01:40:51 attach;
Stage 5a build from the 2026-08-04 16:00:22 attach.

| # | server stamp | line | build era | verdict |
|---|---|---|---|---|
| 1 | 07-29 14:09:41 | SYNCING->SYNCING, boot | 3627886 | historical: the known fresh-image boot defect, fixed by the BOOT pseudo-state on 2026-07-29 |
| 2 | 07-29 16:38:52 | SYNCING->SYNCING, boot | 3627886 | historical, same defect |
| 3 | 07-29 20:20:18 | BOOT->SYNCING, boot | timer-fix | conforms |
| 4 | 07-29 20:24:57 | BOOT->SYNCING, boot | timer-fix | conforms |
| 5 | 07-29 20:26:42 | BOOT->SYNCING, boot | timer-fix | conforms |
| 6 | 07-30 10:50:08 | BOOT->SYNCING, boot | 694d570 | conforms |
| 7 | 07-30 22:26:56 | BOOT->SYNCING, boot | 694d570 | conforms |
| 8 | 07-30 22:36:41 | BOOT->SYNCING, boot | 694d570 | conforms |
| 9 | 07-30 22:50:18 | BOOT->SYNCING, boot | 72ed960 | conforms |
| 10 | 08-01 22:54:17 | BOOT->SYNCING, boot | 72ed960 on 6090 | conforms |
| 11 | 08-03 01:09:02 | BOOT->SYNCING, boot | 72ed960 | conforms |
| 12 | 08-03 01:40:53 | BOOT->SYNCING, boot | e136858 | conforms |
| 13 | 08-04 15:20:48 | BOOT->SYNCING, boot | e136858 | conforms |
| 14 | 08-04 15:50:55 | SYNCING->SYNCING, boot | e136858 | finding F1 mechanism (inherited image), pre-deployed build |
| 15 | 08-04 15:51:09 | SYNCING->SYNCING, boot | e136858 | finding F1 mechanism, pre-deployed build |
| 16 | 08-04 16:00:23 | BOOT->SYNCING, boot | Stage 5a | conforms |
| 17 | 08-04 16:00:37 | SYNCING->SYNCING, boot | Stage 5a | **FINDING F1**, deployed build |
| 18 | 08-04 16:20:55 | BOOT->SYNCING, boot | Stage 5a | conforms |
| 19 | 08-04 16:24:56 | BOOT->SYNCING, boot | Stage 5a | conforms |
| 20 | 08-04 16:29:59 | BOOT->SYNCING, boot | Stage 5a | conforms |
| 21 | 08-04 16:33:02 | BOOT->SYNCING, boot | Stage 5a | conforms |
| 22 | 08-04 16:36:03 | BOOT->SYNCING, boot | Stage 5a | conforms |
| 23 | 08-04 16:37:55 | BOOT->SAFE_HALT, halt flag persisted | Stage 5a | **FINDING F2**, deployed build |
| 24 | 08-04 16:39:55 | BOOT->SYNCING, boot | Stage 5a | conforms |

Field format: every one of the 24 lines carries server timestamp, from-state, to-state, reason,
and a numbers segment, satisfying the section 6 field list; "governing numbers … where relevant"
is met with weekly/timer, resume path, or reason/since content, since no PnL, limit, base, or
locked_until exists in Phase 0.

## 6. Findings, held for owner ruling, nothing changed

### F1: `SYNCING->SYNCING` on an inherited-image re-init has no SPEC table row

Journal line (raw, deployed build):

```
HR  0  16:00:36.296  AccountGuardian (XAUUSD.ecn,M5)  AG|2026.08.04 16:00:37|TRANSITION|SYNCING->SYNCING|boot|weekly=on|timer=1s
```

SPEC cell it fails to match (section 2, the only SYNCING-entering row):

```
| boot | SYNCING | always | log boot, read state file, read GV mirror |
```

Mechanism: an input-change re-init reuses the loaded image, `g_ag_state` survives as SYNCING,
and the `:195` transition reports from=SYNCING. The 2026-07-29 BOOT pseudo-state fix covered the
fresh-image case only. Same family, emittable but never observed: `SAFE_HALT->SYNCING` if a manual
resume is ever executed against an inherited image.

### F2: `BOOT->SAFE_HALT` re-entry on restart matches the pair but not the trigger cell

Journal line (raw, deployed build):

```
MH  0  16:37:54.392  AccountGuardian (XAUUSD.ecn,M5)  AG|2026.08.04 16:37:55|TRANSITION|BOOT->SAFE_HALT|halt flag persisted from an earlier session|reason=crash loop: 4 consecutive unclean sessions, adjacent inits within 300s, limit 3|since=2026.08.04 16:37:04
```

SPEC cell (section 2, the only SAFE_HALT row):

```
| any | SAFE_HALT | more than CrashLoopMaxInits consecutive unclean sessions, each adjacent pair
  of inits no more than CrashLoopWindowSeconds apart (A4) | ... |
```

The pair fits `any -> SAFE_HALT`; the trigger does not: this transition fired because the persisted
halt flag was loaded at boot, not because the chain condition evaluated true in this session. The
behaviour itself is required by SPEC section 8 ("SAFE_HALT survives a further terminal restart") and
by the section 2 prose ("cleared only by manual restart"); the table simply does not enumerate the
re-entry trigger. Same family, emittable but never observed: `SAFE_HALT->SAFE_HALT` from a re-init
while halted in an inherited image.

## 7. Permanent non-observation, recorded so it is not mistaken for a gap

The `:92` trip transition of 2026.08.04 16:37:04 (`BOOT->SAFE_HALT|crash loop: …`) was lost
unflushed with every other line of its hard-killed session (standing observation rule 4). That
event will never have a journal witness; its format conformance rests on the shared choke point,
static only. The trip itself stands on the halt file as read back by the 16:37:55 image,
per the kill-session evidence.

## 8. Side observation, outside this row's scope, flagged for the owner

The section 2 SAFE_HALT action cell reads "banner + periodic Alert". The code raises one Alert per
session at SAFE_HALT entry or re-entry (`AccountGuardian.mq5:93`, `:173`); `OnTimer` in SAFE_HALT
emits the LIFE line and refreshes the banner but raises no periodic Alert (`:221`). This is a
behaviour cell, not a transition-line contract, so it is not judged under A10; recorded here so the
divergence is on the record and the owner decides where it lands.

## 9. Verdict

- Reconciliation and format: PASS on all 24 observed lines and all three call sites.
- Pair-and-trigger conformance against the section 2 table: two divergences on the deployed build,
  F1 and F2 above, held for owner ruling. The row does not close until they are ruled.
