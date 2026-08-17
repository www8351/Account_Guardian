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

//+------------------------------------------------------------------+
//| THE locked_until BOUNDS (Phase 2). Moved here from the EA by      |
//| owner ruling 2026-08-18 so a script can reach them: they are pure |
//| functions of their arguments and the latch above, which is the    |
//| shape a synthetic vector proves best, and while they sat in the   |
//| EA no script could include them and the three rulings they encode |
//| were provable by source reading alone.                            |
//|                                                                   |
//| This file still performs NO LOGGING and still touches no clock    |
//| but TimeCurrent through AgServerNow, so the Q7 header contract    |
//| above and the static acceptance row that greps for TimeLocal,     |
//| TimeGMT and TimeTradeServer are both unaffected by the move.      |
//+------------------------------------------------------------------+

//--- Ruling FOUR's floor: the next day anchor of Q8's high-water latch.
//--- The latch never recedes by construction, so this is monotone even
//--- while the clock itself steps backward, which is the whole property
//--- ruling FOUR needs. Returns 0 when the latch has not been seeded,
//--- i.e. before the first ACTIVE pass, where there is nothing to floor
//--- against and claiming a floor would invent one.
datetime AgLatchFloor()
  {
   return g_ag_high_anchor_seeded ? AgNextDayAnchor(g_ag_high_anchor) : 0;
  }

datetime AgApplyLatchFloor(const datetime t)
  {
   datetime floor_value = AgLatchFloor();
   return (floor_value > 0 && t < floor_value) ? floor_value : t;
  }

//+------------------------------------------------------------------+
//| A value the guardian computes for itself, at a breach it saw.     |
//| Q1 is the base. RULING THREE takes the anchor AFTER the imminent  |
//| one when the quote is frozen at the breach instant, a full        |
//| trading day, which is what stops the measured 62-minute pre-      |
//| anchor freeze producing a lock that expires minutes later at the  |
//| reopen. RULING FOUR floors it.                                     |
//|                                                                   |
//| The 2026-07-30 clamp is deliberately ABSENT: the precedence       |
//| ruling of 2026-08-18 gives it the witness domain only, and a      |
//| value computed here takes the floor alone.                        |
//+------------------------------------------------------------------+
datetime AgLockedUntilComputed(const datetime breach_time, const bool quote_frozen)
  {
   datetime until = AgNextDayAnchor(breach_time);   // Q1
   if(quote_frozen)
      until = AgNextDayAnchor(until);               // ruling THREE
   return AgApplyLatchFloor(until);                 // ruling FOUR
  }

//+------------------------------------------------------------------+
//| A value arriving from a witness, file or GV, which a local        |
//| attacker can write. Order per the precedence ruling of            |
//| 2026-08-18, quoted: "clamp first as the upper bound, floor        |
//| second as the lower bound, so the floor wins any conflict by      |
//| being applied last". Under a rewound clock the clamp's ceiling    |
//| sits BELOW the floor, and applying the floor last is precisely    |
//| the mechanism by which the floor wins that case.                  |
//+------------------------------------------------------------------+
datetime AgLockedUntilFromWitness(const datetime raw)
  {
   datetime until   = raw;
   datetime ceiling = AgNextDayAnchor(AgServerNow());   // clamp, 2026-07-30
   if(until > ceiling)
      until = ceiling;
   return AgApplyLatchFloor(until);                     // ruling FOUR, applied last
  }

#endif // AG_CLOCK_MQH
