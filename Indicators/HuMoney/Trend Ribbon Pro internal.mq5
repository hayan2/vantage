//+------------------------------------------------------------------+
//|                                   Trend Ribbon Pro_Standalone.mq5|
//|                                          Copyright 2025, p3pwp3p |
//+------------------------------------------------------------------+
#property copyright "p3pwp3p"
#property link "https://www.mql5.com"
#property version "1.02"
#property indicator_chart_window

#property indicator_buffers 4
#property indicator_plots 1

#property indicator_label1 "SlopeCloud"
#property indicator_type1 DRAW_COLOR_HISTOGRAM2
#property indicator_color1 clrLime, clrRed
#property indicator_style1 STYLE_SOLID
#property indicator_width1 10

#include <MovingAverages.mqh>  // MT5 내장 수식 라이브러리 사용

//--- Inputs
input group "MA Settings";
input int InputFastPeriod = 20;
input int InputSlowPeriod = 50;
input int InputMaShift = 0;
input ENUM_MA_METHOD InputMaMethod = MODE_EMA;
input ENUM_APPLIED_PRICE InputAppliedPrice = PRICE_CLOSE;

input group "Color Logic";
input int InputSensitivity = 3;

input group "Visual Settings";
input int InputAlphaOpacity = 150;
input bool InputForceColorSwap = false;

//--- Buffers
double fastBuffer[];
double slowBuffer[];
double colorBuffer[];
double dummyBuffer[];

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit() {
    SetIndexBuffer(0, fastBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, slowBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, colorBuffer, INDICATOR_COLOR_INDEX);
    SetIndexBuffer(3, dummyBuffer, INDICATOR_CALCULATIONS);

    // ★ 핵심 수정: 배열을 '시계열 역순'으로 뒤집지 않고 '기본 순서(0=과거)'로
    // 사용 이렇게 해야 계산이 꼬이지 않고 정확하게 나옵니다.
    ArraySetAsSeries(fastBuffer, false);
    ArraySetAsSeries(slowBuffer, false);
    ArraySetAsSeries(colorBuffer, false);

    // 플롯 설정
    PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_HISTOGRAM2);
    PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 2);
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);

    // 색상 설정
    color c1 = clrLime;
    color c2 = clrRed;

    if (InputForceColorSwap) {
        c1 = (color)GetSwappedColor(c1, (uchar)InputAlphaOpacity);
        c2 = (color)GetSwappedColor(c2, (uchar)InputAlphaOpacity);
    } else {
        c1 = ColorToARGB(c1, (uchar)InputAlphaOpacity);
        c2 = ColorToARGB(c2, (uchar)InputAlphaOpacity);
    }

    PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, c1);
    PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, c2);

    return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnCalculate                                                      |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime& time[], const double& open[],
                const double& high[], const double& low[],
                const double& close[], const long& tick_volume[],
                const long& volume[], const int& spread[]) {
    if (rates_total <
        MathMax(InputFastPeriod, InputSlowPeriod) + InputSensitivity)
        return (0);

    int limit;
    // EMA 계산을 위해 맨 처음부터 계산하거나, 마지막 부분만 이어서 계산
    if (prev_calculated == 0) {
        limit = 0;
        // 초기화: 쓰레기 값이 들어가지 않게 0으로 밀어줌
        ArrayInitialize(fastBuffer, 0);
        ArrayInitialize(slowBuffer, 0);
    } else {
        limit = prev_calculated - 1;
    }

    // 1. Fast EMA 계산 (정방향 루프: 0(과거) -> rates_total(현재))
    CalculateSimpleEMA(rates_total, limit, InputFastPeriod, close, fastBuffer);

    // 2. Slow EMA 계산
    CalculateSimpleEMA(rates_total, limit, InputSlowPeriod, close, slowBuffer);

    // 3. 색상 로직 적용
    for (int i = limit; i < rates_total; i++) {
        // 0이 과거이므로, i-Sensitivity가 과거 데이터임
        int compareIndex = i - InputSensitivity;

        if (compareIndex < 0) {
            colorBuffer[i] = 0.0;
            continue;
        }

        double currentVal = slowBuffer[i];
        double oldVal = slowBuffer[compareIndex];

        // 값이 0이면(계산 전) 색상 안 그림
        if (currentVal == 0 || oldVal == 0) {
            colorBuffer[i] = 0.0;
            continue;
        }

        if (currentVal > oldVal)
            colorBuffer[i] = 0.0;  // Lime
        else if (currentVal < oldVal)
            colorBuffer[i] = 1.0;  // Red
        else if (i > 0)
            colorBuffer[i] = colorBuffer[i - 1];  // 이전 색 유지
        else
            colorBuffer[i] = 0.0;
    }

    return (rates_total);
}

//+------------------------------------------------------------------+
//| 간단하고 강력한 EMA 계산 함수 (라이브러리 의존 X)                    |
//+------------------------------------------------------------------+
void CalculateSimpleEMA(const int rates_total, const int limit,
                        const int period, const double& price[],
                        double& buffer[]) {
    double smoothFactor = 2.0 / (period + 1.0);

    int start = limit;
    if (start == 0) {
        // 맨 처음 값은 해당 가격으로 초기화
        buffer[0] = price[0];
        start = 1;
    }

    for (int i = start; i < rates_total; i++) {
        // EMA 공식: (현재가 - 이전EMA) * K + 이전EMA
        // 이전 값이 0이면(초기화 안됨) 현재가로 세팅
        if (buffer[i - 1] == 0) buffer[i - 1] = price[i - 1];

        buffer[i] =
            price[i] * smoothFactor + buffer[i - 1] * (1.0 - smoothFactor);
    }
}

//+------------------------------------------------------------------+
//| Helper                                                           |
//+------------------------------------------------------------------+
uint GetSwappedColor(color baseColor, uchar alpha) {
    int r = (baseColor >> 0) & 0xFF;
    int g = (baseColor >> 8) & 0xFF;
    int b = (baseColor >> 16) & 0xFF;
    return ((uint)alpha << 24) | ((uint)r << 16) | ((uint)g << 8) | (uint)b;
}