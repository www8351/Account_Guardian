//+------------------------------------------------------------------+
//| AccountGuardian - Clock.mqh                                      |
//| Server-time source and anchors per SPEC v0.1 sections 1 and 4.1. |
//| Q7 (FINAL): decision paths use TimeCurrent exclusively.          |
//| TimeTradeServer and TimeLocal are forbidden here.                |
//| The only sanctioned local-clock users are the crash-loop session |
//| timestamps and the heartbeat mutex, which live in Persist.mqh    |
//| under the Amendment A1 clock exemption.                          |
//| No trade calls in this file (static-structure rule, SPEC 1).     |
//+------------------------------------------------------------------+
#ifndef AG_CLOCK_MQH
#define AG_CLOCK_MQH

//+------------------------------------------------------------------+
//| Last-known server time. Frozen in dead markets; errs locked.     |
//+------------------------------------------------------------------+
datetime AgServerNow() { return TimeCurrent(); }

//+------------------------------------------------------------------+
//| Broker server midnight of the day containing t.                  |
//| Recomputed each evaluation, never persisted (charter).           |
//+------------------------------------------------------------------+
datetime AgDayAnchor(const datetime t) { return t - (t % 86400); }

//+------------------------------------------------------------------+
//| Next broker server midnight after t (= DAILY_BREACH expiry, Q1). |
//+------------------------------------------------------------------+
datetime AgNextDayAnchor(const datetime t) { return AgDayAnchor(t) + 86400; }

#endif // AG_CLOCK_MQH
