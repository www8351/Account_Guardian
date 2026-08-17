//+------------------------------------------------------------------+
//| AccountGuardian.mq5                                              |
//| Account-level lockout EA. Event wiring only (SPEC v0.1 sec 1).   |
//| Phase 0 skeleton: no trading calls anywhere in the build.        |
//+------------------------------------------------------------------+
#property copyright "AccountGuardian"
#property version   "1.00"
#property strict
#property description "Account-level lockout guardian. Phase 2: PnL engine plus lock semantics. Locks the state machine and sends no order; open positions stay open until closed by hand. No trading calls anywhere in the build."

#include <AccountGuardian/Log.mqh>
#include <AccountGuardian/Clock.mqh>
#include <AccountGuardian/State.mqh>
#include <AccountGuardian/Persist.mqh>
#include <AccountGuardian/Pnl.mqh>
#include <AccountGuardian/Sweep.mqh>

//--- core config class: malformed means the EA refuses to run (Q4)
input double                 DailyLossPercent       = 5.0;   // Daily loss limit, percent of day-anchor base (0 = off)
input double                 DailyLossCurrency      = 0.0;   // Daily loss limit, account currency (0 = off)
input int                    SweepPeriodSeconds     = 1;     // Timer period, refused outside 1..5
input int                    CrashLoopMaxInits      = 3;     // Consecutive unclean sessions tolerated
input int                    CrashLoopWindowSeconds = 300;   // Max gap between adjacent inits in a chain
input int                    HistoryStablePolls     = 3;     // SYNCING exit condition (used from Phase 1)
//--- optional config class: malformed means feature off plus WARN
input bool                   WeeklyReportEnabled    = true;  // Weekly measurement and reporting
input ENUM_AG_LOG_VERBOSITY  LogVerbosity           = AG_LOG_NORMAL; // Journal verbosity

int  g_timer_seconds       = 1;
bool g_weekly_enabled      = true;
bool g_owns_mutex          = false;
bool g_resumed_from_halt   = false;
bool g_timer_armed         = false;
int  g_timer_ticks         = 0;
bool g_init_refused        = false;

#define AG_LIFE_INTERVAL_SECONDS 30

//--- Phase 1 PnL evaluation state (A6, 4.3a/4.3b/4.4). All in-memory,
//--- none persisted (never-loaded-never-written): a restart re-derives
//--- everything from TimeCurrent and broker history.
long     g_ag_last_deal_count      = -1;    // Q9 coherence baseline
bool     g_ag_breach_deferred_once = false; // Q9 one-shot deferral flag
bool     g_ag_degraded             = false; // Q10 DEGRADED marker
datetime g_ag_last_logged_anchor   = 0;     // monotonic rollover-line latch (2.1)
bool     g_ag_rollover_seeded      = false; // latch seeded on the first ACTIVE pass, logging nothing
datetime g_ag_last_breach_alert    = 0;     // Q2 ALERT cadence, local clock
datetime g_ag_last_anchor_alert    = 0;     // Q8-amendment ALERT cadence, local clock
bool     g_ag_have_pnl_numbers     = false; // false until the first ACTIVE pass completes
bool     g_ag_resyncing            = false; // Q10 NEW RULING 2026-08-09: gates reconnect on AgHistoryStable
datetime g_ag_last_anchor          = 0;
double   g_ag_last_realized        = 0.0;
double   g_ag_last_floating        = 0.0;
double   g_ag_last_base            = 0.0;
double   g_ag_last_limit           = 0.0;
double   g_ag_last_pnl             = 0.0;

//--- Phase 2 Stage 3 (lock semantics). All in-memory, none persisted.
//--- QUOTE FRESHNESS, ruling THREE 2026-08-18. Measured as a purely local
//--- delta and never by clock arithmetic, so it cannot inherit the broker
//--- DST peg this ledger still has open until the October harvest. This is
//--- the A1/A3 clock class, a liveness measure and not an anchor decision,
//--- so TimeLocal is the correct source here exactly as it is for the
//--- proof-of-life interval.
//---
//--- IT NEVER GATES A DECISION. The stale quote ruling of 2026-08-18 is
//--- explicit that the mechanism may log but may never suppress, delay or
//--- gate a breach decision, and ruling THREE reads it only to SIZE the
//--- consequence after the decision has already been taken. The breach
//--- itself is declared from the frozen quote exactly as ruled.
datetime g_ag_last_server_seen     = 0;
datetime g_ag_last_tick_local      = 0;

//--- RATIFIED 2026-08-18, FINAL in DECISIONS of that date. Ruling THREE
//--- named the frozen-clock CONDITION as the trigger without naming a
//--- threshold, and this value closed that gap on its own ruling rather
//--- than by inheritance from the four-part proposal, whose threshold the
//--- stale quote ruling had declared MOOT in its role as a GATE. Grounds
//--- on the record: 120 s cannot false-fire on XAUUSD in an open session
//--- where ticks arrive many times a second, and it catches the measured
//--- 62-minute break within two LIFE lines. Compile-time constant and
//--- deliberately not an input, the AG_LIFE_INTERVAL and AG_MUTEX_STALE
//--- precedent: a value able to disable a guarantee is core or nowhere.
#define AG_QUOTE_FROZEN_SECONDS 120

//--- Q6 input-change-while-locked witness. The two limit inputs as they read
//--- at the moment of breach, held in memory only. NOT persisted: the state
//--- file is charter-constrained to lock state (Amendment 2a FINAL) and the
//--- snapshot it does carry is limit and base, which is what Q6 requires for
//--- judging the window. These two exist solely so a change can be NAMED in
//--- the WARN; enforcement never reads them.
double   g_ag_locked_in_percent    = 0.0;
double   g_ag_locked_in_currency   = 0.0;
datetime g_ag_last_inputchg_warn   = 0;   // cadence, local clock
//--- False until a lock is declared in THIS session's image. Without it, a
//--- Stage 4 boot that restores a lock from the file witness would compare
//--- live inputs against a default-constructed 0.0 and emit a change WARN
//--- that names a change nobody made. Stage 4 seeds the two values above
//--- from the live inputs at restore and sets this true.
bool     g_ag_lock_inputs_captured = false;

//--- Phase 2 Stage 6 (observability). EVERY GLOBAL BELOW IS WRITE-BY-THE-
//--- TIMER, READ-BY-THE-LOGGER, AND READ BY NOTHING ELSE. That is not a
//--- convention, it is the stage's own static acceptance row: question SIX
//--- ships these as logging that may never suppress, delay or gate a
//--- decision, and a grep proving no decision path reads them is what makes
//--- that checkable rather than asserted. They are deliberately kept
//--- separate from g_ag_degraded, which the Q10 gate sets and the numbers
//--- field reads, precisely so the two cannot be confused.
bool     g_ag_obs_connected        = true;    // TERMINAL_CONNECTED, sampled every tick
bool     g_ag_obs_resync_prev      = false;   // edge detector for the RESYNC lines

