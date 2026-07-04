//+------------------------------------------------------------------+
//|                                        MachineLearning.mqh       |
//|                         Machine Learning Module                   |
//|                    Adaptive Pattern Recognition                   |
//+------------------------------------------------------------------+
#property copyright "Institutional EA"

#include "CoreEngine.mqh"

//+------------------------------------------------------------------+
//| Trade Record Structure                                           |
//+------------------------------------------------------------------+
struct STradeRecord
{
   datetime time;
   int      direction;
   int      signalScore;
   int      trendState;
   int      volatilityState;
   int      structureType;
   bool     fvgPresent;
   bool     obPresent;
   int      mtfAlignment;
   double   rsi;
   double   profit;
   bool     isWin;
};

//+------------------------------------------------------------------+
//| Pattern Statistics                                               |
//+------------------------------------------------------------------+
struct SPatternStats
{
   int      trendState;
   int      volatilityState;
   int      structureType;
   int      totalTrades;
   int      wins;
   double   totalProfit;
   double   winRate;
   bool     isActive;         // Disabled if consistently losing
};

//+------------------------------------------------------------------+
//| Machine Learning Class                                           |
//+------------------------------------------------------------------+
class CMachineLearning
{
private:
   STradeRecord  m_records[];
   SPatternStats m_patterns[];
   int           m_maxRecords;
   int           m_recordCount;
   double        m_confidence;

   //--- Pending entry data
   SSignalResult m_pendingSignal;
   SMarketState  m_pendingState;
   bool          m_hasPending;

   //--- File for persistence
   string        m_dataFile;
   bool          m_initialized;

public:
   CMachineLearning() : m_initialized(false), m_recordCount(0), 
                         m_confidence(0.5), m_hasPending(false), m_maxRecords(1000) {}
   ~CMachineLearning() {}

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   void Initialize()
   {
      m_dataFile = "INST_EA_ML_Data.bin";
      ArrayResize(m_records, m_maxRecords);

      //--- Initialize pattern combinations
      //--- 3 trend states x 3 volatility x 3 structure = 27 patterns
      ArrayResize(m_patterns, 27);
      int idx = 0;
      for(int t = -1; t <= 1; t++)
      {
         for(int v = 0; v <= 2; v++)
         {
            for(int s = 0; s <= 2; s++)
            {
               m_patterns[idx].trendState = t;
               m_patterns[idx].volatilityState = v;
               m_patterns[idx].structureType = s;
               m_patterns[idx].totalTrades = 0;
               m_patterns[idx].wins = 0;
               m_patterns[idx].totalProfit = 0;
               m_patterns[idx].winRate = 50.0;
               m_patterns[idx].isActive = true;
               idx++;
            }
         }
      }

      //--- Load historical data
      LoadData();

      m_initialized = true;
   }

