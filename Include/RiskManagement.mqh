//+------------------------------------------------------------------+
//|                                        RiskManagement.mqh        |
//|                         Risk Management Module                   |
//+------------------------------------------------------------------+
#property copyright "Institutional EA"

//+------------------------------------------------------------------+
//| Risk Management Class                                            |
//+------------------------------------------------------------------+
class CRiskManagement
{
private:
   //--- Capital Parameters
   double   m_initialCapital;
   double   m_startLot;
   double   m_maxLot;
   double   m_riskPercent;
   double   m_maxRiskPercent;

   //--- Drawdown Limits
   double   m_maxDailyDD;
   double   m_maxWeeklyDD;
   double   m_maxMonthlyDD;
   double   m_maxGlobalDD;
   int      m_maxConsLosses;

   //--- Tracking
   double   m_dailyStartBalance;
   double   m_weeklyStartBalance;
   double   m_monthlyStartBalance;
   double   m_peakBalance;
   int      m_consecutiveLosses;
   int      m_totalTrades;
   int      m_winningTrades;
   double   m_totalProfit;
   double   m_totalLoss;
   double   m_maxDrawdown;

   //--- Time tracking
   datetime m_lastDayCheck;
   datetime m_lastWeekCheck;
   datetime m_lastMonthCheck;

   //--- State
   bool     m_tradingBlocked;
   string   m_blockReason;
   bool     m_initialized;

public:
   CRiskManagement() : m_initialized(false), m_tradingBlocked(false), 
                        m_consecutiveLosses(0), m_totalTrades(0),
                        m_winningTrades(0), m_totalProfit(0), m_totalLoss(0),
                        m_maxDrawdown(0) {}
   ~CRiskManagement() {}

   //+------------------------------------------------------------------+
   //| Initialize Risk Management                                        |
   //+------------------------------------------------------------------+
   bool Initialize(double initialCapital, double startLot, double maxLot,
                   double riskPercent, double maxRiskPercent,
                   double maxDailyDD, double maxWeeklyDD, 
                   double maxMonthlyDD, double maxGlobalDD,
                   int maxConsLosses)
   {
      m_initialCapital   = initialCapital;
      m_startLot         = startLot;
      m_maxLot           = maxLot;
      m_riskPercent      = riskPercent;
      m_maxRiskPercent   = maxRiskPercent;
      m_maxDailyDD       = maxDailyDD;
      m_maxWeeklyDD      = maxWeeklyDD;
      m_maxMonthlyDD     = maxMonthlyDD;
      m_maxGlobalDD      = maxGlobalDD;
      m_maxConsLosses    = maxConsLosses;

      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_dailyStartBalance   = balance;
      m_weeklyStartBalance  = balance;
      m_monthlyStartBalance = balance;
      m_peakBalance         = balance;

      m_lastDayCheck   = TimeCurrent();
      m_lastWeekCheck  = TimeCurrent();
      m_lastMonthCheck = TimeCurrent();

      m_initialized = true;
      return true;
   }

   //+------------------------------------------------------------------+
   //| Check if trading is allowed                                       |
   //+------------------------------------------------------------------+
   bool IsTradingAllowed()
   {
      if(!m_initialized) return false;

      //--- Update period tracking
      UpdatePeriodTracking();

      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);

      //--- Update peak balance
      if(balance > m_peakBalance)
         m_peakBalance = balance;

      //--- Check Daily Drawdown
      double dailyDD = (m_dailyStartBalance - equity) / m_dailyStartBalance * 100.0;
      if(dailyDD > m_maxDailyDD)
      {
         m_tradingBlocked = true;
         m_blockReason = StringFormat("Daily DD: %.2f%% > %.2f%%", dailyDD, m_maxDailyDD);
         return false;
      }

      //--- Check Weekly Drawdown
      double weeklyDD = (m_weeklyStartBalance - equity) / m_weeklyStartBalance * 100.0;
      if(weeklyDD > m_maxWeeklyDD)
      {
         m_tradingBlocked = true;
         m_blockReason = StringFormat("Weekly DD: %.2f%% > %.2f%%", weeklyDD, m_maxWeeklyDD);
         return false;
      }

