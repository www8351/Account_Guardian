# Bypass demonstration attempt, config-refusal path, 2026-07-30

Build compiled into the terminal: 694d570 (unfixed). Terminal pid 4068, running since 10:50:03.
Owner action at 22:08:42: EA properties dialog, DailyLossPercent edited 5.0 to 0 by hand, DailyLossCurrency already 0.0, OK clicked. Not loaded from a preset (see the preset finding below).

## Result: the refusal fired, the erasure did NOT

| | before (mark 869, 14:34) | after (22:11) |
|---|---|---|
| md5 | 3E7AE7CA5C3FC5680970242244C20D3E | 3209ABA485948D39872B0181C06BE2D6 |
| size | 139 | 138 |
| S records | 6 | 6, all intact |
| record 6 clean flag | 0 | 1 |

Expected on the bypass hypothesis: about 40 bytes, zero S records. Not observed.

The one byte of shrinkage is fully explained by the checksum line: `C|1748524301` (10 digits) became `C|594316798` (9 digits). The payload grew by nothing and lost nothing.

## Journal, every non-LIFE line since the mark

```
22:08:42.314  INFO|deinit|reason=5|session marked clean|timer_armed=1|timer_ticks=40714
22:08:42.318  INFO|init|build=Phase0|account=1200252169|server=JustMarkets-Demo3
22:08:42.318  ALERT|refusing to run, core config invalid: both limits are zero, a guardian with no limit is a config error
22:08:42.318  Alert: AccountGuardian: refusing to run, core config invalid: both limits are zero, a guardian with no limit is a config error
22:08:42.321  INFO|deinit|reason=8|session marked clean|timer_armed=1|timer_ticks=40714
```

Last LIFE line 22:08:39, none after. The EA is fully detached, confirmed by silence plus the reason=8 deinit.

## Why no erasure: measured, not inferred

`timer_ticks=40714` is identical in the reason=5 deinit and the reason=8 deinit. `g_timer_ticks` is a program global incremented once per OnTimer. If MT5 had unloaded and reloaded the program between the two deinits, the counter would have restarted at 0.

It did not, so the program was never unloaded. An input change drives OnDeinit(reason=5) then OnInit() inside the SAME loaded program image, with all globals retaining their values. The refused OnInit returned INIT_PARAMETERS_INCORRECT at AccountGuardian.mq5:92 without calling AgHaltLoad, but `g_ag_sess_count`, `g_ag_sess_init[]` and `g_ag_sess_clean[]` still held the model loaded at 10:50:08 by the healthy session. The unconditional AgHaltSave in the 694d570 OnDeinit therefore wrote a POPULATED model, not a default-constructed empty one. Nothing was erased.

Corollary confirming the path was the intended one: no `mutex acquire` line appears between the init line and the ALERT, so the config refusal did return before AgMutexAcquire, exactly as the plan claimed. The path was isolated correctly; the consequence simply does not follow on this trigger.

## What this corrects

The bypass is real but its trigger is narrower than recorded. Erasure requires the halt model to be genuinely default-constructed, which requires a FRESH program load that then refuses. An input-edit refusal on an already-running instance inherits a populated model and is harmless.

The SPEC threat-model sentence "Trigger is trivial and needs no privilege: attach a second instance and let the mutex refuse it" is exactly the fresh-load case and stands. The adjacent claim that "every config-refusal return reaches the same path" is true as a statement about control flow but does not imply erasure on every trigger, and the ledger's framing of the properties-dialog edit as a demonstration vector is measured false.

Fresh-load refusal routes that WOULD erase on 694d570, none yet demonstrated:
1. Attaching the EA to a second chart, refused by the mutex (separate program instance, fresh globals). This is the SPEC's own stated trigger and also A1's setup.
2. Removing the EA and attaching it fresh from Navigator with a malformed core input.
3. Terminal start with a malformed core input saved in the chart profile.

## Preset finding, A9 impact

The twelve vectors are on disk at `<DataDir>\MQL5\Presets\a9_*.set`, the same folder that already holds ten `AG_*.set` files written by the deleted prior project, so the path is the one MT5 itself uses. The owner reports they do not appear in the properties dialog Load browser. Terminal has been running since 10:50:03; the files were written at about 12:47, after that start. Two candidate causes, not yet separated: the terminal enumerates the preset list at startup and has not rescanned, or the dialog opened at a different default directory. The discriminator is whether the pre-existing `AG_*.set` files appear in that same browser; if they do, it is a refresh problem, if they do not, it is a location problem. Encoding is a third candidate: these files are ASCII while MT5 writes .set as UTF-16LE, so a re-save is the cheap fallback. Not fixed, per instruction to diagnose only.

## ADDENDUM, 22:26:37: the erasure DID fire, on a fresh load, and is fully evidenced

