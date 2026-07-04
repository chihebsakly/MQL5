//+------------------------------------------------------------------+
//|                                          MarketAnalyzer.mqh      |
//|                         Market Analyzer Module                    |
//+------------------------------------------------------------------+
#property copyright "Institutional EA"

#include "CoreEngine.mqh"

//+------------------------------------------------------------------+
//| Market Analyzer Class                                            |
//+------------------------------------------------------------------+
class CMarketAnalyzer
{
private:
   //--- Indicator Handles
   int      m_hEMA20, m_hEMA50, m_hEMA100, m_hEMA200;
   int      m_hRSI;
   int      m_hMACD;
   int      m_hStoch;
   int      m_hATR;
   int      m_hOBV;

   //--- Multi-Timeframe Handles
   int      m_hEMA50_M15, m_hEMA50_H1, m_hEMA50_H4, m_hEMA50_D1;
   int      m_hRSI_H1, m_hRSI_H4;
   int      m_hATR_H4;

   //--- Current Values
   double   m_ema20, m_ema50, m_ema100, m_ema200;
   double   m_rsi;
   double   m_macdMain, m_macdSignal, m_macdHist;
   double   m_stochK, m_stochD;
   double   m_atr;
   double   m_obv, m_obvPrev;

   //--- MTF Values
   double   m_ema50_M15, m_ema50_H1, m_ema50_H4, m_ema50_D1;
   double   m_rsi_H1, m_rsi_H4;
   double   m_atr_H4;

   //--- Market Structure
   double   m_swingHighs[];
   double   m_swingLows[];
   int      m_structureDirection;

   //--- Parameters
   int      m_atrPeriod;

   bool     m_initialized;

public:
   CMarketAnalyzer() : m_initialized(false) {}
   ~CMarketAnalyzer() { ReleaseHandles(); }

