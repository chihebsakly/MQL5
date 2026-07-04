//+------------------------------------------------------------------+
//|                                                    btcusd.mq5    |
//|                         Institutional Grade Expert Advisor        |
//|                              BTCUSD - XM Broker                  |
//+------------------------------------------------------------------+
#property copyright "Institutional EA"
#property link      ""
#property version   "2.00"
#property strict
#property description "Institutional Grade EA for BTCUSD on XM"
#property description "Multi-Factor Analysis | Smart Money | AI Scoring"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| STRUCTURES                                                        |
//+------------------------------------------------------------------+
struct SMarketState
{
   int      trendDirection;
   double   trendStrength;
   bool     emaAligned;
   double   rsiValue;
   double   macdHistogram;
   double   stochMain;
   double   stochSignal;
   int      momentumBias;
   double   atrValue;
   double   atrNormalized;
   int      volatilityState;
   double   volumeRatio;
   bool     volumeConfirm;
   int      structureType;
   bool     bosDetected;
   bool     chochDetected;
   int      structureBias;
   bool     fvgDetected;
   int      fvgDirection;
   bool     orderBlockDetected;
   int      obDirection;
   double   liquidityAbove;
   double   liquidityBelow;
   int      mtfBias;
   int      mtfAlignment;
};

struct SSignalResult
{
   int      direction;
   int      score;
   double   confidence;
   string   reason;
   double   suggestedSL;
   double   suggestedTP;
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input string   InpSection1        = "====== GENERAL SETTINGS ======"; // ===General===
input string   InpSymbol          = "BTCUSD";        // Trading Symbol
input int      InpMagicNumber     = 202401;          // Magic Number
input string   InpComment         = "INST_EA";       // Order Comment
input bool     InpEnableTrading   = true;            // Enable Trading

input string   InpSection2        = "====== CAPITAL MANAGEMENT ======"; // ===Capital===
input double   InpInitialCapital  = 100.0;           // Initial Capital (USD)
input double   InpStartLot        = 0.01;            // Starting Lot Size
input double   InpMaxLot          = 1.0;             // Maximum Lot Size
input double   InpRiskPercent     = 1.0;             // Risk Per Trade (%)
input double   InpMaxRiskPercent  = 2.0;             // Maximum Risk Per Trade (%)

input string   InpSection3        = "====== DRAWDOWN PROTECTION ======"; // ===Drawdown===
input double   InpMaxDailyDD      = 3.0;             // Max Daily Drawdown (%)
input double   InpMaxWeeklyDD     = 5.0;             // Max Weekly Drawdown (%)
input double   InpMaxMonthlyDD    = 8.0;             // Max Monthly Drawdown (%)
input double   InpMaxGlobalDD     = 10.0;            // Max Global Drawdown (%)
input int      InpMaxConsLosses   = 3;               // Max Consecutive Losses Before Pause

input string   InpSection4        = "====== ENTRY FILTERS ======"; // ===Filters===
input int      InpMinSignalScore  = 65;              // Minimum Signal Score (0-100)
input double   InpMaxSpread       = 10000.0;         // Maximum Spread (points)
input int      InpMinVolume       = 10;              // Minimum Tick Volume

input string   InpSection5        = "====== TREND PARAMETERS ======"; // ===Trend===
input int      InpEMA20           = 20;              // EMA Fast Period
input int      InpEMA50           = 50;              // EMA Medium Period
input int      InpEMA100          = 100;             // EMA Slow Period
input int      InpEMA200          = 200;             // EMA Very Slow Period

input string   InpSection6        = "====== MOMENTUM PARAMETERS ======"; // ===Momentum===
input int      InpRSIPeriod       = 14;              // RSI Period
input int      InpMACDFast        = 12;              // MACD Fast
input int      InpMACDSlow        = 26;              // MACD Slow
input int      InpMACDSignal      = 9;               // MACD Signal
input int      InpStochK          = 14;              // Stochastic K
input int      InpStochD          = 3;               // Stochastic D
input int      InpStochSlowing    = 3;               // Stochastic Slowing

input string   InpSection7        = "====== VOLATILITY PARAMETERS ======"; // ===Volatility===
input int      InpATRPeriod       = 14;              // ATR Period
input double   InpATRMultiplierSL = 2.0;             // ATR Multiplier for Stop Loss
input double   InpATRMultiplierTP = 3.0;             // ATR Multiplier for Take Profit

input string   InpSection8        = "====== TRAILING STOP ======"; // ===Trailing===
input bool     InpUseTrailing     = true;            // Enable Trailing Stop
input double   InpTrailATRMult    = 1.5;             // Trailing ATR Multiplier
input bool     InpUseBreakEven    = true;            // Enable Break Even
input double   InpBreakEvenATR    = 1.0;             // Break Even ATR Distance

input string   InpSection9        = "====== PARTIAL CLOSE ======"; // ===Partial===
input bool     InpUsePartialClose = true;            // Enable Partial Close
input double   InpPartialPercent  = 50.0;            // Partial Close Percentage
input double   InpPartialATRMult  = 2.0;             // Partial Close ATR Distance

input string   InpSection10       = "====== SESSION FILTER ======"; // ===Sessions===
input bool     InpUseSessions     = false;           // Enable Session Filter
input int      InpLondonStart     = 7;               // London Session Start (Hour)
input int      InpLondonEnd       = 18;              // London Session End (Hour)
input int      InpNYStart         = 12;              // New York Session Start (Hour)
input int      InpNYEnd           = 23;              // New York Session End (Hour)

input string   InpSection11       = "====== DASHBOARD ======"; // ===Dashboard===
input bool     InpShowDashboard   = true;            // Show Dashboard

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
//--- Indicator Handles
int g_hEMA20, g_hEMA50, g_hEMA100, g_hEMA200;
int g_hRSI, g_hMACD, g_hStoch, g_hATR, g_hOBV;
int g_hEMA50_M15, g_hEMA50_H4, g_hEMA50_D1;
int g_hRSI_H4, g_hATR_H4;

//--- Indicator Values
double g_ema20, g_ema50, g_ema100, g_ema200;
double g_rsi, g_macdMain, g_macdSignal, g_macdHist;
double g_stochK, g_stochD, g_atr;
double g_ema50_M15, g_ema50_H4, g_ema50_D1;
double g_rsi_H4, g_atr_H4;

//--- Market Structure
double g_swingHighs[];
double g_swingLows[];
int    g_structureDirection = 0;

//--- Risk Tracking
double g_dailyStartBalance;
double g_weeklyStartBalance;
double g_monthlyStartBalance;
double g_peakBalance;
int    g_consecutiveLosses = 0;
int    g_totalTrades = 0;
int    g_winningTrades = 0;
double g_totalProfit = 0;
double g_totalLoss = 0;
double g_maxDrawdown = 0;
datetime g_lastDayCheck;
datetime g_lastWeekCheck;
datetime g_lastMonthCheck;

//--- Trade Management
CTrade g_trade;
datetime g_lastBarTime = 0;
bool g_isInitialized = false;
int  g_barCount = 0;

//--- Partial close tracking
ulong  g_trackedTickets[];
bool   g_partialClosed[];

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   string symbol = _Symbol;

