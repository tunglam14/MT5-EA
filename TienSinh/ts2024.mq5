//+------------------------------------------------------------------+
//|                                                       ts2024.mq5 |
//|                                                            lamdt |
//|                                             github.com/tunglam14 |
//+------------------------------------------------------------------+
#property copyright "lamdt"
#property link      "github.com/tunglam14"
#property version   "1.00"

#include <Controls\Edit.mqh>
#include <Controls\Dialog.mqh>
#include <Controls\CheckGroup.mqh>
#include <Controls\Label.mqh>

input string   ORDER_SETTING = "--------";
input double   TP_IN_POINT = 2000; // Khoang gia TP
input double   SL_IN_POINT = 2000; // Khoang gia SL
input int      MAX_ORDER   = 1; // So lenh mo toi da
enum ListModeInit
  {
   OpenInNewCandle=0, // Mo Lenh Khi Sang Nen Moi
   BeforeCloseCandle=1, // Mo Lenh Truoc Khi Dong Nen
  };
input ListModeInit  MODE_ORDER = 0; // Kieu vao lenh

input int LAST_SECOND = 55; // So giay cuoi truoc khi vao lenh

input string   CHART_SETTING = "--------";
input color    RESISTANCE_LINE_COLOR = clrMediumVioletRed; // Mau cua duong khang cu
input color    SUPPORT_LINE_COLOR = clrTeal; // Mau cua duong ho tro

input string   ADVANCE_SETTING = "--------";
input string   COMMENT = "TS EA";
input int      MAX_RETRY = 5;
input int      MAGIC = 13579;

double resistancePrice = 0.0;
double supportPrice = 0.0;
double orderLot = 0.0;
bool enableTrade = false;
int openOrder = 0;

#define INDENT_LEFT                         (11)
#define INDENT_RIGHT                        (11)
#define INDENT_TOP                          (11)
#define INDENT_BOTTOM                       (11)

#define CONTROLS_GAP_X                      (5)
#define CONTROLS_GAP_Y                      (5)

#define R_PRICE_LABEL_WIDTH                 (100)
#define R_PRICE_LABEL_HEIGHT                (20)

#define R_PRICE_WIDTH                       (100)
#define R_PRICE_HEIGHT                      (20)

#define S_PRICE_LABEL_WIDTH                 (100)
#define S_PRICE_LABEL_HEIGHT                (20)

#define S_PRICE_WIDTH                       (100)
#define S_PRICE_HEIGHT                      (20)

#define VOLUME_LABEL_WIDTH                  (100)
#define VOLUME_LABEL_HEIGHT                 (20)

#define VOLUME_WIDTH                        (100)
#define VOLUME_HEIGHT                       (20)

#define ENABLE_TRADE_WIDTH                  (200)
#define ENABLE_TRADE_HEIGHT                 (20)

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

public:
                     CControlsDialog(void);
                    ~CControlsDialog(void);

   virtual bool      Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2);
   virtual bool      OnEvent(const int id,const long &lparam,const double &dparam,const string &sparam);
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

   void              OnChangeCheckGroup(void);

   void              OnChangeResistancePrice(void);
   void              OnChangeSupprtPrice(void);
   void              OnChangeVolume(void);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
