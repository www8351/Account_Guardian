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
//| Anchor high-water-mark sanity latch (4.1a, Q8 FINAL 2026-08-08,  |
//| AMENDED by owner ruling 2026-08-09 to alert-and-advance).        |
//| In-memory only, never persisted (never-loaded-never-written);    |
//| a restart re-seeds on the first pass, which is always accepted   |
//| since there is nothing yet to compare it against.                |
//+------------------------------------------------------------------+
bool     g_ag_high_anchor_seeded = false;
datetime g_ag_high_anchor        = 0;

//--- Set on a pass whose forward jump exceeded one day, cleared on every
//--- other pass. The CALLER owns the announcement: this file must not log
//--- it, because the ALERT cadence needs the local clock, and TimeLocal is
//--- forbidden here by this file's own header (Q7) and by the Stage 3
//--- static acceptance row that greps Clock.mqh for exactly that.
string   g_ag_anchor_jump_note   = "";

//+------------------------------------------------------------------+
//| Applies the Q8 latch to a freshly computed anchor and returns    |
//| the anchor this pass's window must use.                          |
//|                                                                  |
//| Q8 AMENDMENT, owner ruling 2026-08-09, alert-and-advance: a      |
//| forward jump of more than one day sets the jump note, naming     |
//| both anchors for the caller to announce loudly, and then         |
//| ACCEPTS fresh and advances the high mark, so the pass proceeds    |
//| normally and the condition clears itself on that same pass.      |
//|                                                                  |
//| This supersedes the original halt-the-pass behaviour, which      |
//| never self-cleared against a clock that only moves forward:      |
//| self-clearing required fresh to fall BACK within one day of the  |
//| retained mark. The measured weekend freeze advances the anchor   |
//| three days at the Monday reopen (Friday 01:00 is held through    |
//| the freeze, plan 2.3), so the original rule stalled evaluation   |
//| permanently on every weekend-spanning session. A guardian that   |
//| stops computing is fail-open and worse than a widened window,    |
//| per the A4 precedent that the system errs toward staying live    |
//| and loud.                                                        |
//|                                                                  |
//| Backward steps and same-day recomputes are unaffected: the       |
//| window always widens using fresh, and the high mark never        |
//| recedes.                                                          |
//+------------------------------------------------------------------+
datetime AgAnchorSanityCheck(const datetime fresh)
  {
   g_ag_anchor_jump_note = "";
   if(!g_ag_high_anchor_seeded)
     {
      g_ag_high_anchor_seeded = true;
      g_ag_high_anchor        = fresh;
      return fresh;
     }
   if(fresh <= g_ag_high_anchor)
      return fresh;                      // backward step or same day: widen, mark never recedes
   if(fresh - g_ag_high_anchor <= 86400)
     {
      g_ag_high_anchor = fresh;          // ordinary single-day advance
      return fresh;
     }
   //--- anomalous forward jump: name both anchors, then accept and advance
   g_ag_anchor_jump_note = "anchor jump accepted: previous_high="
                           + TimeToString(g_ag_high_anchor, TIME_DATE | TIME_SECONDS)
                           + ", accepted=" + TimeToString(fresh, TIME_DATE | TIME_SECONDS)
                           + ", jump=" + (string)(long)(fresh - g_ag_high_anchor) + "s";
   g_ag_high_anchor = fresh;
   return fresh;
  }

#endif // AG_CLOCK_MQH
