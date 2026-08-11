//+------------------------------------------------------------------+
//| AgPhase1ClockVectors.mq5                                         |
//| Stage 2 synthetic test vectors for Clock.mqh's anchor rework     |
//| (Q1 FINAL, 01:00-server offset) and the Q8 high-water-mark latch |
//| (4.1a), as AMENDED by the owner ruling of 2026-08-09 to          |
//| alert-and-advance. 26 checks: one AGVEC line per case plus a     |
//| final AGVEC|SUMMARY|<pass>/<total> line. Makes no trade calls,   |
//| opens no chart, and writes no file.                             |
//| Double-click from the Navigator to run.                          |
//+------------------------------------------------------------------+
#property copyright "AccountGuardian"
#property version   "1.00"
#property strict
#property script_show_inputs

#include <AccountGuardian/Clock.mqh>

int g_pass  = 0;
int g_total = 0;

void AgVecCheck(const string name, const bool ok, const string detail)
  {
   g_total++;
   if(ok)
     {
      g_pass++;
      PrintFormat("AGVEC|%s|PASS", name);
     }
   else
      PrintFormat("AGVEC|%s|FAIL|%s", name, detail);
  }

void AgVecCheckDT(const string name, const datetime got, const datetime want)
  {
   AgVecCheck(name, got == want,
              "got=" + TimeToString(got, TIME_DATE | TIME_SECONDS)
              + " want=" + TimeToString(want, TIME_DATE | TIME_SECONDS));
  }

