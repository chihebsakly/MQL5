//+------------------------------------------------------------------+
//|                                       AIDecisionEngine.mqh       |
//|                         AI Decision Engine Module                 |
//+------------------------------------------------------------------+
#property copyright "Institutional EA"

#include "CoreEngine.mqh"

//+------------------------------------------------------------------+
//| AI Decision Engine Class                                         |
//+------------------------------------------------------------------+
class CAIDecisionEngine
{
private:
   int      m_minScore;
   bool     m_initialized;

   //--- Weight Configuration
   double   m_weightTrend;
   double   m_weightMomentum;
   double   m_weightVolatility;
   double   m_weightVolume;
   double   m_weightStructure;
   double   m_weightSmartMoney;
   double   m_weightMTF;

public:
   CAIDecisionEngine() : m_initialized(false) {}
   ~CAIDecisionEngine() {}

   //+------------------------------------------------------------------+
   //| Initialize with default weights                                   |
   //+------------------------------------------------------------------+
   bool Initialize(int minScore)
   {
      m_minScore = minScore;

      //--- Default weights (total = 100)
      m_weightTrend      = 20.0;
      m_weightMomentum   = 15.0;
      m_weightVolatility = 10.0;
      m_weightVolume     = 10.0;
      m_weightStructure  = 20.0;
      m_weightSmartMoney = 15.0;
      m_weightMTF        = 10.0;

      m_initialized = true;
      return true;
   }

   //+------------------------------------------------------------------+
   //| Evaluate signal from market state                                 |
   //+------------------------------------------------------------------+
   void EvaluateSignal(const SMarketState &state, SSignalResult &signal)
   {
      signal.direction = 0;
      signal.score = 0;
      signal.confidence = 0;
      signal.reason = "";

      //--- Calculate individual scores
      double trendScore = ScoreTrend(state);
      double momentumScore = ScoreMomentum(state);
      double volatilityScore = ScoreVolatility(state);
      double volumeScore = ScoreVolume(state);
      double structureScore = ScoreStructure(state);
      double smartMoneyScore = ScoreSmartMoney(state);
      double mtfScore = ScoreMTF(state);

      //--- Determine direction consensus
      int bullSignals = 0;
      int bearSignals = 0;

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

      //--- Direction decision (minimum 3 aligned factors)
      if(bullSignals > bearSignals && bullSignals >= 3)
         signal.direction = 1;
      else if(bearSignals > bullSignals && bearSignals >= 3)
         signal.direction = -1;
      else
      {
         signal.direction = 0;
         signal.score = 0;
         signal.reason = "No clear direction";
         return;
      }

      //--- Calculate weighted score
      double rawScore = 0;
      rawScore += trendScore * (m_weightTrend / 100.0);
      rawScore += momentumScore * (m_weightMomentum / 100.0);
      rawScore += volatilityScore * (m_weightVolatility / 100.0);
      rawScore += volumeScore * (m_weightVolume / 100.0);
      rawScore += structureScore * (m_weightStructure / 100.0);
      rawScore += smartMoneyScore * (m_weightSmartMoney / 100.0);
      rawScore += mtfScore * (m_weightMTF / 100.0);

      signal.score = (int)MathRound(rawScore);
      signal.confidence = rawScore / 100.0;

      //--- Quality filter: Penalize conflicting signals
      if(signal.direction == 1 && state.momentumBias < 0)
         signal.score -= 10;
      if(signal.direction == -1 && state.momentumBias > 0)
         signal.score -= 10;

      //--- Volatility adjustment
      if(state.volatilityState == 2) // High volatility
         signal.score -= 5; // More cautious

      //--- RSI extremes bonus (reversal potential at extremes)
      if(signal.direction == 1 && state.rsiValue < 35)
         signal.score += 5;
      if(signal.direction == -1 && state.rsiValue > 65)
         signal.score += 5;

      //--- Clamp score
      if(signal.score > 100) signal.score = 100;
      if(signal.score < 0) signal.score = 0;

      //--- Build reason
      signal.reason = BuildSignalReason(signal.direction, trendScore, momentumScore, 
                                          structureScore, smartMoneyScore);

      //--- Suggested SL/TP based on ATR
      signal.suggestedSL = state.atrValue * 2.0;
      signal.suggestedTP = state.atrValue * 3.0;

      //--- Adjust TP based on confidence
      if(signal.confidence > 0.85)
         signal.suggestedTP = state.atrValue * 4.0;
   }

