# R10 Input Hardening Build Plan: D1f + D7b + D11a

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the input hardening build ruled 2026-09-03: both daily-loss limits become mandatory list inputs with a ceiling and no disable path (D1f), and four former inputs become compile-time constants (D7b, D11a).

**Architecture:** Two MQL5 enums back the two limit inputs; the enum backing integer IS the value (percent in hundredths, currency in whole units), so a `.set` line, a dialog entry and a journal line all read the same number. One membership check per raw input at init refuses anything off the list. Four `#define` constants replace four inputs. Nothing below the ACTIVE breach tail changes, the ratchet and the realized peak are untouched, and no persistence format moves.

**Tech Stack:** MQL5 (MetaTrader 5), MetaEditor `metaeditor64.exe /compile`, PowerShell for read-only harvest under RULE A and RULE B.

**Spec:** `LEDGER.md` DECISIONS `:2205` to `:2246` (D1f through D11a, with the D8b correction at `:2233`) plus the defaults FINAL appended 2026-09-03 after `:2246`. Plan session: this document. Build session: named in D10a, not yet opened.

**Ruling status of this document:** every line tagged FINAL quotes an owner ruling. Every design choice the executor made is tagged UNRULED 2026-09-03 and is a proposal until the owner ratifies it at build review. Nothing tagged UNRULED may be reported later as ruled.

Ratified by the owner 2026-09-03 at plan review, DECISIONS entry "(owner ruling 2026-09-03, R10 plan review, given in the plan approval instruction)", appended after the defaults FINAL: items 2.2 (the `limits accepted` line and the `build=R10` label), 3.3 (`git rm` of the retired vectors, listed in the vectors README with the striking ruling) and 2.6 (the README.md update and the SPEC amendment, both authorized for the build session). Those items are FINAL wherever they appear below; the UNRULED tag on them is lifted by that entry.

## Global Constraints

- D1f (`LEDGER.md:2205`): "BOTH LIMITS BECOME MANDATORY LIST INPUTS. Neither can be zero, neither can be disabled from the dialog. `DailyLossPercent` is an enum of 22 values, 0.25 to 5.50 in steps of 0.25; the top value 5.50 is the ceiling. `DailyLossCurrency` is an enum of 48 values, 1 to 10 in steps of 1, then 15 to 200 in steps of 5; the top value 200 is the ceiling, in account currency. Any value not in its list, from the dialog, a `.set` file or last-used inputs, refuses init. The effective limit remains the min of the two legs, unchanged. There is no disable path inside the EA".
- Defaults FINAL (DECISIONS, appended 2026-09-03 after `:2246`): `DailyLossPercent` default = 5.50, `DailyLossCurrency` default = 200, the top value of each list.
- D4a (`LEDGER.md:2213`): "WITHIN THE CEILING WHILE LOCKED, an input change is rejected and journaled, current Q6 behaviour (Q6/F7, owner ruling 2026-07-29, DECISIONS), unchanged. ABOVE THE CEILING, the value is not a list member and init refuses, per D1f above."
- D5a (`LEDGER.md:2217`): "A tightening of either limit from the dialog takes effect immediately."
- D6a (`LEDGER.md:2221`): "THE RATCHET COMPARES THE DERIVED LIMIT, the min of the two legs, unchanged. THE CEILING CHECK IS PER RAW INPUT AT INIT, against each input's own list under D1f."
- D7b (`LEDGER.md:2225`): "`SweepPeriodSeconds = 1` and `HistoryStablePolls = 3` become compile-time constants."
- D8b (`LEDGER.md:2229`): "Struck a9 vectors are retired, not rewritten. `docs/vectors/README.md` is updated accordingly, not in this session. The FINAL at DECISIONS 2026-08-04 naming the twelve committed a9 vectors is not edited." Correction (`LEDGER.md:2233`): "NEITHER SURVIVOR'S CURRENT CONTENT PASSES D1f AS WRITTEN. Both carry `DailyLossCurrency=0.0`".
- D9a (`LEDGER.md:2236`): "An ignored widening uses the ratchet WARN form, "ratchet HOLDING against a raised limit", at the same cadence cap value, `AG_LIFE_INTERVAL_SECONDS`."
- D10a (`LEDGER.md:2240`): "Hardening ships first as its own build: D1f, D7b and D11a together. The defect 2 ... and defect 4 ... fixes ... are not part of this build."
- D11a (`LEDGER.md:2244`): "CrashLoopMaxInits = 3 and CrashLoopWindowSeconds = 300 become compile-time constants. Two a9 vectors are struck: `a9_crash_max_zero.set` and `a9_window_zero.set`."
- RULE A (`LEDGER.md:1958`): "the MetaTrader Terminal data folder is READ ONLY territory for every executor session, without exception. Permitted: read, and copy OUT to the repository evidence directory. Prohibited: any write, delete, rename, move or in place edit of anything under it". RULE B (same line): "every command that names a path inside that folder must be a plain inline read only cmdlet, Get-Content, Copy-Item source to repository, Get-ChildItem, Get-FileHash, with no user defined helper anywhere in the call chain. At the start of any session that touches the folder, run Get-Alias for rd, del, ri, rm, mv, cp and sc".
- Deploy hand (`LEDGER.md:1902`): "THE OWNER PERFORMS EVERY COPY INTO THE TERMINAL DATA FOLDER, AT THE EXECUTOR'S DICTATION. RULE A IS NOT AMENDED".
- Evidence standard (`LEDGER.md:1962`): "A SESSION REPORT IS NOT EVIDENCE FOR ANYTHING, ONLY ARTIFACTS ARE." and (`LEDGER.md:1759`): "no LEDGER entry may cite an observation of live behaviour without the artifact file name and the line number it was read from."
- Build identity, standing rule 7 (`LEDGER.md:1816`): "the ex5 SIZE AND HASH ARE NOT BUILD IDENTITY ... Build identity rests on three things instead: the md5 of every source file against the committed tree, the ex5 modification timestamp, and the runtime behaviour of the loaded image in the journal". Standing rule 6 (same line): "the metaeditor64.exe process exit code is NOT a compile status signal and is inverted in practice on this installation ... The authoritative signals are the log's Result line and the presence and timestamp of the ex5".
- Writing rules: English only in this document and in LEDGER entries; no em dashes; README.md is bilingual and never names the ledger.

---

## TASK 1: source map

Files: `MQL5/Experts/AccountGuardian/AccountGuardian.mq5` (EA), `MQL5/Include/AccountGuardian/Pnl.mqh`, `MQL5/Include/AccountGuardian/Persist.mqh`, `MQL5/Scripts/AccountGuardian/AgPhase2StateVectors.mq5`. Line numbers are HEAD `00e2b43`.

A grep of the six names over `MQL5/` returns lines in exactly two files, `Pnl.mqh` (five lines, all inside `AgValidateLimits`) and `AccountGuardian.mq5`. No hit in `Persist.mqh`, `State.mqh`, `Clock.mqh`, `Log.mqh`, `Sweep.mqh` or either vector script. That is the persistence finding: NO SOURCE SITE PERSISTS ANY OF THE SIX INPUTS. What is persisted is derived from them, listed under 1.7.

### 1.1 `DailyLossPercent`

| Kind | Site | Quoted line |
|---|---|---|
| declaration | EA:19 | `input double                 DailyLossPercent       = 5.0;   // Daily loss limit, percent of day-anchor base (0 = off)` |
| validation, call | EA:890 | `if(!AgValidateLimits(DailyLossPercent, DailyLossCurrency, why))` |
| validation, refusal | EA:892 | `AgAlertEvent("refusing to run, core config invalid: " + why);` |
| validation, refusal | EA:893 | `return AgRefuseInit(INIT_PARAMETERS_INCORRECT, "core config invalid: " + why);` |
| validation, body | Pnl.mqh:339 | `bool AgValidateLimits(const double percent, const double currency, string &why)` |
| validation, non finite | Pnl.mqh:341-343 | `if(!MathIsValidNumber(percent))` ... `why = "DailyLossPercent is not a finite number";` |
| validation, negative | Pnl.mqh:351-353 | `if(percent < 0.0)` ... `why = "DailyLossPercent is negative (" + DoubleToString(percent, 2) + ")";` |
| validation, above 100 | Pnl.mqh:356-358 | `if(percent > 100.0)` ... `why = "DailyLossPercent is out of range, above 100 (" + DoubleToString(percent, 2) + ")";` |
| validation, both zero | Pnl.mqh:366-368 | `if(percent == 0.0 && currency == 0.0)` ... `why = "both limits are zero, a guardian with no limit is a config error";` |
| read, boot derivation | EA:295 | `double live_limit = AgLimitCurrency(base, DailyLossPercent, DailyLossCurrency);` |
| read, lock declared | EA:370 | `g_ag_locked_in_percent  = DailyLossPercent;` |
| read, lock from boot | EA:441 | `g_ag_locked_in_percent    = DailyLossPercent;` |
| read, Q6 witness | EA:510 | `&& (DailyLossPercent != g_ag_locked_in_percent \|\| DailyLossCurrency != g_ag_locked_in_currency))` |
| read, Q6 WARN text | EA:517 | `+ DoubleToString(g_ag_locked_in_percent, 2) + "->" + DoubleToString(DailyLossPercent, 2)` |
| read, ACTIVE limit | EA:716 | `double limit     = AgLimitCurrency(base, DailyLossPercent, DailyLossCurrency);` |
| consumer | Pnl.mqh:289 | `double AgLimitCurrency(const double base, const double percent, const double currency)` |
| consumer, disabled leg logic | Pnl.mqh:291-298 | `bool has_percent  = (percent > 0.0);` ... `return MathMin(from_percent, currency);` |