   //+------------------------------------------------------------------+
   //| Initialize all indicators                                         |
   //+------------------------------------------------------------------+
   bool Initialize(int ema20, int ema50, int ema100, int ema200,
                   int rsiPeriod, int macdFast, int macdSlow, int macdSignal,
                   int stochK, int stochD, int stochSlowing,
                   int atrPeriod)
   {
      m_atrPeriod = atrPeriod;
      string symbol = _Symbol;

      //--- Trend Indicators (Current TF - H1)
      m_hEMA20  = iMA(symbol, PERIOD_H1, ema20, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA50  = iMA(symbol, PERIOD_H1, ema50, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA100 = iMA(symbol, PERIOD_H1, ema100, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA200 = iMA(symbol, PERIOD_H1, ema200, 0, MODE_EMA, PRICE_CLOSE);

      //--- Momentum Indicators
      m_hRSI   = iRSI(symbol, PERIOD_H1, rsiPeriod, PRICE_CLOSE);
      m_hMACD  = iMACD(symbol, PERIOD_H1, macdFast, macdSlow, macdSignal, PRICE_CLOSE);
      m_hStoch = iStochastic(symbol, PERIOD_H1, stochK, stochD, stochSlowing, MODE_SMA, STO_LOWHIGH);

      //--- Volatility
      m_hATR = iATR(symbol, PERIOD_H1, atrPeriod);

      //--- Volume
      m_hOBV = iOBV(symbol, PERIOD_H1, VOLUME_TICK);

      //--- Multi-Timeframe
      m_hEMA50_M15 = iMA(symbol, PERIOD_M15, ema50, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA50_H1  = iMA(symbol, PERIOD_H1, ema50, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA50_H4  = iMA(symbol, PERIOD_H4, ema50, 0, MODE_EMA, PRICE_CLOSE);
      m_hEMA50_D1  = iMA(symbol, PERIOD_D1, ema50, 0, MODE_EMA, PRICE_CLOSE);
      m_hRSI_H1   = iRSI(symbol, PERIOD_H1, rsiPeriod, PRICE_CLOSE);
      m_hRSI_H4   = iRSI(symbol, PERIOD_H4, rsiPeriod, PRICE_CLOSE);
      m_hATR_H4   = iATR(symbol, PERIOD_H4, atrPeriod);

      //--- Validate handles
      if(m_hEMA20 == INVALID_HANDLE || m_hEMA50 == INVALID_HANDLE ||
         m_hEMA100 == INVALID_HANDLE || m_hEMA200 == INVALID_HANDLE ||
         m_hRSI == INVALID_HANDLE || m_hMACD == INVALID_HANDLE ||
         m_hStoch == INVALID_HANDLE || m_hATR == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create indicator handles");
         return false;
      }

      ArrayResize(m_swingHighs, 10);
      ArrayResize(m_swingLows, 10);

      m_initialized = true;
      return true;
   }

   //+------------------------------------------------------------------+
   //| Update all indicator values                                       |
   //+------------------------------------------------------------------+
   bool Update(string symbol)
   {
      if(!m_initialized) return false;

      double buffer[];
      ArraySetAsSeries(buffer, true);

      //--- EMA values
      if(CopyBuffer(m_hEMA20, 0, 0, 3, buffer) < 3) return false;
      m_ema20 = buffer[1];

      if(CopyBuffer(m_hEMA50, 0, 0, 3, buffer) < 3) return false;
      m_ema50 = buffer[1];

      if(CopyBuffer(m_hEMA100, 0, 0, 3, buffer) < 3) return false;
      m_ema100 = buffer[1];

      if(CopyBuffer(m_hEMA200, 0, 0, 3, buffer) < 3) return false;
      m_ema200 = buffer[1];

      //--- RSI
      if(CopyBuffer(m_hRSI, 0, 0, 3, buffer) < 3) return false;
      m_rsi = buffer[1];

      //--- MACD
      if(CopyBuffer(m_hMACD, 0, 0, 3, buffer) < 3) return false;
      m_macdMain = buffer[1];
      if(CopyBuffer(m_hMACD, 1, 0, 3, buffer) < 3) return false;
      m_macdSignal = buffer[1];
      m_macdHist = m_macdMain - m_macdSignal;

      //--- Stochastic
      if(CopyBuffer(m_hStoch, 0, 0, 3, buffer) < 3) return false;
      m_stochK = buffer[1];
      if(CopyBuffer(m_hStoch, 1, 0, 3, buffer) < 3) return false;
      m_stochD = buffer[1];

      //--- ATR
      if(CopyBuffer(m_hATR, 0, 0, 3, buffer) < 3) return false;
      m_atr = buffer[1];

      //--- OBV
      double obvBuffer[];
      ArraySetAsSeries(obvBuffer, true);
      if(CopyBuffer(m_hOBV, 0, 0, 5, obvBuffer) < 5) return false;
      m_obv = obvBuffer[1];
      m_obvPrev = obvBuffer[2];

      //--- MTF
      if(CopyBuffer(m_hEMA50_M15, 0, 0, 2, buffer) >= 2) m_ema50_M15 = buffer[0];
      if(CopyBuffer(m_hEMA50_H4, 0, 0, 2, buffer) >= 2)  m_ema50_H4 = buffer[0];
      if(CopyBuffer(m_hEMA50_D1, 0, 0, 2, buffer) >= 2)  m_ema50_D1 = buffer[0];
      if(CopyBuffer(m_hRSI_H4, 0, 0, 2, buffer) >= 2)    m_rsi_H4 = buffer[0];
      if(CopyBuffer(m_hATR_H4, 0, 0, 2, buffer) >= 2)    m_atr_H4 = buffer[0];

      //--- Update Market Structure
      UpdateMarketStructure(symbol);

      return true;
   }

   //+------------------------------------------------------------------+
   //| Get complete market state                                         |
   //+------------------------------------------------------------------+
   void GetMarketState(SMarketState &state)
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      //--- Trend Analysis
      AnalyzeTrend(state, price);

      //--- Momentum Analysis
      AnalyzeMomentum(state);

      //--- Volatility Analysis
      AnalyzeVolatility(state, price);

      //--- Volume Analysis
      AnalyzeVolume(state);

      //--- Market Structure
      AnalyzeStructure(state);

      //--- Smart Money Concepts
      AnalyzeSmartMoney(state, price);

      //--- Multi-Timeframe
      AnalyzeMTF(state, price);
   }

   double GetATRValue() { return m_atr; }
   double GetRSIValue() { return m_rsi; }
   double GetATRH4()    { return m_atr_H4; }

private:
   //+------------------------------------------------------------------+
   //| Trend Analysis                                                    |
   //+------------------------------------------------------------------+
   void AnalyzeTrend(SMarketState &state, double price)
   {
      //--- Direction based on EMA alignment
      if(price > m_ema20 && m_ema20 > m_ema50 && m_ema50 > m_ema100 && m_ema100 > m_ema200)
      {
         state.trendDirection = 1;
         state.emaAligned = true;
      }
      else if(price < m_ema20 && m_ema20 < m_ema50 && m_ema50 < m_ema100 && m_ema100 < m_ema200)
      {
         state.trendDirection = -1;
         state.emaAligned = true;
      }
      else
      {
         //--- Partial alignment
         int bullScore = 0;
         if(price > m_ema20)  bullScore++;
         if(price > m_ema50)  bullScore++;
         if(price > m_ema100) bullScore++;
         if(price > m_ema200) bullScore++;

         if(bullScore >= 3) state.trendDirection = 1;
         else if(bullScore <= 1) state.trendDirection = -1;
         else state.trendDirection = 0;

         state.emaAligned = false;
      }

      //--- Trend Strength (distance from EMA200 normalized)
      if(m_ema200 > 0)
         state.trendStrength = MathAbs(price - m_ema200) / m_ema200 * 100.0;
      else
         state.trendStrength = 0;
   }

   //+------------------------------------------------------------------+
   //| Momentum Analysis                                                 |
   //+------------------------------------------------------------------+
   void AnalyzeMomentum(SMarketState &state)
   {
      state.rsiValue = m_rsi;
      state.macdHistogram = m_macdHist;
      state.stochMain = m_stochK;
      state.stochSignal = m_stochD;

      int bullCount = 0;
      int bearCount = 0;

      //--- RSI bias
      if(m_rsi > 50) bullCount++;
      else if(m_rsi < 50) bearCount++;

      //--- MACD bias
      if(m_macdHist > 0) bullCount++;
      else if(m_macdHist < 0) bearCount++;

      //--- Stochastic bias
      if(m_stochK > 50 && m_stochK > m_stochD) bullCount++;
      else if(m_stochK < 50 && m_stochK < m_stochD) bearCount++;

      if(bullCount > bearCount) state.momentumBias = 1;
      else if(bearCount > bullCount) state.momentumBias = -1;
      else state.momentumBias = 0;
   }

   //+------------------------------------------------------------------+
   //| Volatility Analysis                                               |
   //+------------------------------------------------------------------+
   void AnalyzeVolatility(SMarketState &state, double price)
   {
      state.atrValue = m_atr;
      state.atrNormalized = (price > 0) ? (m_atr / price * 100.0) : 0;

      //--- Classify volatility
      //--- BTC typical: Low < 1%, Normal 1-3%, High > 3%
      if(state.atrNormalized < 1.0)
         state.volatilityState = 0; // Low
      else if(state.atrNormalized < 3.0)
         state.volatilityState = 1; // Normal
      else
         state.volatilityState = 2; // High
   }

   //+------------------------------------------------------------------+
   //| Volume Analysis                                                   |
   //+------------------------------------------------------------------+
   void AnalyzeVolume(SMarketState &state)
   {
      //--- Calculate average volume
      long volumes[];
      ArraySetAsSeries(volumes, true);
      if(CopyTickVolume(_Symbol, PERIOD_H1, 0, 20, volumes) >= 20)
      {
         double avgVol = 0;
         for(int i = 1; i < 20; i++)
            avgVol += (double)volumes[i];
         avgVol /= 19.0;

         state.volumeRatio = (avgVol > 0) ? (double)volumes[0] / avgVol : 1.0;
         state.volumeConfirm = (state.volumeRatio > 1.2);
      }
      else
      {
         state.volumeRatio = 1.0;
         state.volumeConfirm = false;
      }
   }

   //+------------------------------------------------------------------+
   //| Market Structure Analysis                                         |
   //+------------------------------------------------------------------+
   void AnalyzeStructure(SMarketState &state)
   {
      state.structureBias = m_structureDirection;
      state.bosDetected = DetectBOS();
      state.chochDetected = DetectCHOCH();

      //--- Classify structure type
      if(state.bosDetected)
         state.structureType = 2; // Breakout
      else if(MathAbs(state.trendStrength) > 2.0)
         state.structureType = 1; // Trend
      else
         state.structureType = 0; // Range
   }

   //+------------------------------------------------------------------+
   //| Smart Money Concept Analysis                                      |
   //+------------------------------------------------------------------+
   void AnalyzeSmartMoney(SMarketState &state, double price)
   {
      //--- Fair Value Gap Detection
      DetectFVG(state);

      //--- Order Block Detection
      DetectOrderBlock(state);

      //--- Liquidity Detection
      DetectLiquidity(state, price);
   }

   //+------------------------------------------------------------------+
   //| Multi-Timeframe Analysis                                          |
   //+------------------------------------------------------------------+
   void AnalyzeMTF(SMarketState &state, double price)
   {
      int alignment = 0;
      int bullTF = 0;

      //--- M15
      if(price > m_ema50_M15) bullTF++;

      //--- H1 (main)
      if(price > m_ema50) bullTF++;

      //--- H4
      if(price > m_ema50_H4) bullTF++;

      //--- D1
      if(price > m_ema50_D1) bullTF++;

      state.mtfAlignment = bullTF;

      if(bullTF >= 3) state.mtfBias = 1;
      else if(bullTF <= 1) state.mtfBias = -1;
      else state.mtfBias = 0;
   }

   //+------------------------------------------------------------------+
   //| Update Market Structure (Swing Highs/Lows)                       |
   //+------------------------------------------------------------------+
   void UpdateMarketStructure(string symbol)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);

      if(CopyRates(symbol, PERIOD_H1, 0, 50, rates) < 50) return;

      int highIdx = 0, lowIdx = 0;
      double lastHH = 0, lastHL = 0, lastLH = 0, lastLL = 0;

      //--- Find swing points (3-bar pivot)
      for(int i = 2; i < 48; i++)
      {
         //--- Swing High
         if(rates[i].high > rates[i-1].high && rates[i].high > rates[i-2].high &&
            rates[i].high > rates[i+1].high && rates[i].high > rates[i+2].high)
         {
            if(highIdx < 10)
            {
               m_swingHighs[highIdx] = rates[i].high;
               highIdx++;
            }
         }

         //--- Swing Low
         if(rates[i].low < rates[i-1].low && rates[i].low < rates[i-2].low &&
            rates[i].low < rates[i+1].low && rates[i].low < rates[i+2].low)
         {
            if(lowIdx < 10)
            {
               m_swingLows[lowIdx] = rates[i].low;
               lowIdx++;
            }
         }
      }

      //--- Determine structure direction
      if(highIdx >= 2 && lowIdx >= 2)
      {
         bool higherHighs = (m_swingHighs[0] > m_swingHighs[1]);
         bool higherLows = (m_swingLows[0] > m_swingLows[1]);
         bool lowerHighs = (m_swingHighs[0] < m_swingHighs[1]);
         bool lowerLows = (m_swingLows[0] < m_swingLows[1]);

         if(higherHighs && higherLows) m_structureDirection = 1;
         else if(lowerHighs && lowerLows) m_structureDirection = -1;
         else m_structureDirection = 0;
      }
   }

   //+------------------------------------------------------------------+
   //| Detect Break of Structure                                         |
   //+------------------------------------------------------------------+
   bool DetectBOS()
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      if(m_structureDirection == 1 && ArraySize(m_swingHighs) > 0)
      {
         if(price > m_swingHighs[0]) return true;
      }
      else if(m_structureDirection == -1 && ArraySize(m_swingLows) > 0)
      {
         if(price < m_swingLows[0]) return true;
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Detect Change of Character                                        |
   //+------------------------------------------------------------------+
   bool DetectCHOCH()
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      //--- Bullish CHoCH: price breaks above swing high in downtrend
      if(m_structureDirection == -1 && ArraySize(m_swingHighs) > 0)
      {
         if(price > m_swingHighs[0]) return true;
      }
      //--- Bearish CHoCH: price breaks below swing low in uptrend
      else if(m_structureDirection == 1 && ArraySize(m_swingLows) > 0)
      {
         if(price < m_swingLows[0]) return true;
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Detect Fair Value Gap                                             |
   //+------------------------------------------------------------------+
   void DetectFVG(SMarketState &state)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);

      if(CopyRates(_Symbol, PERIOD_H1, 0, 10, rates) < 10)
      {
         state.fvgDetected = false;
         return;
      }

      //--- Check last 5 candles for FVG
      for(int i = 1; i < 8; i++)
      {
         //--- Bullish FVG: Gap between candle[i+1].high and candle[i-1].low
         if(rates[i-1].low > rates[i+1].high)
         {
            double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(price >= rates[i+1].high && price <= rates[i-1].low)
            {
               state.fvgDetected = true;
               state.fvgDirection = 1;
               return;
            }
         }

         //--- Bearish FVG: Gap between candle[i-1].high and candle[i+1].low
         if(rates[i-1].high < rates[i+1].low)
         {
            double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(price <= rates[i+1].low && price >= rates[i-1].high)
            {
               state.fvgDetected = true;
               state.fvgDirection = -1;
               return;
            }
         }
      }

      state.fvgDetected = false;
      state.fvgDirection = 0;
   }

   //+------------------------------------------------------------------+
   //| Detect Order Block                                                |
   //+------------------------------------------------------------------+
   void DetectOrderBlock(SMarketState &state)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);

      if(CopyRates(_Symbol, PERIOD_H1, 0, 20, rates) < 20)
      {
         state.orderBlockDetected = false;
         return;
      }

      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      //--- Look for bullish order block (last bearish candle before impulsive move up)
      for(int i = 2; i < 15; i++)
      {
         //--- Bearish candle followed by strong bullish move
         if(rates[i].close < rates[i].open) // Bearish candle
         {
            double moveUp = rates[i-1].close - rates[i].close;
            if(moveUp > m_atr * 1.5) // Impulsive move
            {
               //--- Price returning to OB zone
               if(price >= rates[i].low && price <= rates[i].high)
               {
                  state.orderBlockDetected = true;
                  state.obDirection = 1;
                  return;
               }
            }
         }

         //--- Bullish candle followed by strong bearish move
         if(rates[i].close > rates[i].open) // Bullish candle
         {
            double moveDown = rates[i].close - rates[i-1].close;
            if(moveDown > m_atr * 1.5) // Impulsive move
            {
               if(price >= rates[i].low && price <= rates[i].high)
               {
                  state.orderBlockDetected = true;
                  state.obDirection = -1;
                  return;
               }
            }
         }
      }

      state.orderBlockDetected = false;
      state.obDirection = 0;
   }

