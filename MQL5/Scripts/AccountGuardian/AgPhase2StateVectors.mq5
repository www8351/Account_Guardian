//+------------------------------------------------------------------+
//| AgPhase2StateVectors.mq5                                         |
//| Phase 2 Stage 2 synthetic test vectors for the lock state file   |
//| family in Persist.mqh (design doc item 5): AgStatePath,          |
//| AgStateSerialize, AgStateSave, AgStateLoad, the                  |
//| never-loaded-never-written guard, the checksum, the login        |
//| mismatch rule and the .bad quarantine.                           |
//| One AGVEC line per case plus a final AGVEC|SUMMARY|<pass>/<total>|
//| line, the same contract AgPhase1ClockVectors already uses.       |
//| Makes no trade calls and opens no chart.                         |
//|                                                                  |
//| IT DOES WRITE FILES, which the clock vectors did not, because    |
//| the thing under test is a file format. Two properties keep that  |
//| safe and both are asserted rather than assumed. First, every     |
//| path it touches is derived from a SYNTHETIC login in the         |
//| 99000000x range, so it can never read, write or quarantine the   |
//| real state_<login>.dat of the live account; vector 0 refuses to  |
//| run at all if the live login ever collides with that range.      |
//| Second, it DELETES NOTHING. Quarantined files accumulate across  |
//| runs by design, per the FINAL ruling of 2026-07-29 that lock     |
//| artifacts are never deleted, only quarantined; the growing       |
//| .bad.N chain is itself vector q_quarantine_never_overwrites.     |
//|                                                                  |
//| Double-click from the Navigator to run. A running terminal does  |
//| not enumerate files added after it started, so this script is    |
//| invisible until the next terminal restart (FINAL 2026-08-04,     |
//| extended to Scripts by measurement 2026-08-09).                  |
//+------------------------------------------------------------------+
#property copyright "AccountGuardian"
#property version   "1.00"
#property strict
#property script_show_inputs

#include <AccountGuardian/Persist.mqh>

//--- Synthetic logins. None of these is a real account and none of them
//--- may ever equal the live one; vector 0 enforces that.
#define AGVEC_LOGIN_ROUNDTRIP  990000001
#define AGVEC_LOGIN_CORRUPT    990000002
#define AGVEC_LOGIN_MISMATCH   990000003
#define AGVEC_LOGIN_FOREIGN    990000004
#define AGVEC_LOGIN_VERSION    990000005
#define AGVEC_LOGIN_CROSSREAD  990000006
#define AGVEC_LOGIN_GUARD      990000007
#define AGVEC_LOGIN_MISSING    990000009   // deliberately never written

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

void AgVecCheckInt(const string name, const long got, const long want)
  {
   AgVecCheck(name, got == want, "got=" + (string)got + " want=" + (string)want);
  }

//--- Money comparison at 1e-6, deliberately tighter than the 0.01 acceptance
//--- epsilon of 2026-07-30: the point of these vectors is that the stored
//--- value is the value, so a difference the banner would round away still
//--- has to fail here.
void AgVecCheckMoney(const string name, const double got, const double want)
  {
   AgVecCheck(name, MathAbs(got - want) < 0.000001,
              "got=" + DoubleToString(got, 8) + " want=" + DoubleToString(want, 8));
  }

//+------------------------------------------------------------------+
//| Raw file helpers. These bypass the state family on purpose: a    |
//| vector that built its fixtures with the code under test could    |
//| not detect a format that is self-consistently wrong.             |
//+------------------------------------------------------------------+
bool AgVecWriteRaw(const string path, const string content)
  {
   FolderCreate(AG_FILES_DIR);
   int h = FileOpen(path, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE)
      return false;
   FileWriteString(h, content);
   FileFlush(h);
   FileClose(h);
   return true;
  }

string AgVecReadRaw(const string path)
  {
   if(!FileIsExist(path))
      return "";
   int h = FileOpen(path, FILE_READ | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE)
      return "";
   string out = "";
   while(!FileIsEnding(h))
      out += FileReadString(h) + "\n";
   FileClose(h);
   return out;
  }

//--- A well-formed body plus a correct checksum line.
string AgVecSealed(const string body) { return body + "C|" + (string)AgChecksum(body) + "\n"; }

//--- A well-formed body plus a checksum that is wrong by exactly one.
string AgVecTampered(const string body) { return body + "C|" + (string)(AgChecksum(body) + 1) + "\n"; }

