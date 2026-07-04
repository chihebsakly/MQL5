//+------------------------------------------------------------------+
//|                                              CoreEngine.mqh      |
//|                         Core Engine Module                        |
//+------------------------------------------------------------------+
#property copyright "Institutional EA"

//+------------------------------------------------------------------+
//| Market State Structure                                            |
//+------------------------------------------------------------------+
struct SMarketState
{
   //--- Trend
   int      trendDirection;     // 1=Bull, -1=Bear, 0=Neutral
   double   trendStrength;     // 0-100
   bool     emaAligned;        // All EMAs aligned

   //--- Momentum
   double   rsiValue;
   double   macdHistogram;
   double   stochMain;
   double   stochSignal;
   int      momentumBias;      // 1=Bull, -1=Bear, 0=Neutral

   //--- Volatility
   double   atrValue;
   double   atrNormalized;     // ATR as % of price
   int      volatilityState;   // 0=Low, 1=Normal, 2=High

   //--- Volume
   double   volumeRatio;       // Current vs Average
   bool     volumeConfirm;

   //--- Market Structure
   int      structureType;     // 0=Range, 1=Trend, 2=Breakout
   bool     bosDetected;       // Break of Structure
   bool     chochDetected;     // Change of Character
   int      structureBias;     // 1=Bull, -1=Bear

   //--- Smart Money
   bool     fvgDetected;       // Fair Value Gap
   int      fvgDirection;      // 1=Bull, -1=Bear
   bool     orderBlockDetected;
   int      obDirection;
   double   liquidityAbove;
   double   liquidityBelow;

   //--- Multi-Timeframe
   int      mtfBias;           // Combined MTF bias
   int      mtfAlignment;      // Number of TFs aligned
};

//+------------------------------------------------------------------+
//| Signal Result Structure                                           |
//+------------------------------------------------------------------+
struct SSignalResult
{
   int      direction;         // 1=Buy, -1=Sell, 0=None
   int      score;             // 0-100 signal quality
   double   confidence;        // 0.0-1.0
   string   reason;            // Signal description
   double   suggestedSL;       // Suggested stop loss distance
   double   suggestedTP;       // Suggested take profit distance
};

//+------------------------------------------------------------------+
//| Core Engine Class                                                 |
//+------------------------------------------------------------------+
class CCoreEngine
{
private:
   int      m_magicNumber;
   string   m_comment;
   bool     m_initialized;

public:
   CCoreEngine() : m_initialized(false) {}
   ~CCoreEngine() {}

   bool Initialize(int magic, string comment)
   {
      m_magicNumber = magic;
      m_comment = comment;
      m_initialized = true;
      return true;
   }

   int      GetMagicNumber()  { return m_magicNumber; }
   string   GetComment()      { return m_comment; }
   bool     IsInitialized()   { return m_initialized; }

   //--- Utility: Count open positions for this EA
   int CountPositions(string symbol)
   {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == symbol)
         {
            if(PositionGetInteger(POSITION_MAGIC) == m_magicNumber)
               count++;
         }
      }
      return count;
   }

   //--- Utility: Get total profit of open positions
   double GetOpenProfit(string symbol)
   {
      double profit = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == symbol)
         {
            if(PositionGetInteger(POSITION_MAGIC) == m_magicNumber)
               profit += PositionGetDouble(POSITION_PROFIT);
         }
      }
      return profit;
   }
};
//+------------------------------------------------------------------+
