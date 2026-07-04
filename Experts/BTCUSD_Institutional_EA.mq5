//+------------------------------------------------------------------+
//|                                    BTCUSD_Institutional_EA.mq5   |
//|                         Institutional Grade Expert Advisor        |
//|                              BTCUSD - XM Broker                  |
//+------------------------------------------------------------------+
#property copyright "Institutional EA"
#property link      ""
#property version   "1.00"
#property strict
#property description "Institutional Grade EA for BTCUSD on XM"
#property description "Multi-Factor Analysis | Smart Money | AI Scoring"
#property description "Dynamic Risk Management | Adaptive Position Sizing"

//--- Include Modules
#include "../Include/CoreEngine.mqh"
#include "../Include/MarketAnalyzer.mqh"
#include "../Include/AIDecisionEngine.mqh"
#include "../Include/RiskManagement.mqh"
#include "../Include/ExecutionEngine.mqh"
#include "../Include/Dashboard.mqh"
#include "../Include/MachineLearning.mqh"

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+

//--- General Settings
input string   InpSection1        = "?????? GENERAL SETTINGS ??????"; // ???????????????????
input string   InpSymbol          = "BTCUSD";        // Trading Symbol
input int      InpMagicNumber     = 202401;          // Magic Number
input string   InpComment         = "INST_EA";       // Order Comment
input bool     InpEnableTrading   = true;            // Enable Trading

//--- Capital Management
input string   InpSection2        = "?????? CAPITAL MANAGEMENT ??????"; // ???????????????
input double   InpInitialCapital  = 100.0;           // Initial Capital (USD)
input double   InpStartLot        = 0.01;            // Starting Lot Size
input double   InpMaxLot          = 1.0;             // Maximum Lot Size
input double   InpRiskPercent     = 1.0;             // Risk Per Trade (%)
input double   InpMaxRiskPercent  = 2.0;             // Maximum Risk Per Trade (%)

//--- Drawdown Protection
input string   InpSection3        = "?????? DRAWDOWN PROTECTION ??????"; // ?????????????
input double   InpMaxDailyDD      = 3.0;             // Max Daily Drawdown (%)
input double   InpMaxWeeklyDD     = 5.0;             // Max Weekly Drawdown (%)
input double   InpMaxMonthlyDD    = 8.0;             // Max Monthly Drawdown (%)
input double   InpMaxGlobalDD     = 10.0;            // Max Global Drawdown (%)
input int      InpMaxConsLosses   = 3;               // Max Consecutive Losses Before Pause

//--- Entry Filters
input string   InpSection4        = "?????? ENTRY FILTERS ??????"; // ??????????????????
input int      InpMinSignalScore  = 70;              // Minimum Signal Score (0-100)
input double   InpMaxSpread       = 8000.0;           // Maximum Spread (points)
input int      InpMinVolume       = 50;              // Minimum Tick Volume

//--- Trend Parameters
input string   InpSection5        = "?????? TREND PARAMETERS ??????"; // ???????????????
input int      InpEMA20           = 20;              // EMA Fast Period
input int      InpEMA50           = 50;              // EMA Medium Period
input int      InpEMA100          = 100;             // EMA Slow Period
input int      InpEMA200          = 200;             // EMA Very Slow Period

//--- Momentum Parameters
input string   InpSection6        = "?????? MOMENTUM PARAMETERS ??????"; // ????????????
input int      InpRSIPeriod       = 14;              // RSI Period
input int      InpRSIOverbought   = 70;              // RSI Overbought
input int      InpRSIOversold     = 30;              // RSI Oversold
input int      InpMACDFast        = 12;              // MACD Fast
input int      InpMACDSlow        = 26;              // MACD Slow
input int      InpMACDSignal      = 9;               // MACD Signal
input int      InpStochK          = 14;              // Stochastic K
input int      InpStochD          = 3;               // Stochastic D
input int      InpStochSlowing    = 3;               // Stochastic Slowing