### 1.2 `DailyLossCurrency`

| Kind | Site | Quoted line |
|---|---|---|
| declaration | EA:20 | `input double                 DailyLossCurrency      = 0.0;   // Daily loss limit, account currency (0 = off)` |
| validation, call | EA:890 | as 1.1 |
| validation, non finite | Pnl.mqh:346-348 | `if(!MathIsValidNumber(currency))` ... `why = "DailyLossCurrency is not a finite number";` |
| validation, negative | Pnl.mqh:361-363 | `if(currency < 0.0)` ... `why = "DailyLossCurrency is negative (" + DoubleToString(currency, 2) + ")";` |
| validation, both zero | Pnl.mqh:366-368 | as 1.1 |
| read | EA:295, EA:716 | as 1.1 |
| read, lock declared | EA:371 | `g_ag_locked_in_currency = DailyLossCurrency;` |
| read, lock from boot | EA:442 | `g_ag_locked_in_currency   = DailyLossCurrency;` |
| read, Q6 witness | EA:510 | as 1.1 |
| read, Q6 WARN text | EA:519 | `+ DoubleToString(DailyLossCurrency, 2)` |

### 1.3 `SweepPeriodSeconds`

| Kind | Site | Quoted line |
|---|---|---|
| declaration | EA:21 | `input int                    SweepPeriodSeconds     = 1;     // Timer period, refused outside 1..5` |
| validation | EA:905 | `if(SweepPeriodSeconds < 1 \|\| SweepPeriodSeconds > 5)` |
| validation, refusal | EA:907-909 | `AgAlertEvent("refusing to run, core config invalid: SweepPeriodSeconds out of range 1..5 ("` ... `return AgRefuseInit(INIT_PARAMETERS_INCORRECT, "core config invalid: SweepPeriodSeconds out of range 1..5");` |
| read, the only one | EA:916 | `g_timer_seconds = SweepPeriodSeconds;` |
| carrier global | EA:29 | `int  g_timer_seconds       = 1;` |
| carrier consumer | EA:122 | `g_timer_armed = EventSetTimer(g_timer_seconds);` |
| carrier consumer | EA:124 | `AgInfo("timer armed\|period=" + (string)g_timer_seconds + "s");` |
| carrier consumer | EA:1038 | `+ "\|timer=" + (string)g_timer_seconds + "s");` |

### 1.4 `HistoryStablePolls`

| Kind | Site | Quoted line |
|---|---|---|
| declaration | EA:24 | `input int                    HistoryStablePolls     = 3;     // SYNCING exit condition (used from Phase 1)` |
| validation | EA:911-914 | `if(HistoryStablePolls < 1)` ... `return AgRefuseInit(INIT_PARAMETERS_INCORRECT, "core config invalid: HistoryStablePolls must be at least 1");` |
| read, expiry to SYNCING | EA:561 | `" breach decision\|polls=0/" + (string)HistoryStablePolls);` |
| read, expiry waiting_on | EA:565 | `g_ag_dynamic_waiting_on = "polls=0/" + (string)HistoryStablePolls;` |
| read, RESYNC gate | EA:656 | `if(!AgHistoryStable(HistoryStablePolls))` |
| read, RESYNC waiting_on | EA:659 | `+ "/" + (string)HistoryStablePolls;` |
| read, SYNCING exit | EA:1121 | `if(AgHistoryStable(HistoryStablePolls))` |
| read, transition numbers | EA:1151 | `"polls=" + (string)g_ag_stable_polls + "/" + (string)HistoryStablePolls);` |
| read, SYNCING waiting_on | EA:1156 | `g_ag_dynamic_waiting_on = "polls=" + (string)g_ag_stable_polls + "/" + (string)HistoryStablePolls;` |
| comment | EA:552 | `//--- and increments straight past HistoryStablePolls on the FIRST` |
| consumer | Pnl.mqh:309 | `bool AgHistoryStable(const int required_polls)` |
| consumer, compare | Pnl.mqh:331 | `return g_ag_stable_polls >= required_polls;` |

### 1.5 `CrashLoopMaxInits`

| Kind | Site | Quoted line |
|---|---|---|
| declaration | EA:22 | `input int                    CrashLoopMaxInits      = 3;     // Consecutive unclean sessions tolerated` |
| validation | EA:895-898 | `if(CrashLoopMaxInits < 1)` ... `return AgRefuseInit(INIT_PARAMETERS_INCORRECT, "core config invalid: CrashLoopMaxInits must be at least 1");` |
| read, trip | EA:1027 | `if(chain > CrashLoopMaxInits)` |
| read, SAFE_HALT reason | EA:1030 | `+ (string)CrashLoopWindowSeconds + "s, limit " + (string)CrashLoopMaxInits);` |
| read, verbose | EA:1034 | `AgVerbose("crash-loop check\|chain=" + (string)chain + "/" + (string)CrashLoopMaxInits` |

### 1.6 `CrashLoopWindowSeconds`

| Kind | Site | Quoted line |
|---|---|---|
| declaration | EA:23 | `input int                    CrashLoopWindowSeconds = 300;   // Max gap between adjacent inits in a chain` |
| validation | EA:900-903 | `if(CrashLoopWindowSeconds < 1)` ... `return AgRefuseInit(INIT_PARAMETERS_INCORRECT, "core config invalid: CrashLoopWindowSeconds must be at least 1");` |
| read, chain walk | EA:1023 | `int chain = AgHaltUncleanChain(CrashLoopWindowSeconds);` |
| read, SAFE_HALT reason | EA:1030 | as 1.5 |
| read, verbose | EA:1035 | `+ " consecutive unclean, gap bound " + (string)CrashLoopWindowSeconds + "s");` |
| consumer | Persist.mqh:279 | `int AgHaltUncleanChain(const int max_gap_seconds)` |

### 1.7 Persistence sites, derived values and platform-side copies

- Nothing persists an input. EA:87-92 on the two Q6 witness globals: `//--- Q6 input-change-while-locked witness. The two limit inputs as they read` / `//--- at the moment of breach, held in memory only. NOT persisted: the state`. The globals: EA:93 `double   g_ag_locked_in_percent    = 0.0;`, EA:94 `double   g_ag_locked_in_currency   = 0.0;`.
- The DERIVED limit is persisted three ways: the breach snapshot, EA:374 `AgStateSetBreach(until, breach_time, limit, base);`, EA:456 `AgStateSetBreach(until, g_ag_state_breach_time, g_ag_state_limit_snap, g_ag_state_base_snap);`, EA:463 `AgStateSetBreach(until, derived_breach_time, derived_limit, derived_base);`; the ratchet floor, Persist.mqh:830-831 `g_ag_floor_currency = live_limit;   // running minimum` / `AgFloorSave();`. None of these carries a raw input and none changes format in this build.
- Platform-side persistence, outside the source and the reason D1f names three channels: `LEDGER.md:1800` "MT5 seeds a fresh attach from last-used inputs that persist across restarts via the chart profile", and the `.set` vectors under `docs/vectors/` whose operative copy is the terminal Presets folder (`LEDGER.md:2135`).
- The vector script does not read the inputs: `AgPhase2StateVectors.mq5:492` `double rt_live = AgLimitCurrency(2133.13, 5.0, 0.0);` calls the limit function with literals.

### 1.8 OnInit refusal paths and the a9 init check

The a9 init check is the core-config block EA:888-916, headed EA:888 `//--- core config validation (Q4): refuse to run, visibly`. Six refusal returns exist in `OnInit`, all through EA:855 `int AgRefuseInit(const int retcode, const string reason)`, which sets EA:857 `g_init_refused = true;` and draws the dated banner EA:858 `AgBanner("REFUSED " + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS)`:

1. limits, EA:890-894 (Pnl.mqh `why` texts above);
2. `CrashLoopMaxInits`, EA:895-899;
3. `CrashLoopWindowSeconds`, EA:900-904;
4. `SweepPeriodSeconds`, EA:905-910;
5. `HistoryStablePolls`, EA:911-915;
6. mutex, EA:927-932 `if(!AgMutexAcquire())` ... `return AgRefuseInit(INIT_FAILED, "duplicate instance: another instance holds the mutex");`.

After a refusal `OnDeinit` runs with reason 8 and logs EA:1219 `AgInfo("deinit|halt file NOT written: the halt model was never loaded this session"`, EA:1224 `AgInfo("deinit|reason=" + (string)reason + "|session marked clean"`, EA:1232 `AgInfo("deinit|banner NOT cleared: init was refused, dated REFUSED banner stays on the chart");`. The journal line prefix is Log.mqh:24 `PrintFormat("AG|%s|%s|%s", TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), level, message);`.

After this build, paths 2 to 5 no longer exist (their inputs are constants) and path 1 carries two `why` texts, one per limit. Two refusal returns remain in `OnInit`: limits and mutex.

---

## TASK 2: design

### 2.1 Enum types for the two limits (UNRULED 2026-09-03, executor design under D1f)

