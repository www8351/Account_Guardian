# Kill session 2026-08-04: A3 trip, A4 restart survival, A6 manual resume, A2 takeover

Build: Stage 5a primitive (AgHaltUncleanChain, CrashLoopWindowSeconds default 300 as the
pairwise gap bound), deployed per the fourth ACTIONS entry for 2026-08-04 and loaded into
memory by the first hard kill of this session.

Source: terminal D0E8209F77C8CF37AD8BF550E51FF075.
Primary log: `MQL5\Logs\20260804.log`, 2095 lines, full read, decoder confirmed.
Corroborating log: `logs\20260804.log`, 161 lines, full read, decoder confirmed.

Kill method: `taskkill /F /IM terminal64.exe`, per the corrected method recorded in the
fifth ACTIONS entry for the date. Relaunch spacing at least fifteen seconds, per the
sixth entry, so no relaunch races the ten second mutex staleness threshold.

## Chain accumulation

Every relaunch after a hard kill is also a deliberate stale-heartbeat takeover, which is
the A2 branch that had never been run deliberately on any build.

| Local time | Log line | Takeover | Chain |
|---|---|---|---|
| 16:00:22.056 | 1925 | stale mutex heartbeat (271s) | 1/3 |
| 16:20:54.061 | 1960 | clean acquire, no takeover | 1/3 |
| 16:24:55.835 | 1990 | stale mutex heartbeat (22s) | 2/3 |
| 16:29:57.940 | 2005 | stale mutex heartbeat (31s) | 1/3 |
| 16:33:01.395 | 2016 | stale mutex heartbeat (15s) | 2/3 |
| 16:36:02.790 | 2024 | stale mutex heartbeat (79s) | 3/3 |
| 16:37:03 (approx) | absent, see below | not recoverable | 4, trips |
| 16:37:54.390 | 2033 | stale mutex heartbeat (10s) | halted, no chain line |
| 16:39:54.380 | 2043 | stale mutex heartbeat (28s) | 1/3 after resume |

Chain 3/3 at 16:36:02 did NOT trip. The limit is 3 and the trip needs 4, which the reason
string states in its own words.

## A3, crash loop by hard kills: TRIPPED at server 2026.08.04 16:37:04

The tripping session left no line in the Experts log. Exactly one line in the whole file
matches `16:37:0`, and it is the `since=` field of the NEXT session's transition. The
session was hard killed before its output flushed, which is standing observation rule 4's
own scenario, so the halt file rather than the journal is the witness.

The session provably existed, from `logs\20260804.log`:

```
KR	0	16:37:02.586	Terminal	MetaTrader 5 x64 build 6090 started for MetaQuotes Ltd.
GN	0	16:37:03.180	Experts	expert AccountGuardian (XAUUSD.ecn,M5) loaded successfully
MS	0	16:37:04.099	Network	'1200252169': authorized on JustMarkets-Demo3 through UK6
```

and the trip it produced is carried forward in the persisted halt reason quoted below.

## A4, SAFE_HALT survives a further restart: PROVEN at 16:37:54

`MQL5\Logs\20260804.log` lines 2030 to 2035:

```
AG|2026.08.04 16:37:55|INFO|init|build=Phase0|account=1200252169|server=JustMarkets-Demo3
AG|2026.08.04 16:37:55|WARN|stale mutex heartbeat (10s), taking over crashed-instance mutex
AG|2026.08.04 16:37:55|TRANSITION|BOOT->SAFE_HALT|halt flag persisted from an earlier session|reason=crash loop: 4 consecutive unclean sessions, adjacent inits within 300s, limit 3|since=2026.08.04 16:37:04
AG|2026.08.04 16:37:55|ALERT|SAFE_HALT persists across restart: crash loop: 4 consecutive unclean sessions, adjacent inits within 300s, limit 3. Delete AccountGuardian\halt_1200252169.dat while the EA is stopped, then restart.
AG|2026.08.04 16:37:55|INFO|timer armed|period=1s
```

LIFE lines emitted while halted, two of them, naming the resume condition:

```
AG|2026.08.04 16:37:56|LIFE|state=SAFE_HALT|seconds_in_state=1|waiting_on=manual resume: delete the halt file while the EA is stopped, then restart
```

## A6, manual resume only via halt-file deletion: PROVEN at 16:39:54

`MQL5\Logs\20260804.log` lines 2041 to 2046:

```
AG|2026.08.04 16:39:55|WARN|stale mutex heartbeat (28s), taking over crashed-instance mutex
AG|2026.08.04 16:39:55|DEBUG|no halt file, first session on this account
AG|2026.08.04 16:39:55|INFO|RESUMED_FROM_SAFE_HALT|halt file removed by hand, documented manual resume procedure
AG|2026.08.04 16:39:55|DEBUG|crash-loop check|chain=1/3 consecutive unclean, gap bound 300s
AG|2026.08.04 16:39:55|TRANSITION|BOOT->SYNCING|boot|weekly=on|timer=1s
```

Corroborated by the live halt file, read only, no write and no copy taken from it:
recreated at 16:39:54, 59 bytes, halt flag cleared, one session record.

```
AGHALT|1|1200252169
S|1785861594|0
H|0||0
C|3463244260
```

## Clean shutdowns during the session

Recorded because a separate report described the clean shutdown as not done.

```
AG|2026.08.04 16:20:32|INFO|deinit|reason=9|session marked clean|timer_armed=1|timer_ticks=1208
AG|2026.08.04 16:31:31|INFO|deinit|reason=9|session marked clean|timer_armed=1|timer_ticks=92
```

Both are graceful terminal closes marking the outgoing session clean, and the chain resets
they produce are visible in the table above at 16:20:54 and 16:29:57.

## Evidence gap, permanent

No backup of the halt file was taken between the trip and the deletion that A6 required.
The only 2026-08-04 halt backup in `docs/evidence/` is
`halt_1200252169.dat.pre-stage5a-deploy-2026-08-04`, taken before any of this ran. The
halted file with its flag set therefore has no on-disk decode and never will.

This does not weaken A3 or A4. The trip is proven by the reason string and the `since`
stamp that the 16:37:54 init read out of that file and printed, which is the file's content
reported by the program that loaded it. What is missing is only the independent decode of
the bytes, which every earlier halt-state claim in this project has carried.

Recorded so no future session mistakes the absence for an oversight it can still repair.