//+------------------------------------------------------------------+
//| Single arming point for the timer, return value checked and      |
//| logged. A timer that silently fails to arm freezes the mutex     |
//| heartbeat, and a frozen mutex heartbeat always reads stale,      |
//| which hands the mutex to every later instance. Never assume.     |
//+------------------------------------------------------------------+
void AgArmTimer()
  {
   g_timer_armed = EventSetTimer(g_timer_seconds);
   if(g_timer_armed)
      AgInfo("timer armed|period=" + (string)g_timer_seconds + "s");
   else
      AgAlertEvent("EventSetTimer FAILED (error " + (string)GetLastError()
                   + "), the guardian cannot run: no evaluation, no sweep, and a frozen mutex heartbeat");
  }

//+------------------------------------------------------------------+
//| ACTIVE governing numbers as a LIFE-line field group (A6, 4.5).   |
//| Empty until the first completed ACTIVE pass, or outside ACTIVE.  |
//| Prefixed DEGRADED| whenever g_ag_degraded holds (Q10 FINAL,      |
//| owner finding 2026-08-09): the numbers are last-known figures    |
//| from before a disconnect, and a reader of the numbers field      |
//| alone, without cross-referencing waiting_on, must not be able    |
//| to mistake them for a fresh, live evaluation.                    |
//+------------------------------------------------------------------+
string AgPnlNumbersString()
  {
   if(g_ag_state != AG_STATE_ACTIVE || !g_ag_have_pnl_numbers)
      return "";
   string prefix = g_ag_degraded ? "DEGRADED|" : "";
   return prefix + "anchor=" + TimeToString(g_ag_last_anchor, TIME_DATE | TIME_SECONDS)
        + "|realized=" + DoubleToString(g_ag_last_realized, 2)
        + "|floating=" + DoubleToString(g_ag_last_floating, 2)
        + "|base=" + DoubleToString(g_ag_last_base, 2)
        + "|limit=" + DoubleToString(g_ag_last_limit, 2)
        + "|pnl_vs_limit=" + DoubleToString(g_ag_last_pnl, 2) + " vs -" + DoubleToString(g_ag_last_limit, 2);
  }

//+------------------------------------------------------------------+
void AgRefreshBanner()
  {
   string pnl = "n/a (Phase 1, no ACTIVE pass has completed yet)";
   if(g_ag_state == AG_STATE_SAFE_HALT)
      pnl = "halted: " + g_ag_halt_reason + " (delete " + AgHaltPath() + " to resume)";
   else if(g_ag_state == AG_STATE_ACTIVE && g_ag_have_pnl_numbers)
      pnl = (g_ag_degraded ? "DEGRADED: " : "")
          + DoubleToString(g_ag_last_pnl, 2) + " vs -" + DoubleToString(g_ag_last_limit, 2);
   AgBanner(AgStateName(g_ag_state), AgLockReasonName(g_ag_lock_reason), g_ag_locked_until, pnl);
  }

//+------------------------------------------------------------------+
//| Is the server clock frozen right now? Ruling THREE's trigger.    |
//| Pure read of the local tick-age measure, no side effects, and it |
//| is never consulted before a breach decision, only after one.     |
//+------------------------------------------------------------------+
bool AgQuoteFrozen()
  {
   if(g_ag_last_tick_local == 0)
      return false;   // nothing observed yet this session: never claim frozen
   return (TimeLocal() - g_ag_last_tick_local) >= AG_QUOTE_FROZEN_SECONDS;
  }

