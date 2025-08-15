//+------------------------------------------------------------------+
//| Check if current time is within trading hours                    |
//+------------------------------------------------------------------+
bool IsTradingTimeAllowed()
  {
// If time filter is disabled, always allow trading
   if(!use_time_filter)
     {
      return true;
     }

// Get current broker time
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);

// Convert current time to minutes since midnight
   int currentMinutes = timeStruct.hour * 60 + timeStruct.min;

// Convert start and end times to minutes since midnight
   int startMinutes = start_hour * 60 + start_minute;
   int endMinutes = end_hour * 60 + end_minute;

// Check if trading is allowed
   bool isAllowed = false;

   if(startMinutes <= endMinutes)
     {
      // Normal case: trading window doesn't cross midnight
      isAllowed = (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
     }
   else
     {
      // Special case: trading window crosses midnight (e.g., 22:00 - 02:00)
      isAllowed = (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
     }

// Log time filter status periodically (only on new bars to avoid spam)
   static datetime lastLogTime = 0;
   if(currentTime - lastLogTime >= PeriodSeconds(PERIOD_CURRENT))
     {
      lastLogTime = currentTime;
      if(!isAllowed)
        {
         Print("Trading not allowed. Current time: ",
               StringFormat("%02d:%02d", timeStruct.hour, timeStruct.min),
               " | Allowed hours: ",
               StringFormat("%02d:%02d - %02d:%02d",
                            start_hour, start_minute, end_hour, end_minute));
        }
     }

   return isAllowed;
  }

//+------------------------------------------------------------------+
//|                                          EngulfingMultiOrderEA.mq5|
//|                                                    Custom EA      |
//|                                            Engulfing Pattern EA   |
//+------------------------------------------------------------------+
#property copyright "Engulfing Pattern Multi-Order EA"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\SymbolInfo.mqh>

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input int      order_number = 3;           // Number of orders to open
input double   vol = 1.0;                  // Risk percentage per order (%)
input int      init_balance=50000;         // Initial balance, for calculate fixed lot size. Set 0 for using compounding
input float    tp1 = 1;                    // RR first order
input float    tp2 = 1;                    // RR second order
input float    tp3 = 2;                    // RR (n) orders
input int      magic = 666666;             // Magic Number
input bool     be = false;                 // Enable Break Even
input double   be_start = 100.0;           // Break Even activation (% of TP1 distance)
input string   comment = "Engulfing";      // Order comment

input string   time_separator = "===== Time Filter ====="; // Time Filter Settings
input bool     use_time_filter = true;     // Enable Time Filter
input int      start_hour = 0;             // Trading Start Hour (0-23)
input int      start_minute = 0;           // Trading Start Minute (0-59)
input int      end_hour = 23;              // Trading End Hour (0-23)
input int      end_minute = 59;            // Trading End Minute (0-59)

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo position;
CSymbolInfo symbol;

datetime lastBarTime = 0;
bool newBarOpened = false;

struct EngulfingData
  {
   bool              isEngulfing;
   bool              isBullish;
   double            high;
   double            low;
   double            bodySize;
   double            entryPrice;
   double            stopLoss;
   double            takeProfit1;
   double            takeProfit2;
   double            takeProfit3;
  };

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
// Initialize trade object
   trade.SetExpertMagicNumber(magic);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);

// Initialize symbol
   if(!symbol.Name(Symbol()))
     {
      Print("Failed to initialize symbol");
      return INIT_FAILED;
     }

// Validate time filter inputs
   if(use_time_filter)
     {
      if(start_hour < 0 || start_hour > 23 || end_hour < 0 || end_hour > 23)
        {
         Print("Invalid hour settings. Hours must be between 0 and 23");
         return INIT_FAILED;
        }
      if(start_minute < 0 || start_minute > 59 || end_minute < 0 || end_minute > 59)
        {
         Print("Invalid minute settings. Minutes must be between 0 and 59");
         return INIT_FAILED;
        }
     }

   Print("EA initialized successfully");
   Print("Symbol: ", Symbol());
   Print("Order Number: ", order_number);
   Print("Risk per order: ", vol, "%");
   Print("Magic Number: ", magic);
   Print("Break Even: ", be ? "Enabled" : "Disabled");

   if(use_time_filter)
     {
      Print("Time Filter: Enabled");
      Print("Trading Hours: ", StringFormat("%02d:%02d - %02d:%02d (Broker Time)",
                                            start_hour, start_minute, end_hour, end_minute));
     }
   else
     {
      Print("Time Filter: Disabled (24/7 Trading)");
     }

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
// Clean up graphical objects
   ObjectsDeleteAll(0, "Engulfing_");
   Print("EA deinitialized");
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
// Check for new bar
   if(IsNewBar())
     {
      // Check if trading is allowed based on time filter
      if(!IsTradingTimeAllowed())
        {
         return; // Skip trading if outside allowed hours
        }

      // Check for engulfing pattern on the previous two candles
      EngulfingData engulfing = CheckEngulfingPattern();

      if(engulfing.isEngulfing)
        {
         // Mark the engulfing candle
         MarkEngulfingCandle(engulfing.isBullish);

         // Open orders
         OpenMultipleOrders(engulfing);
        }
     }

