//+------------------------------------------------------------------+
//|                                Smart_Divergence_Filter.mq5      |
//|                                  Copyright 2025, p3pwp3p  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, p3pwp3p"
#property link "https://www.mql5.com"
#property version "2.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots 2

//--- Plot settings
#property indicator_label1 "Smart Buy"
#property indicator_type1 DRAW_ARROW
#property indicator_color1 clrAqua
#property indicator_width1 3

#property indicator_label2 "Smart Sell"
#property indicator_type2 DRAW_ARROW
#property indicator_color2 clrMagenta
#property indicator_width2 3

//--- Input Group: Basic Settings
input group "RSI Settings";
input int RSIPeriod = 14;  // RSI Period
input ENUM_APPLIED_PRICE RSIPrice = PRICE_CLOSE;

//--- Input Group: Advanced Filter
input group "Smart Filter Settings";
input int PeakDepth = 5;        // Peak Detection Depth
input int PeakSearchRange = 3;  // RSI Peak Search Range (Bars)
input int MaxLengthDiff = 2;    // Max Allowed Length Difference (Bars)
input bool DrawLines = true;    // Draw Trend Lines

//--- Buffers
double BuyBuffer[];
double SellBuffer[];
double RSIBuffer[];

//--- Global Vars
int rsiHandle;
string objPrefix = "SmartDiv_";

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit() {
    SetIndexBuffer(0, BuyBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, SellBuffer, INDICATOR_DATA);
    ArraySetAsSeries(RSIBuffer, true);

    PlotIndexSetInteger(0, PLOT_ARROW, 233);
    PlotIndexSetInteger(1, PLOT_ARROW, 234);
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);

    rsiHandle = iRSI(_Symbol, _Period, RSIPeriod, RSIPrice);
    if (rsiHandle == INVALID_HANDLE) return (INIT_FAILED);

    return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    IndicatorRelease(rsiHandle);
    ObjectsDeleteAll(0, objPrefix);
}

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime& time[], const double& open[],
                const double& high[], const double& low[],
                const double& close[], const long& tick_volume[],
                const long& volume[], const int& spread[]) {
    if (rates_total < RSIPeriod + PeakDepth * 2) return (0);

    if (CopyBuffer(rsiHandle, 0, 0, rates_total, RSIBuffer) <= 0) return (0);
    ArraySetAsSeries(RSIBuffer, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(BuyBuffer, true);
    ArraySetAsSeries(SellBuffer, true);

    int limit = prev_calculated == 0
                    ? rates_total - PeakDepth - 5
                    : rates_total - prev_calculated + PeakDepth;
    if (limit >= rates_total - PeakDepth - 5)
        limit = rates_total - PeakDepth - 5;

    // Store previous PEAK info (Index on Chart, Index on RSI)
    static int lastPriceHighIdx = -1;
    static int lastRsiHighIdx = -1;

    // Store previous VALLEY info
    static int lastPriceLowIdx = -1;
    static int lastRsiLowIdx = -1;

    for (int i = limit; i >= PeakDepth + 1; i--) {
        BuyBuffer[i] = 0.0;
        SellBuffer[i] = 0.0;

        // 1. Check for PRICE PEAK (High)
        if (isPeak(i, high, PeakDepth)) {
            // Find actual RSI Peak nearby this Price Peak
            int currentRsiHighIdx =
                getHighestIndex(RSIBuffer, i, PeakSearchRange);

            if (lastPriceHighIdx != -1) {
                // A. Check Bearish Divergence (Price Higher, RSI Lower)
                // Use the ACTUAL found RSI peaks for value comparison
                if (high[i] > high[lastPriceHighIdx] &&
                    RSIBuffer[currentRsiHighIdx] < RSIBuffer[lastRsiHighIdx]) {
                    // B. Length Check Logic (User Request)
                    int priceDist =
                        lastPriceHighIdx - i;  // Distance between Price Peaks
                    int rsiDist =
                        lastRsiHighIdx -
                        currentRsiHighIdx;  // Distance between RSI Peaks

                    // Only trigger if the "Duration" of the waves are similar
                    if (MathAbs(priceDist - rsiDist) <= MaxLengthDiff) {
                        SellBuffer[i] = high[i] + 10 * _Point;
                        if (DrawLines)
                            drawLine(time[lastPriceHighIdx],
                                     high[lastPriceHighIdx], time[i], high[i],
                                     clrMagenta, "Bear_");
                    }
                }
            }
            // Update History
            lastPriceHighIdx = i;
            lastRsiHighIdx = currentRsiHighIdx;
        }

        // 2. Check for PRICE VALLEY (Low)
        if (isValley(i, low, PeakDepth)) {
            // Find actual RSI Valley nearby this Price Valley
            int currentRsiLowIdx =
                getLowestIndex(RSIBuffer, i, PeakSearchRange);

            if (lastPriceLowIdx != -1) {
                // A. Check Bullish Divergence (Price Lower, RSI Higher)
                if (low[i] < low[lastPriceLowIdx] &&
                    RSIBuffer[currentRsiLowIdx] > RSIBuffer[lastRsiLowIdx]) {
                    // B. Length Check Logic
                    int priceDist = lastPriceLowIdx - i;
                    int rsiDist = lastRsiLowIdx - currentRsiLowIdx;

                    if (MathAbs(priceDist - rsiDist) <= MaxLengthDiff) {
                        BuyBuffer[i] = low[i] - 10 * _Point;
                        if (DrawLines)
                            drawLine(time[lastPriceLowIdx],
                                     low[lastPriceLowIdx], time[i], low[i],
                                     clrAqua, "Bull_");
                    }
                }
            }
            // Update History
            lastPriceLowIdx = i;
            lastRsiLowIdx = currentRsiLowIdx;
        }
    }
    return (rates_total);
}

//--- Helper Functions

bool isPeak(int idx, const double& arr[], int depth) {
    double val = arr[idx];
    for (int k = 1; k <= depth; k++)
        if (arr[idx + k] >= val || arr[idx - k] >= val) return false;
    return true;
}

bool isValley(int idx, const double& arr[], int depth) {
    double val = arr[idx];
    for (int k = 1; k <= depth; k++)
        if (arr[idx + k] <= val || arr[idx - k] <= val) return false;
    return true;
}

// Find Highest RSI value index around the center index
int getHighestIndex(const double& arr[], int centerIdx, int range) {
    int bestIdx = centerIdx;
    double maxVal = arr[centerIdx];

    for (int k = 1; k <= range; k++) {
        // Check Left
        if (arr[centerIdx + k] > maxVal) {
            maxVal = arr[centerIdx + k];
            bestIdx = centerIdx + k;
        }
        // Check Right
        if (centerIdx - k >= 0 && arr[centerIdx - k] > maxVal) {
            maxVal = arr[centerIdx - k];
            bestIdx = centerIdx - k;
        }
    }
    return bestIdx;
}

// Find Lowest RSI value index around the center index
int getLowestIndex(const double& arr[], int centerIdx, int range) {
    int bestIdx = centerIdx;
    double minVal = arr[centerIdx];

    for (int k = 1; k <= range; k++) {
        // Check Left
        if (arr[centerIdx + k] < minVal) {
            minVal = arr[centerIdx + k];
            bestIdx = centerIdx + k;
        }
        // Check Right
        if (centerIdx - k >= 0 && arr[centerIdx - k] < minVal) {
            minVal = arr[centerIdx - k];
            bestIdx = centerIdx - k;
        }
    }
    return bestIdx;
}

void drawLine(datetime t1, double p1, datetime t2, double p2, color clr,
              string type) {
    string name = objPrefix + type + TimeToString(t2);
    if (ObjectFind(0, name) >= 0) return;
    ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}
//+------------------------------------------------------------------+