//+------------------------------------------------------------------+
//| BOOT LOCK DERIVATION (Phase 2 Stage 4, design doc item 4, F4).   |
//| Three witnesses, OR'd, STRICTEST WINS.                           |
//|                                                                  |
//| The OR can only ADD a lock, never subtract one. There is no path |
//| here by which a witness UNLOCKS: unlock is exclusively the       |
//| TimeCurrent >= locked_until comparison in AgEvaluateLocked, and  |
//| an absence of derived evidence is never read as a conclusion     |
//| that no lock exists.                                             |
//|                                                                  |
//| Authority order, and why it is not the obvious one. Broker deal  |
//| history is the AUTHORITY because it is server-side and a local-  |
//| machine attacker cannot forge or delete it. The file and the GV  |
//| live entirely on this machine and are locally writable, so they  |
//| are witnesses and accelerators rather than authority: they exist |
//| so a lock is recognized instantly without a full replay, and so  |
//| recognition works even before history stability is established.  |
//|                                                                  |
//| Returns 0 = no lock, 1 = lock, 2 = NOT EVALUABLE. The third is   |
//| the F6 obligation and is why this is not a bool: a failed        |
//| HistorySelect must never be read as "no deals, therefore no      |
//| breach", so it blocks the SYNCING exit for another pass instead  |
//| of licensing an unlock.                                          |
//+------------------------------------------------------------------+
int AgBootDerivation(ENUM_AG_LOCK_REASON &reason_out, datetime &until_out)
  {
   reason_out = AG_LOCK_NONE;
   until_out  = 0;
   datetime now = AgServerNow();
   bool fired   = false;

   //--- WITNESS 1, the state file. AgStateLoad already ran in OnInit and has
   //--- already applied its own corruption policy, so by here the model is
   //--- either a clean load or the CORRUPT_STATE the quarantine branch wrote.
   //--- Fires on locked_until > now rather than on reason != NONE, so an
   //--- expired lock's stale record reads as not-locked with no rewrite.
   if(g_ag_state_reason != AG_LOCK_NONE && g_ag_state_locked_until > now)
     {
      datetime u = AgLockedUntilFromWitness(g_ag_state_locked_until);
      AgInfo("boot witness FILE fired|reason=" + AgLockReasonName(g_ag_state_reason)
             + "|raw=" + TimeToString(g_ag_state_locked_until, TIME_DATE | TIME_SECONDS)
             + "|bounded=" + TimeToString(u, TIME_DATE | TIME_SECONDS));
      fired      = true;
      until_out  = u;
      reason_out = g_ag_state_reason;
     }

   //--- WITNESS 2, the GV mirror. Bare timestamp, no reason, so DAILY_BREACH.
   double gv_raw = 0.0;
   if(GlobalVariableGet(AgGvLock(), gv_raw) && (datetime)(long)gv_raw > now)
     {
      datetime u = AgLockedUntilFromWitness((datetime)(long)gv_raw);
      AgInfo("boot witness GV fired|raw=" + TimeToString((datetime)(long)gv_raw, TIME_DATE | TIME_SECONDS)
             + "|bounded=" + TimeToString(u, TIME_DATE | TIME_SECONDS));
      if(!fired || u > until_out)   // strictest wins
        {
         until_out  = u;
         reason_out = AG_LOCK_DAILY_BREACH;
        }
      fired = true;
     }

   //--- WITNESS 3, derived from broker history. The authority.
   //--- Anchor is computed directly and NOT through the Q8 latch: the latch
   //--- is seeded on the first ACTIVE evaluation pass and moving that here
   //--- would change when Phase 1's seeding happens for no gain, while
   //--- AgLatchFloor correctly contributes nothing while unseeded.
   datetime anchor = AgDayAnchor(now);
   bool ok = true;
   double running_min = 0.0;
   double realized = AgRealizedFold(anchor, ok, running_min);
   if(!ok)
     {
      AgWarn("boot derivation NOT EVALUABLE: the replay's HistorySelect failed,"
             " which is never read as zero deals (F6); staying in SYNCING this pass");
      return 2;
     }
   double base = AgDayBase(anchor, ok);
   if(!ok)
     {
      AgWarn("boot derivation NOT EVALUABLE: the day-base read failed;"
             " staying in SYNCING this pass");
      return 2;
     }

   //--- Q6 as clarified 2026-07-30: a valid unexpired DAILY_BREACH snapshot
   //--- governs the comparison. With no snapshot to apply it to, the rule has
   //--- nothing to govern and the comparison falls back to the LIVE limit.
   //--- That fallback is what makes file plus GV deletion ALONE, inputs
   //--- untouched, fully defended by history: the live limit equals the
   //--- original when nothing was tampered with. Deletion COMBINED with input
   //--- inflation is the accepted residual and is not closed here.
   //--- THE CASCADE, three tiers in this order: snapshot, then floor, then
   //--- live. Tier 2 is the ratchet fold-in ratified 2026-08-18: with no
   //--- snapshot to apply, a valid SAME-DAY floor still tightens the
   //--- comparison, which is what stops file-plus-GV deletion from also
   //--- discarding the day's accumulated tightening. A floor from a prior day
   //--- is stale and AgFloorEffectiveLimit declines it.
   bool   have_snapshot = (g_ag_state_reason == AG_LOCK_DAILY_BREACH
                           && g_ag_state_locked_until > now
                           && g_ag_state_limit_snap > 0.0);
   double live_limit = AgLimitCurrency(base, DailyLossPercent, DailyLossCurrency);
   double limit_cmp;
   if(have_snapshot)
      limit_cmp = g_ag_state_limit_snap;                          // tier 1
   else
      limit_cmp = AgFloorEffectiveLimit(live_limit, anchor);      // tier 2, else tier 3

   double floating = AgFloating();
   bool disjunct_live   = (realized + floating <= -limit_cmp + AG_PNL_EPSILON);
   bool disjunct_replay = (running_min        <= -limit_cmp + AG_PNL_EPSILON);
   if(disjunct_live || disjunct_replay)
     {
      //--- A value the guardian computes for itself: floor only, no clamp.
      datetime u = AgApplyLatchFloor(AgNextDayAnchor(now));
      AgInfo("boot witness DERIVED fired|live=" + (disjunct_live ? "1" : "0")
             + "|replay=" + (disjunct_replay ? "1" : "0")
             + "|realized=" + DoubleToString(realized, 2)
             + "|floating=" + DoubleToString(floating, 2)
             + "|running_min=" + DoubleToString(running_min, 2)
             + "|limit_cmp=" + DoubleToString(limit_cmp, 2)
             + "|tier=" + (have_snapshot ? "snapshot"
                                          : (limit_cmp < live_limit ? "floor" : "live"))
             + "|bounded=" + TimeToString(u, TIME_DATE | TIME_SECONDS));
      if(!fired || u > until_out)   // strictest wins
        {
         until_out  = u;
         reason_out = AG_LOCK_DAILY_BREACH;
        }
      fired = true;
     }

   //--- STRICTEST WINS on the duration, and CORRUPT_STATE wins the reason
   //--- when the file witness reaches the same instant: it is the more
   //--- serious finding and it is the one that says the record cannot be
   //--- trusted, which a DAILY_BREACH label would hide.
   if(fired && g_ag_state_reason == AG_LOCK_CORRUPT_STATE
      && g_ag_state_locked_until > now
      && AgLockedUntilFromWitness(g_ag_state_locked_until) >= until_out)
      reason_out = AG_LOCK_CORRUPT_STATE;

   return fired ? 1 : 0;
  }

//+------------------------------------------------------------------+
//| Declare the lock. Q6 (FINAL): limit and base are snapshotted     |
//| here and the locked window is judged by that snapshot, never by  |
//| live inputs. Ruling TWO (FINAL 2026-08-18): the state machine    |
//| locks and NO ORDER IS SENT. Positions stay open until the owner  |
//| closes them by hand, the floating loss keeps moving, and that is |
//| sanctioned rather than a defect. Sweep, flatten and pending      |
//| deletion are Phase 3 and nothing here may reach for them.        |
//+------------------------------------------------------------------+
void AgDeclareLock(const datetime breach_time, const double limit, const double base,
                   const double pnl, const double realized, const double floating)
  {
   bool     frozen = AgQuoteFrozen();
   datetime until  = AgLockedUntilComputed(breach_time, frozen);

   g_ag_lock_reason      = AG_LOCK_DAILY_BREACH;
   g_ag_locked_until     = until;
   g_ag_locked_in_percent  = DailyLossPercent;
   g_ag_locked_in_currency = DailyLossCurrency;
   g_ag_lock_inputs_captured = true;

   AgStateSetBreach(until, breach_time, limit, base);
   if(!AgStateSave())
      AgAlertEvent("LOCK DECLARED BUT THE STATE FILE WAS NOT WRITTEN: the lock holds in memory"
                   " for this session and will not survive a restart from the file witness");

   AgInfo("breach arithmetic|realized=" + DoubleToString(realized, 2)
          + "|floating=" + DoubleToString(floating, 2) + "|base=" + DoubleToString(base, 2)
          + "|limit=" + DoubleToString(limit, 2) + "|pnl=" + DoubleToString(pnl, 2));
   AgInfo("lock bounds|breach_time=" + TimeToString(breach_time, TIME_DATE | TIME_SECONDS)
          + "|quote_frozen=" + (frozen ? "1" : "0")
          + "|latch_floor=" + TimeToString(AgNextDayAnchor(g_ag_high_anchor), TIME_DATE | TIME_SECONDS)
          + "|locked_until=" + TimeToString(until, TIME_DATE | TIME_SECONDS));

   AgTransition(AG_STATE_LOCKED, "DAILY_BREACH",
                "pnl=" + DoubleToString(pnl, 2) + "|limit=" + DoubleToString(limit, 2)
                + "|locked_until=" + TimeToString(until, TIME_DATE | TIME_SECONDS));
   AgAlertEvent("DAILY_BREACH: account LOCKED until "
                + TimeToString(until, TIME_DATE | TIME_SECONDS)
                + " (pnl=" + DoubleToString(pnl, 2) + " limit=" + DoubleToString(limit, 2)
                + "). Phase 2 locks the state machine and sends no order:"
                " open positions stay open until you close them by hand.");
   g_ag_dynamic_waiting_on = "";
  }