// Manage break even if enabled (always active regardless of time filter)
   if(be)
     {
      ManageBreakEven();
     }
  }

//+------------------------------------------------------------------+
//| Check if new bar opened                                          |
//+------------------------------------------------------------------+
bool IsNewBar()
  {
   datetime currentBarTime = iTime(Symbol(), PERIOD_CURRENT, 0);

   if(currentBarTime != lastBarTime)
     {
      lastBarTime = currentBarTime;
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Check for engulfing pattern                                      |
//+------------------------------------------------------------------+
EngulfingData CheckEngulfingPattern()
  {
   EngulfingData result;
   result.isEngulfing = false;

// Get data for the last two completed candles
   double open1 = iOpen(Symbol(), PERIOD_CURRENT, 2);
   double close1 = iClose(Symbol(), PERIOD_CURRENT, 2);
   double high1 = iHigh(Symbol(), PERIOD_CURRENT, 2);
   double low1 = iLow(Symbol(), PERIOD_CURRENT, 2);

   double open2 = iOpen(Symbol(), PERIOD_CURRENT, 1);
   double close2 = iClose(Symbol(), PERIOD_CURRENT, 1);
   double high2 = iHigh(Symbol(), PERIOD_CURRENT, 1);
   double low2 = iLow(Symbol(), PERIOD_CURRENT, 1);

// Check for bullish engulfing
   if(close1 < open1 && close2 > open2 && // First bearish, second bullish
      open2 <= close1 && close2 >= open1)   // Second body engulfs first
     {
      result.isEngulfing = true;
      result.isBullish = true;
      result.high = high2;
      result.low = low2;
      result.bodySize = MathAbs(close2 - open2);
      result.entryPrice = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
      result.stopLoss = low2; // Stop at the wick of engulfing candle
     }
// Check for bearish engulfing
   else
      if(close1 > open1 && close2 < open2 && // First bullish, second bearish
         open2 >= close1 && close2 <= open1)   // Second body engulfs first
        {
         result.isEngulfing = true;
         result.isBullish = false;
         result.high = high2;
         result.low = low2;
         result.bodySize = MathAbs(open2 - close2);
         result.entryPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
         result.stopLoss = high2; // Stop at the wick of engulfing candle
        }

// Calculate take profit levels if engulfing found
   if(result.isEngulfing)
     {
      if(result.isBullish)
        {
         result.takeProfit1 = result.entryPrice + (result.bodySize * tp1);
         result.takeProfit2 = result.entryPrice + (result.bodySize * tp2);
         result.takeProfit3 = result.entryPrice + (result.bodySize * tp3);
        }
      else
        {
         result.takeProfit1 = result.entryPrice - (result.bodySize * tp1);
         result.takeProfit2 = result.entryPrice - (result.bodySize * tp2);
         result.takeProfit3 = result.entryPrice - (result.bodySize * tp3);
        }
     }

   return result;
  }

//+------------------------------------------------------------------+
//| Mark engulfing candle with arrow                                 |
//+------------------------------------------------------------------+
void MarkEngulfingCandle(bool isBullish)
  {
   string objectName = "Engulfing_" + TimeToString(iTime(Symbol(), PERIOD_CURRENT, 1));

   if(isBullish)
     {
      // Create blue arrow below bullish engulfing
      double price = iLow(Symbol(), PERIOD_CURRENT, 1) - (symbol.Point() * 50);
      ObjectCreate(0, objectName, OBJ_ARROW_UP, 0, iTime(Symbol(), PERIOD_CURRENT, 1), price);
      ObjectSetInteger(0, objectName, OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, objectName, OBJPROP_WIDTH, 2);
     }
   else
     {
      // Create red arrow above bearish engulfing
      double price = iHigh(Symbol(), PERIOD_CURRENT, 1) + (symbol.Point() * 50);
      ObjectCreate(0, objectName, OBJ_ARROW_DOWN, 0, iTime(Symbol(), PERIOD_CURRENT, 1), price);
      ObjectSetInteger(0, objectName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, objectName, OBJPROP_WIDTH, 2);
     }
  }

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                 |
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double stopLoss)
  {
// Get account balance
   double accountBalance = 0.0;

   if(init_balance > 0)
      accountBalance = init_balance;
   else
      accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);

// Calculate risk amount in account currency
   double riskAmount = accountBalance * (vol / 100.0);

// Calculate stop loss distance in points
   double stopLossDistance = MathAbs(entryPrice - stopLoss) / symbol.Point();

// Get symbol contract specifications
   double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);

