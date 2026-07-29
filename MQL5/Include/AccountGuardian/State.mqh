//+------------------------------------------------------------------+
//| AccountGuardian - State.mqh                                      |
//| State machine per SPEC v0.1 section 2.                           |
//| No trade calls in this file (static-structure rule, SPEC 1).     |
//+------------------------------------------------------------------+
#ifndef AG_STATE_MQH
#define AG_STATE_MQH

#include <AccountGuardian/Log.mqh>

enum ENUM_AG_STATE
  {
   AG_STATE_SYNCING   = 0,
   AG_STATE_ACTIVE    = 1,
   AG_STATE_LOCKED    = 2,
   AG_STATE_SAFE_HALT = 3
  };

enum ENUM_AG_LOCK_REASON
  {
   AG_LOCK_NONE          = 0,
   AG_LOCK_DAILY_BREACH  = 1,
   AG_LOCK_CORRUPT_STATE = 2
  };

ENUM_AG_STATE       g_ag_state        = AG_STATE_SYNCING;
ENUM_AG_LOCK_REASON g_ag_lock_reason  = AG_LOCK_NONE;
datetime            g_ag_locked_until = 0;

string AgStateName(const ENUM_AG_STATE s)
  {
   switch(s)
     {
      case AG_STATE_SYNCING:   return "SYNCING";
      case AG_STATE_ACTIVE:    return "ACTIVE";
      case AG_STATE_LOCKED:    return "LOCKED";
      case AG_STATE_SAFE_HALT: return "SAFE_HALT";
     }
   return "UNKNOWN";
  }

string AgLockReasonName(const ENUM_AG_LOCK_REASON r)
  {
   switch(r)
     {
      case AG_LOCK_NONE:          return "-";
      case AG_LOCK_DAILY_BREACH:  return "DAILY_BREACH";
      case AG_LOCK_CORRUPT_STATE: return "CORRUPT_STATE";
     }
   return "UNKNOWN";
  }

//+------------------------------------------------------------------+
//| Single choke point for every transition. Exactly one log line.   |
//+------------------------------------------------------------------+
void AgTransition(const ENUM_AG_STATE to_state, const string reason, const string numbers)
  {
   ENUM_AG_STATE from_state = g_ag_state;
   g_ag_state = to_state;
   AgLogTransition(AgStateName(from_state), AgStateName(to_state), reason, numbers);
  }

#endif // AG_STATE_MQH