   //+------------------------------------------------------------------+
   //| Adjust weights based on performance feedback                      |
   //+------------------------------------------------------------------+
   void AdjustWeights(double trendWinRate, double momentumWinRate, 
                      double structureWinRate, double smcWinRate)
   {
      //--- Increase weight of profitable factors
      double total = trendWinRate + momentumWinRate + structureWinRate + smcWinRate;
      if(total <= 0) return;

      double baseWeight = 100.0 / 7.0; // Distributed equally

      m_weightTrend = baseWeight * (trendWinRate / (total / 4.0));
      m_weightStructure = baseWeight * (structureWinRate / (total / 4.0));
      m_weightSmartMoney = baseWeight * (smcWinRate / (total / 4.0));
      m_weightMomentum = baseWeight * (momentumWinRate / (total / 4.0));

      //--- Normalize to 100
      double sum = m_weightTrend + m_weightMomentum + m_weightVolatility + 
                   m_weightVolume + m_weightStructure + m_weightSmartMoney + m_weightMTF;
      if(sum > 0)
      {
         m_weightTrend = m_weightTrend / sum * 100.0;
         m_weightMomentum = m_weightMomentum / sum * 100.0;
         m_weightStructure = m_weightStructure / sum * 100.0;
         m_weightSmartMoney = m_weightSmartMoney / sum * 100.0;
      }
   }

private:
   //+------------------------------------------------------------------+
   //| Score Trend (0-100)                                               |
   //+------------------------------------------------------------------+
   double ScoreTrend(const SMarketState &state)
   {
      double score = 40.0; // Base

      if(state.emaAligned) score += 35.0;
      else if(state.trendDirection != 0) score += 20.0;

      if(state.trendStrength > 0.5) score += 10.0;
      if(state.trendStrength > 1.0) score += 10.0;
      if(state.trendStrength > 2.0) score += 5.0;

      return MathMin(100.0, MathMax(0.0, score));
   }

   //+------------------------------------------------------------------+
   //| Score Momentum (0-100)                                            |
   //+------------------------------------------------------------------+
   double ScoreMomentum(const SMarketState &state)
   {
      double score = 50.0;

      //--- RSI in good zone (not overbought/oversold against direction)
      if(state.rsiValue > 40 && state.rsiValue < 60)
         score += 10.0;

      //--- MACD histogram confirmation
      if(state.macdHistogram > 0 && state.momentumBias > 0)
         score += 20.0;
      else if(state.macdHistogram < 0 && state.momentumBias < 0)
         score += 20.0;

      //--- Stochastic not in extreme
      if(state.stochMain > 20 && state.stochMain < 80)
         score += 10.0;

      //--- All momentum aligned
      if(state.momentumBias != 0)
         score += 10.0;

      return MathMin(100.0, MathMax(0.0, score));
   }

   //+------------------------------------------------------------------+
   //| Score Volatility (0-100)                                          |
   //+------------------------------------------------------------------+
   double ScoreVolatility(const SMarketState &state)
   {
      double score = 50.0;

      //--- Normal volatility is ideal
      if(state.volatilityState == 1) score += 30.0;
      else if(state.volatilityState == 0) score += 10.0; // Low vol, breakout potential
      else score -= 20.0; // High vol, more risk

      return MathMin(100.0, MathMax(0.0, score));
   }

   //+------------------------------------------------------------------+
   //| Score Volume (0-100)                                              |
   //+------------------------------------------------------------------+
   double ScoreVolume(const SMarketState &state)
   {
      double score = 50.0;

      if(state.volumeConfirm) score += 30.0;
      if(state.volumeRatio > 1.5) score += 10.0;
      if(state.volumeRatio > 2.0) score += 10.0;

      return MathMin(100.0, MathMax(0.0, score));
   }

   //+------------------------------------------------------------------+
   //| Score Structure (0-100)                                           |
   //+------------------------------------------------------------------+
   double ScoreStructure(const SMarketState &state)
   {
      double score = 45.0;

      if(state.bosDetected) score += 25.0;
      if(state.chochDetected) score += 15.0;
      if(state.structureType == 1) score += 15.0; // Trending
      if(state.structureType == 2) score += 20.0; // Breakout
      if(state.structureBias != 0) score += 5.0;

      return MathMin(100.0, MathMax(0.0, score));
   }

   //+------------------------------------------------------------------+
   //| Score Smart Money (0-100)                                         |
   //+------------------------------------------------------------------+
   double ScoreSmartMoney(const SMarketState &state)
   {
      double score = 40.0;

      if(state.fvgDetected) score += 25.0;
      if(state.orderBlockDetected) score += 25.0;

      //--- Bonus if both aligned
      if(state.fvgDetected && state.orderBlockDetected &&
         state.fvgDirection == state.obDirection)
         score += 10.0;

      return MathMin(100.0, MathMax(0.0, score));
   }

   //+------------------------------------------------------------------+
   //| Score Multi-Timeframe (0-100)                                     |
   //+------------------------------------------------------------------+
   double ScoreMTF(const SMarketState &state)
   {
      double score = 35.0;

      //--- Each aligned timeframe adds points
      score += state.mtfAlignment * 12.0;

      //--- Full alignment bonus
      if(state.mtfAlignment >= 4) score += 17.0;
      else if(state.mtfAlignment >= 3) score += 8.0;

      return MathMin(100.0, MathMax(0.0, score));
   }

   //+------------------------------------------------------------------+
   //| Build signal reason string                                        |
   //+------------------------------------------------------------------+
   string BuildSignalReason(int direction, double trendS, double momentumS, 
                            double structureS, double smcS)
   {
      string dir = (direction > 0) ? "BUY" : "SELL";
      string reason = dir + " | ";

      if(trendS > 70)    reason += "Strong Trend ";
      if(momentumS > 70) reason += "| Momentum Confirmed ";
      if(structureS > 70) reason += "| Structure Break ";
      if(smcS > 70)      reason += "| SMC Confluence ";

      return reason;
   }
};
//+------------------------------------------------------------------+