void OnStart()
  {
   //--- fixed reference anchor boundary: 2026.02.10 01:00:00 server, an
   //--- arbitrary Tuesday with no DST or weekend adjacency to confound it.
   datetime A0 = D'2026.02.10 01:00:00';
   datetime A1 = A0 + 86400;   // next boundary
   datetime A2 = A0 + 172800;  // boundary after that
   datetime A3 = A0 + 259200;  // three boundaries forward

   //--- boundary second, one second before and after ---------------------
   AgVecCheckDT("boundary_at",         AgDayAnchor(A0),     A0);
   AgVecCheckDT("boundary_minus_1s",   AgDayAnchor(A0 - 1), A0 - 86400);
   AgVecCheckDT("boundary_plus_1s",    AgDayAnchor(A0 + 1), A0);

   //--- frozen input: same t twice yields the same anchor, both times ----
   datetime frozen_t = A0 + 12345;
   datetime frozen_1 = AgDayAnchor(frozen_t);
   datetime frozen_2 = AgDayAnchor(frozen_t);
   AgVecCheckDT("frozen_input_repeat", frozen_2, frozen_1);

   //--- backward step across the boundary, 1s class -----------------------
   AgVecCheckDT("backward_1s_class", AgDayAnchor(A0 - 1), A0 - 86400);

   //--- backward step across the boundary, 25h class -----------------------
   datetime t_25h_back = A1 + 3600 - 90000; // 25h before a point just after A1
   AgVecCheckDT("backward_25h_class", AgDayAnchor(t_25h_back), A0);

   //--- forward jump across three anchors: AgDayAnchor tracks it directly -
   AgVecCheckDT("forward_jump_three_anchors", AgDayAnchor(A3 + 10), A3);

   //--- AgNextDayAnchor = anchor + 86400 everywhere -----------------------
   AgVecCheck("next_day_anchor_A0", AgNextDayAnchor(A0) == A0 + 86400, "");
   AgVecCheck("next_day_anchor_A1", AgNextDayAnchor(A1) == A1 + 86400, "");
   AgVecCheck("next_day_anchor_backward", AgNextDayAnchor(A0 - 1) == A0, "");

   //--- 4.1a Q8 vector 1: legitimate one-day advance accepts and advances -
   g_ag_high_anchor_seeded = false;
   g_ag_high_anchor        = 0;
   datetime seed = AgAnchorSanityCheck(A0);
   AgVecCheckDT("q8_seed_accepts_first_pass", seed, A0);
   AgVecCheck("q8_seed_sets_high_anchor", g_ag_high_anchor == A0, "");

   datetime advanced = AgAnchorSanityCheck(A1);
   AgVecCheckDT("q8_one_day_advance_accepts", advanced, A1);
   AgVecCheck("q8_one_day_advance_moves_high_anchor", g_ag_high_anchor == A1, "");

   //--- 4.1a Q8 vector 2, AMENDED 2026-08-09 (alert-and-advance): an
   //--- anomalous two-day-plus jump names both anchors in the jump note,
   //--- then ACCEPTS fresh and ADVANCES the high-water mark. No pass is
   //--- halted and the window is never pinned to a stale anchor.
   datetime before_jump_high = g_ag_high_anchor;
   datetime jumped = AgAnchorSanityCheck(A3);   // A3 is two boundaries past A1
   AgVecCheckDT("q8_forward_jump_accepts_fresh", jumped, A3);
   AgVecCheck("q8_forward_jump_high_anchor_advances", g_ag_high_anchor == A3, "");
   AgVecCheck("q8_forward_jump_note_names_both",
              StringFind(g_ag_anchor_jump_note, "previous_high=") >= 0
              && StringFind(g_ag_anchor_jump_note, "accepted=") >= 0, g_ag_anchor_jump_note);
   AgVecCheck("q8_forward_jump_note_carries_previous_value",
              StringFind(g_ag_anchor_jump_note,
                         TimeToString(before_jump_high, TIME_DATE | TIME_SECONDS)) >= 0,
              g_ag_anchor_jump_note);

   //--- the condition clears on the very next ordinary pass, no restart --
   datetime resumed = AgAnchorSanityCheck(A3 + 3600);
   AgVecCheck("q8_note_clears_on_next_ordinary_pass",
              resumed == A3 + 3600 && g_ag_anchor_jump_note == "", g_ag_anchor_jump_note);

   //--- 4.1a Q8 vector 3: backward step still widens using fresh and never
   //--- substitutes the high-water mark -----------------------------------
   datetime high_before_backstep = g_ag_high_anchor;
   datetime backstepped = AgAnchorSanityCheck(A0);   // well behind the retained high mark
   AgVecCheckDT("q8_backward_step_still_widens", backstepped, A0);
   AgVecCheck("q8_backward_step_high_anchor_unchanged", g_ag_high_anchor == high_before_backstep, "");
   AgVecCheck("q8_backward_step_sets_no_note", g_ag_anchor_jump_note == "", g_ag_anchor_jump_note);

   //--- 4.1a Q8 vector 4, NEW 2026-08-09: the weekend reopen, which is the
   //--- exact live signature the original halt rule stalled on permanently.
   //--- Friday 01:00 is held through the measured freeze and Monday 01:00
   //--- lands at the reopen, a three-day advance. Must announce, accept,
   //--- advance, and clear on the following pass. These are the real dates
   //--- of the session that found the defect, not invented ones.
   g_ag_high_anchor_seeded = false;
   g_ag_high_anchor        = 0;
   datetime friday = D'2026.08.07 01:00:00';
   datetime monday = D'2026.08.10 01:00:00';
   AgAnchorSanityCheck(friday);                 // seeds exactly as the live session did
   datetime reopen = AgAnchorSanityCheck(monday);
   AgVecCheckDT("q8_weekend_reopen_accepts_monday", reopen, monday);
   AgVecCheck("q8_weekend_reopen_high_anchor_advances", g_ag_high_anchor == monday, "");
   AgVecCheck("q8_weekend_reopen_note_names_jump",
              StringFind(g_ag_anchor_jump_note, "jump=259200s") >= 0, g_ag_anchor_jump_note);
   datetime after_reopen = AgAnchorSanityCheck(monday + 3600);
   AgVecCheck("q8_weekend_reopen_clears_next_pass",
              after_reopen == monday + 3600 && g_ag_anchor_jump_note == "", g_ag_anchor_jump_note);

   PrintFormat("AGVEC|SUMMARY|%d/%d", g_pass, g_total);
  }
//+------------------------------------------------------------------+