   //--- Create indicator handles
   g_hEMA20  = iMA(symbol, PERIOD_H1, InpEMA20, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA50  = iMA(symbol, PERIOD_H1, InpEMA50, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA100 = iMA(symbol, PERIOD_H1, InpEMA100, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA200 = iMA(symbol, PERIOD_H1, InpEMA200, 0, MODE_EMA, PRICE_CLOSE);
   g_hRSI    = iRSI(symbol, PERIOD_H1, InpRSIPeriod, PRICE_CLOSE);
   g_hMACD   = iMACD(symbol, PERIOD_H1, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   g_hStoch  = iStochastic(symbol, PERIOD_H1, InpStochK, InpStochD, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
   g_hATR    = iATR(symbol, PERIOD_H1, InpATRPeriod);
   g_hOBV    = iOBV(symbol, PERIOD_H1, VOLUME_TICK);

   //--- MTF
   g_hEMA50_M15 = iMA(symbol, PERIOD_M15, InpEMA50, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA50_H4  = iMA(symbol, PERIOD_H4, InpEMA50, 0, MODE_EMA, PRICE_CLOSE);
   g_hEMA50_D1  = iMA(symbol, PERIOD_D1, InpEMA50, 0, MODE_EMA, PRICE_CLOSE);
   g_hRSI_H4   = iRSI(symbol, PERIOD_H4, InpRSIPeriod, PRICE_CLOSE);
   g_hATR_H4   = iATR(symbol, PERIOD_H4, InpATRPeriod);

   if(g_hEMA20 == INVALID_HANDLE || g_hATR == INVALID_HANDLE || 
      g_hRSI == INVALID_HANDLE || g_hMACD == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create indicator handles");
      return INIT_FAILED;
   }

   //--- Risk Management init
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dailyStartBalance   = balance;
   g_weeklyStartBalance  = balance;
   g_monthlyStartBalance = balance;
   g_peakBalance         = balance;
   g_lastDayCheck   = TimeCurrent();
   g_lastWeekCheck  = TimeCurrent();
   g_lastMonthCheck = TimeCurrent();

   //--- Trade setup
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(100);

   //--- Swing arrays
   ArrayResize(g_swingHighs, 10);
   ArrayResize(g_swingLows, 10);
   ArrayInitialize(g_swingHighs, 0);
   ArrayInitialize(g_swingLows, 0);

   g_isInitialized = true;
   g_barCount = 0;

   Print("=======================================================");
   Print("  BTCUSD Institutional EA v2.0 - Initialized");
   Print("  Balance: ", balance, " USD | Max Spread: ", InpMaxSpread);
   Print("  Risk: ", InpRiskPercent, "% | Min Score: ", InpMinSignalScore);
   Print("=======================================================");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(g_hEMA20);
   IndicatorRelease(g_hEMA50);
   IndicatorRelease(g_hEMA100);
   IndicatorRelease(g_hEMA200);
   IndicatorRelease(g_hRSI);
   IndicatorRelease(g_hMACD);
   IndicatorRelease(g_hStoch);
   IndicatorRelease(g_hATR);
   IndicatorRelease(g_hOBV);
   IndicatorRelease(g_hEMA50_M15);
   IndicatorRelease(g_hEMA50_H4);
   IndicatorRelease(g_hEMA50_D1);
   IndicatorRelease(g_hRSI_H4);
   IndicatorRelease(g_hATR_H4);

   if(InpShowDashboard)
      ObjectsDeleteAll(0, "DASH_");

   Print("EA Deinitialized. Trades: ", g_totalTrades, " WR: ", 
         (g_totalTrades > 0 ? DoubleToString((double)g_winningTrades/g_totalTrades*100, 1) : "0"), "%");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_isInitialized || !InpEnableTrading) return;

   //--- Manage positions every tick
   if(g_atr > 0)
      ManageOpenPositions();

   //--- New H1 bar check
   datetime currentBarTime = iTime(_Symbol, PERIOD_H1, 0);
   if(currentBarTime == g_lastBarTime) return;
   g_lastBarTime = currentBarTime;
   g_barCount++;

   //--- Update indicators
   if(!UpdateIndicators())
   {
      if(g_barCount <= 5)
         Print("BAR ", g_barCount, ": Indicator update failed");
      return;
   }

   //--- Log first few bars
   if(g_barCount <= 5)
      Print("BAR ", g_barCount, ": ATR=", DoubleToString(g_atr, 2), " RSI=", DoubleToString(g_rsi, 1));

   //--- Risk check
   if(!IsTradingAllowed())
   {
      if(g_barCount <= 5)
         Print("BAR ", g_barCount, ": BLOCKED by Risk Manager");
      return;
   }

   //--- Session filter
   if(InpUseSessions && !IsValidSession())
      return;

   //--- Spread filter
   long spreadPts = 0;
   if(!SymbolInfoInteger(_Symbol, SYMBOL_SPREAD, spreadPts))
      spreadPts = 0;
   if(spreadPts > (long)InpMaxSpread)
   {
      if(g_barCount <= 5)
         Print("BAR ", g_barCount, ": Spread too high: ", spreadPts);
      return;
   }

   //--- Volume filter
   long vol = iVolume(_Symbol, PERIOD_H1, 1);
   if(vol < InpMinVolume)
      return;

   //--- Check if already have a position
   if(CountMyPositions() > 0)
      return;

   //--- Build market state
   SMarketState state;
   BuildMarketState(state);

   //--- Score signal
   SSignalResult signal;
   EvaluateSignal(state, signal);

   //--- Log periodically
   if(g_barCount <= 10 || g_barCount % 12 == 0)
   {
      Print("BAR ", g_barCount, ": Score=", signal.score, " Dir=", signal.direction,
            " Trend=", state.trendDirection, " Mom=", state.momentumBias,
            " Struct=", state.structureBias, " MTF=", state.mtfBias);
   }

   //--- Execute if strong signal
   if(signal.score >= InpMinSignalScore && signal.direction != 0)
   {
      Print(">>> SIGNAL: Score=", signal.score, " Dir=", (signal.direction > 0 ? "BUY" : "SELL"),
            " ", signal.reason);

      double lotSize = CalculateLotSize(g_atr * InpATRMultiplierSL);

      if(lotSize >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
      {
         ExecuteTrade(signal, lotSize);
      }
      else
      {
         Print("WARNING: Lot too small: ", lotSize);
      }
   }

   //--- Dashboard
   if(InpShowDashboard && g_barCount % 4 == 0)
      UpdateDashboard(signal);
}

//+------------------------------------------------------------------+
//| Update all indicator values                                       |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
   double buf[];
   ArraySetAsSeries(buf, true);

   if(CopyBuffer(g_hATR, 0, 1, 1, buf) < 1) return false;
   g_atr = buf[0];
   if(g_atr <= 0) return false;

   if(CopyBuffer(g_hEMA20, 0, 1, 1, buf) >= 1)  g_ema20 = buf[0];
   if(CopyBuffer(g_hEMA50, 0, 1, 1, buf) >= 1)  g_ema50 = buf[0];
   if(CopyBuffer(g_hEMA100, 0, 1, 1, buf) >= 1) g_ema100 = buf[0];
   if(CopyBuffer(g_hEMA200, 0, 1, 1, buf) >= 1) g_ema200 = buf[0];
   if(CopyBuffer(g_hRSI, 0, 1, 1, buf) >= 1)    g_rsi = buf[0];

   if(CopyBuffer(g_hMACD, 0, 1, 1, buf) >= 1)   g_macdMain = buf[0];
   if(CopyBuffer(g_hMACD, 1, 1, 1, buf) >= 1)   g_macdSignal = buf[0];
   g_macdHist = g_macdMain - g_macdSignal;

   if(CopyBuffer(g_hStoch, 0, 1, 1, buf) >= 1)  g_stochK = buf[0];
   if(CopyBuffer(g_hStoch, 1, 1, 1, buf) >= 1)  g_stochD = buf[0];

   //--- MTF (non-critical)
   if(CopyBuffer(g_hEMA50_M15, 0, 0, 1, buf) >= 1) g_ema50_M15 = buf[0];
   if(CopyBuffer(g_hEMA50_H4, 0, 0, 1, buf) >= 1)  g_ema50_H4 = buf[0];
   if(CopyBuffer(g_hEMA50_D1, 0, 0, 1, buf) >= 1)  g_ema50_D1 = buf[0];
   if(CopyBuffer(g_hRSI_H4, 0, 0, 1, buf) >= 1)    g_rsi_H4 = buf[0];
   if(CopyBuffer(g_hATR_H4, 0, 0, 1, buf) >= 1)    g_atr_H4 = buf[0];

   //--- Update swing structure
   UpdateSwingStructure();

   return true;
}

//+------------------------------------------------------------------+
//| Build complete market state                                       |
//+------------------------------------------------------------------+
void BuildMarketState(SMarketState &state)
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   //--- TREND
   if(price > g_ema20 && g_ema20 > g_ema50 && g_ema50 > g_ema100 && g_ema100 > g_ema200)
   {
      state.trendDirection = 1;
      state.emaAligned = true;
   }
   else if(price < g_ema20 && g_ema20 < g_ema50 && g_ema50 < g_ema100 && g_ema100 < g_ema200)
   {
      state.trendDirection = -1;
      state.emaAligned = true;
   }
   else
   {
      int bullCount = 0;
      if(price > g_ema20)  bullCount++;
      if(price > g_ema50)  bullCount++;
      if(price > g_ema100) bullCount++;
      if(price > g_ema200) bullCount++;

      state.trendDirection = (bullCount >= 3) ? 1 : (bullCount <= 1) ? -1 : 0;
      state.emaAligned = false;
   }
   state.trendStrength = (g_ema200 > 0) ? MathAbs(price - g_ema200) / g_ema200 * 100.0 : 0;

   //--- MOMENTUM
   state.rsiValue = g_rsi;
   state.macdHistogram = g_macdHist;
   state.stochMain = g_stochK;
   state.stochSignal = g_stochD;

   int bullMom = 0, bearMom = 0;
   if(g_rsi > 50) bullMom++; else if(g_rsi < 50) bearMom++;
   if(g_macdHist > 0) bullMom++; else if(g_macdHist < 0) bearMom++;
   if(g_stochK > 50 && g_stochK > g_stochD) bullMom++;
   else if(g_stochK < 50 && g_stochK < g_stochD) bearMom++;

   state.momentumBias = (bullMom > bearMom) ? 1 : (bearMom > bullMom) ? -1 : 0;

   //--- VOLATILITY
   state.atrValue = g_atr;
   state.atrNormalized = (price > 0) ? (g_atr / price * 100.0) : 0;
   state.volatilityState = (state.atrNormalized < 1.0) ? 0 : (state.atrNormalized < 3.0) ? 1 : 2;

   //--- VOLUME
   long volumes[];
   ArraySetAsSeries(volumes, true);
   if(CopyTickVolume(_Symbol, PERIOD_H1, 0, 20, volumes) >= 20)
   {
      double avgVol = 0;
      for(int i = 1; i < 20; i++) avgVol += (double)volumes[i];
      avgVol /= 19.0;
      state.volumeRatio = (avgVol > 0) ? (double)volumes[0] / avgVol : 1.0;
      state.volumeConfirm = (state.volumeRatio > 1.2);
   }
   else { state.volumeRatio = 1.0; state.volumeConfirm = false; }

   //--- STRUCTURE
   state.structureBias = g_structureDirection;
   state.bosDetected = false;
   state.chochDetected = false;

   if(g_structureDirection == 1 && g_swingHighs[0] > 0 && price > g_swingHighs[0])
      state.bosDetected = true;
   if(g_structureDirection == -1 && g_swingLows[0] > 0 && price < g_swingLows[0])
      state.bosDetected = true;
   if(g_structureDirection == -1 && g_swingHighs[0] > 0 && price > g_swingHighs[0])
      state.chochDetected = true;
   if(g_structureDirection == 1 && g_swingLows[0] > 0 && price < g_swingLows[0])
      state.chochDetected = true;

   if(state.bosDetected) state.structureType = 2;
   else if(MathAbs(state.trendStrength) > 2.0) state.structureType = 1;
   else state.structureType = 0;

   //--- SMART MONEY (FVG)
   state.fvgDetected = false;
   state.fvgDirection = 0;
   state.orderBlockDetected = false;
   state.obDirection = 0;
   DetectFVG(state, price);
   DetectOrderBlock(state, price);

   //--- LIQUIDITY
   state.liquidityAbove = price + g_atr * 5;
   state.liquidityBelow = price - g_atr * 5;

   //--- MTF
   int bullTF = 0;
   if(price > g_ema50_M15) bullTF++;
   if(price > g_ema50)     bullTF++;
   if(price > g_ema50_H4)  bullTF++;
   if(price > g_ema50_D1)  bullTF++;
   state.mtfAlignment = bullTF;
   state.mtfBias = (bullTF >= 3) ? 1 : (bullTF <= 1) ? -1 : 0;
}

//+------------------------------------------------------------------+
//| AI Signal Scoring                                                 |
//+------------------------------------------------------------------+
void EvaluateSignal(const SMarketState &state, SSignalResult &signal)
{
   signal.direction = 0;
   signal.score = 0;
   signal.confidence = 0;
   signal.reason = "";

   //--- Direction consensus
   int bullSignals = 0, bearSignals = 0;

   if(state.trendDirection > 0)  bullSignals++;
   if(state.trendDirection < 0)  bearSignals++;
   if(state.momentumBias > 0)    bullSignals++;
   if(state.momentumBias < 0)    bearSignals++;
   if(state.structureBias > 0)   bullSignals++;
   if(state.structureBias < 0)   bearSignals++;
   if(state.mtfBias > 0)         bullSignals++;
   if(state.mtfBias < 0)         bearSignals++;
   if(state.fvgDetected && state.fvgDirection > 0) bullSignals++;
   if(state.fvgDetected && state.fvgDirection < 0) bearSignals++;
   if(state.orderBlockDetected && state.obDirection > 0) bullSignals++;
   if(state.orderBlockDetected && state.obDirection < 0) bearSignals++;

   //--- Need at least 3 aligned factors
   if(bullSignals >= 3 && bullSignals > bearSignals)
      signal.direction = 1;
   else if(bearSignals >= 3 && bearSignals > bullSignals)
      signal.direction = -1;
   else
   {
      signal.reason = "No consensus";
      return;
   }

   //--- Score each component (0-100)
   double trendScore = 40.0;
   if(state.emaAligned) trendScore += 35.0;
   else if(state.trendDirection != 0) trendScore += 20.0;
   if(state.trendStrength > 0.5) trendScore += 10.0;
   if(state.trendStrength > 1.5) trendScore += 15.0;
   trendScore = MathMin(100, trendScore);

   double momScore = 40.0;
   if(state.momentumBias != 0) momScore += 15.0;
   if((signal.direction > 0 && state.macdHistogram > 0) ||
      (signal.direction < 0 && state.macdHistogram < 0)) momScore += 20.0;
   if(state.stochMain > 20 && state.stochMain < 80) momScore += 10.0;
   if((signal.direction > 0 && state.rsiValue > 40 && state.rsiValue < 70) ||
      (signal.direction < 0 && state.rsiValue > 30 && state.rsiValue < 60)) momScore += 15.0;
   momScore = MathMin(100, momScore);

   double volScore = 50.0;
   if(state.volatilityState == 1) volScore += 30.0;
   else if(state.volatilityState == 0) volScore += 10.0;
   else volScore -= 10.0;
   volScore = MathMin(100, MathMax(0, volScore));

   double volumeScore = 50.0;
   if(state.volumeConfirm) volumeScore += 30.0;
   if(state.volumeRatio > 1.5) volumeScore += 10.0;
   volumeScore = MathMin(100, volumeScore);

   double structScore = 45.0;
   if(state.bosDetected) structScore += 25.0;
   if(state.chochDetected) structScore += 15.0;
   if(state.structureType >= 1) structScore += 15.0;
   structScore = MathMin(100, structScore);

   double smcScore = 40.0;
   if(state.fvgDetected) smcScore += 25.0;
   if(state.orderBlockDetected) smcScore += 25.0;
   if(state.fvgDetected && state.orderBlockDetected) smcScore += 10.0;
   smcScore = MathMin(100, smcScore);

   double mtfScore = 35.0;
   mtfScore += state.mtfAlignment * 12.0;
   if(state.mtfAlignment >= 4) mtfScore += 17.0;
   mtfScore = MathMin(100, mtfScore);

   //--- Weighted final score
   double rawScore = trendScore * 0.20 + momScore * 0.15 + volScore * 0.10 +
                     volumeScore * 0.10 + structScore * 0.20 + smcScore * 0.15 + mtfScore * 0.10;

   signal.score = (int)MathRound(rawScore);
   signal.confidence = rawScore / 100.0;

   //--- Bonuses
   if(signal.direction == 1 && state.rsiValue < 35) signal.score += 5;
   if(signal.direction == -1 && state.rsiValue > 65) signal.score += 5;
   if(state.emaAligned && state.momentumBias == signal.direction) signal.score += 5;

   //--- Penalties
   if(state.volatilityState == 2) signal.score -= 5;
   if(signal.direction == 1 && state.momentumBias < 0) signal.score -= 5;
   if(signal.direction == -1 && state.momentumBias > 0) signal.score -= 5;

   signal.score = MathMax(0, MathMin(100, signal.score));

   //--- Build reason
   signal.reason = (signal.direction > 0 ? "BUY" : "SELL");
   if(trendScore > 70)  signal.reason += " |Trend";
   if(momScore > 70)    signal.reason += " |Mom";
   if(structScore > 70) signal.reason += " |Struct";
   if(smcScore > 60)    signal.reason += " |SMC";
   if(mtfScore > 70)    signal.reason += " |MTF";
}

//+------------------------------------------------------------------+
//| Execute trade                                                     |
//+------------------------------------------------------------------+
void ExecuteTrade(const SSignalResult &signal, double lotSize)
{
   double price, sl, tp;
   double slDist = g_atr * InpATRMultiplierSL;
   double tpDist = g_atr * InpATRMultiplierTP;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(signal.direction > 0)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = NormalizeDouble(price - slDist, digits);
      tp = NormalizeDouble(price + tpDist, digits);

      if(g_trade.Buy(lotSize, _Symbol, 0, sl, tp, InpComment))
      {
         Print("BUY executed: Lot=", lotSize, " SL=", sl, " TP=", tp);
         TrackPosition(g_trade.ResultOrder());
         g_totalTrades++;
      }
      else
         Print("BUY FAILED: ", g_trade.ResultRetcode(), " ", g_trade.ResultComment());
   }
   else
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = NormalizeDouble(price + slDist, digits);
      tp = NormalizeDouble(price - tpDist, digits);

      if(g_trade.Sell(lotSize, _Symbol, 0, sl, tp, InpComment))
      {
         Print("SELL executed: Lot=", lotSize, " SL=", sl, " TP=", tp);
         TrackPosition(g_trade.ResultOrder());
         g_totalTrades++;
      }
      else
         Print("SELL FAILED: ", g_trade.ResultRetcode(), " ", g_trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                  |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossDistance)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double accountValue = MathMin(balance, equity);

   //--- Adjusted risk
   double risk = InpRiskPercent;
   if(g_consecutiveLosses >= 1) risk *= 0.75;
   if(g_consecutiveLosses >= 2) risk *= 0.75;

   double currentDD = (g_peakBalance > 0) ? (g_peakBalance - equity) / g_peakBalance * 100.0 : 0;
   if(currentDD > 3.0) risk *= 0.5;

   risk = MathMax(0.25, MathMin(risk, InpMaxRiskPercent));

   double riskAmount = accountValue * (risk / 100.0);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(tickValue <= 0 || tickSize <= 0 || stopLossDistance <= 0)
      return minLot;

   double ticksInSL = stopLossDistance / tickSize;
   double lotSize = riskAmount / (ticksInSL * tickValue);

   lotSize = MathMax(lotSize, minLot);
   lotSize = MathMin(lotSize, InpMaxLot);
   lotSize = MathMin(lotSize, maxLot);
   lotSize = MathFloor(lotSize / lotStep) * lotStep;

   if(lotSize < minLot) lotSize = minLot;

   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Manage open positions                                            |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      ulong ticket = PositionGetInteger(POSITION_TICKET);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double volume = PositionGetDouble(POSITION_VOLUME);
      long posType = PositionGetInteger(POSITION_TYPE);
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

      double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                            SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                            SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      //--- Break Even
      if(InpUseBreakEven)
      {
         double beDist = g_atr * InpBreakEvenATR;
         if(posType == POSITION_TYPE_BUY && currentPrice >= openPrice + beDist && currentSL < openPrice)
         {
            double newSL = NormalizeDouble(openPrice + _Point * 10, digits);
            g_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
         }
         else if(posType == POSITION_TYPE_SELL && currentPrice <= openPrice - beDist && 
                 (currentSL > openPrice || currentSL == 0))
         {
            double newSL = NormalizeDouble(openPrice - _Point * 10, digits);
            g_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
         }
      }

      //--- Trailing Stop
      if(InpUseTrailing)
      {
         double trailDist = g_atr * InpTrailATRMult;
         if(posType == POSITION_TYPE_BUY && currentPrice > openPrice + trailDist)
         {
            double newSL = NormalizeDouble(currentPrice - trailDist, digits);
            if(newSL > currentSL && newSL > openPrice)
               g_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
         }
         else if(posType == POSITION_TYPE_SELL && currentPrice < openPrice - trailDist)
         {
            double newSL = NormalizeDouble(currentPrice + trailDist, digits);
            if((newSL < currentSL || currentSL == 0) && newSL < openPrice)
               g_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
         }
      }

      //--- Partial Close
      if(InpUsePartialClose && !IsPartialClosed(ticket))
      {
         double partialDist = g_atr * InpPartialATRMult;
         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         double closeVol = NormalizeDouble(volume * (InpPartialPercent / 100.0), 2);

         if(closeVol >= minLot && (volume - closeVol) >= minLot)
         {
            bool shouldClose = false;
            if(posType == POSITION_TYPE_BUY && currentPrice >= openPrice + partialDist)
               shouldClose = true;
            if(posType == POSITION_TYPE_SELL && currentPrice <= openPrice - partialDist)
               shouldClose = true;

            if(shouldClose)
            {
               if(g_trade.PositionClosePartial(ticket, closeVol))
                  MarkPartialClosed(ticket);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Risk Management - Check if trading allowed                       |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   UpdatePeriodTracking();

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(balance > g_peakBalance) g_peakBalance = balance;

   double dailyDD = (g_dailyStartBalance > 0) ? (g_dailyStartBalance - equity) / g_dailyStartBalance * 100.0 : 0;
   if(dailyDD > InpMaxDailyDD) return false;

   double weeklyDD = (g_weeklyStartBalance > 0) ? (g_weeklyStartBalance - equity) / g_weeklyStartBalance * 100.0 : 0;
   if(weeklyDD > InpMaxWeeklyDD) return false;

   double monthlyDD = (g_monthlyStartBalance > 0) ? (g_monthlyStartBalance - equity) / g_monthlyStartBalance * 100.0 : 0;
   if(monthlyDD > InpMaxMonthlyDD) return false;

   double globalDD = (g_peakBalance > 0) ? (g_peakBalance - equity) / g_peakBalance * 100.0 : 0;
   if(globalDD > InpMaxGlobalDD) return false;
   if(globalDD > g_maxDrawdown) g_maxDrawdown = globalDD;

   if(g_consecutiveLosses >= InpMaxConsLosses) return false;

   return true;
}

//+------------------------------------------------------------------+
//| Count my positions                                               |
//+------------------------------------------------------------------+
int CountMyPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Session validation                                               |
//+------------------------------------------------------------------+
bool IsValidSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;

   if(hour >= InpLondonStart && hour < InpLondonEnd) return true;
   if(hour >= InpNYStart && hour < InpNYEnd) return true;
   if(hour >= 0 && hour < 6) return true;

   return false;
}

//+------------------------------------------------------------------+
//| Update period tracking for drawdown                              |
//+------------------------------------------------------------------+
void UpdatePeriodTracking()
{
   MqlDateTime now, lastDay, lastWeek, lastMonth;
   TimeToStruct(TimeCurrent(), now);
   TimeToStruct(g_lastDayCheck, lastDay);
   TimeToStruct(g_lastWeekCheck, lastWeek);
   TimeToStruct(g_lastMonthCheck, lastMonth);

   if(now.day != lastDay.day)
   {
      g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_lastDayCheck = TimeCurrent();
      if(g_consecutiveLosses >= InpMaxConsLosses)
         g_consecutiveLosses = 0;
   }
   if(now.day_of_week < lastWeek.day_of_week || (TimeCurrent() - g_lastWeekCheck) > 604800)
   {
      g_weeklyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_lastWeekCheck = TimeCurrent();
   }
   if(now.mon != lastMonth.mon)
   {
      g_monthlyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_lastMonthCheck = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Update swing structure                                           |
//+------------------------------------------------------------------+
void UpdateSwingStructure()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_H1, 0, 50, rates) < 50) return;

   int highIdx = 0, lowIdx = 0;

   for(int i = 2; i < 47; i++)
   {
      if(rates[i].high > rates[i-1].high && rates[i].high > rates[i-2].high &&
         rates[i].high > rates[i+1].high && rates[i].high > rates[i+2].high)
      {
         if(highIdx < 10) { g_swingHighs[highIdx] = rates[i].high; highIdx++; }
      }
      if(rates[i].low < rates[i-1].low && rates[i].low < rates[i-2].low &&
         rates[i].low < rates[i+1].low && rates[i].low < rates[i+2].low)
      {
         if(lowIdx < 10) { g_swingLows[lowIdx] = rates[i].low; lowIdx++; }
      }
   }

   if(highIdx >= 2 && lowIdx >= 2)
   {
      bool hh = (g_swingHighs[0] > g_swingHighs[1]);
      bool hl = (g_swingLows[0] > g_swingLows[1]);
      bool lh = (g_swingHighs[0] < g_swingHighs[1]);
      bool ll = (g_swingLows[0] < g_swingLows[1]);

      if(hh && hl) g_structureDirection = 1;
      else if(lh && ll) g_structureDirection = -1;
      else g_structureDirection = 0;
   }
}

//+------------------------------------------------------------------+
//| Detect Fair Value Gap                                            |
//+------------------------------------------------------------------+
void DetectFVG(SMarketState &state, double price)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_H1, 0, 10, rates) < 10) return;

   for(int i = 1; i < 8; i++)
   {
      if(rates[i-1].low > rates[i+1].high)
      {
         if(price >= rates[i+1].high && price <= rates[i-1].low)
         { state.fvgDetected = true; state.fvgDirection = 1; return; }
      }
      if(rates[i-1].high < rates[i+1].low)
      {
         if(price <= rates[i+1].low && price >= rates[i-1].high)
         { state.fvgDetected = true; state.fvgDirection = -1; return; }
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Order Block                                               |
//+------------------------------------------------------------------+
void DetectOrderBlock(SMarketState &state, double price)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_H1, 0, 20, rates) < 20) return;

   for(int i = 2; i < 15; i++)
   {
      if(rates[i].close < rates[i].open)
      {
         double moveUp = rates[i-1].close - rates[i].close;
         if(moveUp > g_atr * 1.5 && price >= rates[i].low && price <= rates[i].high)
         { state.orderBlockDetected = true; state.obDirection = 1; return; }
      }
      if(rates[i].close > rates[i].open)
      {
         double moveDown = rates[i].close - rates[i-1].close;
         if(moveDown > g_atr * 1.5 && price >= rates[i].low && price <= rates[i].high)
         { state.orderBlockDetected = true; state.obDirection = -1; return; }
      }
   }
}

//+------------------------------------------------------------------+
//| Track position for partial close                                 |
//+------------------------------------------------------------------+
void TrackPosition(ulong ticket)
{
   int size = ArraySize(g_trackedTickets);
   ArrayResize(g_trackedTickets, size + 1);
   ArrayResize(g_partialClosed, size + 1);
   g_trackedTickets[size] = ticket;
   g_partialClosed[size] = false;
}

bool IsPartialClosed(ulong ticket)
{
   for(int i = 0; i < ArraySize(g_trackedTickets); i++)
      if(g_trackedTickets[i] == ticket) return g_partialClosed[i];
   return false;
}

void MarkPartialClosed(ulong ticket)
{
   for(int i = 0; i < ArraySize(g_trackedTickets); i++)
      if(g_trackedTickets[i] == ticket) { g_partialClosed[i] = true; return; }
}

//+------------------------------------------------------------------+
//| OnTrade - Track results                                          |
//+------------------------------------------------------------------+
void OnTrade()
{
   if(!g_isInitialized) return;

   datetime fromDate = TimeCurrent() - 60;
   HistorySelect(fromDate, TimeCurrent());

   int totalDeals = HistoryDealsTotal();
   for(int i = totalDeals - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) continue;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + 
                      HistoryDealGetDouble(ticket, DEAL_SWAP) +
                      HistoryDealGetDouble(ticket, DEAL_COMMISSION);

      if(profit > 0) { g_winningTrades++; g_totalProfit += profit; g_consecutiveLosses = 0; }
      else if(profit < 0) { g_totalLoss += MathAbs(profit); g_consecutiveLosses++; }
   }
}

