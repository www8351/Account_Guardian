//+------------------------------------------------------------------+
//| AccountGuardian - Persist.mqh                                    |
//| Atomic file writes, checksums, halt file (Amendment A1), lock    |
//| state file (Phase 2 Stage 2, design doc item 5), single-instance |
//| mutex heartbeat. SPEC v0.1 sections 3 and 9.                     |
//| Clock exemption (A1): session timestamps and the mutex heartbeat |
//| use TimeLocal; TimeCurrent freezes in dead markets, which would  |
//| fake staleness and make crash timestamps unrecordable offline.   |
//| THE A1 EXEMPTION STOPS AT THE HALT FILE AND THE MUTEX. The lock  |
//| state file's locked_until and breach_time are Q7 (FINAL) fields  |
//| and use TimeCurrent through AgServerNow exclusively; copying the |
//| TimeLocal pattern below into them by analogy is the one mistake  |
//| the design doc names in advance.                                 |
//| No trade calls in this file (static-structure rule, SPEC 1).     |
//+------------------------------------------------------------------+
#ifndef AG_PERSIST_MQH
#define AG_PERSIST_MQH

#include <AccountGuardian/Log.mqh>
#include <AccountGuardian/Clock.mqh>
#include <AccountGuardian/State.mqh>

#define AG_FILES_DIR            "AccountGuardian"
#define AG_HALT_FORMAT_VERSION  1
#define AG_STATE_FORMAT_VERSION 1
#define AG_MAX_SESSIONS         32
#define AG_MUTEX_STALE_SECONDS  10

//--- Money fields are persisted at 8 decimals, not 2. The limit snapshot
//--- is a derived value (base * percent / 100) that carries more precision
//--- than the cent the banner prints: base 1985.97 at 5 percent is 99.2985,
//--- displayed 99.30. Q6 says the locked window is judged by the snapshot,
//--- so rounding it on the way to disk would change the enforced limit on
//--- every restart. The 0.01 epsilon of 2026-07-30 is a comparison rule,
//--- not a storage format.
#define AG_STATE_MONEY_DIGITS   8

// --- halt file in-memory model -------------------------------------
long     g_ag_login = 0;

datetime g_ag_sess_init[AG_MAX_SESSIONS];
bool     g_ag_sess_clean[AG_MAX_SESSIONS];
int      g_ag_sess_count = 0;
int      g_ag_current_session = -1;

bool     g_ag_halt_flag   = false;
string   g_ag_halt_reason = "";
datetime g_ag_halt_time   = 0;

// A save path must never write a model that was never loaded. A refused
// init returns before AgHaltLoad, so the model is default-constructed
// empty, and writing that erases every session record and clears a
// persisted halt flag on disk. See the bypass in SPEC section 7.
bool     g_ag_halt_loaded = false;

// --- mutex ----------------------------------------------------------
double   g_ag_instance_id = 0.0;

// --- lock state file in-memory model (design doc item 5) -------------
// Its own model, mirroring the halt file's, rather than writing State.mqh's
// live globals straight to disk. Stage 3 copies between the two at the one
// point that declares a lock; keeping them separate is what lets this file
// be loaded, quarantined and reset without touching the running state
// machine, which is exactly what the corrupt branch below has to do.
ENUM_AG_LOCK_REASON g_ag_state_reason        = AG_LOCK_NONE;
datetime            g_ag_state_locked_until  = 0;   // Q7: TimeCurrent basis
datetime            g_ag_state_breach_time   = 0;   // Q7: TimeCurrent basis
double              g_ag_state_limit_snap    = 0.0; // Q6 snapshot
double              g_ag_state_base_snap     = 0.0; // Q6 snapshot

// Same obligation as g_ag_halt_loaded, and FINAL in its own right since
// 2026-07-29: "a persistence model that was never loaded is never written",
// stated there as binding beyond the halt file and naming the lock state
// file explicitly.
bool     g_ag_state_loaded = false;

string AgHaltPath()    { return AG_FILES_DIR + "\\halt_" + (string)g_ag_login + ".dat"; }
string AgStatePath()   { return AG_FILES_DIR + "\\state_" + (string)g_ag_login + ".dat"; }
string AgGvHeartbeat() { return "AG_HB_" + (string)g_ag_login; }
string AgGvInstance()  { return "AG_ID_" + (string)g_ag_login; }
string AgGvHaltFlag()  { return "AG_HALT_" + (string)g_ag_login; }

