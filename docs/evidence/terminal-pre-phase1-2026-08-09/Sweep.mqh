//+------------------------------------------------------------------+
//| AccountGuardian - Sweep.mqh                                      |
//| Flatten engine, pending deletion, retry policy. SPEC v0.1 4.4.   |
//|                                                                  |
//| STATIC-STRUCTURE RULE (SPEC 1): this is the ONLY file in the     |
//| project permitted to reach the trade API. Every other file must  |
//| grep clean for OrderSend, CTrade, PositionClose, OrderDelete.    |
//|                                                                  |
//| PHASE 0: deliberately empty of trading calls. The Phase 0        |
//| acceptance matrix requires the whole build, this file included,  |
//| to contain no trade API reference at all. Bodies land in Phase 3.|
//+------------------------------------------------------------------+
#ifndef AG_SWEEP_MQH
#define AG_SWEEP_MQH

//+------------------------------------------------------------------+
//| Phase 3 obligations, declared here so the contract is visible:   |
//|                                                                  |
//| bool AgTradeAllowed(string &blocking_state)                      |
//|   Enumerate and name each disallowed state distinctly (Q3):      |
//|   TERMINAL_TRADE_ALLOWED, MQL_TRADE_ALLOWED,                     |
//|   ACCOUNT_TRADE_ALLOWED, ACCOUNT_TRADE_EXPERT, investor login,   |
//|   symbol session closed or close-only.                           |
//|                                                                  |
//| void AgSweepPass()                                               |
//|   One pass per timer tick while LOCKED: delete all pendings,     |
//|   close all positions, per-position backoff, one log line per    |
//|   attempt carrying the retcode, no unbounded tight retry.        |
//+------------------------------------------------------------------+

#endif // AG_SWEEP_MQH
