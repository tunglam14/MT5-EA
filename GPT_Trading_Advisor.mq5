//+------------------------------------------------------------------+
//|                                        GPT_Trading_Advisor.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "2.00"
#property description "Trading Advisor using GPT-4o and Claude Sonnet 4 APIs for advanced trading analysis"
#property description ""
#property description "SETUP REQUIREMENTS:"
#property description "1. Add 'https://api.openai.com' and 'https://api.anthropic.com' to WebRequest allowed URLs"
#property description "2. Set your API key(s) in Expert Advisor inputs or MT5 properties"
#property description "3. Select AI Model: GPT-4o (OpenAI) or Claude Sonnet 4 (Anthropic)"
#property description "4. Enable 'Allow WebRequest for listed URL' in Expert Advisors settings"
#property description "5. Ensure internet connection is stable for API calls"
#property strict

//--- AI Model Selection Enum
enum ENUM_AI_MODEL
{
   AI_GPT4O = 0,                    // GPT-4o (OpenAI)
   AI_CLAUDE_SONNET_4 = 1          // Claude Sonnet 4 (Anthropic - Latest Available)
};

//--- Input Parameters
input ENUM_AI_MODEL AI_Model = AI_GPT4O;      // AI Model Selection
input string   OpenAI_API_Key = "";           // OpenAI API Key (leave empty to use from properties)
input string   Anthropic_API_Key = "";        // Anthropic API Key (leave empty to use from properties)
input int      Klines_Count = 100;            // Number of klines to analyze
input ENUM_TIMEFRAMES Analysis_Timeframe = PERIOD_M5; // Analysis Timeframe
input double   Risk_Percent = 2.0;            // Risk percentage for position sizing
input bool     Show_Info_Panel = true;        // Show Information Panel
input bool     Show_Recommendations = true;   // Show Trading Recommendations
input color    Bullish_Color = clrLime;       // Bullish signal color
input color    Bearish_Color = clrRed;        // Bearish signal color
input color    Neutral_Color = clrYellow;     // Neutral signal color
input bool     Enable_Auto_Trading = false;   // Enable automatic order placement

//--- Global Variables
string         g_openai_api_key;
string         g_anthropic_api_key;
bool           g_is_connected = false;
string         g_last_analysis = "";
datetime       g_last_analysis_time = 0;
string         g_current_recommendation = "";
color          g_recommendation_color = clrYellow;
double         g_entry_price = 0;
double         g_stop_loss = 0;
double         g_take_profit = 0;
string         g_analysis_status = "Ready";
string         g_analysis_reason = "";         // AI reasoning for the recommendation
double         g_default_lot_size = 0.1;      // Default lot size
string         g_order_button_name = "GPT_Order_Button";

//--- Chart Objects
string         g_button_name = "GPT_Advisor_Button";
string         g_panel_name = "GPT_Advisor_Panel";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Load API keys based on selected model
   Print("Selected AI Model: ", (AI_Model == AI_GPT4O ? "GPT-4o (OpenAI)" : "Claude Sonnet 4 (Anthropic - Latest)"));
   
   if(AI_Model == AI_GPT4O)
   {
      //--- Load OpenAI API key
   if(OpenAI_API_Key == "")
   {
         Print("No OpenAI API key in inputs, trying to load from config files...");
         g_openai_api_key = GetProperty("OpenAI_API_Key");
         if(g_openai_api_key == "")
      {
            Print("Error: OpenAI API Key not found in any config file.");
            Print("Please either:");
            Print("1. Set the OpenAI API key in EA inputs, or");
            Print("2. Create config_openai.txt with: OPENAI_API_KEY=your_key_here");
         return(INIT_FAILED);
      }
   }
   else
   {
         g_openai_api_key = OpenAI_API_Key;
         Print("Using OpenAI API key from EA inputs");
      }
      
      //--- Validate OpenAI API key format
      if(StringLen(g_openai_api_key) < 20 || StringFind(g_openai_api_key, "sk-") != 0)
      {
         Print("Error: OpenAI API key format appears incorrect (length: ", StringLen(g_openai_api_key), ")");
         Print("OpenAI API keys should start with 'sk-' and be much longer");
         return(INIT_FAILED);
      }
      
      Print("OpenAI API key loaded successfully (length: ", StringLen(g_openai_api_key), " characters)");
   }
   else if(AI_Model == AI_CLAUDE_SONNET_4)
   {
      //--- Load Anthropic API key
      if(Anthropic_API_Key == "")
      {
         Print("No Anthropic API key in inputs, trying to load from config files...");
         g_anthropic_api_key = GetProperty("Anthropic_API_Key");
         if(g_anthropic_api_key == "")
         {
            Print("Error: Anthropic API Key not found in any config file.");
            Print("Please either:");
            Print("1. Set the Anthropic API key in EA inputs, or");
            Print("2. Create config_openai.txt with: ANTHROPIC_API_KEY=your_key_here");
            return(INIT_FAILED);
         }
      }
      else
      {
         g_anthropic_api_key = Anthropic_API_Key;
         Print("Using Anthropic API key from EA inputs");
      }
      
      //--- Validate Anthropic API key format
      if(StringLen(g_anthropic_api_key) < 20 || StringFind(g_anthropic_api_key, "sk-ant-") != 0)
      {
         Print("Error: Anthropic API key format appears incorrect (length: ", StringLen(g_anthropic_api_key), ")");
         Print("Anthropic API keys should start with 'sk-ant-' and be much longer");
         return(INIT_FAILED);
      }
      
      Print("Anthropic API key loaded successfully (length: ", StringLen(g_anthropic_api_key), " characters)");
   }
   
   //--- Get lot size from properties
   string lot_size_str = GetProperty("GPT_Lot_Size");
   if(lot_size_str != "")
   {
      g_default_lot_size = StringToDouble(lot_size_str);
      if(g_default_lot_size <= 0)
         g_default_lot_size = 0.1;
   }
   
   //--- Create Trading Advisor button
   CreateTradingAdvisorButton();
   
   //--- Create order button
   CreateOrderButton();
   
   //--- Create information panel
   if(Show_Info_Panel)
      CreateInfoPanel();
   
   //--- Set timer for periodic updates
   EventSetTimer(1);
   
   //--- Initialize reason
   g_analysis_reason = "";
   
   Print("GPT Trading Advisor initialized successfully");
   Print("Symbol: ", _Symbol, ", Timeframe: ", EnumToString(Analysis_Timeframe));
   Print("Default Lot Size: ", g_default_lot_size);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Remove all chart objects
   ObjectDelete(0, g_button_name);
   ObjectDelete(0, g_order_button_name);
   ObjectDelete(0, g_panel_name);
   ObjectDelete(0, g_panel_name + "_BG");
   ObjectDelete(0, g_panel_name + "_Title");
   ObjectDelete(0, g_panel_name + "_Status");
   ObjectDelete(0, g_panel_name + "_Recommendation");
   ObjectDelete(0, g_panel_name + "_Entry");
   ObjectDelete(0, g_panel_name + "_SL");
   ObjectDelete(0, g_panel_name + "_TP");
   
   //--- Remove all reason lines (up to 3 lines)
   for(int i = 1; i <= 3; i++)
   {
      ObjectDelete(0, g_panel_name + "_Reason" + IntegerToString(i));
   }
   
   ObjectDelete(0, g_panel_name + "_LastUpdate");
   
   //--- Remove recommendation lines
   ObjectDelete(0, "GPT_Entry_Line");
   ObjectDelete(0, "GPT_SL_Line");
   ObjectDelete(0, "GPT_TP_Line");
   
   EventKillTimer();
   
   Print("GPT Trading Advisor removed");
}