//+------------------------------------------------------------------+
//| Enter LOCKED from the boot derivation rather than from a breach  |
//| this session saw. Separate from AgDeclareLock because there is   |
//| no fresh computation behind it: the limit and base snapshots are |
//| whatever the file already held, and inventing new ones from live |
//| inputs would be exactly the substitution Q6 forbids.             |
//|                                                                  |
//| The bounded locked_until IS persisted, including when the lock   |
//| came from the derived witness with the file silent, so the next  |
//| boot recognizes it without a second full replay. That write is   |
//| legitimate under never-loaded-never-written because AgStateLoad  |
//| ran in OnInit.                                                   |
//+------------------------------------------------------------------+
void AgEnterLockFromBoot(const ENUM_AG_LOCK_REASON reason, const datetime until)
  {
   g_ag_lock_reason  = reason;
   g_ag_locked_until = until;

   //--- Seed the Q6 input witness from the live inputs, per the note the
   //--- Stage 3 entry left for this stage: without it the first LOCKED pass
   //--- would compare live inputs against a default-constructed 0.0 and warn
   //--- about a change nobody made.
   g_ag_locked_in_percent    = DailyLossPercent;
   g_ag_locked_in_currency   = DailyLossCurrency;
   g_ag_lock_inputs_captured = true;

   if(reason == AG_LOCK_CORRUPT_STATE)
      AgStateSetCorrupt(until);
   else
      AgStateSetBreach(until, g_ag_state_breach_time, g_ag_state_limit_snap, g_ag_state_base_snap);
   if(!AgStateSave())
      AgWarn("boot-derived lock was NOT persisted; it holds in memory for this session");

   AgTransition(AG_STATE_LOCKED, "boot derivation: " + AgLockReasonName(reason),
                "locked_until=" + TimeToString(until, TIME_DATE | TIME_SECONDS));
   AgAlertEvent("LOCKED at boot by derivation (" + AgLockReasonName(reason) + ") until "
                + TimeToString(until, TIME_DATE | TIME_SECONDS)
                + ". Phase 2 locks the state machine and sends no order:"
                " open positions stay open until you close them by hand.");
   g_ag_dynamic_waiting_on = "";
  }

//+------------------------------------------------------------------+
//| LOCKED-state dispatch. EXPIRY IS THE ONLY UNLOCK PATH and the    |
//| comparison is TimeCurrent >= locked_until, per Q7 (FINAL) which  |
//| makes TimeCurrent the only permitted clock in an expiry          |
//| decision. Nothing else here may leave LOCKED: no input, no       |
//| absence of evidence, no reconnect, no operator convenience.      |
//|                                                                  |
//| A frozen or backward-stepping clock therefore DELAYS an unlock,  |
//| which errs locked and needs no special case. The Friday breach   |
//| that outlives its computed expiry by about 48 hours across the   |
//| weekend freeze is that behaviour working, not a defect.          |
//+------------------------------------------------------------------+
void AgEvaluateLocked()
  {
   //--- Q6: an input change while locked is logged loudly. The snapshot
   //--- still governs and nothing about enforcement moves; this is a
   //--- witness, not a control path.
   if(g_ag_lock_inputs_captured
      && (DailyLossPercent != g_ag_locked_in_percent || DailyLossCurrency != g_ag_locked_in_currency))
     {
      datetime now_local = TimeLocal();
      if(g_ag_last_inputchg_warn == 0
         || now_local - g_ag_last_inputchg_warn >= AG_LIFE_INTERVAL_SECONDS)
        {
         AgWarn("input changed while LOCKED and is being IGNORED (Q6): percent "
                + DoubleToString(g_ag_locked_in_percent, 2) + "->" + DoubleToString(DailyLossPercent, 2)
                + ", currency " + DoubleToString(g_ag_locked_in_currency, 2) + "->"
                + DoubleToString(DailyLossCurrency, 2)
                + "; the locked window is judged by the breach snapshot limit="
                + DoubleToString(g_ag_state_limit_snap, 2) + " base="
                + DoubleToString(g_ag_state_base_snap, 2));
         g_ag_last_inputchg_warn = now_local;
        }
     }

   datetime now_server = AgServerNow();
   if(now_server >= g_ag_locked_until)
     {
      AgInfo("lock expired|locked_until=" + TimeToString(g_ag_locked_until, TIME_DATE | TIME_SECONDS)
             + "|server=" + TimeToString(now_server, TIME_DATE | TIME_SECONDS));
      g_ag_lock_reason  = AG_LOCK_NONE;
      g_ag_locked_until = 0;
      AgStateResetModel();
      if(!AgStateSave())
         AgWarn("lock expiry was NOT persisted: the state file still names the expired lock,"
                " which is self-correcting on read since a past locked_until reads as not-locked");
      //--- Re-entering ACTIVE re-derives everything from history; nothing is
      //--- carried across the boundary. The Q9 baseline is deliberately reset
      //--- so the first ACTIVE pass cannot inherit a stale deal count.
      g_ag_last_deal_count      = -1;
      g_ag_breach_deferred_once = false;
      AgTransition(AG_STATE_ACTIVE, "lock expired", "");
      g_ag_dynamic_waiting_on = "";
     }
  }

//+------------------------------------------------------------------+
//| OBSERVABILITY (Phase 2 Stage 6, question SIX FINAL 2026-08-18).  |
//| EVERYTHING BELOW IS LOGGING. It gates nothing, suppresses        |
//| nothing and delays nothing, which is the ruling's own wording    |
//| and is the property the stage's static acceptance row checks by  |
//| grepping that no decision path reads any global declared for it. |
//+------------------------------------------------------------------+

