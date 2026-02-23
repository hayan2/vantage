//+------------------------------------------------------------------+
//|                                                   Stoch RSI.mq5  |
//|                                         Copyright 2026, p3pwp3p  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, p3pwp3p"
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

#property indicator_separate_window
// [시각적 해결] 위아래로 여백을 주어 선이 잘려 보이지 않게 함
#property indicator_minimum - 10.0
#property indicator_maximum 110.0

// [시각적 해결] 0, 20, 80, 100 구간에 점선 추가
#property indicator_level1 0.0
#property indicator_level2 20.0
#property indicator_level3 80.0
#property indicator_level4 100.0
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT

#property indicator_buffers 4
#property indicator_plots 2

#property indicator_type1 DRAW_LINE
#property indicator_color1 clrDodgerBlue
#property indicator_style1 STYLE_SOLID
#property indicator_width1 1
#property indicator_label1 "%K"

#property indicator_type2 DRAW_LINE
#property indicator_color2 clrOrange
#property indicator_style2 STYLE_DASHDOT
#property indicator_width2 1
#property indicator_label2 "%D"

input group "StochRsiSettings";
input int RsiPeriod = 14;
input int StochPeriod = 14;
input int KPeriod = 3;
input int DPeriod = 3;
input ENUM_APPLIED_PRICE AppliedPrice = PRICE_CLOSE;

double kBuffer[];
double dBuffer[];
double rsiBuffer[];
double stochRsiBuffer[];

int rsiHandle;

int OnInit() {
    SetIndexBuffer(0, kBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, dBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, rsiBuffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(3, stochRsiBuffer, INDICATOR_CALCULATIONS);

    // 강제 스케일링 설정 (-10 ~ 110으로 여백 확보)
    IndicatorSetDouble(INDICATOR_MINIMUM, -10.0);
    IndicatorSetDouble(INDICATOR_MAXIMUM, 110.0);

    rsiHandle = iRSI(_Symbol, _Period, RsiPeriod, AppliedPrice);
    if (rsiHandle == INVALID_HANDLE) {
        Print("RSI 지표 핸들 생성 실패");
        return (INIT_FAILED);
    }
    return (INIT_SUCCEEDED);
}

int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime& time[], const double& open[],
                const double& high[], const double& low[],
                const double& close[], const long& tick_volume[],
                const long& volume[], const int& spread[]) {
    if (rates_total < (RsiPeriod + StochPeriod + KPeriod + DPeriod)) return 0;

    int copied = CopyBuffer(rsiHandle, 0, 0, rates_total, rsiBuffer);
    if (copied != rates_total) return 0;

    int stochStart = (prev_calculated == 0) ? StochPeriod : prev_calculated - 1;
    for (int i = stochStart; i < rates_total; i++) {
        double minRsi = rsiBuffer[i];
        double maxRsi = rsiBuffer[i];

        for (int j = 0; j < StochPeriod; j++) {
            if (i - j < 0) continue;
            double currentRsi = rsiBuffer[i - j];
            if (currentRsi < minRsi) minRsi = currentRsi;
            if (currentRsi > maxRsi) maxRsi = currentRsi;
        }

        double stochVal = 0.0;
        if (maxRsi - minRsi > 0.0) {
            stochVal = ((rsiBuffer[i] - minRsi) / (maxRsi - minRsi)) * 100.0;
        } else {
            stochVal = (i > 0) ? stochRsiBuffer[i - 1] : 0.0;
        }

        // 100과 0을 넘어가지 않도록 강제 고정(Clamping)
        if (stochVal > 100.0) stochVal = 100.0;
        if (stochVal < 0.0) stochVal = 0.0;

        stochRsiBuffer[i] = stochVal;
    }

    int kStart =
        (prev_calculated == 0) ? StochPeriod + KPeriod : prev_calculated - 1;
    for (int i = kStart; i < rates_total; i++) {
        double sumK = 0.0;
        for (int j = 0; j < KPeriod; j++) {
            if (i - j < 0) continue;
            sumK += stochRsiBuffer[i - j];
        }
        double kVal = sumK / KPeriod;

        if (kVal > 100.0) kVal = 100.0;
        if (kVal < 0.0) kVal = 0.0;
        kBuffer[i] = kVal;
    }

    int dStart = (prev_calculated == 0) ? StochPeriod + KPeriod + DPeriod
                                        : prev_calculated - 1;
    for (int i = dStart; i < rates_total; i++) {
        double sumD = 0.0;
        for (int j = 0; j < DPeriod; j++) {
            if (i - j < 0) continue;
            sumD += kBuffer[i - j];
        }
        double dVal = sumD / DPeriod;

        if (dVal > 100.0) dVal = 100.0;
        if (dVal < 0.0) dVal = 0.0;
        dBuffer[i] = dVal;
    }

    return (rates_total);
}