//+------------------------------------------------------------------+
//| Expert tick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Update information panel if needed
   if(Show_Info_Panel)
      UpdateInfoPanel();
}

//+------------------------------------------------------------------+
//| Timer function                                                  |
//+------------------------------------------------------------------+
void OnTimer()
{
   //--- Update information panel every second
   if(Show_Info_Panel)
      UpdateInfoPanel();
}

//+------------------------------------------------------------------+
//| Chart event function                                            |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   //--- Handle Trading Advisor button click
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == g_button_name)
   {
      Print("Trading Advisor button clicked - Starting analysis...");
      g_analysis_status = "Analyzing...";
      UpdateInfoPanel();
      
      //--- Start analysis in separate thread
      if(!StartGPTAnalysis())
      {
         g_analysis_status = "Analysis failed";
         g_current_recommendation = "Error: Could not start analysis";
         g_recommendation_color = clrRed;
         UpdateInfoPanel();
      }
   }
   
   //--- Handle Order button click
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == g_order_button_name)
   {
      Print("Order button clicked - Executing trade...");
      
      if(!Enable_Auto_Trading)
      {
         Print("Auto trading is disabled. Please enable it in inputs.");
         g_analysis_status = "Auto trading disabled";
         UpdateInfoPanel();
         return;
      }
      
      if(g_current_recommendation == "" || g_entry_price <= 0)
      {
         Print("No valid recommendation available. Please run analysis first.");
         g_analysis_status = "No recommendation";
         UpdateInfoPanel();
         return;
      }
      
      //--- Execute the trade
      if(ExecuteTrade())
      {
         g_analysis_status = "Order executed";
         Print("Trade executed successfully");
      }
      else
      {
         g_analysis_status = "Order failed";
         Print("Trade execution failed");
      }
      
      UpdateInfoPanel();
   }
}