//--- Is the guarded symbol's QUOTE session open right now? This is the
//--- market-closed distinction the four-part proposal called part two, and
//--- it is the difference between a marker that means something and one that
//--- fires every weekend and every nightly break until nobody reads it.
//--- Reads SymbolInfoSessionQuote, never clock arithmetic against a peg this
//--- project has not yet measured. If the symbol reports no quote session at
//--- all the answer is OPEN, never closed: claiming "market closed" without
//--- evidence would explain away a genuinely frozen feed.
bool AgQuoteSessionOpen()
  {
   MqlDateTime dt;
   TimeToStruct(AgServerNow(), dt);
   ENUM_DAY_OF_WEEK dow = (ENUM_DAY_OF_WEEK)dt.day_of_week;
   int now_sec = dt.hour * 3600 + dt.min * 60 + dt.sec;
   datetime from = 0, to = 0;
   bool any_session = false;
   for(int i = 0; i < 8; i++)
     {
      if(!SymbolInfoSessionQuote(_Symbol, dow, i, from, to))
         break;
      any_session = true;
      if(now_sec >= (int)from && now_sec < (int)to)
         return true;
     }
   return !any_session;
  }

//--- The note appended to the LIFE line's waiting_on field. Empty when there
//--- is nothing to say, which is the normal case.
string AgObservabilityNote()
  {
   if(!g_ag_obs_connected)
      return "DEGRADED: disconnected";
   if(g_ag_last_tick_local == 0)
      return "";
   int age = (int)(TimeLocal() - g_ag_last_tick_local);
   if(age < AG_QUOTE_FROZEN_SECONDS)
      return "";
   //--- Frozen while the session is OPEN is the condition worth naming. The
   //--- same freeze while the session is closed is expected and correct, and
   //--- gets a distinct non-DEGRADED note so the artifact still records it
   //--- without claiming a fault.
   return AgQuoteSessionOpen() ? ("quote_age=" + (string)age + "s") : "market closed";
  }

//+------------------------------------------------------------------+
//| ACTIVE-state evaluation (A6, 4.4), run in this exact order:      |
//| Q10 connection check, Q10 reconnect-coherence RESYNC gate (2026- |
//| 08-09 owner ruling), Q8 anchor sanity, the computation itself,   |
//| Q9 coherence deferral, then the Q2 interim breach posture.       |
//| Sets g_ag_dynamic_waiting_on for the NEXT proof-of-life line     |
//| (AgProofOfLife runs before this dispatch each tick, so every     |
//| field here lags the pass that computed it by one tick, same as   |
//| the rest of the proof-of-life contract).                        |
//+------------------------------------------------------------------+
void AgEvaluateActive()
  {
   //--- Q10: DEGRADED, no breach decisions from a frozen quote -----------
   if(!(bool)TerminalInfoInteger(TERMINAL_CONNECTED))
     {
      g_ag_degraded          = true;
      g_ag_resyncing         = true;   // Q10 NEW RULING 2026-08-09: reconnect must resync
      g_ag_dynamic_waiting_on = "DEGRADED: disconnected, no breach decisions";
      return;
     }
   //--- g_ag_degraded is cleared further below, only once this pass's
   //--- computation actually succeeds (owner finding 2026-08-09): clearing
   //--- it here, on entry, let a HistorySelect failure on the reconnect
   //--- pass show a non-degraded banner over stale numbers.

   //--- Q10 NEW RULING 2026-08-09, reconnect coherence: the first connected
   //--- pass after a disconnect is exactly the condition the SYNCING
   //--- stability counter exists for, so it is reused rather than resuming
   //--- evaluation on the very next tick. No state transition (stays
   //--- ACTIVE); the LIFE line shows the live poll count, prefixed RESYNC
   //--- to read distinctly from initial SYNCING. Numbers stay DEGRADED and
   //--- last-known throughout, since g_ag_degraded has not cleared yet.
   if(g_ag_resyncing)
     {
      if(!AgHistoryStable(HistoryStablePolls))
        {
         g_ag_dynamic_waiting_on = "RESYNC: polls=" + (string)g_ag_stable_polls
                                    + "/" + (string)HistoryStablePolls;
         return;
        }
      g_ag_resyncing = false;
     }

   //--- Q8 (AMENDED 2026-08-09, alert-and-advance): anchor high-water-mark
   //--- sanity check. The pass is NEVER halted. An anomalous forward jump is
   //--- announced loudly and then accepted, so evaluation continues and the
   //--- condition clears itself on this same pass. The original halt could
   //--- not self-clear against a forward-only clock and stalled evaluation
   //--- permanently at every weekend reopen, which is fail-open.
   datetime fresh_anchor   = AgDayAnchor(AgServerNow());
   datetime window_anchor  = AgAnchorSanityCheck(fresh_anchor);
   g_ag_dynamic_waiting_on = g_ag_anchor_jump_note;
   if(g_ag_anchor_jump_note != "")
     {
      //--- journal line every occurrence, popup capped: the same split the
      //--- Q2 interim breach posture already uses below.
      AgInfo(g_ag_anchor_jump_note);
      datetime now_local_anchor = TimeLocal();
      if(g_ag_last_anchor_alert == 0
         || now_local_anchor - g_ag_last_anchor_alert >= AG_LIFE_INTERVAL_SECONDS)
        {
         AgAlertEvent(g_ag_anchor_jump_note
                      + " (jump exceeds one day; evaluation continues, Q8 amendment 2026-08-09)");
         g_ag_last_anchor_alert = now_local_anchor;
        }
     }

   //--- day-rollover journal line, monotonic latch (2.1): fires only when
   //--- the anchor actually advances, never on a backward step. Seeded on
   //--- the first ACTIVE pass WITHOUT logging, so a session start no longer
   //--- reports a rollover that never happened with a jump measured from
   //--- the epoch (owner finding 2026-08-09).
   if(!g_ag_rollover_seeded)
     {
      g_ag_rollover_seeded    = true;
      g_ag_last_logged_anchor = window_anchor;
     }
   else if(window_anchor > g_ag_last_logged_anchor)
     {
      AgInfo("day rollover|old_anchor=" + TimeToString(g_ag_last_logged_anchor, TIME_DATE | TIME_SECONDS)
             + "|new_anchor=" + TimeToString(window_anchor, TIME_DATE | TIME_SECONDS)
             + "|jump=" + (string)(long)(window_anchor - g_ag_last_logged_anchor) + "s");
      g_ag_last_logged_anchor = window_anchor;
     }

   //--- the computation itself --------------------------------------------
   bool ok = true;
   double realized = AgRealized(window_anchor, ok);
   if(!ok)
      return;   // loud WARN already logged inside AgRealized (F6)
   double base = AgDayBase(window_anchor, ok);
   if(!ok)
      return;   // loud WARN already logged inside AgDayBase/AgDealsSumAll
   double floating = AgFloating();
   double limit     = AgLimitCurrency(base, DailyLossPercent, DailyLossCurrency);
   double pnl       = realized + floating;

   g_ag_last_anchor      = window_anchor;
   g_ag_last_realized    = realized;
   g_ag_last_floating    = floating;
   g_ag_last_base        = base;
   g_ag_last_limit       = limit;
   g_ag_last_pnl         = pnl;
   g_ag_have_pnl_numbers = true;
   g_ag_degraded         = false;   // cleared here, not on entry: see the note above

   //--- Q9: coherence-deferral, then the Q2 interim breach posture -------
   //--- PHASE 2 STAGE 5: the ratchet runs here, at the top of the breach
   //--- tail, and returns the limit this pass enforces. Placed here and not
   //--- with the computation above for two reasons: min(limit, floor) is
   //--- ratified as PRE-BREACH ONLY, so its only legitimate consumer is the
   //--- comparison directly below, and the region above the breach tail is
   //--- required to stay byte identical across Phase 2.
   double enforced_limit = AgRatchetUpdate(window_anchor, limit, AG_LIFE_INTERVAL_SECONDS);
   long current_count = HistoryDealsTotal();
   bool breach_now = (pnl <= -enforced_limit + AG_PNL_EPSILON);
   if(breach_now)
     {
      if(current_count == g_ag_last_deal_count && !g_ag_breach_deferred_once)
        {
         AgWarn("breach deferred one pass: no new deal visible, count=" + (string)current_count);
         g_ag_breach_deferred_once = true;
        }
      else
        {
         //--- PHASE 2 STAGE 3 replaces the Q2 interim posture here. Phase 1
         //--- shouted and stayed ACTIVE because it had no lock to take; this
         //--- build takes the lock. The Q9 deferral above is untouched and
         //--- still bounds the delay at exactly one pass.
         //--- The breach time is TimeCurrent, per Q7 (FINAL): it feeds
         //--- AgNextDayAnchor and no other clock may reach an anchor
         //--- decision. It is read once here so every bound below and the
         //--- persisted breach_time all refer to the same instant.
         g_ag_breach_deferred_once = false;
         g_ag_last_deal_count      = current_count;
         //--- The snapshot is the ENFORCED limit, not the raw live one. The
         //--- floor is what ACTIVE enforced up to this instant, so Q6's
         //--- snapshot is automatically the floor at the moment of breach and
         //--- needs no extra obligation; snapshotting the live value instead
         //--- would silently loosen the locked window by exactly the amount
         //--- the ratchet had been holding back.
         AgDeclareLock(AgServerNow(), enforced_limit, base, pnl, realized, floating);
         return;   // LOCKED from this pass on; nothing further is ACTIVE work
        }
     }
   else
      g_ag_breach_deferred_once = false;
   g_ag_last_deal_count = current_count;
  }