//--- Volatility Parameters
input string   InpSection7        = "?????? VOLATILITY PARAMETERS ??????"; // ??????????
input int      InpATRPeriod       = 14;              // ATR Period
input double   InpATRMultiplierSL = 2.0;             // ATR Multiplier for Stop Loss
input double   InpATRMultiplierTP = 3.0;             // ATR Multiplier for Take Profit

//--- Trailing Stop
input string   InpSection8        = "?????? TRAILING STOP ??????"; // ??????????????????
input bool     InpUseTrailing     = true;            // Enable Trailing Stop
input double   InpTrailATRMult    = 1.5;             // Trailing ATR Multiplier
input bool     InpUseBreakEven    = true;            // Enable Break Even
input double   InpBreakEvenATR    = 1.0;             // Break Even ATR Distance

//--- Partial Close
input string   InpSection9        = "?????? PARTIAL CLOSE ??????"; // ??????????????????
input bool     InpUsePartialClose = true;            // Enable Partial Close
input double   InpPartialPercent  = 50.0;            // Partial Close Percentage
input double   InpPartialATRMult  = 2.0;             // Partial Close ATR Distance

//--- Session Filter
input string   InpSection10       = "?????? SESSION FILTER ??????"; // ?????????????????
input bool     InpUseSessions     = true;            // Enable Session Filter
input int      InpLondonStart     = 7;               // London Session Start (Hour)
input int      InpLondonEnd       = 18;              // London Session End (Hour)
input int      InpNYStart         = 12;              // New York Session Start (Hour)
input int      InpNYEnd           = 23;              // New York Session End (Hour)

//--- Dashboard
input string   InpSection11       = "?????? DASHBOARD ??????"; // ???????????????????????
input bool     InpShowDashboard   = true;            // Show Dashboard
input int      InpDashX           = 20;              // Dashboard X Position
input int      InpDashY           = 30;              // Dashboard Y Position

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
CCoreEngine       *g_CoreEngine;
CMarketAnalyzer   *g_MarketAnalyzer;
CAIDecisionEngine *g_AIEngine;
CRiskManagement   *g_RiskManager;
CExecutionEngine  *g_Executor;
CDashboard        *g_Dashboard;
CMachineLearning  *g_MLEngine;

