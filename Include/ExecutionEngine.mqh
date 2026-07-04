//+------------------------------------------------------------------+
//|                                       ExecutionEngine.mqh        |
//|                         Execution Engine Module                   |
//+------------------------------------------------------------------+
#property copyright "Institutional EA"

#include <Trade\Trade.mqh>
#include "CoreEngine.mqh"

//+------------------------------------------------------------------+
//| Execution Engine Class                                           |
//+------------------------------------------------------------------+
class CExecutionEngine
{
private:
   CTrade   m_trade;
   int      m_magicNumber;
   string   m_comment;
   double   m_maxSpread;

   //--- SL/TP Parameters
   double   m_atrMultSL;
   double   m_atrMultTP;

   //--- Trailing Parameters
   bool     m_useTrailing;
   double   m_trailATRMult;
   bool     m_useBreakEven;
   double   m_breakEvenATR;

   //--- Partial Close
   bool     m_usePartialClose;
   double   m_partialPercent;
   double   m_partialATRMult;

   //--- Tracking
   bool     m_partialClosed[];
   ulong    m_tickets[];

   bool     m_initialized;

public:
   CExecutionEngine() : m_initialized(false) {}
   ~CExecutionEngine() {}

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   bool Initialize(int magic, string comment, double maxSpread,
                   double atrMultSL, double atrMultTP,
                   bool useTrailing, double trailATRMult,
                   bool useBreakEven, double breakEvenATR,
                   bool usePartialClose, double partialPercent, double partialATRMult)
   {
      m_magicNumber     = magic;
      m_comment         = comment;
      m_maxSpread       = maxSpread;
      m_atrMultSL       = atrMultSL;
      m_atrMultTP       = atrMultTP;
      m_useTrailing     = useTrailing;
      m_trailATRMult    = trailATRMult;
      m_useBreakEven    = useBreakEven;
      m_breakEvenATR    = breakEvenATR;
      m_usePartialClose = usePartialClose;
      m_partialPercent  = partialPercent;
      m_partialATRMult  = partialATRMult;

      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints(30); // Max slippage for BTC
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);

      m_initialized = true;
      return true;
   }

   //+------------------------------------------------------------------+
   //| Execute a signal                                                  |
   //+------------------------------------------------------------------+
   bool ExecuteSignal(string symbol, const SSignalResult &signal, double lotSize, double atrValue)
   {
      if(!m_initialized) return false;
      if(signal.direction == 0) return false;

      //--- Final spread check
      double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * _Point;
      if(spread > m_maxSpread * _Point)
      {
         Print("EXECUTION BLOCKED: Spread too high: ", spread / _Point, " > ", m_maxSpread);
         return false;
      }

      //--- Calculate levels
      double price, sl, tp;
      double slDistance = atrValue * m_atrMultSL;
      double tpDistance = atrValue * m_atrMultTP;

      if(signal.direction > 0) // BUY
      {
         price = SymbolInfoDouble(symbol, SYMBOL_ASK);
         sl = price - slDistance;
         tp = price + tpDistance;
      }
      else // SELL
      {
         price = SymbolInfoDouble(symbol, SYMBOL_BID);
         sl = price + slDistance;
         tp = price - tpDistance;
      }

      //--- Normalize prices
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      sl = NormalizeDouble(sl, digits);
      tp = NormalizeDouble(tp, digits);

      //--- Execute
      bool result = false;
      string orderComment = m_comment + " S:" + IntegerToString(signal.score);

      if(signal.direction > 0)
         result = m_trade.Buy(lotSize, symbol, 0, sl, tp, orderComment);
      else
         result = m_trade.Sell(lotSize, symbol, 0, sl, tp, orderComment);

      if(result)
      {
         Print("ORDER EXECUTED: ", (signal.direction > 0 ? "BUY" : "SELL"),
               " Lot: ", lotSize, " SL: ", sl, " TP: ", tp,
               " Score: ", signal.score, " Reason: ", signal.reason);

         //--- Track for partial close
         TrackPosition(m_trade.ResultOrder());
      }
      else
      {
         Print("ORDER FAILED: Error ", GetLastError(), 
               " RetCode: ", m_trade.ResultRetcode(),
               " Comment: ", m_trade.ResultComment());
      }

      return result;
   }

   //+------------------------------------------------------------------+
   //| Manage existing positions                                         |
   //+------------------------------------------------------------------+
   void ManagePositions(string symbol, double atrValue)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!PositionGetSymbol(i) == symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber) continue;

         ulong ticket = PositionGetInteger(POSITION_TICKET);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSL = PositionGetDouble(POSITION_SL);
         double currentTP = PositionGetDouble(POSITION_TP);
         double posProfit = PositionGetDouble(POSITION_PROFIT);
         double volume = PositionGetDouble(POSITION_VOLUME);
         long posType = PositionGetInteger(POSITION_TYPE);

         double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                               SymbolInfoDouble(symbol, SYMBOL_BID) :
                               SymbolInfoDouble(symbol, SYMBOL_ASK);

         //--- Break Even
         if(m_useBreakEven)
            ApplyBreakEven(ticket, symbol, posType, openPrice, currentSL, currentPrice, atrValue);

         //--- Trailing Stop
         if(m_useTrailing)
            ApplyTrailingStop(ticket, symbol, posType, openPrice, currentSL, currentPrice, atrValue);

         //--- Partial Close
         if(m_usePartialClose)
            ApplyPartialClose(ticket, symbol, posType, openPrice, currentPrice, volume, atrValue);
      }
   }

