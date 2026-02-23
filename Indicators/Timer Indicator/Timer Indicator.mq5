//+------------------------------------------------------------------+
//|                                        프로그램 제목.mq5  |
//|                                  Copyright 2025, p3pwp3p  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, p3pwp3p"
#property link "https://www.mql5.com"
#property version "1.00"
#property strict
#property indicator_chart_window
#property indicator_plots 0

//--- Inputs
input group "Label Settings";
input ENUM_BASE_CORNER CornerPosition = CORNER_RIGHT_LOWER;  // Label Corner
input int XOffset = 20;                                      // X Offset
input int YOffset = 20;                                      // Y Offset
input color TextColor = clrWhite;                            // Text Color
input int FontSize = 12;                                     // Font Size
input string FontName = "Arial";                             // Font Name

//--- Global Variables
string labelName = "timeRemainingLabel";

//+------------------------------------------------------------------+
//| Custom Functions                                                 |
//+------------------------------------------------------------------+
string formatTime(int totalSeconds) {
    int hours = totalSeconds / 3600;
    int minutes = (totalSeconds % 3600) / 60;
    int seconds = totalSeconds % 60;
    return StringFormat("%02d:%02d:%02d", hours, minutes, seconds);
}

void createOrUpdateDisplay(string textToShow) {
    // 모서리 위치에 따른 텍스트 앵커(Anchor) 동적 할당 (글자 잘림 방지)
    ENUM_ANCHOR_POINT anchorPoint = ANCHOR_LEFT_UPPER;
    if (CornerPosition == CORNER_LEFT_UPPER)
        anchorPoint = ANCHOR_LEFT_UPPER;
    else if (CornerPosition == CORNER_LEFT_LOWER)
        anchorPoint = ANCHOR_LEFT_LOWER;
    else if (CornerPosition == CORNER_RIGHT_UPPER)
        anchorPoint = ANCHOR_RIGHT_UPPER;
    else if (CornerPosition == CORNER_RIGHT_LOWER)
        anchorPoint = ANCHOR_RIGHT_LOWER;

    // 텍스트 라벨 생성 및 업데이트
    if (ObjectFind(0, labelName) < 0) {
        ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);
    }

    ObjectSetInteger(0, labelName, OBJPROP_CORNER, CornerPosition);
    ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, anchorPoint);
    ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, XOffset);
    ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, YOffset);
    ObjectSetInteger(0, labelName, OBJPROP_COLOR, TextColor);
    ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, FontSize);
    ObjectSetString(0, labelName, OBJPROP_FONT, FontName);
    ObjectSetString(0, labelName, OBJPROP_TEXT, textToShow);
}

void updateDisplay() {
    datetime currentTime = TimeCurrent();
    int currentPeriodSeconds = PeriodSeconds();
    datetime currentCandleOpenTime = iTime(Symbol(), Period(), 0);
    datetime nextCandleTime = currentCandleOpenTime + currentPeriodSeconds;

    int timeRemaining = (int)(nextCandleTime - currentTime);
    if (timeRemaining < 0) timeRemaining = 0;

    string currentStr = TimeToString(currentTime, TIME_SECONDS);
    string remainStr = formatTime(timeRemaining);

    string displayText =
        StringFormat("Current: %s | Next Candle In: %s", currentStr, remainStr);

    createOrUpdateDisplay(displayText);
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    EventSetTimer(1);  // 1초마다 Timer 이벤트 발생
    return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    EventKillTimer();
    ObjectDelete(0, labelName);
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime& time[], const double& open[],
                const double& high[], const double& low[],
                const double& close[], const long& tick_volume[],
                const long& volume[], const int& spread[]) {
    updateDisplay();
    return (rates_total);
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer() { updateDisplay(); }
//+------------------------------------------------------------------+