// Calculate point value for 1 lot
   double pointValue = tickValue * (symbol.Point() / tickSize);

// Calculate lot size
   double lotSize = riskAmount / (stopLossDistance * pointValue);

// Round to symbol's lot step
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   lotSize = MathFloor(lotSize / lotStep) * lotStep;

// Ensure minimum lot size
   double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   if(lotSize < minLot)
     {
      lotSize = minLot;
     }

// Ensure maximum lot size
   double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   if(lotSize > maxLot)
     {
      lotSize = maxLot;
     }

   Print("Risk calculation: Balance=", accountBalance,
         " Risk%=", vol,
         " RiskAmount=", riskAmount,
         " SL_Points=", stopLossDistance,
         " LotSize=", lotSize);

   return lotSize;
  }

//+------------------------------------------------------------------+
//| Open multiple orders                                             |
//+------------------------------------------------------------------+
void OpenMultipleOrders(EngulfingData &engulfing)
  {
// Calculate lot size
   double lotSize = CalculateLotSize(engulfing.entryPrice, engulfing.stopLoss);

// Determine order type
   ENUM_ORDER_TYPE orderType = engulfing.isBullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

// Open orders
   for(int i = 0; i < order_number; i++)
     {
      double takeProfit;

      // Set take profit based on order number
      if(i == 0)
        {
         takeProfit = engulfing.takeProfit1;
        }
      else
         if(i == 1)
           {
            takeProfit = engulfing.takeProfit2;
           }
         else
           {
            takeProfit = engulfing.takeProfit3;
           }

      // Prepare comment
      string orderComment = comment + "|" + IntegerToString(i + 1);

      // Open order
      bool result = trade.PositionOpen(
                       Symbol(),
                       orderType,
                       lotSize,
                       engulfing.entryPrice,
                       engulfing.stopLoss,
                       takeProfit,
                       orderComment
                    );

      if(result)
        {
         Print("Order ", i + 1, " opened successfully. Ticket: ", trade.ResultOrder());
        }
      else
        {
         Print("Failed to open order ", i + 1, ". Error: ", GetLastError());
        }
     }
  }

//+------------------------------------------------------------------+
//| Manage break even                                                |
//+------------------------------------------------------------------+
void ManageBreakEven()
  {
// Iterate through all positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(position.SelectByIndex(i))
        {
         // Check if position belongs to this EA
         if(position.Magic() != magic || position.Symbol() != Symbol())
           {
            continue;
           }

         double entryPrice = position.PriceOpen();
         double currentSL = position.StopLoss();
         double takeProfit = position.TakeProfit();
         double currentPrice = position.PriceCurrent();

         // Calculate TP1 distance (50% of body size)
         double tp1Distance = MathAbs(takeProfit - entryPrice) / 3.0; // TP1 is 1/3 of TP3 distance
         double beActivationDistance = tp1Distance * (be_start / 100.0);

         // Check if break even should be activated
         if(position.PositionType() == POSITION_TYPE_BUY)
           {
            if(currentPrice >= entryPrice + beActivationDistance && currentSL < entryPrice)
              {
               // Move stop loss to break even
               trade.PositionModify(position.Ticket(), entryPrice, takeProfit);
               Print("Break even activated for BUY position ", position.Ticket());
              }
           }
         else
            if(position.PositionType() == POSITION_TYPE_SELL)
              {
               if(currentPrice <= entryPrice - beActivationDistance && currentSL > entryPrice)
                 {
                  // Move stop loss to break even
                  trade.PositionModify(position.Ticket(), entryPrice, takeProfit);
                  Print("Break even activated for SELL position ", position.Ticket());
                 }
              }
        }
     }
  }

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
