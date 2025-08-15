//+------------------------------------------------------------------+
//|                                                       ts2024.mq5 |
//|                                                            lamdt |
//|                                             github.com/tunglam14 |
//+------------------------------------------------------------------+
#property copyright "lamdt"
#property link      "github.com/tunglam14"
#property version   "2.00"


#include <Controls\Edit.mqh>
#include <Controls\Dialog.mqh>
#include <Controls\CheckGroup.mqh>
#include <Controls\Label.mqh>
#include <Controls\Button.mqh>
#include <Trade\Trade.mqh>

CTrade                  m_trade;

input string   ORDER_SETTING = "--------";
input double   TP_IN_POINT   = 2000; // Khoang gia TP
input double   SL_IN_POINT   = 2000; // Khoang gia SL
input int      MAX_ORDER     = 1; // So lenh mo toi da

enum ListModeInit
  {
   OpenInNewCandle=0, // Mo Lenh Khi Sang Nen Moi
   BeforeCloseCandle=1, // Mo Lenh Truoc Khi Dong Nen
  };
input ListModeInit  MODE_ORDER = 0; // Kieu vao lenh

input int           LAST_SECOND = 55; // So giay cuoi truoc khi vao lenh

input string   CHART_SETTING         = "--------";
input color    RESISTANCE_LINE_COLOR = clrMediumVioletRed; // Mau cua duong khang cu
input color    SUPPORT_LINE_COLOR    = clrTeal; // Mau cua duong ho tro

input string   ADVANCE_SETTING = "--------";
input string   COMMENT         = "TS EA";
input int      MAX_RETRY       = 5;
input int      MAGIC           = 13579;


double resistancePrice = 0.0;
double supportPrice = 0.0;
double orderLot = 0.0;
bool enableTrade = false;
int openOrder = 0;
double autoBE = 0.0;

#define INDENT_LEFT                         (11)
#define INDENT_RIGHT                        (11)
#define INDENT_TOP                          (11)
#define INDENT_BOTTOM                       (11)

#define CONTROLS_GAP_X                      (5)
#define CONTROLS_GAP_Y                      (5)

#define COLUMN_1_WIDTH                      (80)
#define COLUMN_2_WIDTH                      (80)
#define ROW_HEIGHT                          (20)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CControlsDialog : public CAppDialog
  {
private:
   CLabel            m_r_price_label;
   CEdit             m_r_price;
   CLabel            m_s_price_label;
   CEdit             m_s_price;
   CLabel            m_volume_label;
   CEdit             m_volume;
   CCheckGroup       m_enable_trade;
   CButton           m_btn_closeall;
   CButton           m_btn_be;
   CLabel            m_autobe_label;
   CEdit             m_autobe;

public:
                     CControlsDialog(void);
                    ~CControlsDialog(void);

   virtual bool      Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2);
   virtual bool      OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam);
   virtual bool      UpdateEnableTrade(const bool value);
   virtual bool      UpdateResistancePrice(const double price);
   virtual bool      UpdateSupportPrice(const double price);

protected:
   bool              CreateResistancePriceLabel(void);
   bool              CreateResistancePrice(void);

   bool              CreateSupportPriceLabel(void);
   bool              CreateSupportPrice(void);

   bool              CreateVolumeLabel(void);
   bool              CreateVolume(void);

   bool              CreateEnableTrade(void);

   bool              CreateBtnCloseAll(void);
   bool              CreateBtnBE(void);

   bool              CreateAutoBELabel(void);
   bool              CreateAutoBE(void);

   void              OnChangeCheckGroup(void);

   void              OnChangeResistancePrice(void);
   void              OnChangeSupprtPrice(void);
   void              OnChangeVolume(void);
   void              OnChangeAutoBE(void);
   void              OnClickBtnCloseAll(void);
   void              OnClickBtnBE(void);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
