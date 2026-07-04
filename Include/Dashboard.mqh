//+------------------------------------------------------------------+
//|                                              Dashboard.mqh       |
//|                         Dashboard Module                          |
//+------------------------------------------------------------------+
#property copyright "Institutional EA"

#include "RiskManagement.mqh"
#include "MarketAnalyzer.mqh"
#include "MachineLearning.mqh"

//+------------------------------------------------------------------+
//| Dashboard Class                                                  |
//+------------------------------------------------------------------+
class CDashboard
{
private:
   int      m_x, m_y;
   string   m_prefix;
   color    m_headerColor;
   color    m_textColor;
   color    m_positiveColor;
   color    m_negativeColor;
   color    m_neutralColor;
   int      m_fontSize;
   string   m_fontName;
   bool     m_initialized;

public:
   CDashboard() : m_initialized(false) {}
   ~CDashboard() { Destroy(); }

   //+------------------------------------------------------------------+
   //| Initialize Dashboard                                              |
   //+------------------------------------------------------------------+
   void Initialize(int x, int y)
   {
      m_x = x;
      m_y = y;
      m_prefix = "INST_DASH_";
      m_headerColor = clrGold;
      m_textColor = clrWhite;
      m_positiveColor = clrLime;
      m_negativeColor = clrRed;
      m_neutralColor = clrGray;
      m_fontSize = 9;
      m_fontName = "Consolas";
      m_initialized = true;
   }

   //+------------------------------------------------------------------+
   //| Update Dashboard                                                  |
   //+------------------------------------------------------------------+
   void Update(CRiskManagement *risk, CMarketAnalyzer *market, 
               CMachineLearning *ml, string status)
   {
      if(!m_initialized) return;

      int lineHeight = 18;
      int row = 0;

      //--- Header
      CreateLabel(0, row, "????????????????????????????????????????", m_headerColor);
      row += lineHeight;
      CreateLabel(0, row, "?   BTCUSD INSTITUTIONAL EA v1.0      ?", m_headerColor);
      row += lineHeight;
      CreateLabel(0, row, "????????????????????????????????????????", m_headerColor);
      row += lineHeight;

      //--- Status
      color statusColor = (status == "SIGNAL ACTIVE") ? m_positiveColor : 
                          (StringFind(status, "BLOCKED") >= 0) ? m_negativeColor : m_neutralColor;
      CreateLabel(0, row, "? Status: " + status, statusColor);
      row += lineHeight;

      //--- Account Info
      row += lineHeight;
      CreateLabel(0, row, "???? ACCOUNT ???????????????????????????", m_headerColor);
      row += lineHeight;

      double balance = risk.GetBalance();
      double equity = risk.GetEquity();

      CreateLabel(0, row, StringFormat("? Balance:    $%.2f", balance), m_textColor);
      row += lineHeight;
      CreateLabel(0, row, StringFormat("? Equity:     $%.2f", equity), 
                  (equity >= balance) ? m_positiveColor : m_negativeColor);
      row += lineHeight;
      CreateLabel(0, row, StringFormat("? Drawdown:   %.2f%%", risk.GetCurrentDrawdown()),
                  (risk.GetCurrentDrawdown() < 5) ? m_positiveColor : m_negativeColor);
      row += lineHeight;
      CreateLabel(0, row, StringFormat("? Max DD:     %.2f%%", risk.GetMaxDrawdown()),
                  (risk.GetMaxDrawdown() < 10) ? m_neutralColor : m_negativeColor);
      row += lineHeight;

      //--- Performance
      row += lineHeight;
      CreateLabel(0, row, "???? PERFORMANCE ???????????????????????", m_headerColor);
      row += lineHeight;

      CreateLabel(0, row, StringFormat("? Win Rate:   %.1f%%", risk.GetWinRate()),
                  (risk.GetWinRate() > 50) ? m_positiveColor : m_negativeColor);
      row += lineHeight;
      CreateLabel(0, row, StringFormat("? Profit F:   %.2f", risk.GetProfitFactor()),
                  (risk.GetProfitFactor() > 1.5) ? m_positiveColor : m_negativeColor);
      row += lineHeight;
      CreateLabel(0, row, StringFormat("? Sharpe:     %.2f", risk.GetSharpeRatio()),
                  (risk.GetSharpeRatio() > 1.0) ? m_positiveColor : m_neutralColor);
      row += lineHeight;
      CreateLabel(0, row, StringFormat("? Trades:     %d", risk.GetTotalTrades()), m_textColor);
      row += lineHeight;
      CreateLabel(0, row, StringFormat("? Daily P/L:  $%.2f", risk.GetDailyPnL()),
                  (risk.GetDailyPnL() >= 0) ? m_positiveColor : m_negativeColor);
      row += lineHeight;
      CreateLabel(0, row, StringFormat("? Monthly P/L:$%.2f", risk.GetMonthlyPnL()),
                  (risk.GetMonthlyPnL() >= 0) ? m_positiveColor : m_negativeColor);
      row += lineHeight;

      //--- Risk
      row += lineHeight;
      CreateLabel(0, row, "???? RISK ??????????????????????????????", m_headerColor);
      row += lineHeight;

      CreateLabel(0, row, StringFormat("? Risk/Trade: %.2f%%", risk.GetRiskPerTrade()), m_textColor);
      row += lineHeight;
      CreateLabel(0, row, StringFormat("? Cons.Loss:  %d/%d", 
                  risk.GetConsecutiveLosses(), 3), 
                  (risk.GetConsecutiveLosses() > 1) ? m_negativeColor : m_textColor);
      row += lineHeight;

      //--- Market
      row += lineHeight;
      CreateLabel(0, row, "???? MARKET ????????????????????????????", m_headerColor);
      row += lineHeight;

      CreateLabel(0, row, StringFormat("? ATR:        %.2f", market.GetATRValue()), m_textColor);
      row += lineHeight;
      CreateLabel(0, row, StringFormat("? RSI:        %.1f", market.GetRSIValue()), 
                  (market.GetRSIValue() > 30 && market.GetRSIValue() < 70) ? m_textColor : m_negativeColor);
      row += lineHeight;

      //--- ML Stats
      if(ml != NULL)
      {
         row += lineHeight;
         CreateLabel(0, row, "???? AI / ML ???????????????????????????", m_headerColor);
         row += lineHeight;
         CreateLabel(0, row, StringFormat("? ML Score:   %.1f%%", ml.GetConfidence() * 100.0), m_textColor);
         row += lineHeight;
         CreateLabel(0, row, StringFormat("? Patterns:   %d", ml.GetPatternCount()), m_textColor);
         row += lineHeight;
      }

      //--- Footer
      row += lineHeight;
      CreateLabel(0, row, "????????????????????????????????????????", m_headerColor);

      ChartRedraw();
   }

   //+------------------------------------------------------------------+
   //| Destroy Dashboard                                                 |
   //+------------------------------------------------------------------+
   void Destroy()
   {
      if(!m_initialized) return;
      ObjectsDeleteAll(0, m_prefix);
      m_initialized = false;
   }

private:
   //+------------------------------------------------------------------+
   //| Create text label                                                 |
   //+------------------------------------------------------------------+
   void CreateLabel(int col, int row, string text, color clr)
   {
      string name = m_prefix + IntegerToString(row) + "_" + IntegerToString(col);

      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
         ObjectSetString(0, name, OBJPROP_FONT, m_fontName);
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, m_fontSize);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      }

      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, m_x + col);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, m_y + row);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   }
};
//+------------------------------------------------------------------+
