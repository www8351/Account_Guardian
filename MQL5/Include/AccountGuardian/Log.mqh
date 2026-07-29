//+------------------------------------------------------------------+
//| AccountGuardian - Log.mqh                                        |
//| Logging contract implementation per SPEC v0.1 sections 6 and 9   |
//| (amendment A3, proof of life).                                   |
//| No trade calls in this file (static-structure rule, SPEC 1).     |
//+------------------------------------------------------------------+
#ifndef AG_LOG_MQH
#define AG_LOG_MQH

enum ENUM_AG_LOG_VERBOSITY
  {
   AG_LOG_NORMAL  = 0, // Normal
   AG_LOG_VERBOSE = 1  // Verbose
  };

ENUM_AG_LOG_VERBOSITY g_ag_verbosity     = AG_LOG_NORMAL;
datetime              g_ag_last_life_log = 0;

//+------------------------------------------------------------------+
//| One structured journal line. Level: INFO/WARN/ALERT/TRANSITION.  |
//+------------------------------------------------------------------+
void AgLog(const string level, const string message)
  {
   PrintFormat("AG|%s|%s|%s", TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), level, message);
  }

void AgInfo(const string message)  { AgLog("INFO", message); }
void AgWarn(const string message)  { AgLog("WARN", message); }

//+------------------------------------------------------------------+
//| Verbose-only line. Transitions and proof of life never route     |
//| through this: they must survive any verbosity setting.           |
//+------------------------------------------------------------------+
void AgVerbose(const string message)
  {
   if(g_ag_verbosity == AG_LOG_VERBOSE)
      AgLog("DEBUG", message);
  }

//+------------------------------------------------------------------+
//| Mandatory popup events (SPEC 6): journal line plus Alert().      |
//+------------------------------------------------------------------+
void AgAlertEvent(const string message)
  {
   AgLog("ALERT", message);
   Alert("AccountGuardian: ", message);
  }

//+------------------------------------------------------------------+
//| Exactly one line per state transition, with governing numbers.   |
//+------------------------------------------------------------------+
void AgLogTransition(const string from_state, const string to_state,
                     const string reason, const string numbers)
  {
   AgLog("TRANSITION", from_state + "->" + to_state + "|" + reason + "|" + numbers);
  }

//+------------------------------------------------------------------+
//| Proof of life (SPEC amendment A3). Every state emits this at a   |
//| fixed interval, SYNCING and LOCKED included, carrying the state, |
//| seconds in state, and what a transitional state waits on. A      |
//| stuck guardian and a healthy one must never look identical from  |
//| outside, which is exactly the failure this closes.               |
//| Never suppressed by verbosity, never rate-limited away.          |
//+------------------------------------------------------------------+
void AgProofOfLife(const string state_name, const int seconds_in_state,
                   const string waiting_on, const int interval_seconds)
  {
   datetime now = TimeLocal();   // wall clock: must tick in a dead market too
   if(g_ag_last_life_log != 0 && now - g_ag_last_life_log < interval_seconds)
      return;
   g_ag_last_life_log = now;
   AgLog("LIFE", "state=" + state_name
         + "|seconds_in_state=" + (string)seconds_in_state
         + "|waiting_on=" + (waiting_on == "" ? "-" : waiting_on));
  }

//+------------------------------------------------------------------+
//| Chart banner: state, lock reason, locked_until, PnL vs limit.    |
//+------------------------------------------------------------------+
void AgBanner(const string state_name, const string lock_reason,
              const datetime locked_until, const string pnl_vs_limit)
  {
   string until = (locked_until > 0) ? TimeToString(locked_until, TIME_DATE | TIME_SECONDS) : "-";
   Comment("AccountGuardian\n",
           "State: ",        state_name,   "\n",
           "Lock reason: ",  lock_reason,  "\n",
           "Locked until: ", until,        "\n",
           "Daily PnL vs limit: ", pnl_vs_limit);
  }

void AgBannerClear() { Comment(""); }

#endif // AG_LOG_MQH