While the owner and the executor were exchanging the analysis above, the hazard the owner had just identified fired on its own: MT5 retains last-used inputs per EA, those values were still both-zero from the 22:08 edit, and a fresh Navigator attach confirmed them unchanged. That is a genuine fresh program load followed by a config refusal, which is exactly the erasure trigger. It was uncontrolled in the sense that nobody staged it, but no evidence was lost: the pre-state was already backed up, the journal recorded the event, and the post-state proves the wipe.

Journal, the decisive contrast in a single log:

```
22:26:37.701  INFO|init|build=Phase0|...
22:26:37.701  ALERT|refusing to run, core config invalid: both limits are zero, ...
22:26:37.703  INFO|deinit|reason=8|session marked clean|timer_armed=0|timer_ticks=0      <-- FRESH load, ERASES
22:26:54.730  INFO|init ... mutex acquire ... BOOT->SYNCING ... timer armed              <-- healthy, reseeds
22:35:29.341  INFO|deinit|reason=5|session marked clean|timer_armed=1|timer_ticks=514
22:35:29.346  ALERT|refusing to run, core config invalid: both limits are zero, ...
22:35:29.350  INFO|deinit|reason=8|session marked clean|timer_armed=1|timer_ticks=514    <-- SAME image, harmless
22:36:39.679  INFO|init ... mutex acquire ... BOOT->SYNCING ... timer armed              <-- healthy, live
```

`timer_armed=0|timer_ticks=0` at 22:26:37 versus `timer_armed=1|timer_ticks=514` at 22:35:29 is the discriminator, measured rather than argued: the first refusal ran in a program image whose globals had never been touched, the second inherited a running image. Same input condition, same alert text, opposite consequence.

File-level proof of the wipe:

| | before (22:11) | after (22:38) |
|---|---|---|
| size | 138 | 74 |
| S records | 6 | 2 |
| oldest record | 2026-07-29 14:09:40 | 2026-07-30 22:26:54 |

All five pre-existing session records plus the 10:50:08 one are gone. The two survivors are the 22:26:54 reseed (clean=1, ended by the 22:35 edit) and the 22:36:39 live session (clean=0). The file was reset to an empty model by the refused init's OnDeinit and then reseeded from scratch by the next healthy attach.

CONCLUSION: the SAFE_HALT bypass is DEMONSTRATED against 694d570 on the config-refusal path, with a fresh program load as the necessary trigger. The erasure half only; see the standing scope limit, the false-RESUMED half remains source-read-only because it needs a persisted SAFE_HALT that only the fixed build can produce.

## Fresh-load audit: which Phase 0 rows are exposed to last-used-input persistence

The governing rule, now measured: an input-change re-init reuses the loaded program image and its globals survive; a fresh attach, a recompile, and a terminal restart all build a fresh image with globals reset. MT5 seeds a fresh attach from the last-used inputs for that EA, so a bad value persists silently across attaches and across terminal restarts via the chart profile.

- A1, second attach refuses: the second chart inherits last-used inputs. If those are malformed the instance refuses at the config check (AccountGuardian.mq5:89), which returns BEFORE AgMutexAcquire (:126), so the mutex is never reached and the row tests nothing. The second chart MUST be attached with valid inputs.
- A2, stale mutex takeover: the relaunched terminal restores the EA from the saved chart profile. A profile carrying malformed inputs makes every relaunch refuse, so no takeover ever occurs.
- A3, crash loop: every relaunch is a fresh load from the profile, and AgHaltAppendSession sits downstream of every refusal return, so refused inits append no session record at all. Malformed profile inputs would make the crash count permanently unable to accumulate and the row impossible.
- A4, SAFE_HALT survives restart, and A6, manual resume: same profile dependency as A2 and A3.
- A7, clean re-inits do not accumulate: a recompile builds a fresh image, so each A7 re-init is a fresh load taking inputs from the profile; malformed values would turn every intended clean re-init into a refusal.
- A8, timer with market closed: exposed only through the attach that starts the observation window.
- A9, input matrix: exposed in the opposite direction, and this one changes how the row must be run. A malformed row driven by editing inputs on a RUNNING instance inherits a populated model, so g_ag_halt_loaded is already true, the fix's skip branch never executes, and the row proves the refusal without proving the fix. To exercise the fix each malformed row must be a fresh load. A refusal detaches the EA, so consecutive fresh attaches follow naturally, but the FIRST row must begin from a removal rather than from an edit.
- A10 is unaffected directly, since it audits lines the other rows emit.

Operational consequence adopted for the rest of the matrix: every attach instruction names the exact input values to confirm before OK, and the executor takes the halt baseline BEFORE the owner attaches, never after.

## Files

- Backup of this state: `docs/evidence/halt_1200252169.dat.after-config-refusal-2026-07-30`, md5 3209ABA485948D39872B0181C06BE2D6.
- NOT restored from the post-shutdown backup. Nothing was destroyed, and record 6's clean flag is new information that a restore would overwrite. Under the standing no-overwrite rule the correct action is to leave the live file alone.