      //--- Check Monthly Drawdown
      double monthlyDD = (m_monthlyStartBalance - equity) / m_monthlyStartBalance * 100.0;
      if(monthlyDD > m_maxMonthlyDD)
      {
         m_tradingBlocked = true;
         m_blockReason = StringFormat("Monthly DD: %.2f%% > %.2f%%", monthlyDD, m_maxMonthlyDD);
         return false;
      }

      //--- Check Global Drawdown
      double globalDD = (m_peakBalance - equity) / m_peakBalance * 100.0;
      if(globalDD > m_maxGlobalDD)
      {
         m_tradingBlocked = true;
         m_blockReason = StringFormat("Global DD: %.2f%% > %.2f%%", globalDD, m_maxGlobalDD);
         return false;
      }

      //--- Track max drawdown
      if(globalDD > m_maxDrawdown)
         m_maxDrawdown = globalDD;

      //--- Check Consecutive Losses
      if(m_consecutiveLosses >= m_maxConsLosses)
      {
         m_tradingBlocked = true;
         m_blockReason = StringFormat("Consecutive Losses: %d >= %d", 
                                       m_consecutiveLosses, m_maxConsLosses);
         return false;
      }

      //--- Equity Protection (emergency)
      if(equity < m_initialCapital * 0.85) // 15% equity protection
      {
         m_tradingBlocked = true;
         m_blockReason = "EMERGENCY: Equity below 85% of initial capital";
         return false;
      }

