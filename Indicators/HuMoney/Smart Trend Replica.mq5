//+------------------------------------------------------------------+
//|                                     SmartTrend_Indicator.mq5  |
//|                                  Copyright 2025, p3pwp3p  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, p3pwp3p"
#property link "https://www.mql5.com"
#property version "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots 3

//--- Plot settings for Cloud (Ribbon)
#property indicator_label1 "CloudFast;CloudSlow"
#property indicator_type1 DRAW_FILLING
#property indicator_color1 clrLime, clrRed
#property indicator_width1 1

//--- Plot settings for Buy Arrow
#property indicator_label2 "Buy Signal"
#property indicator_type2 DRAW_ARROW
#property indicator_color2 clrBlue
#property indicator_width2 2

//--- Plot settings for Sell Arrow
#property indicator_label3 "Sell Signal"
#property indicator_type3 DRAW_ARROW
#property indicator_color3 clrRed
#property indicator_width3 2

//--- Input Group: Strategy Settings
input group "Strategy Settings";
input int FastMaPeriod = 9;                // Fast MA Period
input int SlowMaPeriod = 20;               // Slow MA Period
input ENUM_MA_METHOD MaMethod = MODE_EMA;  // MA Method
input int SignalGap = 100;                 // Arrow Distance (points)

//--- Input Group: Dashboard Settings
input group "Dashboard Settings";
input bool ShowDashboard = true;   // Show Dashboard
input color TextColor = clrWhite;  // Text Color
input int TextSize = 10;           // Font Size

//--- Indicator Buffers
double FastMaBuffer[];
double SlowMaBuffer[];
double BuyArrowBuffer[];
double SellArrowBuffer[];

//--- Global Variables
int fastMaHandle;
int slowMaHandle;
string objPrefix = "SmartTrend_";

//+------------------------------------------------------------------+
//| Custom Indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    // 1. Mapping Buffers
    SetIndexBuffer(0, FastMaBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, SlowMaBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, BuyArrowBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, SellArrowBuffer, INDICATOR_DATA);

    // 2. Setting Arrow Codes (Wingdings)
    PlotIndexSetInteger(1, PLOT_ARROW, 233);  // Up Arrow
    PlotIndexSetInteger(2, PLOT_ARROW, 234);  // Down Arrow

    // 3. Initialize MA Handles
    fastMaHandle =
        iMA(_Symbol, _Period, FastMaPeriod, 0, MaMethod, PRICE_CLOSE);
    slowMaHandle =
        iMA(_Symbol, _Period, SlowMaPeriod, 0, MaMethod, PRICE_CLOSE);

    if (fastMaHandle == INVALID_HANDLE || slowMaHandle == INVALID_HANDLE) {
        Print("Failed to create indicator handles.");
        return (INIT_FAILED);
    }

    // 4. Create Dashboard if enabled
    if (ShowDashboard) {
        createDashboard();
    }

    return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom Indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    IndicatorRelease(fastMaHandle);
    IndicatorRelease(slowMaHandle);
    ObjectsDeleteAll(0, objPrefix);
}

//+------------------------------------------------------------------+
//| Custom Indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime& time[], const double& open[],
                const double& high[], const double& low[],
                const double& close[], const long& tick_volume[],
                const long& volume[], const int& spread[]) {
    // Check for data count
    if (rates_total < SlowMaPeriod) return (0);

    // 1. Copy Data from Handles to Buffers
    int toCopy =
        (prev_calculated > 0) ? rates_total - prev_calculated + 1 : rates_total;

    if (CopyBuffer(fastMaHandle, 0, 0, toCopy, FastMaBuffer) <= 0) return (0);
    if (CopyBuffer(slowMaHandle, 0, 0, toCopy, SlowMaBuffer) <= 0) return (0);

    // 2. Main Calculation Loop
    int start = (prev_calculated > 0) ? prev_calculated - 1 : SlowMaPeriod;

    for (int i = start; i < rates_total; i++) {
        // Reset Arrow Buffers
        BuyArrowBuffer[i] = EMPTY_VALUE;
        SellArrowBuffer[i] = EMPTY_VALUE;

        // Crossover Logic (Check previous bar vs current bar)
        // i is current, i-1 is previous
        if (i > 0) {
            bool currentUp = FastMaBuffer[i] > SlowMaBuffer[i];
            bool prevUp = FastMaBuffer[i - 1] > SlowMaBuffer[i - 1];
            bool currentDown = FastMaBuffer[i] < SlowMaBuffer[i];
            bool prevDown = FastMaBuffer[i - 1] < SlowMaBuffer[i - 1];

            // Golden Cross (Buy)
            if (!prevUp && currentUp) {
                BuyArrowBuffer[i] = low[i] - SignalGap * _Point;
            }
            // Dead Cross (Sell)
            else if (!prevDown && currentDown) {
                SellArrowBuffer[i] = high[i] + SignalGap * _Point;
            }
        }
    }

    // 3. Update Dashboard (Realtime info)
    if (ShowDashboard) {
        updateDashboard(FastMaBuffer[rates_total - 1],
                        SlowMaBuffer[rates_total - 1]);
    }

    return (rates_total);
}

//+------------------------------------------------------------------+
//| Helper Function: Create Dashboard Objects                        |
//+------------------------------------------------------------------+
void createDashboard() {
    // Background Panel
    ObjectCreate(0, objPrefix + "Bg", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, objPrefix + "Bg", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(0, objPrefix + "Bg", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, objPrefix + "Bg", OBJPROP_YDISTANCE, 50);
    ObjectSetInteger(0, objPrefix + "Bg", OBJPROP_XSIZE, 150);
    ObjectSetInteger(0, objPrefix + "Bg", OBJPROP_YSIZE, 60);
    ObjectSetInteger(0, objPrefix + "Bg", OBJPROP_BGCOLOR, clrBlack);
    ObjectSetInteger(0, objPrefix + "Bg", OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, objPrefix + "Bg", OBJPROP_BACK, false);

    // Status Text
    ObjectCreate(0, objPrefix + "Text", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, objPrefix + "Text", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(0, objPrefix + "Text", OBJPROP_XDISTANCE, 20);
    ObjectSetInteger(0, objPrefix + "Text", OBJPROP_YDISTANCE, 70);
    ObjectSetInteger(0, objPrefix + "Text", OBJPROP_COLOR, TextColor);
    ObjectSetInteger(0, objPrefix + "Text", OBJPROP_FONTSIZE, TextSize);
    ObjectSetString(0, objPrefix + "Text", OBJPROP_TEXT, "Initializing...");
}

//+------------------------------------------------------------------+
//| Helper Function: Update Dashboard Text                           |
//+------------------------------------------------------------------+
void updateDashboard(double fastVal, double slowVal) {
    bool isBullish = fastVal > slowVal;
    string trendTxt = isBullish ? "UP TREND (BUY)" : "DOWN TREND (SELL)";
    color stateColor = isBullish ? clrLime : clrRed;

    ObjectSetString(0, objPrefix + "Text", OBJPROP_TEXT, trendTxt);
    ObjectSetInteger(0, objPrefix + "Text", OBJPROP_COLOR, stateColor);
}
//+------------------------------------------------------------------+