Location: `Pnl.mqh`, inserted immediately before `AgLimitCurrency` (Pnl.mqh:283). Reason: `Pnl.mqh` already owns limit validation (Pnl.mqh:335-372), it is included by the EA at EA:15 before the input block at EA:19, and a pure function in an include is what the vector script can prove synthetically (`LEDGER.md:1875` "pure functions of their arguments ... exactly the shape a synthetic vector proves best"). The existing enum precedent is Log.mqh:10-14 `enum ENUM_AG_LOG_VERBOSITY { AG_LOG_NORMAL  = 0, // Normal ... }` with the member comment as the dialog text, which the MQL5 reference documents: "If a comment is associated with a mnemonic name, as shown in this example, the comment content is used instead of the mnemonic name" (mql5.com/en/docs/basis/variables/inputvariables).

Backing integers: THE INTEGER IS THE VALUE. Percent in hundredths (25 to 550), currency in whole account-currency units (1 to 200). A `.set` line `DailyLossPercent=550` reads as 5.50 without a lookup, the membership rule is arithmetic on the raw integer, and the D1f ceiling is the top backing value. The rejected alternative, an ordinal index 0 to 21, would make `.set` files and journal lines opaque and would put the ceiling behind a table.

```mql5
//+------------------------------------------------------------------+
//| R10, D1f (FINAL 2026-09-03). Both limits are mandatory list      |
//| inputs. THE BACKING INTEGER IS THE VALUE: percent in hundredths, |
//| currency in whole units. The member comment is the dialog text.  |
//| Defaults FINAL 2026-09-03: the top value of each list.           |
//+------------------------------------------------------------------+
enum ENUM_AG_DAILY_LOSS_PERCENT
  {
   AG_DLP_0_25 =  25, // 0.25
   AG_DLP_0_50 =  50, // 0.50
   AG_DLP_0_75 =  75, // 0.75
   AG_DLP_1_00 = 100, // 1.00
   AG_DLP_1_25 = 125, // 1.25
   AG_DLP_1_50 = 150, // 1.50
   AG_DLP_1_75 = 175, // 1.75
   AG_DLP_2_00 = 200, // 2.00
   AG_DLP_2_25 = 225, // 2.25
   AG_DLP_2_50 = 250, // 2.50
   AG_DLP_2_75 = 275, // 2.75
   AG_DLP_3_00 = 300, // 3.00
   AG_DLP_3_25 = 325, // 3.25
   AG_DLP_3_50 = 350, // 3.50
   AG_DLP_3_75 = 375, // 3.75
   AG_DLP_4_00 = 400, // 4.00
   AG_DLP_4_25 = 425, // 4.25
   AG_DLP_4_50 = 450, // 4.50
   AG_DLP_4_75 = 475, // 4.75
   AG_DLP_5_00 = 500, // 5.00
   AG_DLP_5_25 = 525, // 5.25
   AG_DLP_5_50 = 550  // 5.50
  };

enum ENUM_AG_DAILY_LOSS_CURRENCY
  {
   AG_DLC_1   =   1, // 1
   AG_DLC_2   =   2, // 2
   AG_DLC_3   =   3, // 3
   AG_DLC_4   =   4, // 4
   AG_DLC_5   =   5, // 5
   AG_DLC_6   =   6, // 6
   AG_DLC_7   =   7, // 7
   AG_DLC_8   =   8, // 8
   AG_DLC_9   =   9, // 9
   AG_DLC_10  =  10, // 10
   AG_DLC_15  =  15, // 15
   AG_DLC_20  =  20, // 20
   AG_DLC_25  =  25, // 25
   AG_DLC_30  =  30, // 30
   AG_DLC_35  =  35, // 35
   AG_DLC_40  =  40, // 40
   AG_DLC_45  =  45, // 45
   AG_DLC_50  =  50, // 50
   AG_DLC_55  =  55, // 55
   AG_DLC_60  =  60, // 60
   AG_DLC_65  =  65, // 65
   AG_DLC_70  =  70, // 70
   AG_DLC_75  =  75, // 75
   AG_DLC_80  =  80, // 80
   AG_DLC_85  =  85, // 85
   AG_DLC_90  =  90, // 90
   AG_DLC_95  =  95, // 95
   AG_DLC_100 = 100, // 100
   AG_DLC_105 = 105, // 105
   AG_DLC_110 = 110, // 110
   AG_DLC_115 = 115, // 115
   AG_DLC_120 = 120, // 120
   AG_DLC_125 = 125, // 125
   AG_DLC_130 = 130, // 130
   AG_DLC_135 = 135, // 135
   AG_DLC_140 = 140, // 140
   AG_DLC_145 = 145, // 145
   AG_DLC_150 = 150, // 150
   AG_DLC_155 = 155, // 155
   AG_DLC_160 = 160, // 160
   AG_DLC_165 = 165, // 165
   AG_DLC_170 = 170, // 170
   AG_DLC_175 = 175, // 175
   AG_DLC_180 = 180, // 180
   AG_DLC_185 = 185, // 185
   AG_DLC_190 = 190, // 190
   AG_DLC_195 = 195, // 195
   AG_DLC_200 = 200  // 200
  };

//--- Membership, arithmetic on the raw integer and never on the enum
//--- type, because the terminal can hand OnInit any integer through a
//--- .set file or a stale chart profile (D1f names all three channels).
bool AgDailyLossPercentIsMember(const int raw)
  {
   return raw >= 25 && raw <= 550 && (raw % 25) == 0;
  }

bool AgDailyLossCurrencyIsMember(const int raw)
  {
   if(raw >= 1 && raw <= 10)
      return true;
   return raw >= 15 && raw <= 200 && (raw % 5) == 0;
  }

//--- Mapping to the double the limit arithmetic consumes. Every percent
//--- member is a multiple of 0.25 and every currency member an integer,
//--- so both mappings are exact in binary and DoubleToString(x, 2)
//--- reproduces the dialog text.
double AgDailyLossPercentValue(const ENUM_AG_DAILY_LOSS_PERCENT v)
  {
   return ((double)(int)v) / 100.0;
  }

double AgDailyLossCurrencyValue(const ENUM_AG_DAILY_LOSS_CURRENCY v)
  {
   return (double)(int)v;
  }
```

Member counts: percent 25 to 550 step 25 is 22 members, currency 1 to 10 is 10 plus 15 to 200 step 5 is 38, total 48. Both match D1f's stated counts.

Defaults (FINAL 2026-09-03): `AG_DLP_5_50` and `AG_DLC_200`.

### 2.2 Init refusal for a value not in the list

`AgValidateLimits` keeps its name (`docs/PLAN_PHASE0.md:34` and the ISSUES history refer to it) and changes signature to the two raw integers. The six old checks (Pnl.mqh:341-370) are deleted whole: non finite, negative, above 100 and both zero are all non-members, and D1f says the list check supersedes them (`LEDGER.md:2233` "the list-membership check superseding the zero, negative, range and finite checks each one tests").

```mql5
//+------------------------------------------------------------------+
//| Limit-input validation, core config class (Q4 FINAL, D1f FINAL   |
//| 2026-09-03). Malformed is one thing only: not a member of the    |
//| input's own list. Checked PER RAW INPUT AT INIT (D6a). Caller    |
//| returns INIT_PARAMETERS_INCORRECT.                               |
//+------------------------------------------------------------------+
bool AgValidateLimits(const int percent_raw, const int currency_raw, string &why)
  {
   if(!AgDailyLossPercentIsMember(percent_raw))
     {
      why = "DailyLossPercent is not a list member (raw " + (string)percent_raw
            + "); the list is 0.25 to 5.50 in steps of 0.25, stored as hundredths 25 to 550";
      return false;
     }
   if(!AgDailyLossCurrencyIsMember(currency_raw))
     {
      why = "DailyLossCurrency is not a list member (raw " + (string)currency_raw
            + "); the list is 1 to 10 in steps of 1, then 15 to 200 in steps of 5";
      return false;
     }
   return true;
  }
```

EA:890 becomes `if(!AgValidateLimits((int)DailyLossPercent, (int)DailyLossCurrency, why))`. EA:892-893 stay byte identical, so the journal line for a refused percent of raw 575 is, with the Log.mqh:24 prefix:

```
AG|<server time>|ALERT|refusing to run, core config invalid: DailyLossPercent is not a list member (raw 575); the list is 0.25 to 5.50 in steps of 0.25, stored as hundredths 25 to 550
```

and for a refused currency of raw 0:

```
AG|<server time>|ALERT|refusing to run, core config invalid: DailyLossCurrency is not a list member (raw 0); the list is 1 to 10 in steps of 1, then 15 to 200 in steps of 5
```

followed by the popup `Alert("AccountGuardian: ", message)` (Log.mqh:46), the REFUSED banner (EA:858-860) with reason `core config invalid: DailyLossPercent is not a list member (raw 575); ...`, and the three deinit lines quoted in 1.8.

Acceptance line on success (FINAL, ratified 2026-09-03 at plan review, item FOUR): one INFO line after validation, so a healthy init carries the accepted values and a line no earlier build can emit, which is the standing rule 7 journal channel:

```mql5
   AgInfo("limits accepted|percent=" + DoubleToString(AgInputPercent(), 2)
          + "|currency=" + DoubleToString(AgInputCurrency(), 2)
          + "|raw=" + (string)(int)DailyLossPercent + "/" + (string)(int)DailyLossCurrency
          + "|both list members (D1f), effective limit is the min of the two legs");
```