   //+------------------------------------------------------------------+
   //| Detect Liquidity Levels                                           |
   //+------------------------------------------------------------------+
   void DetectLiquidity(SMarketState &state, double price)
   {
      //--- Find equal highs/lows (liquidity pools)
      MqlRates rates[];
      ArraySetAsSeries(rates, true);

      if(CopyRates(_Symbol, PERIOD_H4, 0, 50, rates) < 50)
      {
         state.liquidityAbove = price + m_atr * 3;
         state.liquidityBelow = price - m_atr * 3;
         return;
      }

      double tolerance = m_atr * 0.3;
      state.liquidityAbove = 0;
      state.liquidityBelow = 0;

      //--- Find liquidity above (equal highs / recent highs)
      for(int i = 1; i < 40; i++)
      {
         if(rates[i].high > price && (state.liquidityAbove == 0 || rates[i].high < state.liquidityAbove))
         {
            //--- Check if multiple touches
            int touches = 0;
            for(int j = i + 1; j < 50; j++)
            {
               if(MathAbs(rates[j].high - rates[i].high) < tolerance)
                  touches++;
            }
            if(touches >= 2)
               state.liquidityAbove = rates[i].high;
         }
      }

      //--- Find liquidity below (equal lows / recent lows)
      for(int i = 1; i < 40; i++)
      {
         if(rates[i].low < price && (state.liquidityBelow == 0 || rates[i].low > state.liquidityBelow))
         {
            int touches = 0;
            for(int j = i + 1; j < 50; j++)
            {
               if(MathAbs(rates[j].low - rates[i].low) < tolerance)
                  touches++;
            }
            if(touches >= 2)
               state.liquidityBelow = rates[i].low;
         }
      }

      //--- Default if not found
      if(state.liquidityAbove == 0) state.liquidityAbove = price + m_atr * 5;
      if(state.liquidityBelow == 0) state.liquidityBelow = price - m_atr * 5;
   }

