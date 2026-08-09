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
   AG_STATE_BOOT      = 0, // pseudo-state: before the first real transition
   AG_STATE_SYNCING   = 1,
   AG_STATE_ACTIVE    = 2,
   AG_STATE_LOCKED    = 3,
   AG_STATE_SAFE_HALT = 4
  };

enum ENUM_AG_LOCK_REASON
  {
   AG_LOCK_NONE          = 0,
   AG_LOCK_DAILY_BREACH  = 1,
   AG_LOCK_CORRUPT_STATE = 2
  };

ENUM_AG_STATE       g_ag_state        = AG_STATE_BOOT;
ENUM_AG_LOCK_REASON g_ag_lock_reason  = AG_LOCK_NONE;
datetime            g_ag_locked_until = 0;
datetime            g_ag_state_since  = 0;   // wall clock, for seconds-in-state

string AgStateName(const ENUM_AG_STATE s)
  {
   switch(s)
     {
      case AG_STATE_BOOT:      return "BOOT";
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
//| Seconds spent in the current state, wall clock so it advances in |
//| a dead market (proof of life, SPEC A3).                          |
//+------------------------------------------------------------------+
int AgSecondsInState()
  {
   if(g_ag_state_since == 0)
      return 0;
   return (int)(TimeLocal() - g_ag_state_since);
  }

//+------------------------------------------------------------------+
//| Single choke point for every transition. Exactly one log line.   |
//+------------------------------------------------------------------+
void AgTransition(const ENUM_AG_STATE to_state, const string reason, const string numbers)
  {
   ENUM_AG_STATE from_state = g_ag_state;
   g_ag_state       = to_state;
   g_ag_state_since = TimeLocal();
   AgLogTransition(AgStateName(from_state), AgStateName(to_state), reason, numbers);
  }

//+------------------------------------------------------------------+
//| What a transitional state is waiting on, for the A3 life line.   |
//| SYNCING has no exit condition implemented in Phase 0: the sync    |
//| check and the PnL engine land in Phase 1. Saying so out loud is   |
//| the point of A3, so the line reports it rather than looking idle. |
//+------------------------------------------------------------------+
string AgWaitingOn()
  {
   switch(g_ag_state)
     {
      case AG_STATE_SYNCING:
         return "Phase1:TERMINAL_CONNECTED+HistoryDealsTotal stable (not implemented in Phase 0, SYNCING is terminal in this build)";
      case AG_STATE_LOCKED:
         return "expiry: TimeCurrent >= locked_until";
      case AG_STATE_SAFE_HALT:
         return "manual resume: delete the halt file while the EA is stopped, then restart";
     }
   return "";
  }

#endif // AG_STATE_MQH
