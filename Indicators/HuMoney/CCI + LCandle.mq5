//+------------------------------------------------------------------+
//|                                        AutoScaledCCI_MA.mq5      |
//|                                  Copyright 2025, p3pwp3p         |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, p3pwp3p"
#property link "https://www.mql5.com"
#property version "1.02"
#property strict

#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots 2

//--- Plot 1: CCI
#property indicator_label1 "CCI"
#property indicator_type1 DRAW_LINE
#property indicator_color1 clrCyan
#property indicator_style1 STYLE_SOLID
#property indicator_width1 1

//--- Plot 2: MA Scaled (화면 표시용)
#property indicator_label2 "MA(Price Action)"
#property indicator_type2 DRAW_LINE
#property indicator_color2 clrRed
#property indicator_style2 STYLE_SOLID
#property indicator_width2 1

//--- Input Parameters
input group "CCI Settings";
input int InpCciPeriod = 14;                           // CCI Period
input ENUM_APPLIED_PRICE InpCciPrice = PRICE_TYPICAL;  // CCI Applied Price

input group "MA Settings";
input int InpMaPeriod = 1;                    // MA Period (1 = Price Itself)
input int InpMaShift = 0;                     // MA Shift
input ENUM_MA_METHOD InpMaMethod = MODE_SMA;  // MA Method
input ENUM_APPLIED_PRICE InpMaPrice = PRICE_TYPICAL;  // MA Applied Price

input group "Visual Scaling";
input int InpFitPeriod = 150;         // Scaling Lookback Period (Bars);
input double InpVisualRange = 250.0;  // Target Visual Range (+/-);

//--- Global Variables (CamelCase)
int cciHandle;
int maHandle;
double cciBuffer[];
double maScaledBuffer[];  // 화면에 그려질 버퍼
double maRawBuffer[];     // 실제 MA 값 저장용 (계산용)
double tempBuffer[];      // 임시 복사용

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    //--- Indicator Buffers Mapping
    SetIndexBuffer(0, cciBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, maScaledBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, maRawBuffer, INDICATOR_CALCULATIONS);  // 숨겨진 버퍼
    SetIndexBuffer(3, tempBuffer, INDICATOR_CALCULATIONS);   // 임시 버퍼

    //--- Plot Labels
    PlotIndexSetString(0, PLOT_LABEL,
                       "CCI(" + IntegerToString(InpCciPeriod) + ")");
    PlotIndexSetString(1, PLOT_LABEL,
                       "MA Scaled");  // 값은 스케일된 값이므로 라벨 주의

    //--- Set empty value
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);

    //--- Initialize CCI Handle
    cciHandle = iCCI(_Symbol, _Period, InpCciPeriod, InpCciPrice);
    if (cciHandle == INVALID_HANDLE) {
        Print("Failed to create CCI handle");
        return (INIT_FAILED);
    }

    //--- Initialize MA Handle
    maHandle =
        iMA(_Symbol, _Period, InpMaPeriod, InpMaShift, InpMaMethod, InpMaPrice);
    if (maHandle == INVALID_HANDLE) {
        Print("Failed to create MA handle");
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
    if (rates_total < InpCciPeriod || rates_total < InpFitPeriod) return (0);

    int start;
    if (prev_calculated == 0)
        start = 0;
    else
        start = prev_calculated - 1;

    //--- 1. 데이터 복사 (CopyBuffer)
    // CCI와 MA 핸들에서 데이터를 가져옵니다.
    if (CopyBuffer(cciHandle, 0, 0, rates_total, tempBuffer) <= 0) return (0);
    // cciBuffer에 복사 (루프 없이 전체 복사 가능하지만, 구조 통일을 위해)
    ArrayCopy(cciBuffer, tempBuffer, 0, 0, rates_total);

    if (CopyBuffer(maHandle, 0, 0, rates_total, tempBuffer) <= 0) return (0);
    ArrayCopy(maRawBuffer, tempBuffer, 0, 0, rates_total);  // Raw 데이터 보존

    //--- 2. 스케일링 로직 (Scaling Logic)
    // 가격(MA)을 CCI 범위에 맞춰 변환합니다.

    for (int i = start; i < rates_total; i++) {
        // 스케일링을 위한 최근 N개(InpFitPeriod)의 MA 최고/최저값 찾기
        // 과거 데이터 부족 시 시작점 조정
        int lookbackIndex = i - InpFitPeriod;
        if (lookbackIndex < 0) lookbackIndex = 0;
        int count = i - lookbackIndex + 1;

        // 현재 구간의 Max, Min 찾기
        double localMax = -DBL_MAX;
        double localMin = DBL_MAX;

        for (int k = 0; k < count; k++) {
            double val = maRawBuffer[i - k];
            if (val > localMax) localMax = val;
            if (val < localMin) localMin = val;
        }

        // 범위 계산
        double range = localMax - localMin;
        if (range == 0.0) range = 0.00001;  // 0 나누기 방지

        // 변환 공식: (현재값 - 최저값) / 범위 * 목표범위 - (목표범위 절반)
        // 목표 범위를 -250 ~ +250 (InpVisualRange) 정도로 잡으면 CCI와 비슷해짐

        double normalizedRatio =
            (maRawBuffer[i] - localMin) / range;  // 0.0 ~ 1.0 사이 값

        // CCI 창의 중심(0)을 기준으로 위아래로 퍼지게 배치
        // 예: 0.0 -> -250, 1.0 -> +250
        double scaledValue =
            (normalizedRatio * (InpVisualRange * 2)) - InpVisualRange;

        maScaledBuffer[i] = scaledValue;
    }

    return (rates_total);
}
//+------------------------------------------------------------------+