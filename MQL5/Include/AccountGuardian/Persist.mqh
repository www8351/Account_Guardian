//+------------------------------------------------------------------+
//| AccountGuardian - Persist.mqh                                    |
//| Atomic file writes, checksums, halt file (Amendment A1),         |
//| single-instance mutex heartbeat. SPEC v0.1 sections 3 and 9.     |
//| Clock exemption (A1): session timestamps and the mutex heartbeat |
//| use TimeLocal; TimeCurrent freezes in dead markets, which would  |
//| fake staleness and make crash timestamps unrecordable offline.   |
//| No trade calls in this file (static-structure rule, SPEC 1).     |
//+------------------------------------------------------------------+
#ifndef AG_PERSIST_MQH
#define AG_PERSIST_MQH

#include <AccountGuardian/Log.mqh>

#define AG_FILES_DIR            "AccountGuardian"
#define AG_HALT_FORMAT_VERSION  1
#define AG_MAX_SESSIONS         32
#define AG_MUTEX_STALE_SECONDS  10

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

string AgHaltPath()    { return AG_FILES_DIR + "\\halt_" + (string)g_ag_login + ".dat"; }
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
//| Unclean sessions inside the window, current session included.    |
//+------------------------------------------------------------------+
int AgHaltUncleanCount(const int window_seconds)
  {
   datetime now = TimeLocal();   // A1 clock exemption
   int unclean = 0;
   for(int i = 0; i < g_ag_sess_count; i++)
      if(!g_ag_sess_clean[i] && now - g_ag_sess_init[i] <= window_seconds)
         unclean++;
   return unclean;
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