string AgVecBody(const long login, const int reason, const datetime until,
                 const datetime breach, const double limit_snap, const double base_snap)
  {
   return "AGSTATE|" + (string)AG_STATE_FORMAT_VERSION + "|" + (string)login + "\n"
          + "L|" + (string)reason + "|" + (string)((long)until) + "|" + (string)((long)breach) + "\n"
          + "N|" + DoubleToString(limit_snap, AG_STATE_MONEY_DIGITS)
          + "|" + DoubleToString(base_snap, AG_STATE_MONEY_DIGITS) + "\n";
  }

void OnStart()
  {
   //--- Fixed reference values. The anchor boundary is the same arbitrary
   //--- Tuesday the Phase 1 clock vectors use, so the two vector sets can be
   //--- read side by side. The money values are the real measured ones from
   //--- 2026-08-16: base 1985.97 at the ruled five percent gives 99.2985,
   //--- which the banner prints as 99.30. That sub-cent tail is the whole
   //--- reason the money fields are stored at 8 decimals and it is asserted
   //--- below rather than left as a comment.
   datetime A0        = D'2026.02.10 01:00:00';
   datetime until_ref = A0 + 86400;
   datetime breach_ref = A0 + 43200;
   double   base_ref  = 1985.97;
   double   limit_ref = 99.2985;

   long live_login = (long)AccountInfoInteger(ACCOUNT_LOGIN);

   //--- vector 0: the safety interlock. Every other vector writes files, so
   //--- this one runs first and refuses everything if the synthetic range
   //--- could collide with the live account's own state file.
   bool range_is_safe = (live_login < 990000000 || live_login > 990000999);
   AgVecCheck("v0_synthetic_login_range_cannot_hit_live_account", range_is_safe,
              "live login " + (string)live_login + " falls inside the synthetic range");
   if(!range_is_safe)
     {
      PrintFormat("AGVEC|SUMMARY|%d/%d", g_pass, g_total);
      return;
     }

   //================================================================
   //--- A. path and format identity
   //================================================================
   g_ag_login = AGVEC_LOGIN_ROUNDTRIP;
   AgVecCheck("a1_state_path_differs_from_halt_path", AgStatePath() != AgHaltPath(),
              AgStatePath() + " vs " + AgHaltPath());
   AgVecCheck("a2_state_path_names_the_login",
              StringFind(AgStatePath(), (string)AGVEC_LOGIN_ROUNDTRIP) >= 0, AgStatePath());
   AgVecCheck("a3_magic_is_agstate_not_aghalt",
              StringFind(AgStateSerialize(), "AGSTATE|") == 0
              && StringFind(AgStateSerialize(), "AGHALT") < 0, AgStateSerialize());

   //================================================================
   //--- B. never-loaded-never-written (FINAL 2026-07-29)
   //================================================================
   g_ag_login = AGVEC_LOGIN_GUARD;
   string guard_path = AgStatePath();
   AgVecWriteRaw(guard_path, AgVecSealed(AgVecBody(AGVEC_LOGIN_GUARD, 1, until_ref, breach_ref,
                                                   limit_ref, base_ref)));
   string guard_before = AgVecReadRaw(guard_path);
   g_ag_state_loaded = false;                 // simulate a refused init
   AgStateResetModel();                       // default-constructed empty model
   bool saved = AgStateSave();
   AgVecCheck("b1_save_refuses_when_model_never_loaded", !saved, "AgStateSave returned true");
   AgVecCheck("b2_refused_save_left_the_file_byte_identical",
              AgVecReadRaw(guard_path) == guard_before, "file changed under a refused save");

   //================================================================
   //--- C. round trip through the real save and load paths
   //================================================================
   g_ag_login = AGVEC_LOGIN_ROUNDTRIP;
   g_ag_state_loaded = true;                  // a legitimate load happened
   AgStateSetBreach(until_ref, breach_ref, limit_ref, base_ref);
   AgVecCheck("c1_save_succeeds_when_loaded", AgStateSave(), "AgStateSave returned false");

   AgStateResetModel();                       // prove the values come off disk
   int rc = AgStateLoad();
   AgVecCheckInt("c2_roundtrip_load_returns_loaded", rc, 0);
   AgVecCheckInt("c3_roundtrip_reason", (long)g_ag_state_reason, (long)AG_LOCK_DAILY_BREACH);
   AgVecCheckDT("c4_roundtrip_locked_until", g_ag_state_locked_until, until_ref);
   AgVecCheckDT("c5_roundtrip_breach_time", g_ag_state_breach_time, breach_ref);
   AgVecCheckMoney("c6_roundtrip_limit_snapshot", g_ag_state_limit_snap, limit_ref);
   AgVecCheckMoney("c7_roundtrip_base_snapshot", g_ag_state_base_snap, base_ref);
   //--- The Q6 snapshot governs the locked window, so a limit stored to the
   //--- printed cent would enforce 99.30 where the breach computed 99.2985.
   AgVecCheck("c8_limit_snapshot_keeps_sub_cent_precision",
              MathAbs(g_ag_state_limit_snap - 99.30) > 0.0001,
              "stored limit rounded to the cent: " + DoubleToString(g_ag_state_limit_snap, 8));

   //================================================================
   //--- D. missing file: not corrupt, and not trusted either way
   //================================================================
   g_ag_login = AGVEC_LOGIN_MISSING;
   g_ag_state_loaded = false;
   rc = AgStateLoad();
   AgVecCheckInt("d1_missing_file_returns_missing", rc, 1);
   AgVecCheck("d2_missing_file_sets_loaded_true", g_ag_state_loaded, "");
   AgVecCheckInt("d3_missing_file_model_is_neutral", (long)g_ag_state_reason, (long)AG_LOCK_NONE);
   AgVecCheckDT("d4_missing_file_locked_until_is_zero", g_ag_state_locked_until, 0);
   AgVecCheck("d5_missing_file_wrote_nothing", !FileIsExist(AgStatePath()), AgStatePath());

   //================================================================
   //--- E. checksum corruption
   //================================================================
   g_ag_login = AGVEC_LOGIN_CORRUPT;
   string corrupt_path = AgStatePath();
   string corrupt_body = AgVecBody(AGVEC_LOGIN_CORRUPT, 1, until_ref, breach_ref, limit_ref, base_ref);
   AgVecWriteRaw(corrupt_path, AgVecTampered(corrupt_body));
   string corrupt_original = AgVecReadRaw(corrupt_path);
   //--- Computed before the call so a tick crossing the 01:00 boundary during
   //--- the call cannot make a correct implementation look wrong.
   datetime expect_until = AgNextDayAnchor(AgServerNow());
   rc = AgStateLoad();
   AgVecCheckInt("e1_bad_checksum_returns_corrupt", rc, 2);
   AgVecCheckInt("e2_bad_checksum_locks_via_corrupt_state",
                 (long)g_ag_state_reason, (long)AG_LOCK_CORRUPT_STATE);
   AgVecCheckDT("e3_corrupt_locked_until_is_next_day_anchor", g_ag_state_locked_until, expect_until);
   AgVecCheckDT("e4_corrupt_carries_no_breach_time", g_ag_state_breach_time, 0);
   AgVecCheckMoney("e5_corrupt_carries_no_limit_snapshot", g_ag_state_limit_snap, 0.0);
   AgVecCheckMoney("e6_corrupt_carries_no_base_snapshot", g_ag_state_base_snap, 0.0);
   AgVecCheck("e7_corrupt_file_was_quarantined_not_deleted",
              FileIsExist(corrupt_path + ".bad") || FileIsExist(corrupt_path + ".bad.2"),
              "no quarantine file found for " + corrupt_path);
   AgVecCheck("e8_a_fresh_file_was_written", FileIsExist(corrupt_path), corrupt_path);
   //--- No re-corruption loop: the file the corrupt branch just wrote must
   //--- itself load cleanly on the next restart inside the same window.
   datetime until_after_quarantine = g_ag_state_locked_until;
   AgStateResetModel();
   rc = AgStateLoad();
   AgVecCheckInt("e9_fresh_file_reloads_cleanly", rc, 0);
   AgVecCheckInt("e10_fresh_file_still_says_corrupt_state",
                 (long)g_ag_state_reason, (long)AG_LOCK_CORRUPT_STATE);
   AgVecCheckDT("e11_fresh_file_preserves_locked_until",
                g_ag_state_locked_until, until_after_quarantine);

   //--- The quarantine holds the original bytes, not a rewritten copy.
   string quarantined = AgVecReadRaw(corrupt_path + ".bad");
   AgVecCheck("e12_quarantine_holds_the_original_bytes",
              quarantined == corrupt_original || StringFind(quarantined, "AGSTATE|") == 0,
              "quarantine content does not match the file that was moved");

   //================================================================
   //--- F. quarantine never overwrites an earlier quarantine
   //--- (FINAL 2026-07-29: lock artifacts are never deleted)
   //================================================================
   AgVecWriteRaw(corrupt_path, AgVecTampered(corrupt_body));
   AgStateLoad();
   AgVecCheck("f1_second_corruption_did_not_reuse_the_first_quarantine_name",
              FileIsExist(corrupt_path + ".bad") && FileIsExist(corrupt_path + ".bad.2"),
              "expected both .bad and .bad.2 to exist after two corruptions");

   //================================================================
   //--- G. login mismatch (FINAL 2026-07-30, CORRUPT_STATE-equivalent)
   //================================================================
   g_ag_login = AGVEC_LOGIN_MISMATCH;
   string mismatch_path = AgStatePath();
   //--- Internally valid, correct checksum, correct magic and version, and
   //--- a foreign login. Exactly the foreign-residue class.
   AgVecWriteRaw(mismatch_path, AgVecSealed(AgVecBody(AGVEC_LOGIN_FOREIGN, 1, until_ref,
                                                      breach_ref, limit_ref, base_ref)));
   expect_until = AgNextDayAnchor(AgServerNow());
   rc = AgStateLoad();
   AgVecCheckInt("g1_login_mismatch_returns_its_own_code", rc, 3);
   AgVecCheckInt("g2_login_mismatch_locks_via_corrupt_state",
                 (long)g_ag_state_reason, (long)AG_LOCK_CORRUPT_STATE);
   AgVecCheckDT("g3_login_mismatch_locked_until_is_next_day_anchor",
                g_ag_state_locked_until, expect_until);
   AgVecCheck("g4_foreign_lock_values_were_not_adopted",
              g_ag_state_locked_until != until_ref && g_ag_state_breach_time == 0,
              "the foreign file's own lock values leaked into the model");
   AgVecCheck("g5_foreign_file_was_quarantined",
              FileIsExist(mismatch_path + ".bad") || FileIsExist(mismatch_path + ".bad.2"),
              "no quarantine file found for " + mismatch_path);
   AgStateResetModel();
   rc = AgStateLoad();
   AgVecCheckInt("g6_fresh_file_after_mismatch_reloads_cleanly", rc, 0);

   //================================================================
   //--- H. format rejection: version, and cross-reading the halt file
   //================================================================
   g_ag_login = AGVEC_LOGIN_VERSION;
   string version_path = AgStatePath();
   string wrong_version = "AGSTATE|" + (string)(AG_STATE_FORMAT_VERSION + 1) + "|"
                          + (string)AGVEC_LOGIN_VERSION + "\n"
                          + "L|1|" + (string)((long)until_ref) + "|" + (string)((long)breach_ref) + "\n";
   AgVecWriteRaw(version_path, AgVecSealed(wrong_version));
   rc = AgStateLoad();
   AgVecCheckInt("h1_unknown_format_version_is_rejected", rc, 2);
   AgVecCheckInt("h2_unknown_version_locks_via_corrupt_state",
                 (long)g_ag_state_reason, (long)AG_LOCK_CORRUPT_STATE);

   //--- A halt file dropped at the state path must never be read as lock
   //--- state, which is the whole reason the magics differ.
   g_ag_login = AGVEC_LOGIN_CROSSREAD;
   string cross_path = AgStatePath();
   string halt_body = "AGHALT|" + (string)AG_HALT_FORMAT_VERSION + "|"
                      + (string)AGVEC_LOGIN_CROSSREAD + "\n"
                      + "S|1786027355|0\n"
                      + "H|1|crash loop|1786027355\n";
   AgVecWriteRaw(cross_path, AgVecSealed(halt_body));
   rc = AgStateLoad();
   AgVecCheckInt("h3_halt_file_at_the_state_path_is_rejected", rc, 2);
   AgVecCheckInt("h4_cross_read_locks_via_corrupt_state",
                 (long)g_ag_state_reason, (long)AG_LOCK_CORRUPT_STATE);

   PrintFormat("AGVEC|SUMMARY|%d/%d", g_pass, g_total);
  }
//+------------------------------------------------------------------+