//+------------------------------------------------------------------+
//| Dashboard                                                        |
//+------------------------------------------------------------------+
void UpdateDashboard(const SSignalResult &signal)
{
   int y = 30;
   int dy = 16;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd = (g_peakBalance > 0) ? (g_peakBalance - equity) / g_peakBalance * 100.0 : 0;
   double wr = (g_totalTrades > 0) ? (double)g_winningTrades / g_totalTrades * 100.0 : 0;
   double pf = (g_totalLoss > 0) ? g_totalProfit / g_totalLoss : 0;

   DashLabel(0, y, "BTCUSD Institutional EA v2.0", clrGold); y += dy;
   DashLabel(0, y, "----------------------------", clrGray); y += dy;
   DashLabel(0, y, StringFormat("Balance: $%.2f", balance), clrWhite); y += dy;
   DashLabel(0, y, StringFormat("Equity:  $%.2f", equity), equity >= balance ? clrLime : clrRed); y += dy;
   DashLabel(0, y, StringFormat("DD: %.2f%% (Max: %.2f%%)", dd, g_maxDrawdown), dd < 5 ? clrLime : clrRed); y += dy;
   DashLabel(0, y, StringFormat("Trades: %d | WR: %.1f%%", g_totalTrades, wr), clrWhite); y += dy;
   DashLabel(0, y, StringFormat("PF: %.2f", pf), pf > 1.5 ? clrLime : clrYellow); y += dy;
   DashLabel(0, y, StringFormat("Signal: %d | Score: %d", signal.direction, signal.score), clrAqua); y += dy;
   DashLabel(0, y, StringFormat("ATR: %.2f | RSI: %.1f", g_atr, g_rsi), clrWhite); y += dy;
}

void DashLabel(int x, int y, string text, color clr)
{
   string name = "DASH_" + IntegerToString(y);
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 20 + x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}
//+------------------------------------------------------------------+