EVENT_MAP_BEGIN(CControlsDialog)
ON_EVENT(ON_CHANGE, m_enable_trade, OnChangeCheckGroup)
ON_EVENT(ON_END_EDIT, m_r_price, OnChangeResistancePrice)
ON_EVENT(ON_END_EDIT, m_s_price, OnChangeSupprtPrice)
ON_EVENT(ON_END_EDIT, m_volume, OnChangeVolume)
ON_EVENT(ON_END_EDIT, m_autobe, OnChangeAutoBE)
ON_EVENT(ON_CLICK, m_btn_closeall, OnClickBtnCloseAll)
ON_EVENT(ON_CLICK, m_btn_be, OnClickBtnBE)
EVENT_MAP_END(CAppDialog)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CControlsDialog::CControlsDialog(void)
  {
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CControlsDialog::~CControlsDialog(void)
  {
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CControlsDialog::UpdateEnableTrade(bool value)
  {
   m_enable_trade.Check(0, value);
   enableTrade = value;
   return m_enable_trade.Value(value);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CControlsDialog::UpdateResistancePrice(double price)
  {
   return m_r_price.Text(DoubleToString(price, 3));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CControlsDialog::UpdateSupportPrice(double price)
  {
   return m_s_price.Text(DoubleToString(price, 3));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CControlsDialog::Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2)
  {
   if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2))
      return(false);

   if(!CreateResistancePriceLabel())
      return(false);

   if(!CreateResistancePrice())
      return(false);

   if(!CreateSupportPriceLabel())
      return(false);

   if(!CreateSupportPrice())
      return(false);

   if(!CreateVolumeLabel())
      return(false);

   if(!CreateVolume())
      return(false);

   if(!CreateEnableTrade())
      return(false);

   if(!CreateAutoBELabel())
      return(false);

   if(!CreateAutoBE())
      return(false);

   if(!CreateBtnCloseAll())
      return(false);

   if(!CreateBtnBE())
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CControlsDialog::CreateResistancePriceLabel(void)
  {
   int x1 = INDENT_LEFT;
   int y1 = INDENT_TOP;
   int x2 = x1 + COLUMN_1_WIDTH;
   int y2 = y1 + ROW_HEIGHT;

   if(!m_r_price_label.Create(0, m_name+"Resistance Price Label", m_subwin, x1, y1, x2, y2))
      return(false);

   if(!m_r_price_label.Text("Resistance:"))
      return(false);
   if(!Add(m_r_price_label))
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CControlsDialog::CreateResistancePrice(void)
  {
   int x1 = INDENT_LEFT + COLUMN_1_WIDTH + CONTROLS_GAP_X;
   int y1 = INDENT_TOP;
   int x2 = x1 + COLUMN_2_WIDTH;
   int y2 = y1 + ROW_HEIGHT;

   if(!m_r_price.Create(0, m_name+"Resistance Price", m_subwin, x1, y1, x2, y2))
      return(false);
   if(!m_r_price.ReadOnly(false))
      return(false);
   if(!Add(m_r_price))
      return(false);

   return(true);
  }
//+---

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CControlsDialog::CreateSupportPriceLabel(void)
  {
   int x1 = INDENT_LEFT;
   int y1 = INDENT_TOP + 1 * (ROW_HEIGHT + CONTROLS_GAP_Y);
   int x2 = x1 + COLUMN_1_WIDTH;
   int y2 = y1 + ROW_HEIGHT;

   if(!m_s_price_label.Create(0, m_name+"Support Price Label", m_subwin, x1, y1, x2, y2))
      return(false);

   if(!m_s_price_label.Text("Support:"))
      return(false);
   if(!Add(m_s_price_label))
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CControlsDialog::CreateSupportPrice(void)
  {
   int x1 = INDENT_LEFT + COLUMN_1_WIDTH + CONTROLS_GAP_X;
   int y1 = INDENT_TOP + 1 * (ROW_HEIGHT + CONTROLS_GAP_Y);
   int x2 = x1 + COLUMN_2_WIDTH;
   int y2 = y1 + ROW_HEIGHT;

   if(!m_s_price.Create(0, m_name+"Support Price", m_subwin, x1, y1, x2, y2))
      return(false);
   if(!m_s_price.ReadOnly(false))
      return(false);
   if(!Add(m_s_price))
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CControlsDialog::CreateVolumeLabel(void)
  {
   int x1 = INDENT_LEFT;
   int y1 = INDENT_TOP + 2 * (ROW_HEIGHT + CONTROLS_GAP_Y);
   int x2 = x1 + COLUMN_1_WIDTH;
   int y2 = y1 + ROW_HEIGHT;

   if(!m_volume_label.Create(0, m_name+"Volume Label", m_subwin, x1, y1, x2, y2))
      return(false);

   if(!m_volume_label.Text("Lot:"))
      return(false);
   if(!Add(m_volume_label))
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CControlsDialog::CreateVolume(void)
  {
   int x1 = INDENT_LEFT + COLUMN_1_WIDTH + CONTROLS_GAP_X;
   int y1 = INDENT_TOP + 2 * (ROW_HEIGHT + CONTROLS_GAP_Y);
   int x2 = x1 + COLUMN_2_WIDTH;
   int y2 = y1 + ROW_HEIGHT;

   if(!m_volume.Create(ChartID(), m_name+"Volume", m_subwin, x1, y1, x2, y2))
      return(false);

   if(!m_volume.ReadOnly(false))
      return(false);

   if(!Add(m_volume))
      return(false);


   return(true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CControlsDialog::CreateEnableTrade(void)
  {
   int x1 = INDENT_LEFT;
   int y1 = INDENT_TOP + 3 * (ROW_HEIGHT + CONTROLS_GAP_Y);
   int x2 = x1 + 2 * COLUMN_1_WIDTH;
   int y2 = y1 + ROW_HEIGHT;

   if(!m_enable_trade.Create(0, m_name+"Enable Trade", m_subwin, x1, y1, x2, y2))
      return(false);

   if(!Add(m_enable_trade))
      return(false);

//m_enable_trade.Alignment(WND_ALIGN_HEIGHT,0,y1,0,0);

   if(!m_enable_trade.AddItem("Cho Phep Vao Lenh", 1<<0))
      return(false);


   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CControlsDialog::CreateAutoBELabel(void)
  {
   int x1 = INDENT_LEFT;
   int y1 = INDENT_TOP + 5 * (ROW_HEIGHT + CONTROLS_GAP_Y);
   int x2 = x1 + COLUMN_1_WIDTH;
   int y2 = y1 + ROW_HEIGHT;

   if(!m_autobe_label.Create(0, m_name+"Auto BE Label", m_subwin, x1, y1, x2, y2))
      return(false);

   if(!m_autobe_label.Text("Auto BE:"))
      return(false);
   if(!Add(m_autobe_label))
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CControlsDialog::CreateAutoBE(void)
  {
   int x1 = INDENT_LEFT + COLUMN_1_WIDTH + CONTROLS_GAP_X;
   int y1 = INDENT_TOP + 5 * (ROW_HEIGHT + CONTROLS_GAP_Y);
   int x2 = x1 + COLUMN_2_WIDTH;
   int y2 = y1 + ROW_HEIGHT;

   if(!m_autobe.Create(0, m_name+"Auto BE", m_subwin, x1, y1, x2, y2))
      return(false);
   if(!m_autobe.ReadOnly(false))
      return(false);
   if(!Add(m_autobe))
      return(false);

   m_autobe.Text(DoubleToString(autoBE, 0));

   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CControlsDialog::CreateBtnCloseAll(void)
  {
//--- coordinates
   int x1 = INDENT_LEFT;
   int y1 = INDENT_TOP + 6 * (ROW_HEIGHT + CONTROLS_GAP_Y);
   int x2 = x1 + COLUMN_1_WIDTH;
   int y2 = y1 + ROW_HEIGHT;

   if(!m_btn_closeall.Create(0, m_name+"BtnCloseAll", m_subwin, x1, y1, x2, y2))
      return(false);

   if(!m_btn_closeall.Text("Close All"))

      return(false);

   if(!Add(m_btn_closeall))
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CControlsDialog::CreateBtnBE(void)
  {
//--- coordinates
   int x1 = INDENT_LEFT + COLUMN_1_WIDTH + CONTROLS_GAP_X;
   int y1 = INDENT_TOP + 6 * (ROW_HEIGHT + CONTROLS_GAP_Y);
   int x2 = x1 + COLUMN_2_WIDTH;
   int y2 = y1 + ROW_HEIGHT;

   if(!m_btn_be.Create(0, m_name+"BtnBE", m_subwin, x1, y1, x2, y2))
      return(false);

   if(!m_btn_be.Text("SL=BE"))
      return(false);

   if(!Add(m_btn_be))
      return(false);

   return(true);
  }
//+------------------------------------------------------------------+
//| Event handler                                                    |
//+------------------------------------------------------------------+
void CControlsDialog::OnChangeCheckGroup(void)
  {
//Comment(__FUNCTION__+" : Value="+IntegerToString(m_enable_trade.Value()));
   enableTrade = m_enable_trade.Value();
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CControlsDialog::OnChangeResistancePrice(void)
  {
   Print("Change Resistance price = ", m_r_price.Text());
   resistancePrice = StringToDouble(m_r_price.Text());

   ObjectCreate(0, "Resistance price line", OBJ_HLINE, 0, 0, resistancePrice);
   ObjectSetInteger(0, "Resistance price line", OBJPROP_COLOR, RESISTANCE_LINE_COLOR);
   ObjectSetInteger(0, "Resistance price line", OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, "Resistance price line", OBJPROP_SELECTED, true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CControlsDialog::OnChangeSupprtPrice(void)
  {
   Print("Change Support price = ", m_s_price.Text());
   supportPrice = StringToDouble(m_s_price.Text());

   ObjectCreate(0, "Support price line", OBJ_HLINE, 0, 0, supportPrice);
   ObjectSetInteger(0, "Support price line", OBJPROP_COLOR, SUPPORT_LINE_COLOR);
   ObjectSetInteger(0, "Support price line", OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, "Support price line", OBJPROP_SELECTED, true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CControlsDialog::OnChangeVolume(void)
  {
   Print("Change volume = ", m_volume.Text());
   orderLot = StringToDouble(m_volume.Text());
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CControlsDialog::OnChangeAutoBE(void)
  {
   Print("Change autoBE = ", m_autobe.Text());
   autoBE = StringToDouble(m_autobe.Text());
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CControlsDialog::OnClickBtnCloseAll(void)
  {
   Print("Trigger button CloseAllOrder");
   closeAllPositions();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CControlsDialog::OnClickBtnBE(void)
  {
   Print("Trigger button BE");
   setBEAllPositions();
  }

CControlsDialog ExtDialog;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {

   if(!ExtDialog.Create(0, "TS Trading Panel", 0, 20, 40, 20 + INDENT_LEFT + COLUMN_1_WIDTH + CONTROLS_GAP_X + COLUMN_2_WIDTH + INDENT_RIGHT + INDENT_RIGHT, 40 + INDENT_TOP + ROW_HEIGHT * 9 + CONTROLS_GAP_Y * 7 + INDENT_BOTTOM))
      return(INIT_FAILED);

   if(!ExtDialog.Run())
      return(INIT_FAILED);

   return INIT_SUCCEEDED;
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   orderLot = 0.0;
   ExtDialog.UpdateEnableTrade(false);
   ExtDialog.Destroy(reason);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   static datetime dtBarCurrent  = WRONG_VALUE;
   datetime dtBarPrevious = dtBarCurrent;
   dtBarCurrent  = iTime(_Symbol, _Period, 0);
   bool     bNewBarEvent  = (dtBarCurrent != dtBarPrevious);
   double currentAsk = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(Symbol(), SYMBOL_BID);

   MqlDateTime tm= {};
   TimeToStruct(SymbolInfoInteger(Symbol(), SYMBOL_TIME), tm);

   if(ObjectGetDouble(0, "Resistance price line", OBJPROP_PRICE))
     {
      resistancePrice = ObjectGetDouble(0, "Resistance price line", OBJPROP_PRICE);
      ExtDialog.UpdateResistancePrice(resistancePrice);
     }

   if(ObjectGetDouble(0, "Support price line", OBJPROP_PRICE))
     {
      supportPrice = ObjectGetDouble(0, "Support price line", OBJPROP_PRICE);
      ExtDialog.UpdateSupportPrice(supportPrice);
     }

   updateListOrder();

   if(enableTrade && supportPrice && resistancePrice && orderLot)
     {
      if(openOrder >= MAX_ORDER)
        {
         Comment("ACTIVE - So lenh vuot qua MAX_ORDER " + IntegerToString(openOrder) + "/" + IntegerToString(MAX_ORDER));
         return;
        }

      Comment("ACTIVE - Dang cho vao " + orderLot +" lot neu gia pha vo " + DoubleToString(supportPrice, 3) + "-" + DoubleToString(resistancePrice, 3));

      if(currentBid >= resistancePrice)
        {
         double tp = 0;
         double sl = 0;

         if(TP_IN_POINT != 0.0)
            tp = NormalizeDouble(currentAsk + TP_IN_POINT*Point(), Digits());
         if(SL_IN_POINT != 0.0)
            sl = NormalizeDouble(currentAsk - SL_IN_POINT*Point(), Digits());

         if(MODE_ORDER == 0 && bNewBarEvent)
           {
            createOrder(Symbol(), ORDER_TYPE_BUY, orderLot, "", currentAsk, tp, sl);
           }

         if(MODE_ORDER == 1 && tm.sec >= LAST_SECOND)
           {
            createOrder(Symbol(), ORDER_TYPE_BUY, orderLot, "", currentAsk, tp, sl);
           }
        }

      if(currentBid <= supportPrice)
        {
         double tp = 0;
         double sl = 0;

         if(TP_IN_POINT != 0.0)
            tp = NormalizeDouble(currentBid - TP_IN_POINT*Point(), Digits());
         if(SL_IN_POINT != 0.0)
            sl = NormalizeDouble(currentBid + SL_IN_POINT*Point(), Digits());

         if(MODE_ORDER == 0 && bNewBarEvent)
           {
            createOrder(Symbol(), ORDER_TYPE_SELL, orderLot, "", currentAsk, tp, sl);
           }

         if(MODE_ORDER == 1 && tm.sec >= LAST_SECOND)
           {
            createOrder(Symbol(), ORDER_TYPE_SELL, orderLot, "", currentAsk, tp, sl);
           }
        }

     }
   else
     {
      if(!supportPrice)
         Comment("DISABLED - Gia ho tro loi");
      if(!resistancePrice)
         Comment("DISABLED - Gia ho tro loi");
      if(!orderLot)
         Comment("DISABLED - So lot vao lenh loi");
      if(!enableTrade)
         Comment("DISABLED - Chua cho phep vao lenh");
     }

   if(autoBE > 0)
     {
      for(int i=PositionsTotal()-1; i>=0; i--)
        {
         if(PositionGetTicket(i))
           {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double tpPrice = PositionGetDouble(POSITION_TP);
            double slPrice = PositionGetDouble(POSITION_SL);
            double profit  = PositionGetDouble(POSITION_PROFIT);
            int    type    = PositionGetInteger(POSITION_TYPE);

            if(profit > 0 && slPrice != openPrice && type == POSITION_TYPE_BUY && currentBid - openPrice >= NormalizeDouble(autoBE*Point(), Digits()))
              {
               Print("Set BE ticket: ", i, " openPrice=", openPrice, "tpPrice=", tpPrice, "slPrice=", slPrice);
               m_trade.PositionModify(PositionGetTicket(i), openPrice, tpPrice);
              }
            
            if(profit > 0 && slPrice != openPrice && type == POSITION_TYPE_SELL && openPrice - currentAsk >= NormalizeDouble(autoBE*Point(), Digits()))
              {
               Print("Set BE ticket: ", i, " openPrice=", openPrice, "tpPrice=", tpPrice, "slPrice=", slPrice);
               m_trade.PositionModify(PositionGetTicket(i), openPrice, tpPrice);
              }
           }
        }
     }

  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,         // event ID
                  const long& lparam,   // event parameter of the long type
                  const double& dparam, // event parameter of the double type
                  const string& sparam) // event parameter of the string type
  {
   ExtDialog.ChartEvent(id, lparam, dparam, sparam);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void updateListOrder()
  {
   openOrder = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(PositionGetTicket(i) && PositionGetInteger(POSITION_MAGIC) == MAGIC)
        {
         openOrder += 1;
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int createOrder(string symbol, int orderType, double lotSize, string comment, double price, double priceTP=0, double priceSL=0)
  {
   color orderColor = (orderType == ORDER_TYPE_BUY) ? clrGreen : clrRed;

   int retryCount = 0;

   while(retryCount < MAX_RETRY)
     {
      MqlTradeRequest request= {};
      request.action=TRADE_ACTION_DEAL;
      request.magic = MAGIC;
      request.symbol = symbol;
      request.volume = orderLot;
      request.sl = priceSL;
      request.tp = priceTP;
      request.type = orderType;
      request.price = price;
      request.comment = COMMENT;

      MqlTradeResult result= {};

      int ticket = OrderSend(request, result);

      if(ticket > 0)
        {
         ExtDialog.UpdateEnableTrade(false);
         return ticket;
        }
      else
        {
         Print("Error placing order: ", GetLastError());
         Print("Retrying... ", retryCount);
         retryCount++;
         Sleep(500);
        }
     }
   return 0;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closeAllPositions()
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(PositionGetTicket(i))
        {
         Print("Close ticket: ", i);
         m_trade.PositionClose(PositionGetTicket(i));
        }
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void setBEAllPositions()
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      if(PositionGetTicket(i))
        {
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double tpPrice = PositionGetDouble(POSITION_TP);
         double slPrice = PositionGetDouble(POSITION_SL);
         double profit  = PositionGetDouble(POSITION_PROFIT);

         if(profit > 0 && slPrice != openPrice)
           {
            Print("Set BE ticket: ", i, " openPrice=", openPrice, "tpPrice=", tpPrice, "slPrice=", slPrice);
            m_trade.PositionModify(PositionGetTicket(i), openPrice, tpPrice);
           }
        }
     }
  }
//+------------------------------------------------------------------+
