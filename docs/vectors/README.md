# A9 input matrix vectors

Twelve `.set` files, one per row of the A9 acceptance matrix. Each is a complete
input set with exactly one field moved off the defaults, so a refusal or a WARN
can be attributed to that one field and nothing else.

| File | Field off default | Expected |
|---|---|---|
| `a9_defaults.set` | none | healthy init |
| `a9_both_zero.set` | both daily limits 0 | refuse, core config invalid |
| `a9_neg_percent.set` | `DailyLossPercent` negative | refuse |
| `a9_neg_currency.set` | `DailyLossCurrency` negative | refuse |
| `a9_percent_over_100.set` | `DailyLossPercent` > 100 | refuse |
| `a9_sweep_zero.set` | `SweepPeriodSeconds` 0 | refuse |
| `a9_sweep_over.set` | `SweepPeriodSeconds` above range | refuse |
| `a9_crash_max_zero.set` | `CrashLoopMaxInits` 0 | refuse |
| `a9_window_zero.set` | `CrashLoopWindowSeconds` 0 | refuse |
| `a9_polls_zero.set` | `HistoryStablePolls` 0 | refuse |
| `a9_nonfinite.set` | non-finite numeric | refuse |
| `a9_optional_bad.set` | optional-class field malformed | feature off plus WARN, init succeeds |

## Which copy is operative

The **terminal Presets folder is the operative copy**. It is the only one the
MetaTrader Load browser reads, and it is what an acceptance row actually loads:

```
%APPDATA%\MetaQuotes\Terminal\<terminal-id>\MQL5\Presets\a9_*.set
```

The copy in this directory is the **reviewable record**. It exists so a change to
a vector shows up as a diff against a committed baseline instead of appearing
from nowhere inside a terminal folder that no review ever sees.

## Keeping the two in sync

This repository is the source. The direction is always repo to terminal, never
back:

1. Edit the vector here and commit it, so the change is reviewable on its own.
2. Copy the file into the terminal Presets folder.
3. Restart the terminal. A running terminal never enumerates files added to its
   data folder after it started, so a vector copied into a live terminal stays
   invisible in the Load browser until the next start.
4. Confirm the file is listed in the Load browser before running any row that
   depends on it.

Step 3 is not optional and is not a precaution. It is measured behaviour, and it
has already cost this project one misdiagnosed session.

If the two copies ever disagree, the terminal copy is what ran and the repo copy
is wrong. Fix the repo copy to match what ran, record why, and never assume the
committed file describes a completed row.