//+------------------------------------------------------------------+
//| Create Trading Advisor Button                                   |
//+------------------------------------------------------------------+
void CreateTradingAdvisorButton()
{
   //--- Create button background
   ObjectCreate(0, g_button_name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, g_button_name, OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, g_button_name, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, g_button_name, OBJPROP_XSIZE, 150);
   ObjectSetInteger(0, g_button_name, OBJPROP_YSIZE, 30);
   ObjectSetInteger(0, g_button_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, g_button_name, OBJPROP_TEXT, "🤖 Trading Advisor");
   ObjectSetInteger(0, g_button_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, g_button_name, OBJPROP_BGCOLOR, clrBlue);
   ObjectSetInteger(0, g_button_name, OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetInteger(0, g_button_name, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, g_button_name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, g_button_name, OBJPROP_STATE, false);
   ObjectSetInteger(0, g_button_name, OBJPROP_BACK, false);
   ObjectSetInteger(0, g_button_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, g_button_name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, g_button_name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, g_button_name, OBJPROP_ZORDER, 0);
}

//+------------------------------------------------------------------+
//| Create Order Button                                             |
//+------------------------------------------------------------------+
void CreateOrderButton()
{
   //--- Create order button
   ObjectCreate(0, g_order_button_name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, g_order_button_name, OBJPROP_XDISTANCE, 180);
   ObjectSetInteger(0, g_order_button_name, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, g_order_button_name, OBJPROP_XSIZE, 120);
   ObjectSetInteger(0, g_order_button_name, OBJPROP_YSIZE, 30);
   ObjectSetInteger(0, g_order_button_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, g_order_button_name, OBJPROP_TEXT, "📈 Place Order");
   ObjectSetInteger(0, g_order_button_name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, g_order_button_name, OBJPROP_BGCOLOR, clrGreen);
   ObjectSetInteger(0, g_order_button_name, OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetInteger(0, g_order_button_name, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, g_order_button_name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, g_order_button_name, OBJPROP_STATE, false);
   ObjectSetInteger(0, g_order_button_name, OBJPROP_BACK, false);
   ObjectSetInteger(0, g_order_button_name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, g_order_button_name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, g_order_button_name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, g_order_button_name, OBJPROP_ZORDER, 0);
}

//+------------------------------------------------------------------+
//| Create Information Panel                                        |
//+------------------------------------------------------------------+
void CreateInfoPanel()
{
   //--- Create background rectangle (expanded for multi-line reason text)
   ObjectCreate(0, g_panel_name + "_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_panel_name + "_BG", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, g_panel_name + "_BG", OBJPROP_YDISTANCE, 60);
   ObjectSetInteger(0, g_panel_name + "_BG", OBJPROP_XSIZE, 360);
   ObjectSetInteger(0, g_panel_name + "_BG", OBJPROP_YSIZE, 300);
   ObjectSetInteger(0, g_panel_name + "_BG", OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, g_panel_name + "_BG", OBJPROP_BORDER_COLOR, clrBlack);
   ObjectSetInteger(0, g_panel_name + "_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, g_panel_name + "_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, g_panel_name + "_BG", OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, g_panel_name + "_BG", OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, g_panel_name + "_BG", OBJPROP_BACK, false);
   ObjectSetInteger(0, g_panel_name + "_BG", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, g_panel_name + "_BG", OBJPROP_SELECTED, false);
   ObjectSetInteger(0, g_panel_name + "_BG", OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, g_panel_name + "_BG", OBJPROP_ZORDER, 0);
   
   //--- Create title (dynamic based on selected model)
   string title_text = (AI_Model == AI_GPT4O ? "GPT-4o Trading Advisor" : "Claude Sonnet 4 Trading Advisor");
   ObjectCreate(0, g_panel_name + "_Title", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_panel_name + "_Title", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, g_panel_name + "_Title", OBJPROP_YDISTANCE, 70);
   ObjectSetInteger(0, g_panel_name + "_Title", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, g_panel_name + "_Title", OBJPROP_TEXT, title_text);
   ObjectSetInteger(0, g_panel_name + "_Title", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, g_panel_name + "_Title", OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, g_panel_name + "_Title", OBJPROP_FONT, "Arial Bold");
   
   //--- Create status label
   ObjectCreate(0, g_panel_name + "_Status", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_panel_name + "_Status", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, g_panel_name + "_Status", OBJPROP_YDISTANCE, 95);
   ObjectSetInteger(0, g_panel_name + "_Status", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, g_panel_name + "_Status", OBJPROP_TEXT, "Status: Ready");
   ObjectSetInteger(0, g_panel_name + "_Status", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, g_panel_name + "_Status", OBJPROP_FONTSIZE, 9);
   
   //--- Create recommendation label
   ObjectCreate(0, g_panel_name + "_Recommendation", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_panel_name + "_Recommendation", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, g_panel_name + "_Recommendation", OBJPROP_YDISTANCE, 115);
   ObjectSetInteger(0, g_panel_name + "_Recommendation", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, g_panel_name + "_Recommendation", OBJPROP_TEXT, "Recommendation: None");
   ObjectSetInteger(0, g_panel_name + "_Recommendation", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, g_panel_name + "_Recommendation", OBJPROP_FONTSIZE, 9);
   
   //--- Create entry price label
   ObjectCreate(0, g_panel_name + "_Entry", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_panel_name + "_Entry", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, g_panel_name + "_Entry", OBJPROP_YDISTANCE, 135);
   ObjectSetInteger(0, g_panel_name + "_Entry", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, g_panel_name + "_Entry", OBJPROP_TEXT, "Entry: --");
   ObjectSetInteger(0, g_panel_name + "_Entry", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, g_panel_name + "_Entry", OBJPROP_FONTSIZE, 9);
   
   //--- Create stop loss label
   ObjectCreate(0, g_panel_name + "_SL", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_panel_name + "_SL", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, g_panel_name + "_SL", OBJPROP_YDISTANCE, 155);
   ObjectSetInteger(0, g_panel_name + "_SL", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, g_panel_name + "_SL", OBJPROP_TEXT, "Stop Loss: --");
   ObjectSetInteger(0, g_panel_name + "_SL", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, g_panel_name + "_SL", OBJPROP_FONTSIZE, 9);
   
   //--- Create take profit label
   ObjectCreate(0, g_panel_name + "_TP", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_panel_name + "_TP", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, g_panel_name + "_TP", OBJPROP_YDISTANCE, 175);
   ObjectSetInteger(0, g_panel_name + "_TP", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, g_panel_name + "_TP", OBJPROP_TEXT, "Take Profit: --");
   ObjectSetInteger(0, g_panel_name + "_TP", OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, g_panel_name + "_TP", OBJPROP_FONTSIZE, 9);
   
   //--- Create multi-line reason labels (up to 3 lines)
   for(int i = 1; i <= 5; i++)
   {
      string reason_name = g_panel_name + "_Reason" + IntegerToString(i);
      ObjectCreate(0, reason_name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, reason_name, OBJPROP_XDISTANCE, 30);
      ObjectSetInteger(0, reason_name, OBJPROP_YDISTANCE, 195 + (i * 15)); // 15px spacing between lines
      ObjectSetInteger(0, reason_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetString(0, reason_name, OBJPROP_TEXT, "");
      ObjectSetInteger(0, reason_name, OBJPROP_COLOR, clrDarkBlue);
      ObjectSetInteger(0, reason_name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, reason_name, OBJPROP_FONT, "Arial");
   }
   
   //--- Create last update label (moved further down)
   ObjectCreate(0, g_panel_name + "_LastUpdate", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_panel_name + "_LastUpdate", OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, g_panel_name + "_LastUpdate", OBJPROP_YDISTANCE, 330);
   ObjectSetInteger(0, g_panel_name + "_LastUpdate", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, g_panel_name + "_LastUpdate", OBJPROP_TEXT, "Last Update: Never");
   ObjectSetInteger(0, g_panel_name + "_LastUpdate", OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, g_panel_name + "_LastUpdate", OBJPROP_FONTSIZE, 8);
}

//+------------------------------------------------------------------+
//| Update Information Panel                                        |
//+------------------------------------------------------------------+
void UpdateInfoPanel()
{
   //--- Update status
   ObjectSetString(0, g_panel_name + "_Status", OBJPROP_TEXT, "Status: " + g_analysis_status);
   
   //--- Update recommendation
   ObjectSetString(0, g_panel_name + "_Recommendation", OBJPROP_TEXT, "Recommendation: " + g_current_recommendation);
   ObjectSetInteger(0, g_panel_name + "_Recommendation", OBJPROP_COLOR, g_recommendation_color);
   
   //--- Update entry price
   if(g_entry_price > 0)
      ObjectSetString(0, g_panel_name + "_Entry", OBJPROP_TEXT, "Entry: " + FormatPrice(g_entry_price));
   else
      ObjectSetString(0, g_panel_name + "_Entry", OBJPROP_TEXT, "Entry: --");
   
   //--- Update stop loss
   if(g_stop_loss > 0)
      ObjectSetString(0, g_panel_name + "_SL", OBJPROP_TEXT, "Stop Loss: " + FormatPrice(g_stop_loss));
   else
      ObjectSetString(0, g_panel_name + "_SL", OBJPROP_TEXT, "Stop Loss: --");
   
   //--- Update take profit
   if(g_take_profit > 0)
      ObjectSetString(0, g_panel_name + "_TP", OBJPROP_TEXT, "Take Profit: " + FormatPrice(g_take_profit));
   else
      ObjectSetString(0, g_panel_name + "_TP", OBJPROP_TEXT, "Take Profit: --");
   
   //--- Update reason (multi-line support)
   if(g_analysis_reason != "")
   {
      string reason_lines[];
      WrapText(g_analysis_reason, 45, reason_lines); // 45 chars per line for panel width
      
      for(int i = 1; i <= 5; i++)
      {
         string reason_name = g_panel_name + "_Reason" + IntegerToString(i);
         string line_text = "";
         
         if(i == 1)
         {
            // First line includes "Reason:" prefix
            if(ArraySize(reason_lines) > 0)
               line_text = "Reason: " + reason_lines[0];
            else
               line_text = "Reason: --";
         }
         else if(i - 1 < ArraySize(reason_lines))
         {
            // Subsequent lines with indentation
            line_text = "        " + reason_lines[i - 1]; // 8 spaces for alignment
         }
         
         ObjectSetString(0, reason_name, OBJPROP_TEXT, line_text);
      }
   }
   else
   {
      // Clear all reason lines when no reason
      for(int i = 1; i <= 3; i++)
      {
         string reason_name = g_panel_name + "_Reason" + IntegerToString(i);
         if(i == 1)
            ObjectSetString(0, reason_name, OBJPROP_TEXT, "Reason: --");
         else
            ObjectSetString(0, reason_name, OBJPROP_TEXT, "");
      }
   }
   
   //--- Update last update time
   if(g_last_analysis_time > 0)
      ObjectSetString(0, g_panel_name + "_LastUpdate", OBJPROP_TEXT, "Last Update: " + TimeToString(g_last_analysis_time));
   else
      ObjectSetString(0, g_panel_name + "_LastUpdate", OBJPROP_TEXT, "Last Update: Never");
}

//+------------------------------------------------------------------+
//| Start GPT Analysis                                              |
//+------------------------------------------------------------------+
bool StartGPTAnalysis()
{
   //--- Get kline data
   MqlRates rates_m5[];
   MqlRates rates_m15[];
   MqlRates rates_h1[];
   MqlRates rates_h4[];
   ArraySetAsSeries(rates_m5, true);
   ArraySetAsSeries(rates_m15, true);
   ArraySetAsSeries(rates_h1, true);
   ArraySetAsSeries(rates_h4, true);
   
   int copied_m5 = CopyRates(_Symbol, PERIOD_M5, 0, Klines_Count, rates_m5);
   int copied_m15 = CopyRates(_Symbol, PERIOD_M15, 0, Klines_Count, rates_m15);
   int copied_h1 = CopyRates(_Symbol, PERIOD_H1, 0, Klines_Count, rates_h1);
   int copied_h4 = CopyRates(_Symbol, PERIOD_H4, 0, Klines_Count, rates_h4);

   if(copied_m5 < Klines_Count)
   {
      Print("Error: Could not copy enough kline data. Requested: ", Klines_Count, ", Got: ", copied_m5);
      return false;
   }
   
   //--- Prepare data for GPT analysis
   string kline_data = PrepareKlineData(rates_m5, rates_m15, rates_h1, rates_h4);
   
   //--- Create analysis request
   string prompt = CreateAnalysisPrompt(kline_data);
   
   //--- Send to OpenAI API
   Print("prompt: ", prompt);
   SendGPTAnalysisRequest(prompt);
   
   return true;
}

//+------------------------------------------------------------------+
//| Prepare Kline Data for GPT                                      |
//+------------------------------------------------------------------+
string PrepareKlineData(const MqlRates &rates_m5[], const MqlRates &rates_m15[], const MqlRates &rates_h1[], const MqlRates &rates_h4[])
{
   string data = "Symbol: " + _Symbol + "\n";
   // M5
   data += "Timeframe: 5 Minutes\n";
   data += "Current Price: " + FormatPrice(rates_m5[0].close) + "\n\n";
   data += "Recent Klines (Last " + IntegerToString(Klines_Count) + " bars):\n";
   data += "Time,Open,High,Low,Close,Volume\n";
   
   for(int i = Klines_Count - 1; i >= 0; i--)
   {
      data += TimeToString(rates_m5[i].time) + ",";
      data += DoubleToString(rates_m5[i].open, _Digits) + ",";
      data += DoubleToString(rates_m5[i].high, _Digits) + ",";
      data += DoubleToString(rates_m5[i].low, _Digits) + ",";
      data += DoubleToString(rates_m5[i].close, _Digits) + ",";
      data += IntegerToString(rates_m5[i].tick_volume) + "\n";
   }
   
   // M15
   data += "Timeframe: 15 Minutes\n";
   data += "Current Price: " + FormatPrice(rates_m15[0].close) + "\n\n";
   data += "Recent Klines (Last " + IntegerToString(Klines_Count) + " bars):\n";
   data += "Time,Open,High,Low,Close,Volume\n";
   
   for(int i = Klines_Count - 1; i >= 0; i--)
   {
      data += TimeToString(rates_m15[i].time) + ",";
      data += DoubleToString(rates_m15[i].open, _Digits) + ",";
      data += DoubleToString(rates_m15[i].high, _Digits) + ",";
      data += DoubleToString(rates_m15[i].low, _Digits) + ",";
      data += DoubleToString(rates_m15[i].close, _Digits) + ",";
      data += IntegerToString(rates_m15[i].tick_volume) + "\n";
   }
   
   // H1
   data += "Timeframe: 1 Hour\n";
   data += "Current Price: " + FormatPrice(rates_h1[0].close) + "\n\n";
   data += "Recent Klines (Last " + IntegerToString(Klines_Count) + " bars):\n";
   data += "Time,Open,High,Low,Close,Volume\n";
   
   for(int i = 50 - 1; i >= 0; i--)
   {
      data += TimeToString(rates_h1[i].time) + ",";
      data += DoubleToString(rates_h1[i].open, _Digits) + ",";
      data += DoubleToString(rates_h1[i].high, _Digits) + ",";
      data += DoubleToString(rates_h1[i].low, _Digits) + ",";
      data += DoubleToString(rates_h1[i].close, _Digits) + ",";
      data += IntegerToString(rates_h1[i].tick_volume) + "\n";
   }
   
   // H4
   data += "Timeframe: 4 Hours\n";
   data += "Current Price: " + FormatPrice(rates_h4[0].close) + "\n\n";
   data += "Recent Klines (Last " + IntegerToString(Klines_Count) + " bars):\n";
   data += "Time,Open,High,Low,Close,Volume\n";
   
   for(int i = 50 - 1; i >= 0; i--)
   {
      data += TimeToString(rates_h4[i].time) + ",";
      data += DoubleToString(rates_h4[i].open, _Digits) + ",";
      data += DoubleToString(rates_h4[i].high, _Digits) + ",";
      data += DoubleToString(rates_h4[i].low, _Digits) + ",";
      data += DoubleToString(rates_h4[i].close, _Digits) + ",";
      data += IntegerToString(rates_h4[i].tick_volume) + "\n";
   }
   
   return data;
}

//+------------------------------------------------------------------+
//| Create Analysis Prompt                                          |
//+------------------------------------------------------------------+
string CreateAnalysisPrompt(const string kline_data)
{
   string prompt = "Analyze this " + _Symbol + " market data on " + EnumToString(Analysis_Timeframe) + " timeframe for swing trading.\n\n";
   prompt += "Current market data:\n" + kline_data + "\n\n";
   prompt += "Provide your analysis in this exact format:\n\n";
   prompt += "SENTIMENT:Bullish\n";
   prompt += "ENTRY:2650.50\n";
   prompt += "SL:2640.00\n";
   prompt += "TP:2680.00\n";
   prompt += "REASON:...\n\n";
   prompt += "Requirements:\n";
   prompt += "- SENTIMENT must be exactly: Bullish, Bearish, or Neutral\n";
   prompt += "- ENTRY/SL/TP must be numeric prices only (no symbols)\n";
   prompt += "- REASON should be 1-2 sentences maximum. Return the language as Vietnamese without diacritics\n";
   prompt += "- Use the exact keywords and format shown above\n";
   prompt += "- Consider risk-reward ratio of 1:2 minimum";
   
   return prompt;
}

//+------------------------------------------------------------------+
//| Send Real AI Analysis Request                                    |
//+------------------------------------------------------------------+
void SendGPTAnalysisRequest(const string prompt)
{
   string model_name = (AI_Model == AI_GPT4O ? "GPT-4o" : "Claude Sonnet 4");
   Print("Sending analysis request to ", model_name, "...");
   Print("Prompt length: ", StringLen(prompt), " characters");
   
   //--- Call appropriate AI API based on selected model
   string api_response = "";
   if(AI_Model == AI_GPT4O)
   {
      api_response = CallOpenAIAPI(prompt);
   }
   else if(AI_Model == AI_CLAUDE_SONNET_4)
   {
      api_response = CallAnthropicAPI(prompt);
   }
   
   if(api_response != "")
   {
      //--- Parse response and update recommendations (same format for both providers)
      ParseAIResponse(api_response);
   
   //--- Update status
   g_analysis_status = "Analysis Complete";
   g_last_analysis_time = TimeCurrent();
      
      Print("AI analysis completed successfully");
   }
   else
   {
      //--- Handle API error
      g_analysis_status = "API Error";
      g_current_recommendation = "API call failed";
      g_recommendation_color = clrRed;
      g_analysis_reason = "API connection failed";
      
      Print("Error: GPT API call failed");
   }
   
   //--- Update panel
   UpdateInfoPanel();
   
   //--- Draw recommendation lines on chart
   if(Show_Recommendations && g_entry_price > 0)
      DrawRecommendationLines();
}

//+------------------------------------------------------------------+
//| Call OpenAI API for Analysis                                    |
//+------------------------------------------------------------------+
string CallOpenAIAPI(const string prompt)
{
   //--- Prepare API endpoint
   string api_url = "https://api.openai.com/v1/chat/completions";
   
   //--- Prepare headers
   string headers = "Content-Type: application/json\r\n";
   headers += "Authorization: Bearer " + g_openai_api_key + "\r\n";
   
   //--- Prepare JSON request body
   string json_request = CreateJSONRequest(prompt);
   
   //--- Prepare request data
   char post_data[];
   ArrayResize(post_data, StringLen(json_request));
   StringToCharArray(json_request, post_data, 0, StringLen(json_request));
   
   //--- Prepare response data
   char response_data[];
   string response_headers;
   
   //--- Enable HTTPS requests in MT5
   int timeout = 10000; // 10 seconds timeout
   
   Print("Making API request to OpenAI...");
   
   //--- Make the HTTP request
   int result = WebRequest("POST", api_url, headers, timeout, post_data, response_data, response_headers);
   
   if(result == -1)
   {
      int error = GetLastError();
      Print("WebRequest failed with error: ", error);
      Print("Make sure to add 'https://api.openai.com' to allowed URLs in MT5 settings");
      return "";
   }
   
   //--- Convert response to string
   string response_string = CharArrayToString(response_data);
   
   Print("API Response Code: ", result);
   Print("Response Length: ", StringLen(response_string));
   
   if(result == 200)
   {
      //--- Debug: Print first 500 characters of response for debugging
      string debug_response = StringSubstr(response_string, 0, MathMin(500, StringLen(response_string)));
      Print("Response preview: ", debug_response);
      
      //--- Parse JSON response to extract the content
      string analysis_content = ParseOpenAIResponse(response_string);
      return analysis_content;
   }
   else
   {
      Print("API Error: HTTP ", result);
      Print("Response: ", response_string);
      return "";
   }
}

//+------------------------------------------------------------------+
//| Call Anthropic API for Analysis                                 |
//+------------------------------------------------------------------+
string CallAnthropicAPI(const string prompt)
{
   //--- Prepare API endpoint
   string api_url = "https://api.anthropic.com/v1/messages";
   
   //--- Prepare headers
   string headers = "Content-Type: application/json\r\n";
   headers += "x-api-key: " + g_anthropic_api_key + "\r\n";
   headers += "anthropic-version: 2023-06-01\r\n";
   
   //--- Prepare JSON request body for Anthropic
   string json_request = CreateAnthropicJSONRequest(prompt);
   
   //--- Prepare request data
   char post_data[];
   ArrayResize(post_data, StringLen(json_request));
   StringToCharArray(json_request, post_data, 0, StringLen(json_request));
   
   //--- Prepare response data
   char response_data[];
   string response_headers;
   
   //--- Enable HTTPS requests in MT5
   int timeout = 10000; // 10 seconds timeout
   
   Print("Making API request to Anthropic...");
   
   //--- Make the HTTP request
   int result = WebRequest("POST", api_url, headers, timeout, post_data, response_data, response_headers);
   
   if(result == -1)
   {
      int error = GetLastError();
      Print("WebRequest failed with error: ", error);
      Print("Make sure to add 'https://api.anthropic.com' to allowed URLs in MT5 settings");
      return "";
   }
   
   //--- Convert response to string
   string response_string = CharArrayToString(response_data);
   
   Print("API Response Code: ", result);
   Print("Response Length: ", StringLen(response_string));
   
   if(result == 200)
   {
      //--- Debug: Print first 500 characters of response for debugging
      string debug_response = StringSubstr(response_string, 0, MathMin(500, StringLen(response_string)));
      Print("Response preview: ", debug_response);
      
      //--- Parse JSON response to extract the content
      string analysis_content = ParseAnthropicResponse(response_string);
      return analysis_content;
   }
   else
   {
      Print("API Error: HTTP ", result);
      Print("Response: ", response_string);
      return "";
   }
}

//+------------------------------------------------------------------+
//| Create JSON Request for OpenAI API                              |
//+------------------------------------------------------------------+
string CreateJSONRequest(const string prompt)
{
   //--- Escape special characters in prompt
   string escaped_prompt = EscapeJSONString(prompt);
   
   //--- Create enhanced system prompt for trading analysis
   string system_prompt = "You are a professional swing trading analyst. ";
   system_prompt += "Analyze the market data and respond in this EXACT format (no additional text):\\n\\n";
   system_prompt += "SENTIMENT:Bullish\\n";
   system_prompt += "ENTRY:1234.56\\n";
   system_prompt += "SL:1230.00\\n";
   system_prompt += "TP:1245.00\\n";
   system_prompt += "REASON:Brief explanation here\\n\\n";
   system_prompt += "Rules:\\n";
   system_prompt += "- Use only Bullish, Bearish, or Neutral for SENTIMENT\\n";
   system_prompt += "- Use only numbers for ENTRY, SL, TP (no currency symbols)\\n";
   system_prompt += "- Keep REASON under 50 words\\n";
   system_prompt += "- Start each line with the exact keywords shown\\n";
   system_prompt += "- Do not add any other text outside this format";
   
   string escaped_system = EscapeJSONString(system_prompt);
   
   //--- Build JSON request
   string json = "{";
   json += "\"model\":\"gpt-4o\",";
   json += "\"messages\":[";
   json += "{\"role\":\"system\",\"content\":\"" + escaped_system + "\"},";
   json += "{\"role\":\"user\",\"content\":\"" + escaped_prompt + "\"}";
   json += "],";
   json += "\"max_tokens\":500,";
   json += "\"temperature\":0.3";
   json += "}";
   
   return json;
}

//+------------------------------------------------------------------+
//| Create JSON Request for Anthropic API                           |
//+------------------------------------------------------------------+
string CreateAnthropicJSONRequest(const string prompt)
{
   //--- Escape special characters in prompt
   string escaped_prompt = EscapeJSONString(prompt);
   
   //--- Create system prompt for trading analysis (optimized for Claude)
   string system_prompt = "You are a professional swing trading analyst with deep expertise in technical analysis and market psychology. ";
   system_prompt += "Analyze market data comprehensively and provide structured trading recommendations.\\n\\n";
   system_prompt += "Always respond in this exact format:\\n\\n";
   system_prompt += "SENTIMENT:Bullish\\n";
   system_prompt += "ENTRY:1234.56\\n";
   system_prompt += "SL:1230.00\\n";
   system_prompt += "TP:1245.00\\n";
   system_prompt += "REASON:Brief technical analysis explanation\\n\\n";
   system_prompt += "Rules:\\n";
   system_prompt += "- SENTIMENT: exactly Bullish, Bearish, or Neutral\\n";
   system_prompt += "- ENTRY/SL/TP: numerical prices only (no symbols or formatting)\\n";
   system_prompt += "- REASON: concise technical reasoning (max 50 words)\\n";
   system_prompt += "- Consider risk-reward ratios, volume, momentum, and support/resistance levels";
   
   string escaped_system = EscapeJSONString(system_prompt);
   
   //--- Build JSON request for Anthropic format (using latest Claude Sonnet 4)
   string json = "{";
   json += "\"model\":\"claude-sonnet-4-20250514\",";  // Latest Claude Sonnet 4 model
   json += "\"max_tokens\":1000,";  // Claude Sonnet 4 supports up to 64k tokens
   json += "\"temperature\":0.3,";
   json += "\"system\":\"" + escaped_system + "\",";
   json += "\"messages\":[";
   json += "{\"role\":\"user\",\"content\":\"" + escaped_prompt + "\"}";
   json += "]";
   json += "}";
   
   return json;
}

//+------------------------------------------------------------------+
//| Parse Anthropic API Response                                    |
//+------------------------------------------------------------------+
string ParseAnthropicResponse(const string json_response)
{
   Print("Parsing Anthropic response...");
   
   //--- Anthropic uses different JSON structure: content[0].text
   string patterns[] = {
      "\"text\":\"",          // Standard format
      "\"text\": \"",         // With space
      "'text':'",             // Single quotes
      "'text': '"             // Single quotes with space
   };
   
   int start_pos = -1;
   string found_pattern = "";
   
   //--- Try each pattern
   for(int p = 0; p < ArraySize(patterns); p++)
   {
      start_pos = StringFind(json_response, patterns[p]);
      if(start_pos >= 0)
      {
         found_pattern = patterns[p];
         Print("Found text content using pattern: ", found_pattern);
         break;
      }
   }
   
   if(start_pos == -1)
   {
      Print("Error: Could not find text field in Anthropic response");
      Print("Searching for alternative patterns...");
      
      //--- Try to find any text-like field
      int alt_pos = StringFind(json_response, "text");
      if(alt_pos >= 0)
      {
         string surrounding = StringSubstr(json_response, MathMax(0, alt_pos-50), 100);
         Print("Found 'text' at position ", alt_pos, ", surrounding text: ", surrounding);
         
         //--- Try manual extraction from surrounding text
         string manual_content = ExtractContentManually(json_response, alt_pos);
         if(manual_content != "")
         {
            Print("Successfully extracted content manually");
            return manual_content;
         }
      }
      
      return "";
   }
   
   start_pos += StringLen(found_pattern);
   
   //--- Find the end of the content (look for closing quote)
   int end_pos = start_pos;
   bool in_escape = false;
   string quote_char = "\"";
   
   //--- Determine quote character from pattern
   if(StringFind(found_pattern, "'") >= 0)
      quote_char = "'";
   
   for(int i = start_pos; i < StringLen(json_response); i++)
   {
      string char_at_i = StringSubstr(json_response, i, 1);
      
      if(in_escape)
      {
         in_escape = false;
         continue;
      }
      
      if(char_at_i == "\\")
      {
         in_escape = true;
         continue;
      }
      
      if(char_at_i == quote_char)
      {
         end_pos = i;
         break;
      }
   }
   
   if(end_pos <= start_pos)
   {
      Print("Error: Could not find end of text field");
      Print("Text starts at: ", start_pos);
      string partial = StringSubstr(json_response, start_pos, MathMin(100, StringLen(json_response) - start_pos));
      Print("Partial content: ", partial);
      return "";
   }
   
   //--- Extract and unescape content
   string content = StringSubstr(json_response, start_pos, end_pos - start_pos);
   content = UnescapeJSONString(content);
   
   Print("Successfully extracted content (length: ", StringLen(content), ")");
   Print("Content preview: ", StringSubstr(content, 0, MathMin(200, StringLen(content))));
   
   return content;
}

//+------------------------------------------------------------------+
//| Manual content extraction fallback method                       |
//+------------------------------------------------------------------+
string ExtractContentManually(const string json_response, int content_pos)
{
   //--- Look for patterns around the content position
   int search_start = MathMax(0, content_pos - 10);
   int search_end = MathMin(StringLen(json_response), content_pos + 200);
   string search_area = StringSubstr(json_response, search_start, search_end - search_start);
   
   Print("Manual extraction search area: ", search_area);
   
   //--- Try different quote patterns
   string manual_patterns[] = {
      "content\":\"",
      "content\": \"",
      "content':'",
      "content': '",
      "content\": '",
      "content\":'"
   };
   
   for(int p = 0; p < ArraySize(manual_patterns); p++)
   {
      int pattern_pos = StringFind(search_area, manual_patterns[p]);
      if(pattern_pos >= 0)
      {
         int start = pattern_pos + StringLen(manual_patterns[p]);
         string quote = StringSubstr(manual_patterns[p], StringLen(manual_patterns[p]) - 1, 1);
         
         int end = StringFind(search_area, quote, start);
         if(end > start)
         {
            string extracted = StringSubstr(search_area, start, end - start);
            Print("Manual extraction found content: ", extracted);
            return UnescapeJSONString(extracted);
         }
      }
   }
   
   return "";
}

//+------------------------------------------------------------------+
//| Parse OpenAI API Response                                       |
//+------------------------------------------------------------------+
string ParseOpenAIResponse(const string json_response)
{
   Print("Parsing OpenAI response...");
   
   //--- Try multiple patterns to find content
   string patterns[] = {
      "\"content\":\"",      // Standard format
      "\"content\": \"",     // With space
      "'content':'",         // Single quotes
      "'content': '"         // Single quotes with space
   };
   
   int start_pos = -1;
   string found_pattern = "";
   
   //--- Try each pattern
   for(int p = 0; p < ArraySize(patterns); p++)
   {
      start_pos = StringFind(json_response, patterns[p]);
      if(start_pos >= 0)
      {
         found_pattern = patterns[p];
         Print("Found content using pattern: ", found_pattern);
         break;
      }
   }
   
   if(start_pos == -1)
   {
      Print("Error: Could not find content field in API response");
      Print("Searching for alternative patterns...");
      
      //--- Try to find any content-like field
      int alt_pos = StringFind(json_response, "content");
      if(alt_pos >= 0)
      {
         string surrounding = StringSubstr(json_response, MathMax(0, alt_pos-50), 100);
         Print("Found 'content' at position ", alt_pos, ", surrounding text: ", surrounding);
         
         //--- Try manual extraction from surrounding text
         string manual_content = ExtractContentManually(json_response, alt_pos);
         if(manual_content != "")
         {
            Print("Successfully extracted content manually");
            return manual_content;
         }
      }
      
      return "";
   }
   
   start_pos += StringLen(found_pattern);
   
   //--- Find the end of the content (look for closing quote)
   int end_pos = start_pos;
   bool in_escape = false;
   string quote_char = "\"";
   
   //--- Determine quote character from pattern
   if(StringFind(found_pattern, "'") >= 0)
      quote_char = "'";
   
   for(int i = start_pos; i < StringLen(json_response); i++)
   {
      string char_at_i = StringSubstr(json_response, i, 1);
      
      if(in_escape)
      {
         in_escape = false;
         continue;
      }
      
      if(char_at_i == "\\")
      {
         in_escape = true;
         continue;
      }
      
      if(char_at_i == quote_char)
      {
         end_pos = i;
         break;
      }
   }
   
   if(end_pos <= start_pos)
   {
      Print("Error: Could not find end of content field");
      Print("Content starts at: ", start_pos);
      string partial = StringSubstr(json_response, start_pos, MathMin(100, StringLen(json_response) - start_pos));
      Print("Partial content: ", partial);
      return "";
   }
   
   //--- Extract and unescape content
   string content = StringSubstr(json_response, start_pos, end_pos - start_pos);
   content = UnescapeJSONString(content);
   
   Print("Successfully extracted content (length: ", StringLen(content), ")");
   Print("Content preview: ", StringSubstr(content, 0, MathMin(200, StringLen(content))));
   
   return content;
}

//+------------------------------------------------------------------+
//| Escape special characters for JSON                              |
//+------------------------------------------------------------------+
string EscapeJSONString(const string input_str)
{
   string output_str = input_str;
   
   //--- Replace backslash first
   StringReplace(output_str, "\\", "\\\\");
   
   //--- Replace quotes
   StringReplace(output_str, "\"", "\\\"");
   
   //--- Replace newlines
   StringReplace(output_str, "\n", "\\n");
   StringReplace(output_str, "\r", "\\r");
   
   //--- Replace tabs
   StringReplace(output_str, "\t", "\\t");
   
   return output_str;
}

//+------------------------------------------------------------------+
//| Unescape JSON string                                            |
//+------------------------------------------------------------------+
string UnescapeJSONString(const string input_str)
{
   string output_str = input_str;
   
   //--- Replace escaped characters
   StringReplace(output_str, "\\n", "\n");
   StringReplace(output_str, "\\r", "\r");
   StringReplace(output_str, "\\t", "\t");
   StringReplace(output_str, "\\\"", "\"");
   StringReplace(output_str, "\\\\", "\\");
   
   return output_str;
}

//+------------------------------------------------------------------+
//| Parse AI Response (Works for both OpenAI and Anthropic)        |
//+------------------------------------------------------------------+
void ParseAIResponse(const string response)
{
   //--- Parse sentiment
   if(StringFind(response, "SENTIMENT:Bullish") >= 0)
   {
      g_current_recommendation = "BUY (Bullish)";
      g_recommendation_color = Bullish_Color;
   }
   else if(StringFind(response, "SENTIMENT:Bearish") >= 0)
   {
      g_current_recommendation = "SELL (Bearish)";
      g_recommendation_color = Bearish_Color;
   }
   else
   {
      g_current_recommendation = "WAIT (Neutral)";
      g_recommendation_color = Neutral_Color;
   }
   
   //--- Parse entry price
   int entry_pos = StringFind(response, "ENTRY:");
   if(entry_pos >= 0)
   {
      string entry_str = StringSubstr(response, entry_pos + 6);
      int newline_pos = StringFind(entry_str, "\n");
      if(newline_pos >= 0)
         entry_str = StringSubstr(entry_str, 0, newline_pos);
      g_entry_price = StringToDouble(entry_str);
   }
   
   //--- Parse stop loss
   int sl_pos = StringFind(response, "SL:");
   if(sl_pos >= 0)
   {
      string sl_str = StringSubstr(response, sl_pos + 3);
      int newline_pos = StringFind(sl_str, "\n");
      if(newline_pos >= 0)
         sl_str = StringSubstr(sl_str, 0, newline_pos);
      g_stop_loss = StringToDouble(sl_str);
   }
   
   //--- Parse take profit
   int tp_pos = StringFind(response, "TP:");
   if(tp_pos >= 0)
   {
      string tp_str = StringSubstr(response, tp_pos + 3);
      int newline_pos = StringFind(tp_str, "\n");
      if(newline_pos >= 0)
         tp_str = StringSubstr(tp_str, 0, newline_pos);
      g_take_profit = StringToDouble(tp_str);
   }
   
   //--- Parse reason
   int reason_pos = StringFind(response, "REASON:");
   if(reason_pos >= 0)
   {
      string reason_str = StringSubstr(response, reason_pos + 7);
      int newline_pos = StringFind(reason_str, "\n");
      if(newline_pos >= 0)
         reason_str = StringSubstr(reason_str, 0, newline_pos);
      
      //--- Clean up the reason text
      reason_str = TrimString(reason_str);
      g_analysis_reason = reason_str;
   }
   else
   {
      g_analysis_reason = "No reasoning provided";
   }
   
   Print("Parsed recommendation: ", g_current_recommendation);
   Print("Entry: ", g_entry_price, ", SL: ", g_stop_loss, ", TP: ", g_take_profit);
   Print("Reason: ", g_analysis_reason);
}

//+------------------------------------------------------------------+
//| Execute Trade Based on AI Recommendation                         |
//+------------------------------------------------------------------+
bool ExecuteTrade()
{
   //--- Check if we have valid recommendation
   if(g_current_recommendation == "" || g_entry_price <= 0)
   {
      Print("Error: No valid recommendation available");
      return false;
   }
   
   //--- Get current market price
   double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   //--- Determine order type and price
   ENUM_ORDER_TYPE order_type;
   double order_price;
   
   if(StringFind(g_current_recommendation, "BUY") >= 0)
   {
      order_type = ORDER_TYPE_BUY;
      order_price = ask_price; // Use ask price for buy orders
   }
   else if(StringFind(g_current_recommendation, "SELL") >= 0)
   {
      order_type = ORDER_TYPE_SELL;
      order_price = current_price; // Use bid price for sell orders
   }
   else
   {
      Print("Error: Invalid recommendation for trading: ", g_current_recommendation);
      return false;
   }
   
   //--- Calculate lot size based on risk management
   double lot_size = CalculateLotSize(order_type, order_price);
   
   //--- Prepare trade request
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lot_size;
   request.type = order_type;
   request.price = order_price;
   request.deviation = 10;
   request.magic = 123456; // Unique magic number for GPT trades
   request.comment = "GPT Trading Advisor";
   
   //--- Set stop loss if available
   if(g_stop_loss > 0)
   {
      if(order_type == ORDER_TYPE_BUY)
         request.sl = g_stop_loss;
      else
         request.sl = g_stop_loss;
   }
   
   //--- Set take profit if available
   if(g_take_profit > 0)
   {
      if(order_type == ORDER_TYPE_BUY)
         request.tp = g_take_profit;
      else
         request.tp = g_take_profit;
   }
   
   //--- Execute the trade
   Print("Executing trade: ", EnumToString(order_type), " ", _Symbol, " ", lot_size, " lots at ", order_price);
   if(g_stop_loss > 0) Print("Stop Loss: ", g_stop_loss);
   if(g_take_profit > 0) Print("Take Profit: ", g_take_profit);
   
   bool success = OrderSend(request, result);
   
   if(success && result.retcode == TRADE_RETCODE_DONE)
   {
      Print("Trade executed successfully! Order ticket: ", result.order);
      return true;
   }
   else
   {
      Print("Trade execution failed. Error code: ", result.retcode, " - ", result.comment);
      return false;
   }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size Based on Risk Management                      |
//+------------------------------------------------------------------+
double CalculateLotSize(ENUM_ORDER_TYPE order_type, double entry_price)
{
   //--- Use default lot size from properties
   double lot_size = g_default_lot_size;
   
   //--- Check if we should use risk-based position sizing
   if(Risk_Percent > 0)
   {
      //--- Get account balance
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double risk_amount = balance * Risk_Percent / 100.0;
      
      //--- Calculate stop loss distance in points
      double sl_distance = 0;
      if(g_stop_loss > 0)
      {
         if(order_type == ORDER_TYPE_BUY)
            sl_distance = (entry_price - g_stop_loss) / _Point;
         else
            sl_distance = (g_stop_loss - entry_price) / _Point;
      }
      
      //--- If we have valid stop loss, calculate position size
      if(sl_distance > 0)
      {
         double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         
         //--- Calculate lot size based on risk
         double calculated_lot = risk_amount / (sl_distance * tick_value);
         
         //--- Round to lot step
         calculated_lot = MathFloor(calculated_lot / lot_step) * lot_step;
         
         //--- Check minimum and maximum lot sizes
         double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
         
         if(calculated_lot >= min_lot && calculated_lot <= max_lot)
         {
            lot_size = calculated_lot;
            Print("Risk-based lot size calculated: ", lot_size);
         }
         else
         {
            Print("Calculated lot size out of range, using default: ", g_default_lot_size);
         }
      }
   }
   
   return lot_size;
}

//+------------------------------------------------------------------+
//| Draw Recommendation Lines on Chart                              |
//+------------------------------------------------------------------+
void DrawRecommendationLines()
{
   if(g_entry_price <= 0) return;
   
   //--- Remove previous lines
   ObjectDelete(0, "GPT_Entry_Line");
   ObjectDelete(0, "GPT_SL_Line");
   ObjectDelete(0, "GPT_TP_Line");
   
   //--- Draw entry line
   ObjectCreate(0, "GPT_Entry_Line", OBJ_HLINE, 0, 0, g_entry_price);
   ObjectSetInteger(0, "GPT_Entry_Line", OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, "GPT_Entry_Line", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, "GPT_Entry_Line", OBJPROP_WIDTH, 2);
   ObjectSetString(0, "GPT_Entry_Line", OBJPROP_TEXT, "GPT Entry: " + FormatPrice(g_entry_price));
   
   //--- Draw stop loss line
   if(g_stop_loss > 0)
   {
      ObjectCreate(0, "GPT_SL_Line", OBJ_HLINE, 0, 0, g_stop_loss);
      ObjectSetInteger(0, "GPT_SL_Line", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, "GPT_SL_Line", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, "GPT_SL_Line", OBJPROP_WIDTH, 2);
      ObjectSetString(0, "GPT_SL_Line", OBJPROP_TEXT, "GPT SL: " + FormatPrice(g_stop_loss));
   }
   
   //--- Draw take profit line
   if(g_take_profit > 0)
   {
      ObjectCreate(0, "GPT_TP_Line", OBJ_HLINE, 0, 0, g_take_profit);
      ObjectSetInteger(0, "GPT_TP_Line", OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, "GPT_TP_Line", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, "GPT_TP_Line", OBJPROP_WIDTH, 2);
      ObjectSetString(0, "GPT_TP_Line", OBJPROP_TEXT, "GPT TP: " + FormatPrice(g_take_profit));
   }
}

//+------------------------------------------------------------------+
//| Helper function to wrap text into multiple lines               |
//+------------------------------------------------------------------+
void WrapText(const string text, const int max_chars_per_line, string &lines[])
{
   ArrayResize(lines, 0);
   
   if(StringLen(text) == 0)
      return;
   
   string remaining_text = text;
   
   while(StringLen(remaining_text) > 0)
   {
      if(StringLen(remaining_text) <= max_chars_per_line)
      {
         // Last line - add as is
         ArrayResize(lines, ArraySize(lines) + 1);
         lines[ArraySize(lines) - 1] = remaining_text;
         break;
      }
      
      // Find a good break point (space, comma, or period)
      int break_pos = max_chars_per_line;
      
      // Look for space, comma, or period within the limit
      for(int i = max_chars_per_line; i > max_chars_per_line * 0.7; i--)
      {
         string char_at_i = StringSubstr(remaining_text, i, 1);
         if(char_at_i == " " || char_at_i == "," || char_at_i == ".")
         {
            break_pos = i + 1; // Include the punctuation/space
            break;
         }
      }
      
      // Extract the line
      string line = StringSubstr(remaining_text, 0, break_pos);
      line = TrimString(line);
      
      // Add to array
      ArrayResize(lines, ArraySize(lines) + 1);
      lines[ArraySize(lines) - 1] = line;
      
      // Remove processed text
      remaining_text = StringSubstr(remaining_text, break_pos);
      remaining_text = TrimString(remaining_text);
   }
}

//+------------------------------------------------------------------+
//| Helper function to trim whitespace from string                  |
//+------------------------------------------------------------------+
string TrimString(const string str)
{
   if(StringLen(str) == 0) return str;
   
   int start = 0;
   int end = StringLen(str) - 1;
   
   // Find first non-whitespace character
   while(start <= end)
   {
      ushort char_code = StringGetCharacter(str, start);
      if(char_code != ' ' && char_code != '\t' && char_code != '\r' && char_code != '\n')
         break;
      start++;
   }
   
   // Find last non-whitespace character
   while(end >= start)
   {
      ushort char_code = StringGetCharacter(str, end);
      if(char_code != ' ' && char_code != '\t' && char_code != '\r' && char_code != '\n')
         break;
      end--;
   }
   
   if(start > end) return "";
   
   return StringSubstr(str, start, end - start + 1);
}

//+------------------------------------------------------------------+
//| Get Property Value from Config File                             |
//+------------------------------------------------------------------+
string GetProperty(const string property_name)
{
   string config_files[] = {"config_openai.txt", ".env", "openai_config.txt"};
   
   //--- Try to read from multiple config files
   for(int f = 0; f < ArraySize(config_files); f++)
   {
      string filename = config_files[f];
      int file_handle = FileOpen(filename, FILE_READ | FILE_TXT);
      
      if(file_handle != INVALID_HANDLE)
      {
         Print("Reading config from: ", filename);
         
         //--- Read file line by line
         while(!FileIsEnding(file_handle))
         {
            string line = FileReadString(file_handle);
            line = TrimString(line); // Remove whitespace
            
            //--- Skip empty lines and comments
            if(StringLen(line) == 0 || StringGetCharacter(line, 0) == '#')
               continue;
            
            //--- Look for property_name=value format
            if(StringFind(line, property_name + "=") == 0)
            {
               string value = StringSubstr(line, StringLen(property_name) + 1);
               
               //--- Remove quotes if present
               if(StringLen(value) >= 2)
               {
                  if((StringGetCharacter(value, 0) == '"' && StringGetCharacter(value, StringLen(value)-1) == '"') ||
                     (StringGetCharacter(value, 0) == '\'' && StringGetCharacter(value, StringLen(value)-1) == '\''))
                  {
                     value = StringSubstr(value, 1, StringLen(value) - 2);
                  }
               }
               
               FileClose(file_handle);
               Print("Found ", property_name, " in ", filename, " (length: ", StringLen(value), ")");
               return value;
            }
            
            //--- Also try OPENAI_API_KEY format (environment variable style)
            if(property_name == "OpenAI_API_Key" && StringFind(line, "OPENAI_API_KEY=") == 0)
            {
               string value = StringSubstr(line, 15); // 15 = length of "OPENAI_API_KEY="
               
               //--- Remove quotes if present
               if(StringLen(value) >= 2)
               {
                  if((StringGetCharacter(value, 0) == '"' && StringGetCharacter(value, StringLen(value)-1) == '"') ||
                     (StringGetCharacter(value, 0) == '\'' && StringGetCharacter(value, StringLen(value)-1) == '\''))
                  {
                     value = StringSubstr(value, 1, StringLen(value) - 2);
                  }
               }
               
               FileClose(file_handle);
               Print("Found OPENAI_API_KEY in ", filename, " (length: ", StringLen(value), ")");
               return value;
            }
            
            //--- Also try ANTHROPIC_API_KEY format (environment variable style)
            if(property_name == "Anthropic_API_Key" && StringFind(line, "ANTHROPIC_API_KEY=") == 0)
            {
               string value = StringSubstr(line, 17); // 17 = length of "ANTHROPIC_API_KEY="
               
               //--- Remove quotes if present
               if(StringLen(value) >= 2)
               {
                  if((StringGetCharacter(value, 0) == '"' && StringGetCharacter(value, StringLen(value)-1) == '"') ||
                     (StringGetCharacter(value, 0) == '\'' && StringGetCharacter(value, StringLen(value)-1) == '\''))
                  {
                     value = StringSubstr(value, 1, StringLen(value) - 2);
                  }
               }
               
               FileClose(file_handle);
               Print("Found ANTHROPIC_API_KEY in ", filename, " (length: ", StringLen(value), ")");
               return value;
            }
         }
         
         FileClose(file_handle);
      }
      else
      {
         Print("Config file not found: ", filename);
      }
   }
   
   Print("Property ", property_name, " not found in any config file");
   return "";
}

//+------------------------------------------------------------------+
//| Helper function to format price with commas                     |
//+------------------------------------------------------------------+
string FormatPrice(double price)
{
   string price_str = DoubleToString(price, _Digits);
   
   // Add comma for thousands if price > 1000
   if(price >= 1000)
   {
      int dot_pos = StringFind(price_str, ".");
      if(dot_pos > 0)
      {
         string whole_part = StringSubstr(price_str, 0, dot_pos);
         string decimal_part = StringSubstr(price_str, dot_pos);
         
         // Add commas every 3 digits from right
         int len = StringLen(whole_part);
         for(int i = len - 3; i > 0; i -= 3)
         {
            whole_part = StringSubstr(whole_part, 0, i) + "," + StringSubstr(whole_part, i);
         }
         
         return whole_part + decimal_part;
      }
      else
      {
         // No decimal part
         int len = StringLen(price_str);
         for(int i = len - 3; i > 0; i -= 3)
         {
            price_str = StringSubstr(price_str, 0, i) + "," + StringSubstr(price_str, i);
         }
         return price_str;
      }
   }
   
   return price_str;
}

//+------------------------------------------------------------------+
//| Helper function to convert timeframe to string                  |
//+------------------------------------------------------------------+
string EnumToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1: return "M1";
      case PERIOD_M5: return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1: return "H1";
      case PERIOD_H4: return "H4";
      case PERIOD_D1: return "D1";
      case PERIOD_W1: return "W1";
      case PERIOD_MN1: return "MN1";
      default: return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| Helper function to convert order type to string                 |
//+------------------------------------------------------------------+
string EnumToString(ENUM_ORDER_TYPE ot)
{
   switch(ot)
   {
      case ORDER_TYPE_BUY: return "BUY";
      case ORDER_TYPE_SELL: return "SELL";
      case ORDER_TYPE_BUY_LIMIT: return "BUY LIMIT";
      case ORDER_TYPE_SELL_LIMIT: return "SELL LIMIT";
      case ORDER_TYPE_BUY_STOP: return "BUY STOP";
      case ORDER_TYPE_SELL_STOP: return "SELL STOP";
      default: return "Unknown";
   }
}