Expected on defaults: `AG|<server time>|INFO|limits accepted|percent=5.50|currency=200.00|raw=550/200|both list members (D1f), effective limit is the min of the two legs`.

Build label (FINAL, ratified 2026-09-03 at plan review, item FOUR; grounded in standing rule 7): EA:886 `AgInfo("init|build=Phase2|account=" ...` becomes `build=R10`. `LEDGER.md:1320` records the same move for Phase 2: "the init line's build label moving `Phase1` to `Phase2`, that last one because standing rule 7 makes the journal the only measure of what is actually running".

### 2.3 Read sites: two accessors in the EA (UNRULED 2026-09-03)

```mql5
//--- R10, D1f: the two limit inputs are enums whose backing integer is
//--- the value. Every arithmetic read goes through these two accessors,
//--- so no site can read the enum as if it were the double it replaced.
double AgInputPercent()  { return AgDailyLossPercentValue(DailyLossPercent); }
double AgInputCurrency() { return AgDailyLossCurrencyValue(DailyLossCurrency); }
```

Placed after the globals block, before `AgArmTimer` (EA:120). Replacements, one per site from TASK 1:

| Site | Before | After |
|---|---|---|
| EA:295 | `AgLimitCurrency(base, DailyLossPercent, DailyLossCurrency)` | `AgLimitCurrency(base, AgInputPercent(), AgInputCurrency())` |
| EA:370 | `g_ag_locked_in_percent  = DailyLossPercent;` | `g_ag_locked_in_percent  = AgInputPercent();` |
| EA:371 | `g_ag_locked_in_currency = DailyLossCurrency;` | `g_ag_locked_in_currency = AgInputCurrency();` |
| EA:441 | `g_ag_locked_in_percent    = DailyLossPercent;` | `g_ag_locked_in_percent    = AgInputPercent();` |
| EA:442 | `g_ag_locked_in_currency   = DailyLossCurrency;` | `g_ag_locked_in_currency   = AgInputCurrency();` |
| EA:510 | `(DailyLossPercent != g_ag_locked_in_percent \|\| DailyLossCurrency != g_ag_locked_in_currency)` | `(AgInputPercent() != g_ag_locked_in_percent \|\| AgInputCurrency() != g_ag_locked_in_currency)` |
| EA:517 | `DoubleToString(DailyLossPercent, 2)` | `DoubleToString(AgInputPercent(), 2)` |
| EA:519 | `DoubleToString(DailyLossCurrency, 2)` | `DoubleToString(AgInputCurrency(), 2)` |
| EA:716 | `AgLimitCurrency(base, DailyLossPercent, DailyLossCurrency)` | `AgLimitCurrency(base, AgInputPercent(), AgInputCurrency())` |
| EA:890 | `AgValidateLimits(DailyLossPercent, DailyLossCurrency, why)` | `AgValidateLimits((int)DailyLossPercent, (int)DailyLossCurrency, why)` |

`AgLimitCurrency` (Pnl.mqh:289-299) BODY UNCHANGED. Under D1f both legs are always positive, so the `has_percent && has_currency` branch at Pnl.mqh:294-295 is the only live one and the min of the two legs is what D1f, D6a and Q8 all require. The two disabled-leg branches are dead by construction and are left in place because `AgPhase2StateVectors.mq5:492` still calls the function with a zero currency literal and its k1 row depends on the percent-only path. Only the comment Pnl.mqh:284-287 changes, to say that D1f makes both legs mandatory and the disabled-leg branches unreachable from the EA.

EA:716 is the ONE line above the ACTIVE breach tail that changes. The V1 build recorded that region byte identical by hash (`LEDGER.md:122` "The region above the breach tail in `AgEvaluateActive` is byte identical BY HASH"). This build cannot keep that: D1f changes the type of the two values the line reads. Static row R10-S3 in TASK 4 records the region diff as exactly that one line and the tail EA:728-845 unchanged by hash.

Input block after the build:

```mql5
//--- core config class: malformed means the EA refuses to run (Q4). R10,
//--- D1f (FINAL 2026-09-03): both limits are mandatory list inputs, the
//--- backing integer is the value, any non member refuses init, and there
//--- is no disable path. Defaults FINAL 2026-09-03: the top of each list.
input ENUM_AG_DAILY_LOSS_PERCENT  DailyLossPercent  = AG_DLP_5_50; // Daily loss limit, percent of day-anchor base
input ENUM_AG_DAILY_LOSS_CURRENCY DailyLossCurrency = AG_DLC_200;  // Daily loss limit, account currency
//--- optional config class: malformed means feature off plus WARN
input bool                   WeeklyReportEnabled    = true;  // Weekly measurement and reporting
input ENUM_AG_LOG_VERBOSITY  LogVerbosity           = AG_LOG_NORMAL; // Journal verbosity
```

### 2.4 The four compile-time constants (D7b, D11a FINAL)

Names follow EA:37 `#define AG_LIFE_INTERVAL_SECONDS 30`, EA:85 `#define AG_QUOTE_FROZEN_SECONDS 120` and Persist.mqh:31 `#define AG_MUTEX_STALE_SECONDS  10`. Placed in the EA directly after EA:37, because every consumer is in the EA and the two include functions take the value as a parameter (Pnl.mqh:309, Persist.mqh:279) and stay unchanged.

```mql5
//--- R10, D7b and D11a (FINAL 2026-09-03): four former inputs are now
//--- compile-time constants, the AG_LIFE_INTERVAL_SECONDS precedent of
//--- 2026-07-29: "a config value that can disable the fail-visible
//--- guarantee belongs to the core class or nowhere. Nowhere is simpler."
//--- Values are the ruled defaults, unchanged. Formerly the inputs
//--- SweepPeriodSeconds, HistoryStablePolls, CrashLoopMaxInits and
//--- CrashLoopWindowSeconds; this comment is the only place the four old
//--- names survive in the tree, which static row R10-S2 checks.
#define AG_SWEEP_PERIOD_SECONDS       1
#define AG_HISTORY_STABLE_POLLS       3
#define AG_CRASH_LOOP_MAX_INITS       3
#define AG_CRASH_LOOP_WINDOW_SECONDS  300
```

Edits, one per site from TASK 1:

| Site | Change |
|---|---|
| EA:21, 22, 23, 24 | four `input int` lines deleted |
| EA:29 | `int  g_timer_seconds       = 1;` deleted; a constant needs no carrier |
| EA:122 | `EventSetTimer(AG_SWEEP_PERIOD_SECONDS)` |
| EA:124 | `(string)AG_SWEEP_PERIOD_SECONDS + "s"`, journal text `timer armed\|period=1s` unchanged |
| EA:552 | comment: `past AG_HISTORY_STABLE_POLLS` |
| EA:561, 565, 659, 1151, 1156 | `(string)AG_HISTORY_STABLE_POLLS`, journal text `polls=<n>/3` unchanged |
| EA:656, 1121 | `AgHistoryStable(AG_HISTORY_STABLE_POLLS)` |
| EA:895-915 | the four refusal blocks deleted whole |
| EA:916 | `g_timer_seconds = SweepPeriodSeconds;` deleted |
| EA:1023 | `AgHaltUncleanChain(AG_CRASH_LOOP_WINDOW_SECONDS)` |
| EA:1027 | `if(chain > AG_CRASH_LOOP_MAX_INITS)` |
| EA:1030 | `(string)AG_CRASH_LOOP_WINDOW_SECONDS + "s, limit " + (string)AG_CRASH_LOOP_MAX_INITS` |
| EA:1034-1035 | the two constants, verbose text unchanged |
| EA:1038 | `+ "\|timer=" + (string)AG_SWEEP_PERIOD_SECONDS + "s"`, transition numbers `timer=1s` unchanged |

Every journal string these sites emit is byte identical after the change because the constants equal the former defaults.

### 2.5 FINAL touch table: INHERITED or SUPERSEDED, quoted

