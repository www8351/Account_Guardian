# Phase 1 Stage 3 evidence: Pnl.mqh history engine

Date: 2026-08-09. Branch: worktree-phase1-pnl-core. Static evidence
only, gathered inside an isolated git worktree with no terminal
access; no live acceptance rows are claimed here.

## What changed

`MQL5/Include/AccountGuardian/Pnl.mqh` gained bodies for every Phase 1
obligation the file previously only declared in a comment:

- `AG_HISTORY_SELECT_TO = D'3000.01.01'`, a clock-independent upper bound.
- `AgDealValue(ticket)`: DEAL_PROFIT + DEAL_SWAP + DEAL_COMMISSION + DEAL_FEE (Q3 FINAL),
  factored into one helper so the formula cannot drift between the two callers below.
- `AgRealized(anchor, ok)`: HistorySelect(anchor, AG_HISTORY_SELECT_TO), DEAL_TYPE_BUY/SELL
  whitelist (F12 FINAL). HistorySelect failure sets ok=false and WARNs, never read as zero.
- `AgDealsSumAll(anchor, ok)`: same window, all deal types (Q2 FINAL day-base identity).
- `AgDayBase(anchor, ok)`: ACCOUNT_BALANCE minus AgDealsSumAll.
- `AgFloating()`: POSITION_PROFIT + POSITION_SWAP over open positions (F11 FINAL).
- `AgLimitCurrency(base, percent, currency)`: min over enabled legs only, 0 disables a leg.
- `AgHistoryStable(required_polls)`: poll counter over HistoryDealsTotal(), resets on count
  change or disconnection (TERMINAL_CONNECTED).

## Static acceptance rows (grep, this session, quoted from the plan's own Stage 3 list)

```
$ grep -nE "OrderSend|OrderClose|trade\.(Buy|Sell|PositionClose)|CTrade" \
    MQL5/Include/AccountGuardian/Pnl.mqh MQL5/Include/AccountGuardian/Clock.mqh
(no matches)

$ grep -nE "TimeLocal|TimeGMT|TimeTradeServer" \
    MQL5/Include/AccountGuardian/Pnl.mqh MQL5/Include/AccountGuardian/Clock.mqh
MQL5/Include/AccountGuardian/Clock.mqh:7://| TimeTradeServer and TimeLocal are forbidden here.
(the only hit is the header-comment prohibition text; zero real calls)

$ grep -n "HistorySelect(" MQL5/Include/AccountGuardian/Pnl.mqh
55:   if(!HistorySelect(anchor, AG_HISTORY_SELECT_TO))
88:   if(!HistorySelect(anchor, AG_HISTORY_SELECT_TO))
177:  if(!HistorySelect(0, AG_HISTORY_SELECT_TO))
(every call's upper bound is the AG_HISTORY_SELECT_TO constant; none derives from a clock call)

$ grep -n "DEAL_FEE\|DEAL_PROFIT\|DEAL_SWAP\|DEAL_COMMISSION" MQL5/Include/AccountGuardian/Pnl.mqh
37:   return HistoryDealGetDouble(ticket, DEAL_PROFIT)
38:        + HistoryDealGetDouble(ticket, DEAL_SWAP)
39:        + HistoryDealGetDouble(ticket, DEAL_COMMISSION)
40:        + HistoryDealGetDouble(ticket, DEAL_FEE);
(DEAL_FEE reads alongside the other three in AgDealValue, which both AgRealized and
AgDealsSumAll/AgDayBase call; the formula cannot appear in one and not the other)
```

## Compile: not attempted this session

Stage 2's evidence already recorded why: MetaEditor's include resolution roots to the
deployed terminal MQL5 tree, not this worktree, and deploying into that tree is a
Stage 5 action reserved for the owner. No compile log is claimed for Stage 3 either.

## Owner-review finding 3, fixed 2026-08-09: AgFloating stale-selection comment

Owner review of tip `e5d32bc` flagged `AgFloating()`'s loop with no explanation of why a
`ticket == 0` skip is correct rather than a bug: `PositionGetTicket(i)` both returns and
selects the position (MQL5 semantics, same pattern as `HistoryDealGetTicket`), so a
position closing mid-loop (`PositionsTotal()` having shrunk since the loop started) makes
`PositionGetTicket` legitimately return 0 for a now-stale index. No logic change; an
explanatory comment was added inline so a future reader does not "fix" the skip into a
re-fetch or an index-shift correction.

## Status

Static evidence: DONE, this session. Live/compile acceptance: OPEN, Stage 5 owner gate.
