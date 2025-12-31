//+------------------------------------------------------------------+
//|                                     Chart_Overlay_CCI_ATR.mq5    |
//|                                  Copyright 2025, p3pwp3p         |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, p3pwp3p"
#property link "https://www.mql5.com"
#property version "2.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots 2

//--- Plot 1: 1MA (Base Line)
#property indicator_label1 "BasePrice(1MA)"
#property indicator_type1 DRAW_LINE
#property indicator_color1 clrRed
#property indicator_style1 STYLE_SOLID
#property indicator_width1 1

//--- Plot 2: Scaled CCI
#property indicator_label2 "OnChartCCI"
#property indicator_type2 DRAW_LINE
#property indicator_color2 clrCyan
#property indicator_style2 STYLE_SOLID
#property indicator_width2 2

//--- Input Parameters
input group "CCI Settings";
input int CciPeriod = 14;                           // CCI 기간
input ENUM_APPLIED_PRICE CciPrice = PRICE_TYPICAL;  // 적용 가격

input group "Visual Settings";
input double VisualHeight = 1.0;  // 시각적 높이 조절 (1.0 = 표준 ATR 크기)
input int AtrPeriod = 14;         // 스케일링용 ATR 기간
input int MaPeriod = 1;           // 기준선 MA 기간

//--- Global Variables
double baseLineBuffer[];
double cciPlotBuffer[];
int cciHandle;
int maHandle;
int atrHandle;  // 변동성 계산용 핸들 추가

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    SetIndexBuffer(0, baseLineBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, cciPlotBuffer, INDICATOR_DATA);

    PlotIndexSetString(0, PLOT_LABEL, "Base(1MA)");
    PlotIndexSetString(1, PLOT_LABEL, "CCI(Overlay)");

    // 1. CCI 핸들
    cciHandle = iCCI(Symbol(), Period(), CciPeriod, CciPrice);

    // 2. MA 핸들 (기준선)
    maHandle = iMA(Symbol(), Period(), MaPeriod, 0, MODE_SMA, CciPrice);

    // 3. ATR 핸들 (스케일링용 핵심)
    atrHandle = iATR(Symbol(), Period(), AtrPeriod);

    if (cciHandle == INVALID_HANDLE || maHandle == INVALID_HANDLE ||
        atrHandle == INVALID_HANDLE) {
        Print("Failed to create handles.");
        return (INIT_FAILED);
    }

    return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime& time[], const double& open[],
                const double& high[], const double& low[],
                const double& close[], const long& tick_volume[],
                const long& volume[], const int& spread[]) {
    int limit = rates_total - prev_calculated;
    if (limit > 1) limit = rates_total - 1;

    double cciVal[];
    double maVal[];
    double atrVal[];  // ATR 값 배열

    ArraySetAsSeries(cciVal, true);
    ArraySetAsSeries(maVal, true);
    ArraySetAsSeries(atrVal, true);

    // 데이터 카피
    if (CopyBuffer(cciHandle, 0, 0, limit + 1, cciVal) <= 0) return (0);
    if (CopyBuffer(maHandle, 0, 0, limit + 1, maVal) <= 0) return (0);
    if (CopyBuffer(atrHandle, 0, 0, limit + 1, atrVal) <= 0) return (0);

    for (int i = 0; i < limit; i++) {
        int barIndex = rates_total - 1 - i;

        double currentCci = cciVal[i];
        double currentMa = maVal[i];
        double currentAtr = atrVal[i];

        // --- 핵심 변경 로직 ---
        // CCI 값(보통 -100 ~ 100)을 ATR(캔들 크기) 비율로 변환합니다.
        // 공식: 기준가격 + ( (CCI / 100.0) * ATR * 높이조절계수 )
        // 설명: CCI가 100일 때, 캔들 1개 크기(ATR)만큼 기준선 위로 올라가게
        // 됩니다.

        double scaledOffset = (currentCci / 100.0) * currentAtr * VisualHeight;

        baseLineBuffer[barIndex] = currentMa;                // 빨간선
        cciPlotBuffer[barIndex] = currentMa + scaledOffset;  // 초록선
    }

    return (rates_total);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    IndicatorRelease(cciHandle);
    IndicatorRelease(maHandle);
    IndicatorRelease(atrHandle);
}