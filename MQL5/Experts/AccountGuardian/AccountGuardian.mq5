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

//+------------------------------------------------------------------+
void AgRefreshBanner()
  {
   string pnl = "n/a (Phase 0, PnL engine lands in Phase 1)";
   if(g_ag_state == AG_STATE_SAFE_HALT)
      pnl = "halted: " + g_ag_halt_reason + " (delete " + AgHaltPath() + " to resume)";
   AgBanner(AgStateName(g_ag_state), AgLockReasonName(g_ag_lock_reason), g_ag_locked_until, pnl);
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
      return INIT_PARAMETERS_INCORRECT;
     }
   if(CrashLoopMaxInits < 1)
     {
      AgAlertEvent("refusing to run, core config invalid: CrashLoopMaxInits must be at least 1");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(CrashLoopWindowSeconds < 1)
     {
      AgAlertEvent("refusing to run, core config invalid: CrashLoopWindowSeconds must be at least 1");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(SweepPeriodSeconds < 1 || SweepPeriodSeconds > 5)
     {
      AgAlertEvent("refusing to run, core config invalid: SweepPeriodSeconds out of range 1..5 ("
                   + (string)SweepPeriodSeconds + ")");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(HistoryStablePolls < 1)
     {
      AgAlertEvent("refusing to run, core config invalid: HistoryStablePolls must be at least 1");
      return INIT_PARAMETERS_INCORRECT;
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
      AgBanner("REFUSED", "duplicate instance", 0, "another instance holds the mutex");
      return INIT_FAILED;
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
      EventSetTimer(g_timer_seconds);
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
      EventSetTimer(g_timer_seconds);
      return INIT_SUCCEEDED;
     }
   AgVerbose("crash-loop check|unclean=" + (string)unclean + "/" + (string)CrashLoopMaxInits
             + " inside " + (string)CrashLoopWindowSeconds + "s");

   AgTransition(AG_STATE_SYNCING, "boot", "weekly=" + (g_weekly_enabled ? "on" : "off")
                + "|timer=" + (string)g_timer_seconds + "s");
   AgRefreshBanner();
   EventSetTimer(g_timer_seconds);
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| All logic runs here (F13 FINAL). Phase 0 carries the spine only. |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(g_owns_mutex)
      AgMutexRefresh();

   if(g_ag_state == AG_STATE_SAFE_HALT)
     {
      AgHeartbeatLog(AgStateName(g_ag_state));
      AgRefreshBanner();
      return;   // closes nothing, sweeps nothing, no expiry
     }

   // Phase 1 adds: SYNCING exit condition, PnL evaluation, breach check.
   // Phase 2 adds: lock persistence and expiry. Phase 3 adds: sweep.
   AgHeartbeatLog(AgStateName(g_ag_state));
   AgRefreshBanner();
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
   AgHaltMarkClean();
   AgHaltSave();
   if(g_owns_mutex)
      AgMutexRelease();
   AgInfo("deinit|reason=" + (string)reason + "|session marked clean");
   AgBannerClear();
  }