| Change | FINAL touched | Quoted clause | Status |
|---|---|---|---|
| enum inputs, list refusal | Q4/F9 `LEDGER.md:1993` | "Core (daily limit, lock behavior) malformed, or both limits zero -> OnInit returns INIT_PARAMETERS_INCORRECT, EA visibly refuses to run." | "malformed ... refuses" INHERITED; "both limits zero" SUPERSEDED by D1f (`:2205` "supersedes the both-limits-zero clause of Q4/F9") |
| enum inputs, list refusal | Q8 `LEDGER.md:2009` | "Dual limits, percent and fixed currency, stricter wins, 0 disables each, both zero refuses init per the config-class decision." | "stricter wins" INHERITED (`:2205` "The effective limit remains the min of the two legs, unchanged"); "0 disables each, both zero refuses init" SUPERSEDED by D1f (`:2205` "on that clause alone") |
| enum inputs | Q6/F7 `LEDGER.md:2001` | "the locked window is judged by the snapshot, never by live inputs. An input change while locked is logged loudly." | INHERITED, D4a `:2213` "current Q6 behaviour ... unchanged"; the witness sites EA:370-371, 441-442, 510-519 change only the read expression |
| enum inputs | reseed on reload `LEDGER.md:1854` | "On reload the state takes the current input values. A record of an input change made while locked is not required." | INHERITED, EA:441-442 keep seeding from the live inputs |
| enum inputs | D5a `:2217` | "A tightening of either limit from the dialog takes effect immediately." | INHERITED by construction: a dialog change re-inits (`LEDGER.md:1800` "an input-change re-init reuses the loaded image"), OnInit re-enters SYNCING (EA:1037), the next ACTIVE pass reads EA:716, and the ratchet lowers on a decrease (Persist.mqh:828-832 `if(live_limit < g_ag_floor_currency - AG_PNL_EPSILON)`) |
| enum inputs | D6a `:2221` | "THE RATCHET COMPARES THE DERIVED LIMIT ... THE CEILING CHECK IS PER RAW INPUT AT INIT" | INHERITED, EA:735 `AgRatchetUpdate(window_anchor, limit, AG_LIFE_INTERVAL_SECONDS)` still receives the min; the raw check is 2.2 |
| enum inputs | D9a `:2236` | "ratchet HOLDING against a raised limit" | INHERITED, the text exists at Persist.mqh:839 `AgWarn("ratchet HOLDING against a raised limit (question SEVEN): live="` at the cadence passed from EA:735 |
| enum inputs | visible refusal `LEDGER.md:2127` | "The mutex refusal and all five config refusals draw one dated REFUSED banner ... through a single helper" | mechanism INHERITED (EA:855-862 unchanged); the count "five" becomes two `why` texts on one return plus the mutex, a consequence of D7b and D11a, not a new ruling |
| enum inputs | R4 `LEDGER.md:2086` | "runs both refusal rows at contact 1: both limits zero, and a malformed but nonzero core input." | INHERITED as history; both rows are unreachable after this build (zero is a non-member, `SweepPeriodSeconds` no longer exists), no re-run |
| enum inputs | SPEC 4.3 `docs/SPEC_v0.1.md:90` | "Stricter wins. 0 disables each. Both zero refuses init (section 5)." | "Stricter wins" INHERITED; the two zero clauses SUPERSEDED by D1f; SPEC amendment in the build session |
| enum inputs | SPEC 5 table `docs/SPEC_v0.1.md:119-120` | `\| DailyLossPercent \| double \| 5.0 \| 0 \| core \| percent of day-anchor base \|` | SUPERSEDED: type enum, default 5.50 and 200, off-value none |
| defaults | defaults FINAL (appended after `:2246`) | "the top value of each D1f list" | NEW, no prior FINAL named a default for the two limits under D1f; the old defaults at EA:19-20 (`5.0`, `0.0`) and SPEC:119-120 are superseded |
| vectors | 2026-08-04 `LEDGER.md:2135` | "The twelve a9 acceptance vectors are committed to the repository under docs/vectors/. The terminal Presets folder remains the OPERATIVE copy" | procedure INHERITED (sync direction, restart, Load browser check); count SUPERSEDED by D8b `:2229` "on the vector count alone" |
| constants | `LEDGER.md:2058` | "AG_LIFE_INTERVAL_SECONDS stays a compile-time constant at 30 s and does not become an input." Reason: "a config value that can disable the fail-visible guarantee belongs to the core class or nowhere. Nowhere is simpler." | INHERITED as the precedent D7b and D11a extend |
| constants | `LEDGER.md:2062` | "AG_MUTEX_STALE_SECONDS stays a compile-time constant at 10 s and is deliberately not an input" | INHERITED as precedent |
| constants | R1 `LEDGER.md:2074` | "Trip when more than CrashLoopMaxInits consecutive unclean sessions exist and each adjacent pair of inits lies within CrashLoopWindowSeconds." | INHERITED in mechanism; the two names now denote constants (D11a) and `AgHaltUncleanChain` (Persist.mqh:279) is unchanged |
| constants | R2 `LEDGER.md:2078` | "CrashLoopWindowSeconds default becomes 300, redefined as the pairwise gap bound." | INHERITED, the constant is 300 |
| constants | 2026-07-30 deferral `LEDGER.md:1701` | "four core inputs reach a refusal return while having a safe clamp available (SweepPeriodSeconds, CrashLoopMaxInits, CrashLoopWindowSeconds, HistoryStablePolls) ... refuse-versus-clamp deferred to post Phase 0." | CLOSED for two inputs by D7b `:2225` "This closes the refuse-versus-clamp deferral of 2026-07-30 ... for these two inputs"; closed for the other two as a consequence of D11a, an input that no longer exists can neither refuse nor clamp |
| constants | 2026-08-04 wording `LEDGER.md:2139` | "the source comment at AccountGuardian.mq5:21 change from "clamped 1..5" to language stating the value is refused outside 1..5" | SUPERSEDED as a consequence of D7b: the input and its comment are removed, SPEC:122 removed with it |
| constants | backward clock step `LEDGER.md:2131` | "A negative gap between two adjacent session inits ... counts as inside CrashLoopWindowSeconds and does not break the unclean chain." | INHERITED, Persist.mqh:279 unchanged |
| constants | Q10 amendment `LEDGER.md:2197` | "do not run the breach evaluation until `AgHistoryStable(HistoryStablePolls)` passes again" | INHERITED, EA:656 passes the constant, `RESYNC: polls=<n>/3` unchanged |
| constants | F13 `LEDGER.md:2021` | "Timer-driven architecture, EventSetTimer(1)." | INHERITED, now literally `EventSetTimer(AG_SWEEP_PERIOD_SECONDS)` with the constant 1 |
| constants | Q9 `LEDGER.md:2193` | "a real breach is delayed by at most one second (the current SweepPeriodSeconds default), never suppressed." | INHERITED, the bound is fixed at 1 s by constant |
| constants | 2026-08-08 Q6 `LEDGER.md:2176` | "all eight inputs read at their ruled defaults, including HistoryStablePolls=3" | INHERITED as history; the input set becomes four |
| all | D2/D3/D3b `:2209` | "VOID UNDER D1f. No `guard_<login>.dat` is created, no change is made to `floor_<login>.dat`" | INHERITED, no persistence format changes in this build |
| all | D10a `:2240` | "The defect 2 ... and defect 4 ... fixes ... are not part of this build." | INHERITED, ISSUES `:17-23` stay OPEN and untouched |

### 2.6 Documentation surfaces the build session touches

- `docs/SPEC_v0.1.md:90` and `:113-126` (config classes text and the input table): amendment rows for the two enums, the defaults, and the four rows `:122-125` removed. Amendment numbering continues the SPEC's own series.
- `docs/vectors/README.md`: TASK 3 target table, in scope per D8b.
- `README.md:24`, `:125-130`, `:200`, `:276`, `:377-382`, `:452` all describe `0` as a disable value or list the four removed inputs. Bilingual, English first, Hebrew below, and it never names the ledger. AUTHORIZED for the build session by the R10 plan review ruling, item TWO (Task B4 step 4).
- Dated records NOT amended: `docs/DESIGN_PHASE1_2.md`, `docs/PLAN_PHASE0.md`, `docs/PLAN_PHASE1_PNL_CORE.md`, `docs/FIXPLAN_*`, `docs/PROCEDURE_*`, `docs/evidence/**`.

### 2.7 Build session task list

TDD adaptation: MQL5 has no unit framework; the synthetic vector script is the test harness and it runs only inside the terminal, which the owner deploys under RULE A. So each task is compile-verified in the worktree (standing rule 6: read the `Result:` line, not the exit code), and the run happens at acceptance (TASK 4). The vectors are written before the EA edits so the membership functions are specified by tests first.

#### Task B1: enums, membership, mapping, validation in `Pnl.mqh`

**Files:** Modify `MQL5/Include/AccountGuardian/Pnl.mqh:283-299` (insert 2.1 before `AgLimitCurrency`, amend its comment), `:334-372` (replace `AgValidateLimits` with 2.2).

**Interfaces produced:** `ENUM_AG_DAILY_LOSS_PERCENT`, `ENUM_AG_DAILY_LOSS_CURRENCY`, `bool AgDailyLossPercentIsMember(const int)`, `bool AgDailyLossCurrencyIsMember(const int)`, `double AgDailyLossPercentValue(const ENUM_AG_DAILY_LOSS_PERCENT)`, `double AgDailyLossCurrencyValue(const ENUM_AG_DAILY_LOSS_CURRENCY)`, `bool AgValidateLimits(const int, const int, string&)`.

- [ ] Step 1: insert the 2.1 block and replace `AgValidateLimits` with the 2.2 block, exactly as written.
- [ ] Step 2: compile the EA in the worktree. It FAILS: EA:890 still passes doubles and EA:19-20 are still doubles. Expected `Result:` line carries errors naming `AgValidateLimits`. Record the line.
- [ ] Step 3: no commit yet (the tree does not build); proceed to B2.

#### Task B2: synthetic vectors in `AgPhase2StateVectors.mq5`

**Files:** Modify `MQL5/Scripts/AccountGuardian/AgPhase2StateVectors.mq5`, insert before the final `PrintFormat("AGVEC|SUMMARY|%d/%d", g_pass, g_total);` at `:552`. Helpers exist: `:51 void AgVecCheck(const string name, const bool ok, const string detail)`, `:70 void AgVecCheckInt(const string name, const long got, const long want)`, `:79 void AgVecCheckMoney(const string name, const double got, const double want)`.

- [ ] Step 1: add the eleven checks:

```mql5
   //--- R10, D1f (FINAL 2026-09-03): list membership and mapping. Counts are
   //--- exhaustive over a range that brackets both lists, so the two member
   //--- totals D1f states, 22 and 48, are measured rather than asserted.
   int r10_pct_members = 0;
   for(int p = -1000; p <= 1000; p++)
      if(AgDailyLossPercentIsMember(p))
         r10_pct_members++;
   AgVecCheckInt("r10_percent_member_count_is_22", r10_pct_members, 22);
   int r10_cur_members = 0;
   for(int c = -1000; c <= 1000; c++)
      if(AgDailyLossCurrencyIsMember(c))
         r10_cur_members++;
   AgVecCheckInt("r10_currency_member_count_is_48", r10_cur_members, 48);
   AgVecCheck("r10_percent_floor_and_ceiling",
              AgDailyLossPercentIsMember(25) && AgDailyLossPercentIsMember(550)
              && !AgDailyLossPercentIsMember(0) && !AgDailyLossPercentIsMember(575),
              "25 and 550 in, 0 and 575 out");
   AgVecCheck("r10_percent_off_grid_rejected",
              !AgDailyLossPercentIsMember(510) && !AgDailyLossPercentIsMember(5)
              && !AgDailyLossPercentIsMember(-25),
              "510, 5 and -25 out");
   AgVecCheck("r10_currency_two_segments",
              AgDailyLossCurrencyIsMember(1) && AgDailyLossCurrencyIsMember(10)
              && AgDailyLossCurrencyIsMember(15) && AgDailyLossCurrencyIsMember(200)
              && !AgDailyLossCurrencyIsMember(0) && !AgDailyLossCurrencyIsMember(12)
              && !AgDailyLossCurrencyIsMember(205) && !AgDailyLossCurrencyIsMember(-5),
              "1, 10, 15, 200 in; 0, 12, 205, -5 out");
   AgVecCheckMoney("r10_map_percent_550_is_5_50", AgDailyLossPercentValue(AG_DLP_5_50), 5.50);
   AgVecCheckMoney("r10_map_percent_25_is_0_25", AgDailyLossPercentValue(AG_DLP_0_25), 0.25);
   AgVecCheckMoney("r10_map_currency_200", AgDailyLossCurrencyValue(AG_DLC_200), 200.0);
   AgVecCheckMoney("r10_default_limit_is_min_of_legs",
                   AgLimitCurrency(2000.0, AgDailyLossPercentValue(AG_DLP_5_50),
                                   AgDailyLossCurrencyValue(AG_DLC_200)), 110.0);
   string r10_why = "";
   AgVecCheck("r10_validate_rejects_currency_zero",
              !AgValidateLimits(550, 0, r10_why)
              && StringFind(r10_why, "DailyLossCurrency is not a list member (raw 0)") == 0,
              r10_why);
   AgVecCheck("r10_validate_accepts_defaults", AgValidateLimits(550, 200, r10_why), "550/200");
```

- [ ] Step 2: compile the script in the worktree: `Result: 0 errors, 0 warnings`. Record the line. The script includes `Pnl.mqh`, so B1 is exercised here.
- [ ] Step 3: commit B1 and B2 together: `r10: D1f enums, membership and mapping in Pnl.mqh with eleven synthetic vectors`.

#### Task B3: the EA

**Files:** Modify `MQL5/Experts/AccountGuardian/AccountGuardian.mq5` per 2.2, 2.3 and 2.4.

- [ ] Step 1: input block (2.3), constants block (2.4), delete EA:29, add the two accessors before EA:120.
- [ ] Step 2: the ten read-site replacements of 2.3 and the constant replacements of 2.4, including deletion of EA:895-916.
- [ ] Step 3: after the validation block, add the `limits accepted` line of 2.2; change EA:886 to `build=R10`.
- [ ] Step 4: compile the EA: `Result: 0 errors, 0 warnings`. Record the line, the ex5 mtime, and the md5 of all seven source files (standing rule 7).
- [ ] Step 5: run the static rows R10-S1 to R10-S4 of TASK 4 and record each measurement.
- [ ] Step 6: commit: `r10: D1f list inputs, D7b and D11a constants, build label R10`.

#### Task B4: vectors and the two READMEs

**Files:** Modify `docs/vectors/a9_defaults.set`, `docs/vectors/a9_optional_bad.set`; create the six files of 3.2; `git rm` the ten files of 3.3; rewrite `docs/vectors/README.md` to 3.4; update `README.md`.

- [ ] Step 1: write the eight files exactly as in 3.1 and 3.2, ASCII, CRLF as the existing files (`scripts/agtest.ps1:35` writes `-Encoding ASCII` with `` `r`n ``).
- [ ] Step 2: `git rm` the ten retired files.
- [ ] Step 3: `docs/vectors/README.md` per 3.4.
- [ ] Step 4: `README.md` (authorized, R10 plan review item TWO). English section: `:24` drop "Enable one or both" and the zero-disable sentence, both legs are mandatory list inputs and the stricter wins; `:125-126` the two limit rows become enum rows with defaults 5.50 and 200 and "off-list value refuses init", no zero text; `:127-130` the four rows for `SweepPeriodSeconds`, `CrashLoopMaxInits`, `CrashLoopWindowSeconds` and `HistoryStablePolls` deleted, replaced by one sentence naming them as fixed at 1, 3, 3 and 300; `:60` and `:84` keep their meaning with the fixed value 3 named instead of the input; `:200` unchanged, still true. Hebrew section: the same edits at `:276`, `:312`, `:336`, `:377-382`, `:452`, full Hebrew sentences, code identifiers in backticks only. The file never names the ledger, the plan or any session.
- [ ] Step 5: commit: `r10: a9 vectors, two rewritten, six added, ten retired per D8b, both READMEs`.

#### Task B5: SPEC amendment

**Files:** Modify `docs/SPEC_v0.1.md:90`, `:113-126`.

- [ ] Step 1: line 90 becomes `- limit_currency = min of the two legs (Q8 FINAL, D1f FINAL 2026-09-03): percent limit = DailyLossPercent% of base; fixed limit = DailyLossCurrency. Stricter wins. Both legs are mandatory list inputs; a value off either list refuses init (section 5).`
- [ ] Step 2: table rows 119-120 become `| DailyLossPercent | enum, 22 members 0.25 to 5.50 step 0.25 | 5.50 | none | core | percent of day-anchor base; off-list refuses init |` and `| DailyLossCurrency | enum, 48 members 1 to 10 step 1 then 15 to 200 step 5 | 200 | none | core | account currency; stricter of the two wins; off-list refuses init |`; rows 122-125 deleted; a note under the table: `SweepPeriodSeconds 1, HistoryStablePolls 3, CrashLoopMaxInits 3 and CrashLoopWindowSeconds 300 are compile-time constants from R10 (D7b, D11a FINAL 2026-09-03).`
- [ ] Step 3: commit: `spec: amend section 4.3 and the section 5 input table for R10`.

#### Task B6: LEDGER

- [ ] Step 1: ACTIONS entry per TASK 5 draft 5.3, with every placeholder replaced by the measured value.
- [ ] Step 2: ISSUES entry per 5.1, and the NEXT BEST ACTION Action line (`LEDGER.md:6`) rewritten to point at the acceptance rows.
- [ ] Step 3: commit: `ledger: R10 build implemented, acceptance rows open`.

#### Task B7: deploy and acceptance (owner performs every copy)

Follows TASK 4 rows R10-D, R10-1 to R10-8 in order. Executor's part is dictation, read-only hashing and the read-only harvest.

---

## TASK 3: vectors

### 3.1 Survivor rewrite spec (D8b correction, defaults FINAL)

Both survivors currently read (`docs/vectors/a9_defaults.set:1-8`): `DailyLossPercent=5.0`, `DailyLossCurrency=0.0`, `SweepPeriodSeconds=1`, `CrashLoopMaxInits=3`, `CrashLoopWindowSeconds=300`, `HistoryStablePolls=3`, `WeeklyReportEnabled=true`, `LogVerbosity=0` (`a9_optional_bad.set:8` differs only as `LogVerbosity=99`). Four of the eight keys name inputs that no longer exist after D7b and D11a, and the two limit lines are non-members under D1f (`LEDGER.md:2233`). A complete input set under this build has four keys. The plain `key=value` form is kept: `LEDGER.md:1699` "a9_defaults.set parsed correctly and the EA attached healthy with percent 5.0 in force".

`a9_defaults.set`:
```
DailyLossPercent=550
DailyLossCurrency=200
WeeklyReportEnabled=true
LogVerbosity=0
```

`a9_optional_bad.set`:
```
DailyLossPercent=550
DailyLossCurrency=200
WeeklyReportEnabled=true
LogVerbosity=99
```

### 3.2 New vectors for list membership refusal (UNRULED 2026-09-03, executor design)

Six files, each the defaults with exactly one field moved, matching the README's own rule (`docs/vectors/README.md:3-5` "exactly one field moved off the defaults, so a refusal or a WARN can be attributed to that one field and nothing else"). Three failure classes per input, which is the smallest set that separates a membership check from a range check and from a ceiling clamp:

| File | Field moved | Why this value |
|---|---|---|
| `a9_percent_zero.set` | `DailyLossPercent=0` | the retired disable value and the old currency default class; proves "Neither can be zero" (D1f) |
| `a9_percent_off_grid.set` | `DailyLossPercent=510` | 5.10, inside the range, between members 5.00 and 5.25; a range check would accept it, only membership refuses |
| `a9_percent_over_ceiling.set` | `DailyLossPercent=575` | on the 0.25 grid, one step above the 5.50 ceiling; the runtime-widening case D4a names, "ABOVE THE CEILING, the value is not a list member and init refuses" |
| `a9_currency_zero.set` | `DailyLossCurrency=0` | the value both survivors carried (`LEDGER.md:2233`); the disable path that D1f removes |
| `a9_currency_gap.set` | `DailyLossCurrency=12` | inside the range, in the gap between the two segments (10 and 15); a check written as one range would accept it |
| `a9_currency_over_ceiling.set` | `DailyLossCurrency=205` | on the 5 grid, one step above the 200 ceiling |

Each file is the four-line default set with one line replaced, for example `a9_currency_gap.set`:
```
DailyLossPercent=550
DailyLossCurrency=12
WeeklyReportEnabled=true
LogVerbosity=0
```

The synthetic vectors of Task B2 prove the membership functions exhaustively without the terminal. The six `.set` files prove the terminal channel D1f names: that a non-member arriving through a `.set` file reaches `OnInit` and is refused. That is a platform behaviour this ledger has not measured (the MQL5 reference is silent on out-of-list values for enum inputs), so the rows carry two admissible outcomes in TASK 4.

### 3.3 Retired files (D8b FINAL, D8b correction)

`a9_both_zero.set`, `a9_neg_percent.set`, `a9_neg_currency.set`, `a9_percent_over_100.set`, `a9_nonfinite.set` (D1f); `a9_sweep_zero.set`, `a9_sweep_over.set`, `a9_polls_zero.set` (D7b); `a9_crash_max_zero.set`, `a9_window_zero.set` (D11a). Reading of "retired", FINAL, ratified 2026-09-03 at plan review, item ONE, "none of the ten is needed by the build or by the guardian's function": the ten are removed from the tree by `git rm` and named in the README's retired section with the ruling and the commit, so a future repo-to-terminal sync cannot copy a vector that names inputs the build no longer has. History keeps the bytes. The terminal Presets copies of the ten are the owner's to delete by hand under RULE A, or to leave; the README already says a terminal copy that disagrees with the repository "is what ran and the repo copy is wrong" (`docs/vectors/README.md:51-52`), so a stale Presets file is a live hazard for any row that loads it by mistake.

### 3.4 `docs/vectors/README.md` target table

Heading paragraph: "Eight `.set` files, one per row of the A9 acceptance matrix as rewritten by R10 (D1f, D7b, D11a FINAL 2026-09-03). Each is a complete input set of four keys with exactly one field moved off the defaults."

| File | Field off default | Expected |
|---|---|---|
| `a9_defaults.set` | none | healthy init; `limits accepted\|percent=5.50\|currency=200.00\|raw=550/200` |
| `a9_optional_bad.set` | `LogVerbosity` 99 | WARN `optional config invalid: LogVerbosity unrecognised, falling back to NORMAL`, init succeeds |
| `a9_percent_zero.set` | `DailyLossPercent` 0 | refuse, `DailyLossPercent is not a list member (raw 0)` |
| `a9_percent_off_grid.set` | `DailyLossPercent` 510 (5.10) | refuse, `(raw 510)` |
| `a9_percent_over_ceiling.set` | `DailyLossPercent` 575 (5.75) | refuse, `(raw 575)` |
| `a9_currency_zero.set` | `DailyLossCurrency` 0 | refuse, `DailyLossCurrency is not a list member (raw 0)` |
| `a9_currency_gap.set` | `DailyLossCurrency` 12 | refuse, `(raw 12)` |
| `a9_currency_over_ceiling.set` | `DailyLossCurrency` 205 | refuse, `(raw 205)` |

Followed by a "Retired 2026-09-03 (D8b)" list of the ten names with the striking ruling each, and the unchanged sections "Which copy is operative" and "Keeping the two in sync" (`README.md:22-53`).

Final count: 8 committed a9 vectors (2 rewritten, 6 new, 10 retired). Synthetic: 11 new `r10_*` checks in `AgPhase2StateVectors.mq5`; the SUMMARY denominator is measured at run time from the terminal journal, not predicted.

---

## TASK 4: acceptance

Evidence standard for every row: the artifact file name and line number (`LEDGER.md:1759`), banked as a transcoded `.txt` under `docs/evidence/` (`LEDGER.md:1774`), with the owner copying the journal out of the Terminal folder at the executor's dictation and the executor reading the copy only (`LEDGER.md:1768`). An owner dialog reading or banner reading counts as owner-eyewitness fact (`LEDGER.md:2177`). A session report counts for nothing (`LEDGER.md:1962`).

Build identity for every live row, standing rule 7: the md5 of all seven source files against the committed tip, the ex5 mtime, and the `init|build=R10` journal line. The ex5 md5 and size are recorded for the copy-landing check only (`LEDGER.md:1903` "an independent check that the file that landed is the file that was named"), never as identity.

### Static rows (worktree, no terminal)

| Row | Procedure | Expected | Evidence |
|---|---|---|---|
| R10-S1 compile | `metaeditor64.exe /compile:<wt>\MQL5\Experts\AccountGuardian\AccountGuardian.mq5 /include:<wt>\MQL5 /log:<jobtmp>\metaeditor.log`, and the same for `AgPhase2StateVectors.mq5` and `AgPhase1ClockVectors.mq5` | `Result: 0 errors, 0 warnings` three times; every include path in the log under the worktree | log lines quoted; exit code ignored (standing rule 6) |
| R10-S2 names gone | grep the four old names over `MQL5/` | hits only inside the 2.4 constants comment; grep `^input ` over the EA returns exactly four lines | grep output quoted |
| R10-S3 region diff | `git diff 00e2b43 -- MQL5/Experts/AccountGuardian/AccountGuardian.mq5` restricted to `AgEvaluateActive` | one changed line above the breach tail (EA:716); the tail EA:728-845 md5 identical before and after | hashes quoted |
| R10-S4 untouched files | md5 of `Persist.mqh`, `State.mqh`, `Clock.mqh`, `Log.mqh`, `Sweep.mqh` | identical to `00e2b43`; `AgLimitCurrency` body Pnl.mqh:290-299 byte identical | hashes quoted |

### Deploy row (owner performs every copy, RULE A)

