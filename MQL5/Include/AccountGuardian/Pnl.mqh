//+------------------------------------------------------------------+
//| AccountGuardian - Pnl.mqh                                        |
//| Day/week windows, realized + floating, base. SPEC v0.1 sec 4,    |
//| amended by A6 (Phase 1 PnL core). Read-only: no trade calls in   |
//| this file, ever. The weekly path lives here precisely so that    |
//| it is provably unable to trade (SPEC 1, 4.7).                    |
//+------------------------------------------------------------------+
#ifndef AG_PNL_MQH
#define AG_PNL_MQH

#include <AccountGuardian/Clock.mqh>

//+------------------------------------------------------------------+
//| History-select upper bound: a clock-independent constant, never  |
//| derived from TimeCurrent, so neither a frozen nor a backward-     |
//| stepping clock can truncate the window (Phase 0 obligation,      |
//| discharged here; proof in the plan section 4.3). The MQL5        |
//| datetime domain ends 3000.12.31; no deal can ever be stamped     |
//| past this bound for the life of the product.                    |
//+------------------------------------------------------------------+
#define AG_HISTORY_SELECT_TO D'3000.01.01'

//+------------------------------------------------------------------+
//| Flat epsilon, account-currency units (owner ruling, 2026-07-30). |
//| The live breach comparison errs toward breach: total <= -limit + |
//| epsilon is acceptable.                                            |
//+------------------------------------------------------------------+
#define AG_PNL_EPSILON 0.01

//+------------------------------------------------------------------+
//| Sums one deal's contribution per the ruled formula (Q3 FINAL,    |
//| 2026-08-08): profit, swap, commission and fee, uniformly over    |
//| every deal type the caller has already selected.                 |
//+------------------------------------------------------------------+
double AgDealValue(const ulong ticket)
  {
   return HistoryDealGetDouble(ticket, DEAL_PROFIT)
        + HistoryDealGetDouble(ticket, DEAL_SWAP)
        + HistoryDealGetDouble(ticket, DEAL_COMMISSION)
        + HistoryDealGetDouble(ticket, DEAL_FEE);
  }

//+------------------------------------------------------------------+
//| Realized PnL since anchor: DEAL_TYPE_BUY and DEAL_TYPE_SELL      |
//| deals only (F12 FINAL, the realized whitelist). HistorySelect's  |
//| own inclusive-from semantics already match the Q4 boundary       |
//| ruling (DEAL_TIME >= anchor counts to the new day), so no        |
//| separate comparison is needed. HistorySelect returning false is  |
//| a loud stability failure and is never read as zero deals (F6):   |
//| ok is set false and the caller must not use the return value.    |
//+------------------------------------------------------------------+
double AgRealized(const datetime anchor, bool &ok)
  {
   ok = true;
   if(!HistorySelect(anchor, AG_HISTORY_SELECT_TO))
     {
      ok = false;
      AgWarn("HistorySelect failed for the realized window, anchor="
             + TimeToString(anchor, TIME_DATE | TIME_SECONDS)
             + ": treated as a stability failure, never as zero deals");
      return 0.0;
     }
   double sum = 0.0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      long type = HistoryDealGetInteger(ticket, DEAL_TYPE);
      if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL)
         continue;
      sum += AgDealValue(ticket);
     }
   return sum;
  }

//+------------------------------------------------------------------+
//| Sum of ALL deals since anchor, trading and balance types alike   |
//| (Q2 FINAL, the day-base identity). Same failure discipline as    |
//| AgRealized. Runs its own HistorySelect: MQL5 history selection   |
//| is a single active window, so this call re-selects rather than   |
//| trusting a prior AgRealized selection to still be active.        |
//+------------------------------------------------------------------+
double AgDealsSumAll(const datetime anchor, bool &ok)
  {
   ok = true;
   if(!HistorySelect(anchor, AG_HISTORY_SELECT_TO))
     {
      ok = false;
      AgWarn("HistorySelect failed for the day-base window, anchor="
             + TimeToString(anchor, TIME_DATE | TIME_SECONDS)
             + ": treated as a stability failure, never as zero deals");
      return 0.0;
     }
   double sum = 0.0;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      sum += AgDealValue(ticket);
     }
   return sum;
  }

