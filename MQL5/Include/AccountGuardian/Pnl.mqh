//+------------------------------------------------------------------+
//| AccountGuardian - Pnl.mqh                                        |
//| Day/week windows, realized + floating, base. SPEC v0.1 sec 4.    |
//| Phase 0: declarations and the input-validation contract only.    |
//| Bodies land in Phase 1.                                          |
//| No trade calls in this file, ever. The weekly path lives here    |
//| precisely so that it is provably unable to trade (SPEC 1, 4.7).  |
//+------------------------------------------------------------------+
#ifndef AG_PNL_MQH
#define AG_PNL_MQH

#include <AccountGuardian/Clock.mqh>

//+------------------------------------------------------------------+
//| Phase 1 obligations, declared here so the contract is visible:   |
//|                                                                  |
//| double AgRealized(datetime from, datetime to)                    |
//|   DEAL_PROFIT + DEAL_SWAP + DEAL_COMMISSION over DEAL_TYPE_BUY   |
//|   and DEAL_TYPE_SELL deals only (F12 FINAL).                     |
//|                                                                  |
//| double AgFloating()                                              |
//|   POSITION_PROFIT + POSITION_SWAP over open positions.           |
//|                                                                  |
//| double AgDayBase()                                               |
//|   balance minus the sum of ALL deals since the day anchor,       |
//|   trading and balance types alike (Q2 FINAL). Never cached.      |
//|                                                                  |
//| double AgLimitCurrency(double base)                              |
//|   stricter of percent-of-base and fixed currency (Q8 FINAL).     |
//+------------------------------------------------------------------+

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