   //+------------------------------------------------------------------+
   //| Should filter signal based on ML                                  |
   //+------------------------------------------------------------------+
   bool ShouldFilterSignal(const SSignalResult &signal, const SMarketState &state)
   {
      if(!m_initialized) return false;
      if(m_recordCount < 20) return false; // Not enough data

      //--- Find matching pattern
      int patIdx = FindPattern(state.trendDirection, state.volatilityState, state.structureType);
      if(patIdx < 0) return false;

      //--- Check if pattern is deactivated
      if(!m_patterns[patIdx].isActive)
      {
         Print("ML FILTER: Pattern disabled (Trend:", state.trendDirection, 
               " Vol:", state.volatilityState, " Struct:", state.structureType, ")");
         return true;
      }

      //--- Check win rate for this pattern (minimum 10 samples)
      if(m_patterns[patIdx].totalTrades >= 10)
      {
         if(m_patterns[patIdx].winRate < 35.0) // Very low win rate
         {
            Print("ML FILTER: Low win rate pattern (", 
                  DoubleToString(m_patterns[patIdx].winRate, 1), "%)");
            return true;
         }
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Record trade entry                                                |
   //+------------------------------------------------------------------+
   void RecordEntry(const SSignalResult &signal, const SMarketState &state)
   {
      m_pendingSignal = signal;
      m_pendingState = state;
      m_hasPending = true;
   }

   //+------------------------------------------------------------------+
   //| On Trade Close - Record result                                    |
   //+------------------------------------------------------------------+
   void OnTradeClose()
   {
      if(!m_hasPending) return;

      //--- Get last closed trade profit
      HistorySelect(TimeCurrent() - 300, TimeCurrent());
      int deals = HistoryDealsTotal();

      if(deals <= 0) return;

      ulong ticket = HistoryDealGetTicket(deals - 1);
      if(ticket == 0) return;

      int entry = (int)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT) return;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                      HistoryDealGetDouble(ticket, DEAL_SWAP) +
                      HistoryDealGetDouble(ticket, DEAL_COMMISSION);

      //--- Record trade
      if(m_recordCount < m_maxRecords)
      {
         m_records[m_recordCount].time = TimeCurrent();
         m_records[m_recordCount].direction = m_pendingSignal.direction;
         m_records[m_recordCount].signalScore = m_pendingSignal.score;
         m_records[m_recordCount].trendState = m_pendingState.trendDirection;
         m_records[m_recordCount].volatilityState = m_pendingState.volatilityState;
         m_records[m_recordCount].structureType = m_pendingState.structureType;
         m_records[m_recordCount].fvgPresent = m_pendingState.fvgDetected;
         m_records[m_recordCount].obPresent = m_pendingState.orderBlockDetected;
         m_records[m_recordCount].mtfAlignment = m_pendingState.mtfAlignment;
         m_records[m_recordCount].rsi = m_pendingState.rsiValue;
         m_records[m_recordCount].profit = profit;
         m_records[m_recordCount].isWin = (profit > 0);
         m_recordCount++;
      }

      //--- Update pattern statistics
      UpdatePatternStats(m_pendingState.trendDirection, m_pendingState.volatilityState,
                         m_pendingState.structureType, profit);

      //--- Update confidence
      UpdateConfidence();

      m_hasPending = false;
   }

   //+------------------------------------------------------------------+
   //| Get confidence level                                              |
   //+------------------------------------------------------------------+
   double GetConfidence() { return m_confidence; }
   int    GetPatternCount() { return GetActivePatterns(); }

   //+------------------------------------------------------------------+
   //| Save data to file                                                 |
   //+------------------------------------------------------------------+
   void SaveData()
   {
      int handle = FileOpen(m_dataFile, FILE_WRITE | FILE_BIN);
      if(handle == INVALID_HANDLE) return;

      FileWriteInteger(handle, m_recordCount);
      for(int i = 0; i < m_recordCount; i++)
      {
         FileWriteInteger(handle, (int)m_records[i].time);
         FileWriteInteger(handle, m_records[i].direction);
         FileWriteInteger(handle, m_records[i].signalScore);
         FileWriteInteger(handle, m_records[i].trendState);
         FileWriteInteger(handle, m_records[i].volatilityState);
         FileWriteInteger(handle, m_records[i].structureType);
         FileWriteDouble(handle, m_records[i].profit);
         FileWriteInteger(handle, m_records[i].isWin ? 1 : 0);
      }

      //--- Save patterns
      int patCount = ArraySize(m_patterns);
      FileWriteInteger(handle, patCount);
      for(int i = 0; i < patCount; i++)
      {
         FileWriteInteger(handle, m_patterns[i].totalTrades);
         FileWriteInteger(handle, m_patterns[i].wins);
         FileWriteDouble(handle, m_patterns[i].totalProfit);
         FileWriteDouble(handle, m_patterns[i].winRate);
         FileWriteInteger(handle, m_patterns[i].isActive ? 1 : 0);
      }

      FileClose(handle);
   }

   //+------------------------------------------------------------------+
   //| Load data from file                                               |
   //+------------------------------------------------------------------+
   void LoadData()
   {
      if(!FileIsExist(m_dataFile)) return;

      int handle = FileOpen(m_dataFile, FILE_READ | FILE_BIN);
      if(handle == INVALID_HANDLE) return;

      m_recordCount = FileReadInteger(handle);
      if(m_recordCount > m_maxRecords) m_recordCount = m_maxRecords;

      for(int i = 0; i < m_recordCount; i++)
      {
         m_records[i].time = (datetime)FileReadInteger(handle);
         m_records[i].direction = FileReadInteger(handle);
         m_records[i].signalScore = FileReadInteger(handle);
         m_records[i].trendState = FileReadInteger(handle);
         m_records[i].volatilityState = FileReadInteger(handle);
         m_records[i].structureType = FileReadInteger(handle);
         m_records[i].profit = FileReadDouble(handle);
         m_records[i].isWin = (FileReadInteger(handle) == 1);
      }

      //--- Load patterns
      int patCount = FileReadInteger(handle);
      if(patCount == ArraySize(m_patterns))
      {
         for(int i = 0; i < patCount; i++)
         {
            m_patterns[i].totalTrades = FileReadInteger(handle);
            m_patterns[i].wins = FileReadInteger(handle);
            m_patterns[i].totalProfit = FileReadDouble(handle);
            m_patterns[i].winRate = FileReadDouble(handle);
            m_patterns[i].isActive = (FileReadInteger(handle) == 1);
         }
      }

      FileClose(handle);

      if(m_recordCount > 0)
         Print("ML: Loaded ", m_recordCount, " trade records");
   }

private:
   //+------------------------------------------------------------------+
   //| Find pattern index                                                |
   //+------------------------------------------------------------------+
   int FindPattern(int trend, int volatility, int structure)
   {
      for(int i = 0; i < ArraySize(m_patterns); i++)
      {
         if(m_patterns[i].trendState == trend &&
            m_patterns[i].volatilityState == volatility &&
            m_patterns[i].structureType == structure)
            return i;
      }
      return -1;
   }

   //+------------------------------------------------------------------+
   //| Update pattern statistics                                         |
   //+------------------------------------------------------------------+
   void UpdatePatternStats(int trend, int volatility, int structure, double profit)
   {
      int idx = FindPattern(trend, volatility, structure);
      if(idx < 0) return;

      m_patterns[idx].totalTrades++;
      m_patterns[idx].totalProfit += profit;
      if(profit > 0) m_patterns[idx].wins++;

      //--- Update win rate
      if(m_patterns[idx].totalTrades > 0)
         m_patterns[idx].winRate = (double)m_patterns[idx].wins / m_patterns[idx].totalTrades * 100.0;

      //--- Auto-disable losing patterns (minimum 15 trades)
      if(m_patterns[idx].totalTrades >= 15)
      {
         if(m_patterns[idx].winRate < 30.0 || m_patterns[idx].totalProfit < -50.0)
         {
            m_patterns[idx].isActive = false;
            Print("ML: DISABLED pattern [Trend:", trend, " Vol:", volatility, 
                  " Struct:", structure, "] WR:", 
                  DoubleToString(m_patterns[idx].winRate, 1), "%");
         }
      }

      //--- Re-enable if performance improves (check last 10 trades)
      if(!m_patterns[idx].isActive && m_patterns[idx].totalTrades >= 25)
      {
         //--- Calculate recent performance
         int recentWins = 0;
         int recentTrades = 0;
         for(int i = m_recordCount - 1; i >= 0 && recentTrades < 10; i--)
         {
            if(m_records[i].trendState == trend && 
               m_records[i].volatilityState == volatility &&
               m_records[i].structureType == structure)
            {
               recentTrades++;
               if(m_records[i].isWin) recentWins++;
            }
         }

         if(recentTrades >= 5 && (double)recentWins / recentTrades > 0.55)
         {
            m_patterns[idx].isActive = true;
            Print("ML: RE-ENABLED pattern [Trend:", trend, " Vol:", volatility, 
                  " Struct:", structure, "]");
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Update overall confidence                                         |
   //+------------------------------------------------------------------+
   void UpdateConfidence()
   {
      if(m_recordCount < 5)
      {
         m_confidence = 0.5;
         return;
      }

      //--- Calculate from last 20 trades
      int lookback = MathMin(20, m_recordCount);
      int wins = 0;
      for(int i = m_recordCount - lookback; i < m_recordCount; i++)
      {
         if(m_records[i].isWin) wins++;
      }

      m_confidence = (double)wins / lookback;
   }

   //+------------------------------------------------------------------+
   //| Count active patterns                                             |
   //+------------------------------------------------------------------+
   int GetActivePatterns()
   {
      int count = 0;
      for(int i = 0; i < ArraySize(m_patterns); i++)
      {
         if(m_patterns[i].isActive && m_patterns[i].totalTrades > 0)
            count++;
      }
      return count;
   }
};
//+------------------------------------------------------------------+