private:
   //+------------------------------------------------------------------+
   //| Apply Break Even                                                  |
   //+------------------------------------------------------------------+
   void ApplyBreakEven(ulong ticket, string symbol, long posType, 
                       double openPrice, double currentSL, double currentPrice, double atr)
   {
      double beDistance = atr * m_breakEvenATR;
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

      if(posType == POSITION_TYPE_BUY)
      {
         //--- Price has moved enough in our favor
         if(currentPrice >= openPrice + beDistance)
         {
            //--- SL not yet at break even
            if(currentSL < openPrice)
            {
               double newSL = NormalizeDouble(openPrice + _Point * 10, digits); // Small buffer
               m_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
            }
         }
      }
      else // SELL
      {
         if(currentPrice <= openPrice - beDistance)
         {
            if(currentSL > openPrice || currentSL == 0)
            {
               double newSL = NormalizeDouble(openPrice - _Point * 10, digits);
               m_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Apply Trailing Stop                                               |
   //+------------------------------------------------------------------+
   void ApplyTrailingStop(ulong ticket, string symbol, long posType,
                          double openPrice, double currentSL, double currentPrice, double atr)
   {
      double trailDistance = atr * m_trailATRMult;
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

      if(posType == POSITION_TYPE_BUY)
      {
         //--- Only trail if in profit past break even
         if(currentPrice > openPrice + trailDistance)
         {
            double newSL = NormalizeDouble(currentPrice - trailDistance, digits);
            if(newSL > currentSL && newSL > openPrice)
            {
               m_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
            }
         }
      }
      else // SELL
      {
         if(currentPrice < openPrice - trailDistance)
         {
            double newSL = NormalizeDouble(currentPrice + trailDistance, digits);
            if((newSL < currentSL || currentSL == 0) && newSL < openPrice)
            {
               m_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Apply Partial Close                                               |
   //+------------------------------------------------------------------+
   void ApplyPartialClose(ulong ticket, string symbol, long posType,
                          double openPrice, double currentPrice, double volume, double atr)
   {
      double partialDistance = atr * m_partialATRMult;

      //--- Check if already partially closed
      if(IsPartialClosed(ticket)) return;

      //--- Minimum volume check
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double closeVolume = NormalizeDouble(volume * (m_partialPercent / 100.0), 2);
      if(closeVolume < minLot) return;
      if(volume - closeVolume < minLot) return; // Remaining must be valid

      bool shouldClose = false;

      if(posType == POSITION_TYPE_BUY)
         shouldClose = (currentPrice >= openPrice + partialDistance);
      else
         shouldClose = (currentPrice <= openPrice - partialDistance);

      if(shouldClose)
      {
         if(m_trade.PositionClosePartial(ticket, closeVolume))
         {
            MarkPartialClosed(ticket);
            Print("PARTIAL CLOSE: Ticket ", ticket, " Volume: ", closeVolume);
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Track position for partial close                                  |
   //+------------------------------------------------------------------+
   void TrackPosition(ulong ticket)
   {
      int size = ArraySize(m_tickets);
      ArrayResize(m_tickets, size + 1);
      ArrayResize(m_partialClosed, size + 1);
      m_tickets[size] = ticket;
      m_partialClosed[size] = false;
   }

   bool IsPartialClosed(ulong ticket)
   {
      for(int i = 0; i < ArraySize(m_tickets); i++)
      {
         if(m_tickets[i] == ticket)
            return m_partialClosed[i];
      }
      return false;
   }

   void MarkPartialClosed(ulong ticket)
   {
      for(int i = 0; i < ArraySize(m_tickets); i++)
      {
         if(m_tickets[i] == ticket)
         {
            m_partialClosed[i] = true;
            return;
         }
      }
   }
};
//+------------------------------------------------------------------+
