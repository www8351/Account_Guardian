//+------------------------------------------------------------------+
//| AccountGuardian - Log.mqh                                        |
//| Logging contract implementation per SPEC v0.1 section 6.         |
//| No trade calls in this file (static-structure rule, SPEC 1).     |
//+------------------------------------------------------------------+
#ifndef AG_LOG_MQH
#define AG_LOG_MQH

enum ENUM_AG_LOG_VERBOSITY
  {
   AG_LOG_NORMAL  = 0, // Normal
   AG_LOG_VERBOSE = 1  // Verbose
  };

ENUM_AG_LOG_VERBOSITY g_ag_verbosity      = AG_LOG_NORMAL;
datetime              g_ag_last_heartbeat = 0;

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
//| Verbose-only line. Transitions never route through this.         |
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
//| Heartbeat journal line, at most once per minute (SPEC 6).        |
//+------------------------------------------------------------------+
void AgHeartbeatLog(const string state_name)
  {
   datetime now = TimeCurrent();
   if(now - g_ag_last_heartbeat < 60)
      return;
   g_ag_last_heartbeat = now;
   AgVerbose("heartbeat|state=" + state_name);
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
