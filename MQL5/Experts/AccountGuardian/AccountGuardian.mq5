//+------------------------------------------------------------------+
//| AccountGuardian.mq5                                              |
//| Account-level lockout EA. Event wiring only (SPEC v0.1 sec 1).   |
//| Phase 0 skeleton: no trading calls anywhere in the build.        |
//+------------------------------------------------------------------+
#property copyright "AccountGuardian"
#property version   "1.00"
#property strict
#property description "Account-level lockout guardian. Phase 0 skeleton, no trading calls."

#include <AccountGuardian/Log.mqh>
#include <AccountGuardian/Clock.mqh>
#include <AccountGuardian/State.mqh>
#include <AccountGuardian/Persist.mqh>
#include <AccountGuardian/Pnl.mqh>
#include <AccountGuardian/Sweep.mqh>

//--- core config class: malformed means the EA refuses to run (Q4)
input double                 DailyLossPercent       = 5.0;   // Daily loss limit, percent of day-anchor base (0 = off)
input double                 DailyLossCurrency      = 0.0;   // Daily loss limit, account currency (0 = off)
input int                    SweepPeriodSeconds     = 1;     // Timer period, clamped 1..5
input int                    CrashLoopMaxInits      = 3;     // Unclean sessions tolerated inside the window
input int                    CrashLoopWindowSeconds = 60;    // Crash-loop detection window
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
void AgRefreshBanner()
  {
   string pnl = "n/a (Phase 0, PnL engine lands in Phase 1)";
   if(g_ag_state == AG_STATE_SAFE_HALT)
      pnl = "halted: " + g_ag_halt_reason + " (delete " + AgHaltPath() + " to resume)";
   AgBanner(AgStateName(g_ag_state), AgLockReasonName(g_ag_lock_reason), g_ag_locked_until, pnl);
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
   AgInfo("init|build=Phase0|account=" + (string)g_ag_login + "|server=" + AccountInfoString(ACCOUNT_SERVER));

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
   int unclean = AgHaltUncleanCount(CrashLoopWindowSeconds);
   if(!AgHaltSave())
      AgAlertEvent("halt file could not be written, crash-loop evidence is not durable this session");

   if(unclean > CrashLoopMaxInits)
     {
      AgEnterSafeHalt("crash loop: " + (string)unclean + " unclean sessions inside "
                      + (string)CrashLoopWindowSeconds + "s, limit " + (string)CrashLoopMaxInits);
      AgArmTimer();
      return INIT_SUCCEEDED;
     }
   AgVerbose("crash-loop check|unclean=" + (string)unclean + "/" + (string)CrashLoopMaxInits
             + " inside " + (string)CrashLoopWindowSeconds + "s");

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

   //--- second, in every state including SYNCING and SAFE_HALT:
   //--- proof of life (SPEC A3). A stuck guardian and a healthy one
   //--- must never look identical from outside.
   AgProofOfLife(AgStateName(g_ag_state), AgSecondsInState(), AgWaitingOn(), AG_LIFE_INTERVAL_SECONDS);
   AgRefreshBanner();

   if(g_ag_state == AG_STATE_SAFE_HALT)
      return;   // closes nothing, sweeps nothing, no expiry

   // Phase 1 adds: SYNCING exit condition, PnL evaluation, breach check.
   // Phase 2 adds: lock persistence and expiry. Phase 3 adds: sweep.
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