//+------------------------------------------------------------------+
//| FNV-1a over a string. Torn-write detector, not tamper defense:   |
//| forgery is layered against elsewhere (SPEC 4.6, threat model).   |
//+------------------------------------------------------------------+
uint AgChecksum(const string payload)
  {
   uchar bytes[];
   int n = StringToCharArray(payload, bytes, 0, WHOLE_ARRAY, CP_UTF8);
   uint hash = 2166136261;
   for(int i = 0; i < n - 1; i++)   // n-1: skip trailing NUL
     {
      hash ^= (uint)bytes[i];
      hash *= 16777619;
     }
   return hash;
  }

//+------------------------------------------------------------------+
//| Atomic write: tmp, FileFlush, FileMove FILE_REWRITE (SPEC 3).    |
//| Failures are loud and reported to the caller.                    |
//+------------------------------------------------------------------+
bool AgAtomicWrite(const string path, const string content)
  {
   if(!FolderCreate(AG_FILES_DIR))
     {
      if(GetLastError() != 0 && !FileIsExist(path) && GetLastError() != 5019) // 5019: file exists
         AgVerbose("FolderCreate note, error " + (string)GetLastError());
     }
   string tmp = path + ".tmp";
   int handle = FileOpen(tmp, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
     {
      AgAlertEvent("state-write failure: cannot open " + tmp + ", error " + (string)GetLastError());
      return false;
     }
   FileWriteString(handle, content);
   FileFlush(handle);
   FileClose(handle);
   if(!FileMove(tmp, 0, path, FILE_REWRITE))
     {
      AgAlertEvent("state-write failure: cannot rename " + tmp + " onto " + path + ", error " + (string)GetLastError());
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Serialize the halt model. Checksum line last.                    |
//+------------------------------------------------------------------+
string AgHaltSerialize()
  {
   string body = "AGHALT|" + (string)AG_HALT_FORMAT_VERSION + "|" + (string)g_ag_login + "\n";
   for(int i = 0; i < g_ag_sess_count; i++)
      body += "S|" + (string)((long)g_ag_sess_init[i]) + "|" + (g_ag_sess_clean[i] ? "1" : "0") + "\n";
   body += "H|" + (g_ag_halt_flag ? "1" : "0") + "|" + g_ag_halt_reason + "|" + (string)((long)g_ag_halt_time) + "\n";
   body += "C|" + (string)AgChecksum(body) + "\n";
   return body;
  }

bool AgHaltSave()
  {
   return AgAtomicWrite(AgHaltPath(), AgHaltSerialize());
  }

//+------------------------------------------------------------------+
//| Load halt file. Returns: 0 = loaded, 1 = missing, 2 = corrupt.   |
//| Corrupt: quarantine as .bad, loud WARN, model reset (A1 policy:  |
//| fails toward the guardian running, because SAFE_HALT means no    |
//| protection at all).                                              |
//+------------------------------------------------------------------+
int AgHaltLoad()
  {
   g_ag_sess_count = 0;
   g_ag_halt_flag = false;
   g_ag_halt_reason = "";
   g_ag_halt_time = 0;

   // Every exit below leaves a deliberately initialized model: loaded from
   // a valid file, empty because no file exists, or reset after quarantine.
   // All three are legitimate to persist; only never-loaded is not.
   g_ag_halt_loaded = true;

   string path = AgHaltPath();
   if(!FileIsExist(path))
      return 1;

   int handle = FileOpen(path, FILE_READ | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
     {
      AgWarn("halt file exists but cannot be opened, error " + (string)GetLastError());
      return 2;
     }

   string body = "";
   string checksum_line = "";
   bool ok = false;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      if(StringFind(line, "C|") == 0)
        {
         checksum_line = line;
         ok = true;
         break;
        }
      body += line + "\n";
     }
   FileClose(handle);

   bool valid = ok && (checksum_line == "C|" + (string)AgChecksum(body));
   if(valid)
     {
      string lines[];
      int count = StringSplit(body, '\n', lines);
      if(count < 2 || StringFind(lines[0], "AGHALT|" + (string)AG_HALT_FORMAT_VERSION + "|") != 0)
         valid = false;
      else
        {
         for(int i = 1; i < count; i++)
           {
            string fields[];
            if(StringSplit(lines[i], '|', fields) < 2)
               continue;
            if(fields[0] == "S" && g_ag_sess_count < AG_MAX_SESSIONS)
              {
               g_ag_sess_init[g_ag_sess_count]  = (datetime)StringToInteger(fields[1]);
               g_ag_sess_clean[g_ag_sess_count] = (ArraySize(fields) > 2 && fields[2] == "1");
               g_ag_sess_count++;
              }
            else if(fields[0] == "H" && ArraySize(fields) >= 4)
              {
               g_ag_halt_flag   = (fields[1] == "1");
               g_ag_halt_reason = fields[2];
               g_ag_halt_time   = (datetime)StringToInteger(fields[3]);
              }
           }
        }
     }

   if(!valid)
     {
      string bad = path + ".bad";
      FileMove(path, 0, bad, FILE_REWRITE);
      AgWarn("halt file failed checksum, quarantined as " + bad + ", starting fresh (A1 corruption policy)");
      g_ag_sess_count = 0;
      g_ag_halt_flag = false;
      g_ag_halt_reason = "";
      g_ag_halt_time = 0;
      return 2;
     }
   return 0;
  }

//+------------------------------------------------------------------+
//| Append the current session as unclean; prune to AG_MAX_SESSIONS. |
//+------------------------------------------------------------------+
void AgHaltAppendSession()
  {
   if(g_ag_sess_count >= AG_MAX_SESSIONS)
     {
      for(int i = 1; i < g_ag_sess_count; i++)
        {
         g_ag_sess_init[i - 1]  = g_ag_sess_init[i];
         g_ag_sess_clean[i - 1] = g_ag_sess_clean[i];
        }
      g_ag_sess_count--;
     }
   g_ag_sess_init[g_ag_sess_count]  = TimeLocal();   // A1 clock exemption
   g_ag_sess_clean[g_ag_sess_count] = false;
   g_ag_current_session = g_ag_sess_count;
   g_ag_sess_count++;
  }

//+------------------------------------------------------------------+
//| Consecutive unclean sessions ending at the newest record (R1).    |
//| Walks back from the newest session, which is the current one and  |
//| is unclean by construction, and stops at the first clean record   |
//| or the first adjacent init pair further apart than the bound.     |
//|                                                                   |
//| Anchored on adjacent init pairs, never on "now": that is what     |
//| makes a clean record reset the chain, so routine re-inits cannot  |
//| accumulate toward SAFE_HALT while genuine deaths still do.        |
//|                                                                   |
//| A backward local clock step gives a negative gap, which counts as |
//| inside the bound. Breaking the chain on a negative gap would let  |
//| one clock change disarm the count in a single step, worse than    |
//| the compression residual the SPEC threat model already accepts.   |
//+------------------------------------------------------------------+
int AgHaltUncleanChain(const int max_gap_seconds)
  {
   int chain = 0;
   for(int i = g_ag_sess_count - 1; i >= 0; i--)
     {
      if(g_ag_sess_clean[i])
         break;
      if(i < g_ag_sess_count - 1
         && (long)g_ag_sess_init[i + 1] - (long)g_ag_sess_init[i] > (long)max_gap_seconds)
         break;
      chain++;
     }
   return chain;
  }

void AgHaltMarkClean()
  {
   if(g_ag_current_session >= 0 && g_ag_current_session < g_ag_sess_count)
      g_ag_sess_clean[g_ag_current_session] = true;
  }

void AgHaltSetFlag(const string reason)
  {
   g_ag_halt_flag   = true;
   g_ag_halt_reason = reason;
   g_ag_halt_time   = TimeLocal();   // A1 clock exemption
  }

//+------------------------------------------------------------------+
//| LOCK STATE FILE (Phase 2 Stage 2, design doc item 5, SPEC 3)     |
//|                                                                  |
//| Charter-constrained to lock state only. SAFE_HALT evidence lives |
//| in the halt file and does not belong here (Amendment 2a FINAL:   |
//| "the state file is charter-constrained to lock state only and    |
//| SAFE_HALT is explicitly not a lock"). No freshness field either: |
//| the stale quote ruling of 2026-08-18 makes a snapshot taken from |
//| a frozen quote valid BY DESIGN, so there is nothing to record.   |
//| No floating baseline either, per question FIVE of the same date. |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| A free quarantine name, never one that would overwrite an        |
//| existing quarantine.                                             |
//|                                                                  |
//| The design doc says to reuse the halt file's plain ".bad" move.  |
//| Deviating deliberately, and the ground is a FINAL entry that     |
//| outranks the convenience: "lock artifacts are never deleted,     |
//| only quarantined" (2026-07-29), which a FileMove FILE_REWRITE    |
//| onto an existing .bad would silently break on the second         |
//| corruption. The halt file's own single-name pattern is left      |
//| exactly as it is; SAFE_HALT evidence is not a lock artifact and  |
//| that path is out of Stage 2's scope.                             |
//+------------------------------------------------------------------+
string AgStateQuarantinePath(const string path)
  {
   string candidate = path + ".bad";
   if(!FileIsExist(candidate))
      return candidate;
   for(int i = 2; i < 1000; i++)
     {
      candidate = path + ".bad." + (string)i;
      if(!FileIsExist(candidate))
         return candidate;
     }
   return path + ".bad.overflow";
  }

//+------------------------------------------------------------------+
//| Serialize the lock state model. Checksum line last, same shape   |
//| as AgHaltSerialize so the two read alike.                        |
//| Magic is AGSTATE, deliberately distinct from AGHALT, so the two  |
//| formats can never cross-read even if the paths were swapped.     |
//+------------------------------------------------------------------+
string AgStateSerialize()
  {
   string body = "AGSTATE|" + (string)AG_STATE_FORMAT_VERSION + "|" + (string)g_ag_login + "\n";
   body += "L|" + (string)(int)g_ag_state_reason
           + "|" + (string)((long)g_ag_state_locked_until)
           + "|" + (string)((long)g_ag_state_breach_time) + "\n";
   body += "N|" + DoubleToString(g_ag_state_limit_snap, AG_STATE_MONEY_DIGITS)
           + "|" + DoubleToString(g_ag_state_base_snap, AG_STATE_MONEY_DIGITS) + "\n";
   body += "C|" + (string)AgChecksum(body) + "\n";
   return body;
  }

//+------------------------------------------------------------------+
//| Write the lock state file. Refuses loudly, never silently, if    |
//| the model was never loaded (FINAL 2026-07-29, binding on this    |
//| file by name). Mirrors the OnDeinit gate on the halt file.       |
//+------------------------------------------------------------------+
bool AgStateSave()
  {
   if(!g_ag_state_loaded)
     {
      AgWarn("state file NOT written: the lock state model was never loaded this session,"
             " so writing it would overwrite a real lock with a default-constructed empty one");
      return false;
     }
   return AgAtomicWrite(AgStatePath(), AgStateSerialize());
  }

void AgStateResetModel()
  {
   g_ag_state_reason       = AG_LOCK_NONE;
   g_ag_state_locked_until = 0;
   g_ag_state_breach_time  = 0;
   g_ag_state_limit_snap   = 0.0;
   g_ag_state_base_snap    = 0.0;
  }

//+------------------------------------------------------------------+
//| Q6 (FINAL): at breach, limit and base are snapshotted here and   |
//| the locked window is judged by the snapshot, never by live       |
//| inputs. Model mutator only, no I/O, mirroring AgHaltSetFlag.     |
//| Both datetimes are TimeCurrent-basis values supplied by the      |
//| caller; this function reads no clock at all, which is what keeps |
//| the A1 TimeLocal exemption out of Q7's fields.                   |
//+------------------------------------------------------------------+
void AgStateSetBreach(const datetime locked_until, const datetime breach_time,
                      const double limit_snapshot, const double base_snapshot)
  {
   g_ag_state_reason       = AG_LOCK_DAILY_BREACH;
   g_ag_state_locked_until = locked_until;
   g_ag_state_breach_time  = breach_time;
   g_ag_state_limit_snap   = limit_snapshot;
   g_ag_state_base_snap    = base_snapshot;
  }

//+------------------------------------------------------------------+
//| CORRUPT_STATE carries no snapshots: there was no breach          |
//| computation behind it, so limit and base are unset rather than   |
//| zero-as-a-value (design doc item 5, "unset/0 for CORRUPT_STATE").|
//+------------------------------------------------------------------+
void AgStateSetCorrupt(const datetime locked_until)
  {
   g_ag_state_reason       = AG_LOCK_CORRUPT_STATE;
   g_ag_state_locked_until = locked_until;
   g_ag_state_breach_time  = 0;
   g_ag_state_limit_snap   = 0.0;
   g_ag_state_base_snap    = 0.0;
  }

//+------------------------------------------------------------------+
//| Quarantine the current file, reset the model to CORRUPT_STATE,   |
//| and write a fresh valid file. Shared by the corrupt branch and   |
//| the login-mismatch branch, which the 2026-07-30 FINAL ruling     |
//| makes the same outcome.                                          |
//|                                                                  |
//| The fresh write is legitimate under never-loaded-never-written   |
//| because g_ag_state_loaded was set true earlier in this same      |
//| call: this is the "reset after quarantine" deliberate            |
//| initialization branch, exactly as AgHaltLoad already does it.    |
//|                                                                  |
//| locked_until is computed NOW from AgServerNow and is never read  |
//| back from the failed file, which is the SPEC's own explicit rule |
//| and the reason a corrupt file cannot dictate its own lock        |
//| window. On a later restart still inside that window this fresh   |
//| file is itself valid and loads cleanly, so there is no           |
//| re-corruption loop.                                              |
//+------------------------------------------------------------------+
int AgStateQuarantine(const string path, const int code, const string why)
  {
   string bad = AgStateQuarantinePath(path);
   if(!FileMove(path, 0, bad, FILE_REWRITE))
      AgWarn("state file quarantine move FAILED onto " + bad + ", error " + (string)GetLastError()
             + "; the fresh CORRUPT_STATE file below will overwrite it in place");
   AgStateSetCorrupt(AgNextDayAnchor(AgServerNow()));
   AgWarn("state file " + why + ", quarantined as " + bad
          + ", locking via CORRUPT_STATE until "
          + TimeToString(g_ag_state_locked_until, TIME_DATE | TIME_SECONDS)
          + " and writing a fresh file");
   AgStateSave();
   return code;
  }

//+------------------------------------------------------------------+
//| Load the lock state file.                                        |
//| Returns: 0 = loaded, 1 = missing, 2 = corrupt, 3 = login         |
//| mismatch. 2 and 3 are handled IDENTICALLY per the FINAL ruling   |
//| of 2026-07-30 that a valid file carrying a foreign login is      |
//| CORRUPT_STATE-equivalent; they are returned distinctly only so   |
//| the caller can say which one happened in the journal.            |
//|                                                                  |
//| Corrupt and mismatch both: quarantine, loud WARN, reset the      |
//| model to CORRUPT_STATE with locked_until = next day anchor       |
//| computed NOW, and write that fresh file. Errs locked and loud.   |
//|                                                                  |
//| Missing is NOT corrupt and NOT trusted as unlocked: the model    |
//| defaults to NONE/0 and the OR-of-three-witnesses formula still   |
//| checks GV and derived history independently (design doc item 4). |
//+------------------------------------------------------------------+
int AgStateLoad()
  {
   AgStateResetModel();

   // Set before the file-exists check, exactly where g_ag_halt_loaded sits.
   // Every exit below leaves a deliberately initialized model: loaded from a
   // valid file, empty because no file exists, or reset after quarantine.
   // All three are legitimate to persist; only never-loaded is not.
   g_ag_state_loaded = true;

   string path = AgStatePath();
   if(!FileIsExist(path))
      return 1;

   int handle = FileOpen(path, FILE_READ | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
     {
      AgWarn("state file exists but cannot be opened, error " + (string)GetLastError());
      return AgStateQuarantine(path, 2, "cannot be opened");
     }

   string body = "";
   string checksum_line = "";
   bool ok = false;
   while(!FileIsEnding(handle))
     {
      string line = FileReadString(handle);
      if(StringFind(line, "C|") == 0)
        {
         checksum_line = line;
         ok = true;
         break;
        }
      body += line + "\n";
     }
   FileClose(handle);

   bool valid = ok && (checksum_line == "C|" + (string)AgChecksum(body));
   long file_login = 0;
   if(valid)
     {
      string lines[];
      int count = StringSplit(body, '\n', lines);
      string header[];
      if(count < 2
         || StringSplit(lines[0], '|', header) < 3
         || header[0] != "AGSTATE"
         || header[1] != (string)AG_STATE_FORMAT_VERSION)
         valid = false;
      else
        {
         file_login = StringToInteger(header[2]);
         for(int i = 1; i < count; i++)
           {
            string fields[];
            if(StringSplit(lines[i], '|', fields) < 2)
               continue;
            if(fields[0] == "L" && ArraySize(fields) >= 4)
              {
               g_ag_state_reason       = (ENUM_AG_LOCK_REASON)(int)StringToInteger(fields[1]);
               g_ag_state_locked_until = (datetime)StringToInteger(fields[2]);
               g_ag_state_breach_time  = (datetime)StringToInteger(fields[3]);
              }
            else if(fields[0] == "N" && ArraySize(fields) >= 3)
              {
               g_ag_state_limit_snap = StringToDouble(fields[1]);
               g_ag_state_base_snap  = StringToDouble(fields[2]);
              }
           }
        }
     }

   if(!valid)
      return AgStateQuarantine(path, 2, "failed checksum or does not parse");

   //--- A file that is internally valid but belongs to a different account.
   //--- Distinct from the checksum check by design: this project has already
   //--- been bitten once by foreign-project residue sitting at an expected
   //--- path (2026-07-29 residue finding).
   if(file_login != g_ag_login)
      return AgStateQuarantine(path, 3,
                               "carries login " + (string)file_login
                               + " but this account is " + (string)g_ag_login);

   return 0;
  }

//+------------------------------------------------------------------+
//| Single-instance mutex heartbeat (SPEC 5, F8).                    |
//| Live other instance: refuse. Stale mutex heartbeat: takeover.    |
//| Mutex heartbeat 0 = deliberate release by a clean OnDeinit.      |
//|                                                                  |
//| A frozen mutex heartbeat always reads stale, and staleness       |
//| authorizes takeover, so a refresh that silently stops disarms    |
//| single-instance protection completely. Every write is therefore  |
//| checked and logged rather than assumed.                          |
//+------------------------------------------------------------------+
bool AgMutexAcquire()
  {
   double hb = 0.0;
   if(GlobalVariableGet(AgGvHeartbeat(), hb) && hb > 0.5)
     {
      double age = (double)TimeLocal() - hb;   // A1 clock exemption
      if(age < AG_MUTEX_STALE_SECONDS)
         return false;                          // live instance holds it
      AgWarn("stale mutex heartbeat (" + DoubleToString(age, 0) + "s), taking over crashed-instance mutex");
     }
   g_ag_instance_id = (double)GetTickCount() * 65536.0 + (double)MathRand();

   string   id_name = AgGvInstance();
   string   hb_name = AgGvHeartbeat();
   datetime hb_now  = TimeLocal();             // A1 clock exemption

   bool id_set = GlobalVariableSet(id_name, g_ag_instance_id) > 0;
   bool hb_set = GlobalVariableSet(hb_name, (double)hb_now) > 0;
   GlobalVariablesFlush();

   AgInfo("mutex acquire|id_name=" + id_name + "|id_set=" + (id_set ? "1" : "0")
          + "|id_exists=" + (GlobalVariableCheck(id_name) ? "1" : "0")
          + "|hb_name=" + hb_name + "|hb_set=" + (hb_set ? "1" : "0")
          + "|hb_exists=" + (GlobalVariableCheck(hb_name) ? "1" : "0")
          + "|hb_value=" + (string)((long)hb_now));

   if(!id_set || !hb_set)
      AgAlertEvent("mutex write failed at acquire, single-instance protection is not in force"
                   + " (id_set=" + (id_set ? "1" : "0") + ", hb_set=" + (hb_set ? "1" : "0")
                   + ", error " + (string)GetLastError() + ")");
   return true;
  }

//+------------------------------------------------------------------+
//| Called from the first timer tick onward in EVERY state. Guardian |
//| liveness does not depend on history sync, breach evaluation, or  |
//| anything downstream, so nothing may gate this.                   |
//+------------------------------------------------------------------+
void AgMutexRefresh()
  {
   double id = 0.0;
   if(GlobalVariableGet(AgGvInstance(), id) && id != g_ag_instance_id)
     {
      AgAlertEvent("instance mutex overwritten by another instance, this should not happen");
      return;
     }
   datetime hb_now = TimeLocal();              // A1 clock exemption
   if(GlobalVariableSet(AgGvHeartbeat(), (double)hb_now) == 0)
      AgWarn("mutex heartbeat refresh failed, error " + (string)GetLastError()
             + ", takeover protection is degraded");
   GlobalVariablesFlush();
  }

void AgMutexRelease()
  {
   double id = 0.0;
   if(GlobalVariableGet(AgGvInstance(), id) && id == g_ag_instance_id)
     {
      GlobalVariableSet(AgGvHeartbeat(), 0.0);   // deliberate-release marker
      GlobalVariablesFlush();
     }
  }

#endif // AG_PERSIST_MQH