   //+------------------------------------------------------------------+
   //| Release indicator handles                                         |
   //+------------------------------------------------------------------+
   void ReleaseHandles()
   {
      if(m_hEMA20 != INVALID_HANDLE)  IndicatorRelease(m_hEMA20);
      if(m_hEMA50 != INVALID_HANDLE)  IndicatorRelease(m_hEMA50);
      if(m_hEMA100 != INVALID_HANDLE) IndicatorRelease(m_hEMA100);
      if(m_hEMA200 != INVALID_HANDLE) IndicatorRelease(m_hEMA200);
      if(m_hRSI != INVALID_HANDLE)    IndicatorRelease(m_hRSI);
      if(m_hMACD != INVALID_HANDLE)   IndicatorRelease(m_hMACD);
      if(m_hStoch != INVALID_HANDLE)  IndicatorRelease(m_hStoch);
      if(m_hATR != INVALID_HANDLE)    IndicatorRelease(m_hATR);
      if(m_hOBV != INVALID_HANDLE)    IndicatorRelease(m_hOBV);
      if(m_hEMA50_M15 != INVALID_HANDLE) IndicatorRelease(m_hEMA50_M15);
      if(m_hEMA50_H4 != INVALID_HANDLE)  IndicatorRelease(m_hEMA50_H4);
      if(m_hEMA50_D1 != INVALID_HANDLE)  IndicatorRelease(m_hEMA50_D1);
      if(m_hRSI_H4 != INVALID_HANDLE)    IndicatorRelease(m_hRSI_H4);
      if(m_hATR_H4 != INVALID_HANDLE)    IndicatorRelease(m_hATR_H4);
   }
};
//+------------------------------------------------------------------+