//+------------------------------------------------------------------+
//| Day-anchor base: current Balance minus every deal since anchor,  |
//| reconstructed live, never cached (Q2 FINAL). Deposits and        |
//| withdrawals cancel out of this identity by construction: a       |
//| deposit raises Balance and raises the all-deals sum by the same  |
//| amount, so Base is unchanged (deposit/withdrawal neutrality,     |
//| Q5, PASS-BY-CONSTRUCTION on the withdrawal side).                 |
//+------------------------------------------------------------------+
double AgDayBase(const datetime anchor, bool &ok)
  {
   double all_deals = AgDealsSumAll(anchor, ok);
   if(!ok)
      return 0.0;
   return AccountInfoDouble(ACCOUNT_BALANCE) - all_deals;
  }

//+------------------------------------------------------------------+
//| Floating PnL over every open position (F11 FINAL: a position     |
//| carried across the rollover counts its floating loss against     |
//| the day it is still open on).                                    |
//+------------------------------------------------------------------+
double AgFloating()
  {
   double sum = 0.0;
   int total = PositionsTotal();
   for(int i = 0; i < total; i++)
     {
      //--- PositionGetTicket(i) both returns the ticket AND selects that
      //--- position for the PositionGetDouble calls below (MQL5 semantics,
      //--- same pattern as HistoryDealGetTicket). PositionsTotal() can
      //--- shrink between this call and the loop's start if a position
      //--- closes mid-iteration, and PositionGetTicket then legitimately
      //--- returns 0 for the now-stale index; skipping it is correct, not
      //--- a bug to "fix" into a re-fetch or an index-shift correction.
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      sum += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return sum;
  }

//+------------------------------------------------------------------+
//| Stricter of the two enabled limit legs, min over enabled          |
//| candidates only (Q8 of the original architecture review, naive-  |
//| min trap avoided: a disabled leg, 0, never wins as "smallest").  |
//| AgValidateLimits already guarantees not both are zero.            |
//+------------------------------------------------------------------+
double AgLimitCurrency(const double base, const double percent, const double currency)
  {
   bool has_percent  = (percent > 0.0);
   bool has_currency = (currency > 0.0);
   double from_percent = has_percent ? (base * percent / 100.0) : 0.0;
   if(has_percent && has_currency)
      return MathMin(from_percent, currency);
   if(has_percent)
      return from_percent;
   return currency;
  }

//+------------------------------------------------------------------+
//| SYNCING exit gate: required_polls consecutive stable, connected  |
//| polls of HistoryDealsTotal(). Resets on any count change or on   |
//| disconnection, per the design doc's stability-counter rule.      |
//+------------------------------------------------------------------+
int  g_ag_stable_polls       = 0;
long g_ag_last_history_total = -1;

bool AgHistoryStable(const int required_polls)
  {
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
     {
      g_ag_stable_polls       = 0;
      g_ag_last_history_total = -1;
      return false;
     }
   if(!HistorySelect(0, AG_HISTORY_SELECT_TO))
     {
      g_ag_stable_polls = 0;
      AgWarn("HistorySelect failed during the SYNCING stability poll: stability counter reset");
      return false;
     }
   long total = HistoryDealsTotal();
   if(total != g_ag_last_history_total)
     {
      g_ag_last_history_total = total;
      g_ag_stable_polls       = 1;
     }
   else
      g_ag_stable_polls++;
   return g_ag_stable_polls >= required_polls;
  }

//+------------------------------------------------------------------+
//| Limit-input validation, core config class (Q4 FINAL).            |
//| Malformed is concrete: non-finite, negative, out of range, or    |
//| both limits zero. Caller returns INIT_PARAMETERS_INCORRECT.      |
//+------------------------------------------------------------------+
bool AgValidateLimits(const double percent, const double currency, string &why)
  {
   if(!MathIsValidNumber(percent))
     {
      why = "DailyLossPercent is not a finite number";
      return false;
     }
   if(!MathIsValidNumber(currency))
     {
      why = "DailyLossCurrency is not a finite number";
      return false;
     }
   if(percent < 0.0)
     {
      why = "DailyLossPercent is negative (" + DoubleToString(percent, 2) + ")";
      return false;
     }
   if(percent > 100.0)
     {
      why = "DailyLossPercent is out of range, above 100 (" + DoubleToString(percent, 2) + ")";
      return false;
     }
   if(currency < 0.0)
     {
      why = "DailyLossCurrency is negative (" + DoubleToString(currency, 2) + ")";
      return false;
     }
   if(percent == 0.0 && currency == 0.0)
     {
      why = "both limits are zero, a guardian with no limit is a config error";
      return false;
     }
   return true;
  }

#endif // AG_PNL_MQH
