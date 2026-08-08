//+------------------------------------------------------------------+
//| AccountGuardian - Clock.mqh                                      |
//| Server-time source and anchors per SPEC v0.1 sections 1 and 4.1, |
//| amended by A6 (Phase 1, day anchor at 01:00 server, Q1 FINAL,    |
//| and the anchor high-water-mark sanity latch, Q8 FINAL).          |
//| Q7 (FINAL): decision paths use TimeCurrent exclusively.          |
//| TimeTradeServer and TimeLocal are forbidden here.                |
//| The only sanctioned local-clock users are the crash-loop session |
//| timestamps and the mutex heartbeat in Persist.mqh (Amendment A1  |
//| clock exemption), and the proof-of-life line and seconds-in-     |
//| state counter (A3), which must advance in a dead market.         |
//| No trade calls in this file (static-structure rule, SPEC 1).     |
//+------------------------------------------------------------------+
#ifndef AG_CLOCK_MQH
#define AG_CLOCK_MQH

#include <AccountGuardian/Log.mqh>

//+------------------------------------------------------------------+
//| Day-anchor offset from server midnight, Q1 FINAL 2026-08-08:     |
//| fixed 01:00 server, compile-time constant, deliberately not an   |
//| input (AG_LIFE_INTERVAL/AG_MUTEX_STALE precedent: a value able   |
//| to disable a guarantee is core or nowhere). REVISIT scheduled    |
//| after the 2026-10-25..2026-11-01 broker DST-peg measurement.     |
//+------------------------------------------------------------------+
#define AG_DAY_ANCHOR_OFFSET_SECONDS 3600

//+------------------------------------------------------------------+
//| Last-known server time. Frozen in dead markets; errs locked.     |
//+------------------------------------------------------------------+
datetime AgServerNow() { return TimeCurrent(); }

//+------------------------------------------------------------------+
//| Last 01:00-server boundary <= t. Pure function of t, recomputed  |
//| every evaluation, never persisted (charter, unchanged by A6).    |
//+------------------------------------------------------------------+
datetime AgDayAnchor(const datetime t)
  {
   return t - ((t - AG_DAY_ANCHOR_OFFSET_SECONDS) % 86400);
  }

//+------------------------------------------------------------------+
//| Next 01:00-server boundary after t (Q1: stays derivable).        |
//+------------------------------------------------------------------+
datetime AgNextDayAnchor(const datetime t) { return AgDayAnchor(t) + 86400; }

//+------------------------------------------------------------------+
//| Anchor high-water-mark sanity latch (4.1a, Q8 FINAL 2026-08-08). |
//| In-memory only, never persisted (never-loaded-never-written);    |
//| a restart re-seeds on the first pass, which is always accepted   |
//| since there is nothing yet to compare it against.                |
//+------------------------------------------------------------------+
bool     g_ag_high_anchor_seeded = false;
datetime g_ag_high_anchor        = 0;
string   g_ag_anchor_waiting_on  = "";

//+------------------------------------------------------------------+
//| Applies the Q8 latch to a freshly computed anchor and returns    |
//| the anchor this pass's window must use. Halts loudly (ALERT      |
//| naming both anchors) on a forward jump of more than one day      |
//| rather than narrowing the window; self-clearing on the next pass |
//| once fresh falls back within one day of the retained high mark.  |
//| Backward steps and same-day recomputes are unaffected: the       |
//| window always widens using fresh, and the high mark never        |
//| recedes.                                                          |
//+------------------------------------------------------------------+
datetime AgAnchorSanityCheck(const datetime fresh)
  {
   if(!g_ag_high_anchor_seeded)
     {
      g_ag_high_anchor_seeded = true;
      g_ag_high_anchor        = fresh;
      g_ag_anchor_waiting_on  = "";
      return fresh;
     }
   if(fresh <= g_ag_high_anchor)
     {
      g_ag_anchor_waiting_on = "";
      return fresh;
     }
   if(fresh - g_ag_high_anchor <= 86400)
     {
      g_ag_high_anchor       = fresh;
      g_ag_anchor_waiting_on = "";
      return fresh;
     }
   AgAlertEvent("anchor sanity: fresh anchor " + TimeToString(fresh, TIME_DATE | TIME_SECONDS)
                + " exceeds retained high anchor " + TimeToString(g_ag_high_anchor, TIME_DATE | TIME_SECONDS)
                + " by more than one day, evaluation halted this pass");
   g_ag_anchor_waiting_on = "anchor sanity: retained=" + TimeToString(g_ag_high_anchor, TIME_DATE | TIME_SECONDS)
                            + ", rejected=" + TimeToString(fresh, TIME_DATE | TIME_SECONDS);
   return g_ag_high_anchor;
  }

#endif // AG_CLOCK_MQH