//+------------------------------------------------------------------+
//| Visible refusal (Q4, owner ruling 2026-08-03). Sets the refusal  |
//| flag and draws the dated REFUSED banner before every refusal     |
//| return in OnInit, both paths. OnDeinit skips the banner clear    |
//| while the flag is set, so the refusal stays on the chart as a    |
//| dated event record, not an apparent live state, until the next   |
//| attach on that chart or the terminal restart.                    |
//+------------------------------------------------------------------+
int AgRefuseInit(const int retcode, const string reason)
  {
   g_init_refused = true;
   AgBanner("REFUSED " + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS)
            + " (local " + TimeToString(TimeLocal(), TIME_DATE | TIME_SECONDS) + ")",
            reason, 0, "n/a (init refused)");
   return retcode;
  }

//+------------------------------------------------------------------+
//| Enter SAFE_HALT. Not a lock: closes nothing, sweeps nothing,     |
//| excluded from expiry, manual restart only (charter, A1).         |
//+------------------------------------------------------------------+
void AgEnterSafeHalt(const string reason)
  {
   AgHaltSetFlag(reason);
   if(!AgHaltSave())
      AgAlertEvent("SAFE_HALT could not be persisted, halt holds in memory only for this session");
   GlobalVariableSet(AgGvHaltFlag(), 1.0);
   GlobalVariablesFlush();
   AgTransition(AG_STATE_SAFE_HALT, reason, "closes=nothing|resume=manual delete of " + AgHaltPath());
   AgAlertEvent("SAFE_HALT: " + reason + ". Guardian is NOT protecting the account. "
                + "Delete " + AgHaltPath() + " while the EA is stopped, then restart.");
   AgRefreshBanner();
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   g_ag_verbosity = LogVerbosity;
   g_ag_login     = AccountInfoInteger(ACCOUNT_LOGIN);
   AgInfo("init|build=Phase2|account=" + (string)g_ag_login + "|server=" + AccountInfoString(ACCOUNT_SERVER));

   //--- core config validation (Q4): refuse to run, visibly
   string why = "";
   if(!AgValidateLimits(DailyLossPercent, DailyLossCurrency, why))
     {
      AgAlertEvent("refusing to run, core config invalid: " + why);
      return AgRefuseInit(INIT_PARAMETERS_INCORRECT, "core config invalid: " + why);
     }
   if(CrashLoopMaxInits < 1)
     {
      AgAlertEvent("refusing to run, core config invalid: CrashLoopMaxInits must be at least 1");
      return AgRefuseInit(INIT_PARAMETERS_INCORRECT, "core config invalid: CrashLoopMaxInits must be at least 1");
     }
   if(CrashLoopWindowSeconds < 1)
     {
      AgAlertEvent("refusing to run, core config invalid: CrashLoopWindowSeconds must be at least 1");
      return AgRefuseInit(INIT_PARAMETERS_INCORRECT, "core config invalid: CrashLoopWindowSeconds must be at least 1");
     }
   if(SweepPeriodSeconds < 1 || SweepPeriodSeconds > 5)
     {
      AgAlertEvent("refusing to run, core config invalid: SweepPeriodSeconds out of range 1..5 ("
                   + (string)SweepPeriodSeconds + ")");
      return AgRefuseInit(INIT_PARAMETERS_INCORRECT, "core config invalid: SweepPeriodSeconds out of range 1..5");
     }
   if(HistoryStablePolls < 1)
     {
      AgAlertEvent("refusing to run, core config invalid: HistoryStablePolls must be at least 1");
      return AgRefuseInit(INIT_PARAMETERS_INCORRECT, "core config invalid: HistoryStablePolls must be at least 1");
     }
   g_timer_seconds = SweepPeriodSeconds;

   //--- optional config class: off plus WARN, never half-enforced
   g_weekly_enabled = WeeklyReportEnabled;
   if(LogVerbosity != AG_LOG_NORMAL && LogVerbosity != AG_LOG_VERBOSE)
     {
      g_ag_verbosity = AG_LOG_NORMAL;
      AgWarn("optional config invalid: LogVerbosity unrecognised, falling back to NORMAL");
     }

   //--- single instance (F8): live holder refuses, stale one is taken over
   if(!AgMutexAcquire())
     {
      AgAlertEvent("refusing to run: another AccountGuardian instance is live on account "
                   + (string)g_ag_login);
      return AgRefuseInit(INIT_FAILED, "duplicate instance: another instance holds the mutex");
     }
   g_owns_mutex = true;

   //--- crash-loop evidence, persisted across process death (A1)
   int load_result = AgHaltLoad();
   if(load_result == 1)
      AgVerbose("no halt file, first session on this account");

   //--- Lock state file. The load is required before any write can be
   //--- legitimate: the FINAL never-loaded-never-written rule names this file
   //--- explicitly and AgStateSave refuses while g_ag_state_loaded is false.
   //--- What the file SAYS is acted on at the SYNCING exit, by the boot
   //--- derivation, which ORs this file witness with the GV witness and the
   //--- derived-history witness. It is deliberately not acted on here: a lock
   //--- conclusion belongs after history stability, not during OnInit.
   int state_result = AgStateLoad();
   if(state_result == 0)
      AgInfo("lock state file loaded|reason=" + AgLockReasonName(g_ag_state_reason)
             + "|locked_until=" + TimeToString(g_ag_state_locked_until, TIME_DATE | TIME_SECONDS)
             + "|weighed by the boot derivation at the SYNCING exit");
   else if(state_result == 1)
      AgVerbose("no lock state file, first session on this account");
   else
      AgWarn("lock state file was quarantined at load (code " + (string)state_result
             + "); a fresh CORRUPT_STATE file was written and the boot derivation"
             " will weigh it at the SYNCING exit");

   //--- Ratchet floor (Phase 2 Stage 5). Loaded for the same reason the state
   //--- file is: AgFloorSave refuses while g_ag_floor_loaded is false, so
   //--- without this the floor could never be persisted. A floor from a prior
   //--- day loads cleanly and is simply stale, which AgFloorEffectiveLimit
   //--- declines and the first completed pass of the new day reseeds.
   int floor_result = AgFloorLoad();
   if(floor_result == 0)
      AgInfo("ratchet floor loaded|anchor="
             + TimeToString(g_ag_floor_anchor, TIME_DATE | TIME_SECONDS)
             + "|floor=" + DoubleToString(g_ag_floor_currency, 2));
   else if(floor_result == 1)
      AgVerbose("no ratchet floor file, first session on this account");
   else
      AgWarn("ratchet floor file was quarantined at load (code " + (string)floor_result
             + "); it reseeds from the live limit on the next completed pass"
             " and no lock follows, the floor not being lock state");

   double gv_halt = 0.0;
   bool   was_halted_before = (GlobalVariableGet(AgGvHaltFlag(), gv_halt) && gv_halt > 0.5);
   if(was_halted_before && !g_ag_halt_flag)
     {
      g_resumed_from_halt = true;
      GlobalVariableSet(AgGvHaltFlag(), 0.0);
      GlobalVariablesFlush();
      AgInfo("RESUMED_FROM_SAFE_HALT|halt file removed by hand, documented manual resume procedure");
     }

   if(g_ag_halt_flag)
     {
      AgHaltAppendSession();
      AgHaltSave();
      AgTransition(AG_STATE_SAFE_HALT, "halt flag persisted from an earlier session",
                   "reason=" + g_ag_halt_reason + "|since=" + TimeToString(g_ag_halt_time, TIME_DATE | TIME_SECONDS));
      AgAlertEvent("SAFE_HALT persists across restart: " + g_ag_halt_reason
                   + ". Delete " + AgHaltPath() + " while the EA is stopped, then restart.");
      AgRefreshBanner();
      AgArmTimer();
      return INIT_SUCCEEDED;
     }

   AgHaltAppendSession();
   int chain = AgHaltUncleanChain(CrashLoopWindowSeconds);
   if(!AgHaltSave())
      AgAlertEvent("halt file could not be written, crash-loop evidence is not durable this session");

   if(chain > CrashLoopMaxInits)
     {
      AgEnterSafeHalt("crash loop: " + (string)chain + " consecutive unclean sessions, adjacent inits within "
                      + (string)CrashLoopWindowSeconds + "s, limit " + (string)CrashLoopMaxInits);
      AgArmTimer();
      return INIT_SUCCEEDED;
     }
   AgVerbose("crash-loop check|chain=" + (string)chain + "/" + (string)CrashLoopMaxInits
             + " consecutive unclean, gap bound " + (string)CrashLoopWindowSeconds + "s");

   AgTransition(AG_STATE_SYNCING, "boot", "weekly=" + (g_weekly_enabled ? "on" : "off")
                + "|timer=" + (string)g_timer_seconds + "s");
   AgRefreshBanner();
   AgArmTimer();
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| All logic runs here (F13 FINAL). Phase 0 carries the spine only. |
//+------------------------------------------------------------------+
void OnTimer()
  {
   g_timer_ticks++;

   //--- first, unconditionally, in every state: the mutex heartbeat.
   //--- Nothing downstream may gate it. Guardian liveness is not a
   //--- function of history sync, PnL, or lock state.
   if(g_owns_mutex)
      AgMutexRefresh();

   //--- Quote-freshness measure (Phase 2 Stage 3, ruling THREE 2026-08-18).
   //--- Deliberately here rather than inside AgEvaluateActive, for two
   //--- reasons. It must keep measuring in EVERY state, including LOCKED,
   //--- since ruling THREE reads it at a breach that may follow any state
   //--- history. And AgEvaluateActive's pre-breach-tail region is required
   //--- to stay byte-identical across this stage, which a tracker inserted
   //--- there would have broken for no gain.
   //--- Purely local delta, never clock arithmetic, so it inherits nothing
   //--- from the unmeasured broker DST peg. Records only; gates nothing.
   datetime server_now_tick = AgServerNow();
   if(server_now_tick != g_ag_last_server_seen)
     {
      g_ag_last_server_seen = server_now_tick;
      g_ag_last_tick_local  = TimeLocal();   // A1/A3 clock class: a liveness measure
     }

   //--- GV lock mirror (Phase 2 Stage 4, design doc item 4). Rewritten from
   //--- the authoritative in-memory lock state every tick, unconditionally,
   //--- mirroring the mutex-heartbeat pattern directly above. That is what
   //--- makes it SELF-HEALING against live tampering: a GV cleared through
   //--- the terminal's Global Variables window while the EA is alive is
   //--- restored within one tick, so no separate re-derivation is needed.
   //--- The state FILE is deliberately not rewritten per tick; it is written
   //--- at breach, at expiry and at corruption handling only, matching the
   //--- halt file's event-triggered pattern. Deleting the file while the EA
   //--- is alive and LOCKED changes nothing, since enforcement runs from
   //--- memory and restart recovery is what the boot derivation covers.
   if(g_owns_mutex)
     {
      GlobalVariableSet(AgGvLock(), (double)(long)g_ag_locked_until);
      GlobalVariablesFlush();
     }

   //--- second, in every state including SYNCING and SAFE_HALT:
   //--- proof of life (SPEC A3). A stuck guardian and a healthy one
   //--- must never look identical from outside. Renders last-known
   //--- state, waiting_on, and PnL numbers, i.e. this pass's own
   //--- dispatch below is what the NEXT proof-of-life line reflects.
   //--- Stage 6: sample the connection every tick, in every state. ACTIVE
   //--- already carries Q10's DEGRADED marker from inside the evaluation; the
   //--- gap this closes is SYNCING and LOCKED, where seven lines emitted
   //--- entirely offline on 2026-08-14 were indistinguishable from healthy
   //--- ones to any reader.
   g_ag_obs_connected = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);

   string waiting_on = AgWaitingOn();
   string obs_note   = AgObservabilityNote();
   if(obs_note != "")
     {
      bool is_degraded_note = (StringFind(obs_note, "DEGRADED") == 0);
      if(!is_degraded_note || g_ag_state == AG_STATE_SYNCING || g_ag_state == AG_STATE_LOCKED)
         waiting_on = (waiting_on == "") ? obs_note : (waiting_on + "|" + obs_note);
     }
   AgProofOfLife(AgStateName(g_ag_state), AgSecondsInState(), waiting_on,
                 AG_LIFE_INTERVAL_SECONDS, AgPnlNumbersString());
   AgRefreshBanner();

   if(g_ag_state == AG_STATE_SAFE_HALT)
      return;   // closes nothing, sweeps nothing, no expiry: daily PnL logic never runs here

   //--- per-state dispatch (A6, 4.4). LOCKED is an explicit empty case so
   //--- Phase 2 adds expiry and witness code without touching this branch.
   if(g_ag_state == AG_STATE_SYNCING)
     {
      if(AgHistoryStable(HistoryStablePolls))
        {
         //--- Phase 2 Stage 4: boot lock derivation at the SYNCING exit.
         //--- The transition table's own structure is what guarantees a
         //--- "no breach found" conclusion can never be acted on before
         //--- stability: leaving SYNCING requires BOTH stability and no
         //--- witness firing, so an unevaluable pass simply is not yet
         //--- eligible to leave rather than being licensed to unlock.
         ENUM_AG_LOCK_REASON boot_reason = AG_LOCK_NONE;
         datetime            boot_until  = 0;
         int derived = AgBootDerivation(boot_reason, boot_until);
         if(derived == 2)
           {
            g_ag_dynamic_waiting_on = "boot derivation not evaluable, retrying";
           }
         else if(derived == 1)
           {
            AgEnterLockFromBoot(boot_reason, boot_until);
           }
         else
           {
            AgTransition(AG_STATE_ACTIVE, "history stable",
                         "polls=" + (string)g_ag_stable_polls + "/" + (string)HistoryStablePolls);
            g_ag_dynamic_waiting_on = "";
           }
        }
      else
         g_ag_dynamic_waiting_on = "polls=" + (string)g_ag_stable_polls + "/" + (string)HistoryStablePolls;
     }
   else if(g_ag_state == AG_STATE_ACTIVE)
      AgEvaluateActive();
   else if(g_ag_state == AG_STATE_LOCKED)
      AgEvaluateLocked();   // Phase 2 Stage 3: expiry only. Stage 4 adds witness reconciliation.

   //--- Stage 6: RESYNC entry and exit lines, edge-triggered on the flag the
   //--- Q10 reconnect-coherence gate already maintains. Placed AFTER the
   //--- dispatch so both edges are seen on the tick they happen, and written
   //--- as an observer of that flag rather than inside the gate itself, which
   //--- keeps the evaluation path untouched.
   //--- This is the answer to a measured blindness rather than a nicety: the
   //--- RESYNC window is about three seconds at a one-second timer while LIFE
   //--- lines are thirty seconds apart, so five live disconnects produced zero
   //--- RESYNC observations and the row could only ever close by luck. An
   //--- event line is not sampled and does not depend on that coincidence.
   if(g_ag_resyncing != g_ag_obs_resync_prev)
     {
      if(g_ag_resyncing)
         AgInfo("RESYNC entered|reconnect coherence gate armed, evaluation waits for"
                " history stability before the first post-disconnect breach decision");
      else
         AgInfo("RESYNC exited|history stable again, evaluation resumes");
      g_ag_obs_resync_prev = g_ag_resyncing;
     }

   // Phase 3 adds: sweep acceleration on OnTradeTransaction.
  }