| Row | Procedure | Expected | Evidence |
|---|---|---|---|
| R10-D deploy | RULE B alias audit first. Executor records worktree md5 and size of `AccountGuardian.ex5` and `AgPhase2StateVectors.ex5` and of the eight `.set` files. Owner copies, one file at a time at dictation: the two ex5 to `MQL5\Experts\AccountGuardian\` and `MQL5\Scripts\AccountGuardian\`, the eight `.set` to `MQL5\Presets\`. Executor `Get-FileHash` on each landed file. Owner restarts the terminal (`LEDGER.md:2135` "The restart is mandatory"). Owner opens the EA properties on the running chart immediately after restart and reads both limit inputs. | every landed md5 equals the worktree md5; Load browser lists the eight files (owner reading). FIRST-INIT HAZARD, stated so it is not read as a defect: the chart profile holds last-used `DailyLossPercent=5.0` and `DailyLossCurrency=0.0` as doubles; on the new build these arrive at enum inputs and either (a) parse to 5 and 0, both non-members, and the first init REFUSES with the two ALERT lines of 2.2, or (b) fail to apply and the defaults 550 and 200 hold. Under (a) the owner selects 5.50 and 200 in the dialog and clicks OK; the re-init then runs healthy. Either way the night ends with valid last-used inputs (`LEDGER.md:1805-1806` standing lesson). | hashes quoted; the first init's journal lines quoted with file and line; owner dialog reading |

### Live rows (fresh load from a removal per `LEDGER.md:1801`; halt file md5 taken BEFORE each attach)

| Row | Procedure | Expected journal lines | Evidence |
|---|---|---|---|
| R10-0 synthetic run | owner runs `AgPhase2StateVectors` on a chart | `AGVEC\|SUMMARY\|<n>/<n>` with every `r10_*` line `PASS`; `<n>` equals the previous denominator plus 11 | Experts journal copy, lines quoted; per `LEDGER.md:1246` verified from the terminal's own journal |
| R10-1 `a9_defaults.set` | remove EA, attach fresh, Load `a9_defaults.set`, confirm dialog shows 5.50 and 200, OK | `INFO\|init\|build=R10\|account=1200252169\|server=...`; `INFO\|limits accepted\|percent=5.50\|currency=200.00\|raw=550/200\|both list members (D1f), effective limit is the min of the two legs`; `INFO\|timer armed\|period=1s`; `TRANSITION\|...->SYNCING\|boot\|weekly=on\|timer=1s`; then `TRANSITION\|SYNCING->ACTIVE\|history stable\|polls=3/3`. SAME-DAY NOTE: if `floor_<login>.dat` holds today's 5.00 percent floor, the raised 5.50 leg is HELD and `WARN\|ratchet HOLDING against a raised limit (question SEVEN): live=<x> floor=<y>; the floor is enforced until the next day anchor` repeats at the 30 s cadence until 01:00 server. That is D9a's form behaving as ruled, not a defect. | lines quoted with file and line |
| R10-2 `a9_percent_zero.set` | as R10-1 with the file | `ALERT\|refusing to run, core config invalid: DailyLossPercent is not a list member (raw 0); the list is 0.25 to 5.50 in steps of 0.25, stored as hundredths 25 to 550`; `INFO\|deinit\|halt file NOT written: ...`; `INFO\|deinit\|reason=8\|...`; `INFO\|deinit\|banner NOT cleared: init was refused, dated REFUSED banner stays on the chart`; REFUSED banner on the chart; halt file md5 unchanged; no `timer armed` line | lines quoted; owner banner reading; two `Get-FileHash` values |
| R10-3 `a9_percent_off_grid.set` | as R10-2 | same shape, `(raw 510)` | as R10-2 |
| R10-4 `a9_percent_over_ceiling.set` | as R10-2 | same shape, `(raw 575)` | as R10-2 |
| R10-5 `a9_currency_zero.set` | as R10-2 | `ALERT\|refusing to run, core config invalid: DailyLossCurrency is not a list member (raw 0); the list is 1 to 10 in steps of 1, then 15 to 200 in steps of 5` and the same three deinit lines | as R10-2 |
| R10-6 `a9_currency_gap.set` | as R10-2 | same shape, `(raw 12)` | as R10-2 |
| R10-7 `a9_currency_over_ceiling.set` | as R10-2 | same shape, `(raw 205)` | as R10-2 |
| R10-8 `a9_optional_bad.set` | as R10-1 with the file | the R10-1 lines plus `WARN\|optional config invalid: LogVerbosity unrecognised, falling back to NORMAL` before the mutex step; init proceeds | lines quoted |

Second admissible outcome for R10-2 to R10-7, recorded so the rows cannot be reported as failed by mistake: if the terminal COERCES an off-list `.set` value to a list member before `OnInit` runs, the row shows a healthy init and the dialog shows a member (owner reading names which). Then the `.set` channel cannot deliver a non-member, the refusal is unreachable through it, and the row closes as PASS-BY-CONSTRUCTION for that channel with the membership check itself proven by R10-0. The two outcomes are separable on the artifact: a refusal carries the ALERT line, a coercion carries `limits accepted` with the coerced `raw=` value. The row is not closable on a session report either way.

Not rowed: D4a within the ceiling while LOCKED. Ruled unchanged (`:2213`), and the reload behaviour is ruled at `LEDGER.md:1854` "A record of an input change made while locked is not required"; P2-H stays OPEN under `LEDGER.md:1858` "Not closable by code or by code reading". A live lock is not producible on demand for an acceptance night.

End state after the night (`LEDGER.md:1805-1806`): the chart carries `a9_defaults.set` values as last-used, a healthy instance in SYNCING or ACTIVE, `limits accepted` quoted from its init.

---

## TASK 5: LEDGER entries this plan creates, drafted, not written

### 5.1 ISSUES, build session, added at the top

```
Issue:  R10 BUILD ACCEPTANCE PENDING. The build ruled 2026-09-03 (D1f, D7b, D11a, D10a, DECISIONS :2205 to :2246, defaults FINAL appended after :2246) is implemented on branch `<branch>` at commit `<hash>` per `docs/PLAN_R10_INPUT_HARDENING_2026-09-03.md`. Static rows R10-S1 to R10-S4 <closed/open with measured values>. Deploy row R10-D and live rows R10-0 to R10-8 are NOT RUN. One platform question is open inside the rows and is stated so it is not later read as a defect either way: whether the terminal delivers an off-list `.set` integer to an enum input unmodified (rows refuse) or coerces it (rows close PASS-BY-CONSTRUCTION on the `.set` channel, the check proven by R10-0). The MQL5 reference is silent on it.
Action: OWNER DEPLOYS per RULE A at the executor's dictation (R10-D), including the first-init dialog reading on the existing chart, then runs R10-0 to R10-8 as fresh loads from a removal with the halt md5 taken before each attach. Executor harvests read only and closes each row on quoted lines. Owner deletes the ten retired a9 Presets copies by hand, or records that they stay.
Status: OPEN
```

Plus the rewrite of the NEXT BEST ACTION Action line at `LEDGER.md:6`, replacing "NEXT: build D1f + D7b + D11a as one build per D10a" with "NEXT: R10 acceptance per the ISSUES entry above, then a D2/D4 defect-fix plan session, then enforcement phase kickoff, Sweep.mqh flatten engine."

### 5.2 ACTIONS, this plan session (written this session as the third commit, per the plan approval; the only TASK 5 entry written)

```
2026-09-03. R10 BUILD PLAN SESSION, PLAN ONLY. No source file was written, no compile was run, nothing was deployed, no vector or README file was edited, and nothing under the MetaTrader Terminal data folder was read, written or approached, per RULE A; no command named a path inside it, so RULE B's alias audit was not reached. Work in worktree `dreamy-tinkering-aurora` on branch `worktree-r10-plan-20260903` from `00e2b43`, main's own head. Three commits: two DECISIONS entries, the D1f defaults FINAL and the R10 plan review FINAL, appended after D11a (`<hash1>`); `docs/PLAN_R10_INPUT_HARDENING_2026-09-03.md` (`<hash2>`); and this entry (`<hash3>`). The plan maps every read, validation and persistence site of the six inputs (none is persisted; the derived limit is, at EA:374, :456, :463 and Persist.mqh:830-831), designs the two enums with the backing integer as the value, the membership refusal text and the four constants, tags each executor choice UNRULED 2026-09-03 except the four the plan review ratified, rewrites the two surviving a9 vectors to the ruled defaults, adds six refusal vectors and eleven synthetic checks, and sets the acceptance rows with two admissible outcomes for the `.set` channel. The build's ISSUES and ACTIONS entries are drafted inside the plan and not written. STATE FOUND AND LEFT FOR THE OWNER: the branch `worktree-input-hardening-r10-20260903`, deleted locally by the owner-instructed cleanup at 12:36, was re-created at 12:39:57 by a checkout in this worktree from the surviving remote-tracking ref `origin/worktree-input-hardening-r10-20260903` ("branch: Created from origin/..."), 52 seconds after this session's prompt and before its first git command; the session ran no checkout and its harness record names `worktree-dreamy-tinkering-aurora`, so the hand was owner-side. This session switched back to the survivor with one plain checkout, both refs at `00e2b43`, and touched neither the re-created branch nor the remote ref. The first incarnation's commit `69b29f8` of 10:32:37, reset away by the same cleanup, is reachable from no branch and still in the reflog; nothing here reuses it. Nothing is merged and the executor performed no push.
```

### 5.3 ACTIONS, build session template (every angle-bracket field is a measured value)

```
<date>. R10 BUILD IMPLEMENTED, D1f + D7b + D11a PER D10a, on branch `<branch>` at `<hash>`, <n> files, <ins> insertions and <del> deletions, per `docs/PLAN_R10_INPUT_HARDENING_2026-09-03.md`. RULE A held: nothing under the Terminal data folder was read, written or approached. Compile inside the worktree: `Result: 0 errors, 0 warnings, <ms> ms elapsed` for the EA and for both vector scripts, exit code ignored per standing rule 6. Build identity per standing rule 7: `AccountGuardian.mq5` `<md5>`, `Pnl.mqh` `<md5>`, `AgPhase2StateVectors.mq5` `<md5>`, and the five unchanged includes `<md5 each>`; ex5 `<md5>` at <bytes> bytes, mtime <ts>, recorded and not identity. Static rows: R10-S2 grep of the four old names returns <n> lines, all inside the constants comment; R10-S3 one changed line above the breach tail, EA:716, tail md5 `<hash>` unchanged; R10-S4 five includes unchanged by md5. Vectors: `a9_defaults.set` and `a9_optional_bad.set` rewritten to 550/200, six added, ten removed by `git rm` per D8b, README table at eight rows. SPEC 4.3 and the section 5 table amended. UNRULED executor readings carried from the plan and awaiting owner review: the backing integer as the value, the enum and accessor names, the six vector names and values, the eleven synthetic checks. Ratified at plan review 2026-09-03 and applied here: `limits accepted`, `build=R10`, retire as `git rm`, README.md and the SPEC amendment. Nothing deployed, nothing merged, no push.
```

### 5.4 ACTIONS, acceptance session template

```
<date>. R10 ACCEPTANCE, <k> OF 9 LIVE ROWS CLOSED. Deploy R10-D: owner copied at dictation, landed md5 `<md5>` equals worktree `<md5>` for each of the ten files; terminal restarted; first init on the existing chart <refused with the two ALERT lines at `<file>:<line>` / applied defaults, `limits accepted` at `<file>:<line>`>; owner dialog reading <values>. R10-0: `AGVEC|SUMMARY|<n>/<n>` at `<file>:<line>`, eleven `r10_*` PASS lines at `:<lines>`. R10-1: `limits accepted|percent=5.50|currency=200.00|raw=550/200` at `<file>:<line>`, SYNCING to ACTIVE at `:<line>`<, ratchet HOLDING WARN at `:<line>` as the plan predicted for a same-day deploy>. R10-2 to R10-7: <per row, the ALERT line at `<file>:<line>`, halt md5 `<before>` = `<after>`, banner reading / or the coercion outcome with the dialog value the owner read>. R10-8: WARN at `:<line>`, init proceeded at `:<line>`. End state: <values> as last-used, instance <state>. Evidence banked at `docs/evidence/journal-<date>-r10-acceptance.txt` md5 `<md5>`.
```