datetime g_lastBarTime = 0;
bool     g_isInitialized = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Validate symbol
   if(_Symbol != InpSymbol && StringFind(_Symbol, "BTC") < 0)
   {
      Print("WARNING: EA designed for BTCUSD. Current symbol: ", _Symbol);
   }

   //--- Initialize Core Engine
   g_CoreEngine = new CCoreEngine();
   if(!g_CoreEngine.Initialize(InpMagicNumber, InpComment))
   {
      Print("ERROR: Failed to initialize Core Engine");
      return INIT_FAILED;
   }

   //--- Initialize Market Analyzer
   g_MarketAnalyzer = new CMarketAnalyzer();
   if(!g_MarketAnalyzer.Initialize(
      InpEMA20, InpEMA50, InpEMA100, InpEMA200,
      InpRSIPeriod, InpMACDFast, InpMACDSlow, InpMACDSignal,
      InpStochK, InpStochD, InpStochSlowing,
      InpATRPeriod))
   {
      Print("ERROR: Failed to initialize Market Analyzer");
      return INIT_FAILED;
   }

   //--- Initialize AI Decision Engine
   g_AIEngine = new CAIDecisionEngine();
   if(!g_AIEngine.Initialize(InpMinSignalScore))
   {
      Print("ERROR: Failed to initialize AI Decision Engine");
      return INIT_FAILED;
   }

   //--- Initialize Risk Management
   g_RiskManager = new CRiskManagement();
   if(!g_RiskManager.Initialize(
      InpInitialCapital, InpStartLot, InpMaxLot,
      InpRiskPercent, InpMaxRiskPercent,
      InpMaxDailyDD, InpMaxWeeklyDD, InpMaxMonthlyDD, InpMaxGlobalDD,
      InpMaxConsLosses))
   {
      Print("ERROR: Failed to initialize Risk Management");
      return INIT_FAILED;
   }

   //--- Initialize Execution Engine
   g_Executor = new CExecutionEngine();
   if(!g_Executor.Initialize(
      InpMagicNumber, InpComment, InpMaxSpread,
      InpATRMultiplierSL, InpATRMultiplierTP,
      InpUseTrailing, InpTrailATRMult,
      InpUseBreakEven, InpBreakEvenATR,
      InpUsePartialClose, InpPartialPercent, InpPartialATRMult))
   {
      Print("ERROR: Failed to initialize Execution Engine");
      return INIT_FAILED;
   }

   //--- Initialize Dashboard
   g_Dashboard = new CDashboard();
   if(InpShowDashboard)
      g_Dashboard.Initialize(InpDashX, InpDashY);

   //--- Initialize Machine Learning
   g_MLEngine = new CMachineLearning();
   g_MLEngine.Initialize();

   g_isInitialized = true;

   Print("???????????????????????????????????????????????????????");
   Print("  BTCUSD Institutional EA - Initialized Successfully  ");
   Print("  Capital: ", InpInitialCapital, " USD | Lot: ", InpStartLot);
   Print("  Risk: ", InpRiskPercent, "% | Max DD: ", InpMaxGlobalDD, "%");
   Print("???????????????????????????????????????????????????????");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Save ML data
   if(g_MLEngine != NULL)
   {
      g_MLEngine.SaveData();
      delete g_MLEngine;
   }

   //--- Cleanup
   if(g_Dashboard != NULL)
   {
      g_Dashboard.Destroy();
      delete g_Dashboard;
   }
   if(g_Executor != NULL)    delete g_Executor;
   if(g_RiskManager != NULL) delete g_RiskManager;
   if(g_AIEngine != NULL)    delete g_AIEngine;
   if(g_MarketAnalyzer != NULL) delete g_MarketAnalyzer;
   if(g_CoreEngine != NULL)  delete g_CoreEngine;

   Print("BTCUSD Institutional EA - Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_isInitialized || !InpEnableTrading) return;

   //--- Manage existing positions (every tick)
   double currentATR = g_MarketAnalyzer.GetATRValue();
   if(currentATR > 0)
      g_Executor.ManagePositions(_Symbol, currentATR);

   //--- New bar check for signal generation
   datetime currentBarTime = iTime(_Symbol, PERIOD_H1, 0);
   if(currentBarTime == g_lastBarTime) return;
   g_lastBarTime = currentBarTime;

   //--- Bar counter for logging
   static int barCount = 0;
   barCount++;

   //--- Update market analysis
   if(!g_MarketAnalyzer.Update(_Symbol))
   {
      if(barCount <= 10)
         Print("BAR ", barCount, ": Update() failed - ATR unavailable");
      return;
   }

   //--- Log first bars to confirm EA is processing
   if(barCount <= 3)
   {
      Print("BAR ", barCount, ": Update OK. ATR=", DoubleToString(g_MarketAnalyzer.GetATRValue(), 2),
            " RSI=", DoubleToString(g_MarketAnalyzer.GetRSIValue(), 1));
   }

   //--- Check risk limits
   if(!g_RiskManager.IsTradingAllowed())
   {
      if(barCount <= 5)
         Print("BAR ", barCount, ": BLOCKED by Risk Manager");
      if(InpShowDashboard)
         g_Dashboard.Update(g_RiskManager, g_MarketAnalyzer, g_MLEngine, "BLOCKED - Risk Limit");
      return;
   }

   //--- Session filter
   if(InpUseSessions && !IsValidSession())
   {
      if(barCount <= 5)
         Print("BAR ", barCount, ": BLOCKED by Session Filter");
      if(InpShowDashboard)
         g_Dashboard.Update(g_RiskManager, g_MarketAnalyzer, g_MLEngine, "WAITING - Session");
      return;
   }

   //--- Spread filter
   long spreadPoints = 0;
   if(!SymbolInfoInteger(_Symbol, SYMBOL_SPREAD, spreadPoints))
      spreadPoints = 0;
   if(spreadPoints > (long)InpMaxSpread)
   {
      if(barCount <= 5)
         Print("BAR ", barCount, ": BLOCKED by Spread (", spreadPoints, " > ", InpMaxSpread, ")");
      if(InpShowDashboard)
         g_Dashboard.Update(g_RiskManager, g_MarketAnalyzer, g_MLEngine, "BLOCKED - Spread");
      return;
   }

   //--- Volume filter
   long tickVolume = iVolume(_Symbol, PERIOD_H1, 1);
   if(tickVolume < InpMinVolume)
   {
      if(barCount <= 5)
         Print("BAR ", barCount, ": BLOCKED by Volume (", tickVolume, " < ", InpMinVolume, ")");
      if(InpShowDashboard)
         g_Dashboard.Update(g_RiskManager, g_MarketAnalyzer, g_MLEngine, "LOW VOLUME");
      return;
   }

   //--- Get market state
   SMarketState state;
   g_MarketAnalyzer.GetMarketState(state);

   //--- AI Signal Scoring
   SSignalResult signal;
   g_AIEngine.EvaluateSignal(state, signal);

   //--- Log every bar for first 10, then every 24 bars
   if(barCount <= 10 || barCount % 24 == 0)
   {
      Print("BAR ", barCount, ": Score=", signal.score, " Dir=", signal.direction,
            " Trend=", state.trendDirection, " Mom=", state.momentumBias,
            " Struct=", state.structureBias, " MTF=", state.mtfBias,
            " ATR=", DoubleToString(g_MarketAnalyzer.GetATRValue(), 2),
            " RSI=", DoubleToString(state.rsiValue, 1));
   }

   //--- ML Filter
   if(g_MLEngine.ShouldFilterSignal(signal, state))
   {
      if(InpShowDashboard)
         g_Dashboard.Update(g_RiskManager, g_MarketAnalyzer, g_MLEngine, "ML FILTERED");
      return;
   }

   //--- Execute if signal is strong enough
   if(signal.score >= InpMinSignalScore)
   {
      Print("SIGNAL TRIGGERED: Score=", signal.score, " Dir=", signal.direction,
            " Reason=", signal.reason);

      double lotSize = g_RiskManager.CalculateLotSize(
         _Symbol, 
         g_MarketAnalyzer.GetATRValue() * InpATRMultiplierSL
      );

      if(lotSize > 0)
      {
         bool result = g_Executor.ExecuteSignal(
            _Symbol, signal, lotSize, 
            g_MarketAnalyzer.GetATRValue()
         );

         if(result)
         {
            g_MLEngine.RecordEntry(signal, state);
            g_RiskManager.OnTradeOpened(lotSize);
         }
      }
      else
      {
         Print("WARNING: LotSize calculated as 0");
      }
   }

   //--- Update Dashboard
   if(InpShowDashboard)
   {
      string status = signal.score >= InpMinSignalScore ? "SIGNAL ACTIVE" : "SCANNING";
      g_Dashboard.Update(g_RiskManager, g_MarketAnalyzer, g_MLEngine, status);
   }
}

//+------------------------------------------------------------------+
//| Trade event handler                                               |
//+------------------------------------------------------------------+
void OnTrade()
{
   if(!g_isInitialized) return;
   g_RiskManager.OnTradeEvent();
   g_MLEngine.OnTradeClose();
}

//+------------------------------------------------------------------+
//| Session validation                                                |
//+------------------------------------------------------------------+
bool IsValidSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;

   //--- London session
   if(hour >= InpLondonStart && hour < InpLondonEnd)
      return true;

   //--- New York session
   if(hour >= InpNYStart && hour < InpNYEnd)
      return true;

   //--- Asian session for crypto (high BTC liquidity)
   if(hour >= 0 && hour < 6)
      return true;

   return false;
}
//+------------------------------------------------------------------+