//+------------------------------------------------------------------+
//| Acceleration only; correctness never depends on it (F13 FINAL).  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   // Phase 3: trigger an immediate sweep pass while LOCKED.
  }

//+------------------------------------------------------------------+
//| OnTick is unused by design (F13 FINAL).                          |
//+------------------------------------------------------------------+
void OnTick() { }

//+------------------------------------------------------------------+
//| Clean exit marks the session clean, so routine re-inits never    |
//| accumulate toward SAFE_HALT (A1). Never touches lock state.      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   //--- A model that was never loaded is never written. OnDeinit also runs
   //--- after a refused OnInit (reason 8), where the halt model is still
   //--- default-constructed empty; saving it there wiped every session
   //--- record and cleared a persisted halt flag, which the GV mirror then
   //--- read back as a human deletion. The skip is logged, never silent.
   if(g_ag_halt_loaded)
     {
      AgHaltMarkClean();
      AgHaltSave();
     }
   else
      AgInfo("deinit|halt file NOT written: the halt model was never loaded this session"
             + " (init refused before AgHaltLoad), so writing it would erase the session"
             + " history and any persisted halt flag");
   if(g_owns_mutex)
      AgMutexRelease();
   AgInfo("deinit|reason=" + (string)reason + "|session marked clean"
          + "|timer_armed=" + (g_timer_armed ? "1" : "0")
          + "|timer_ticks=" + (string)g_timer_ticks);
   //--- Visible refusal (owner ruling 2026-08-03): a refused init leaves its
   //--- dated REFUSED banner on the chart. The gate keys on the dedicated
   //--- refusal flag, never on a proxy like g_ag_halt_loaded, whose semantic
   //--- is model-loaded, not init-refused. The skip is logged, never silent.
   if(g_init_refused)
      AgInfo("deinit|banner NOT cleared: init was refused, dated REFUSED banner stays on the chart");
   else
      AgBannerClear();
  }