EVENT_MAP_BEGIN(CControlsDialog)
ON_EVENT(ON_CHANGE,m_enable_trade,OnChangeCheckGroup)
ON_EVENT(ON_END_EDIT,m_r_price,OnChangeResistancePrice)
ON_EVENT(ON_END_EDIT,m_s_price,OnChangeSupprtPrice)
ON_EVENT(ON_END_EDIT,m_volume,OnChangeVolume)
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
   return m_r_price.Text(DoubleToString(price));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CControlsDialog::UpdateSupportPrice(double price)
  {
   return m_s_price.Text(DoubleToString(price));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CControlsDialog::Create(const long chart,const string name,const int subwin,const int x1,const int y1,const int x2,const int y2)
  {
   if(!CAppDialog::Create(chart,name,subwin,x1,y1,x2,y2))
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

   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CControlsDialog::CreateResistancePriceLabel(void)
  {
   int x1 = INDENT_LEFT;
   int y1 = INDENT_TOP;
   int x2 = x1 + R_PRICE_LABEL_WIDTH;
   int y2 = y1 + R_PRICE_LABEL_HEIGHT;

   if(!m_r_price_label.Create(m_chart_id,m_name+"Resistance Price Label",m_subwin,x1,y1,x2,y2))
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
   int x1 = INDENT_LEFT;
   int y1 = INDENT_TOP + (R_PRICE_LABEL_HEIGHT + CONTROLS_GAP_Y);
   int x2 = x1 + R_PRICE_WIDTH;
   int y2 = y1 + R_PRICE_HEIGHT;

   if(!m_r_price.Create(m_chart_id,m_name+"Resistance Price",m_subwin,x1,y1,x2,y2))
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
   int y1 = INDENT_TOP + (R_PRICE_LABEL_HEIGHT + CONTROLS_GAP_Y) + (R_PRICE_HEIGHT + CONTROLS_GAP_Y);
   int x2 = x1 + S_PRICE_LABEL_WIDTH;
   int y2 = y1 + S_PRICE_LABEL_HEIGHT;

   if(!m_s_price_label.Create(m_chart_id,m_name+"Support Price Label",m_subwin,x1,y1,x2,y2))
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
   int x1 = INDENT_LEFT;
   int y1 = INDENT_TOP + (R_PRICE_LABEL_HEIGHT + CONTROLS_GAP_Y) + (R_PRICE_HEIGHT + CONTROLS_GAP_Y) + (S_PRICE_LABEL_HEIGHT + CONTROLS_GAP_Y);
   int x2 = x1 + S_PRICE_WIDTH;
   int y2 = y1 + S_PRICE_HEIGHT;

   if(!m_s_price.Create(m_chart_id,m_name+"Support Price",m_subwin,x1,y1,x2,y2))
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
   int y1 = INDENT_TOP + (R_PRICE_LABEL_HEIGHT + CONTROLS_GAP_Y) + (R_PRICE_HEIGHT + CONTROLS_GAP_Y) + (S_PRICE_LABEL_HEIGHT + CONTROLS_GAP_Y) + (S_PRICE_HEIGHT + CONTROLS_GAP_Y);
   int x2 = x1 + VOLUME_LABEL_WIDTH;
   int y2 = y1 + VOLUME_LABEL_HEIGHT;

   if(!m_volume_label.Create(m_chart_id,m_name+"Volume Label",m_subwin,x1,y1,x2,y2))
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
   int x1 = INDENT_LEFT;
   int y1 = INDENT_TOP + (R_PRICE_LABEL_HEIGHT + CONTROLS_GAP_Y) + (R_PRICE_HEIGHT + CONTROLS_GAP_Y) + (S_PRICE_LABEL_HEIGHT + CONTROLS_GAP_Y) + (S_PRICE_HEIGHT + CONTROLS_GAP_Y) + (VOLUME_LABEL_HEIGHT + CONTROLS_GAP_Y);
   int x2 = x1 + VOLUME_WIDTH;
   int y2 = y1 + VOLUME_HEIGHT;

   if(!m_volume.Create(m_chart_id,m_name+"Volume",m_subwin,x1,y1,x2,y2))
      return(false);
   if(!m_volume.ReadOnly(false))
      return(false);
   if(!Add(m_volume))
      return(false);
   
   m_volume.Text(DoubleToString(orderLot));

   return(true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CControlsDialog::CreateEnableTrade(void)
  {
   int x1 = INDENT_LEFT;
   int y1 = INDENT_TOP + 3*CONTROLS_GAP_Y + (R_PRICE_LABEL_HEIGHT + CONTROLS_GAP_Y) + (R_PRICE_HEIGHT + CONTROLS_GAP_Y) + (S_PRICE_LABEL_HEIGHT + CONTROLS_GAP_Y) + (S_PRICE_HEIGHT + CONTROLS_GAP_Y) + (VOLUME_LABEL_HEIGHT + CONTROLS_GAP_Y) + (VOLUME_HEIGHT + CONTROLS_GAP_Y);
   int x2 = x1 + ENABLE_TRADE_WIDTH;
   int y2 = y1 + ENABLE_TRADE_HEIGHT;

   if(!m_enable_trade.Create(m_chart_id,m_name+"Enable Trade",m_subwin,x1,y1,x2,y2))
      return(false);
   if(!Add(m_enable_trade))
      return(false);
   m_enable_trade.Alignment(WND_ALIGN_HEIGHT,0,y1,0,INDENT_BOTTOM);

   if(!m_enable_trade.AddItem("Cho Phep Vao Lenh",1<<0))
      return(false);
//Comment(__FUNCTION__+" : Value="+IntegerToString(m_enable_trade.Value()));

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

   ObjectCreate(0,"Resistance price line", OBJ_HLINE, 0, 0, resistancePrice);
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

   ObjectCreate(0,"Support price line", OBJ_HLINE, 0, 0, supportPrice);
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

CControlsDialog ExtDialog;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {

   if(!ExtDialog.Create(0,"TS Trading Panel",0,20,40,250,324))
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
      //Print("openOrder ", openOrder, "MAX_ORDER ", MAX_ORDER, " ", openOrder > MAX_ORDER);
      if(openOrder >= MAX_ORDER)
        {
         Comment("ACTIVE - So lenh vuot qua MAX_ORDER " + IntegerToString(openOrder) + "/" + IntegerToString(MAX_ORDER));
         return;
        }

      Comment("ACTIVE - Dang cho vao lenh neu gia pha vo " + DoubleToString(supportPrice) + "-" + DoubleToString(resistancePrice));

      double currentAsk = SymbolInfoDouble(Symbol(),SYMBOL_ASK);
      double currentBid = SymbolInfoDouble(Symbol(),SYMBOL_BID);

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
   ExtDialog.ChartEvent(id,lparam,dparam,sparam);
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

      int ticket = OrderSend(request,result);

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