      m_tradingBlocked = false;
      m_blockReason = "";
      return true;
   }

   //+------------------------------------------------------------------+
   //| Calculate dynamic lot size                                        |
   //+------------------------------------------------------------------+
   double CalculateLotSize(string symbol, double stopLossDistance)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);

      //--- Use minimum of balance and equity for safety
      double accountValue = MathMin(balance, equity);

      //--- Dynamic risk adjustment
      double adjustedRisk = GetAdjustedRisk();

      //--- Calculate monetary risk
      double riskAmount = accountValue * (adjustedRisk / 100.0);

      //--- Get symbol specifications
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

      if(tickValue <= 0 || tickSize <= 0 || stopLossDistance <= 0)
         return m_startLot;

      //--- Calculate lot size
      double ticksInSL = stopLossDistance / tickSize;
      double lotSize = riskAmount / (ticksInSL * tickValue);

      //--- Apply constraints
      lotSize = MathMax(lotSize, minLot);
      lotSize = MathMin(lotSize, m_maxLot);
      lotSize = MathMin(lotSize, maxLot);

      //--- Round to lot step
      lotSize = MathFloor(lotSize / lotStep) * lotStep;

      //--- Final safety check
      if(lotSize < minLot) lotSize = minLot;

      return NormalizeDouble(lotSize, 2);
   }

   //+------------------------------------------------------------------+
   //| Get adjusted risk based on performance                            |
   //+------------------------------------------------------------------+
   double GetAdjustedRisk()
   {
      double risk = m_riskPercent;

      //--- Reduce risk after losses
      if(m_consecutiveLosses >= 1) risk *= 0.75;
      if(m_consecutiveLosses >= 2) risk *= 0.75;

      //--- Reduce risk during drawdown
      double currentDD = GetCurrentDrawdown();
      if(currentDD > 3.0) risk *= 0.5;
      else if(currentDD > 2.0) risk *= 0.75;

      //--- Increase risk when performing well (conservative)
      double winRate = GetWinRate();
      if(winRate > 60.0 && m_totalTrades > 20 && m_consecutiveLosses == 0)
         risk *= 1.1; // Only 10% increase

      //--- Clamp
      risk = MathMax(risk, 0.25);  // Minimum 0.25%
      risk = MathMin(risk, m_maxRiskPercent);

      return risk;
   }

   //+------------------------------------------------------------------+
   //| On Trade Opened                                                   |
   //+------------------------------------------------------------------+
   void OnTradeOpened(double lotSize)
   {
      m_totalTrades++;
   }

   //+------------------------------------------------------------------+
   //| On Trade Event (check closed positions)                           |
   //+------------------------------------------------------------------+
   void OnTradeEvent()
   {
      //--- Check recent history for closed trades
      datetime fromDate = TimeCurrent() - 60; // Last 60 seconds
      HistorySelect(fromDate, TimeCurrent());

      int totalDeals = HistoryDealsTotal();
      for(int i = totalDeals - 1; i >= 0; i--)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0) continue;

         int dealEntry = (int)HistoryDealGetInteger(ticket, DEAL_ENTRY);
         if(dealEntry != DEAL_ENTRY_OUT) continue;

         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + 
                         HistoryDealGetDouble(ticket, DEAL_SWAP) +
                         HistoryDealGetDouble(ticket, DEAL_COMMISSION);

         if(profit > 0)
         {
            m_winningTrades++;
            m_totalProfit += profit;
            m_consecutiveLosses = 0;
         }
         else if(profit < 0)
         {
            m_totalLoss += MathAbs(profit);
            m_consecutiveLosses++;
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Getters for Dashboard                                             |
   //+------------------------------------------------------------------+
   double GetBalance()          { return AccountInfoDouble(ACCOUNT_BALANCE); }
   double GetEquity()           { return AccountInfoDouble(ACCOUNT_EQUITY); }
   double GetCurrentDrawdown()  
   { 
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      return (m_peakBalance > 0) ? (m_peakBalance - eq) / m_peakBalance * 100.0 : 0;
   }
   double GetMaxDrawdown()      { return m_maxDrawdown; }
   double GetWinRate()          
   { 
      return (m_totalTrades > 0) ? (double)m_winningTrades / m_totalTrades * 100.0 : 0;
   }
   double GetProfitFactor()     
   { 
      return (m_totalLoss > 0) ? m_totalProfit / m_totalLoss : 
             (m_totalProfit > 0) ? 99.9 : 0;
   }
   double GetSharpeRatio()
   {
      if(m_totalTrades < 10) return 0;
      double avgReturn = (m_totalProfit - m_totalLoss) / m_totalTrades;
      double stdDev = MathSqrt(m_totalProfit + m_totalLoss) / m_totalTrades;
      return (stdDev > 0) ? avgReturn / stdDev : 0;
   }
   int    GetTotalTrades()      { return m_totalTrades; }
   int    GetWinningTrades()    { return m_winningTrades; }
   int    GetConsecutiveLosses(){ return m_consecutiveLosses; }
   double GetRiskPerTrade()     { return GetAdjustedRisk(); }
   bool   IsBlocked()           { return m_tradingBlocked; }
   string GetBlockReason()      { return m_blockReason; }
   double GetDailyPnL()
   {
      return AccountInfoDouble(ACCOUNT_EQUITY) - m_dailyStartBalance;
   }
   double GetMonthlyPnL()
   {
      return AccountInfoDouble(ACCOUNT_EQUITY) - m_monthlyStartBalance;
   }

private:
   //+------------------------------------------------------------------+
   //| Update period tracking                                            |
   //+------------------------------------------------------------------+
   void UpdatePeriodTracking()
   {
      MqlDateTime now, lastDay, lastWeek, lastMonth;
      TimeToStruct(TimeCurrent(), now);
      TimeToStruct(m_lastDayCheck, lastDay);
      TimeToStruct(m_lastWeekCheck, lastWeek);
      TimeToStruct(m_lastMonthCheck, lastMonth);

      //--- New Day
      if(now.day != lastDay.day)
      {
         m_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
         m_lastDayCheck = TimeCurrent();

         //--- Reset consecutive losses at new day if blocked
         if(m_tradingBlocked && m_consecutiveLosses >= m_maxConsLosses)
            m_consecutiveLosses = 0;
      }

      //--- New Week
      if(now.day_of_week < lastWeek.day_of_week || 
         (TimeCurrent() - m_lastWeekCheck) > 7 * 24 * 3600)
      {
         m_weeklyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
         m_lastWeekCheck = TimeCurrent();
      }

      //--- New Month
      if(now.mon != lastMonth.mon)
      {
         m_monthlyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
         m_lastMonthCheck = TimeCurrent();
      }
   }
};
//+------------------------------------------------------------------+
