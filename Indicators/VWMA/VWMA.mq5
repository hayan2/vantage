//+------------------------------------------------------------------+
//|                                                        VWMA.mq5  |
//|                                         Copyright 2026, p3pwp3p  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, p3pwp3p"
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots 1

#property indicator_type1 DRAW_LINE
#property indicator_color1 clrDodgerBlue
#property indicator_style1 STYLE_SOLID
#property indicator_width1 2

input group "VwmaSettings";
input int VwmaPeriod = 20;

double vwmaBuffer[];

int OnInit() {
    SetIndexBuffer(0, vwmaBuffer, INDICATOR_DATA);
    PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, VwmaPeriod);
    PlotIndexSetString(0, PLOT_LABEL,
                       "VWMA(" + IntegerToString(VwmaPeriod) + ")");
    return (INIT_SUCCEEDED);
}

int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime& time[], const double& open[],
                const double& high[], const double& low[],
                const double& close[], const long& tick_volume[],
                const long& volume[], const int& spread[]) {
    if (rates_total < VwmaPeriod) return 0;

    int startIndex = (prev_calculated > 0) ? prev_calculated - 1 : VwmaPeriod;

    for (int i = startIndex; i < rates_total; i++) {
        double sumPriceVol = 0.0;
        long sumVol = 0;

        for (int j = 0; j < VwmaPeriod; j++) {
            double currPrice = close[i - j];
            long currVol = tick_volume[i - j];

            sumPriceVol += currPrice * currVol;
            sumVol += currVol;
        }

        if (sumVol > 0) {
            vwmaBuffer[i] = sumPriceVol / sumVol;
        } else {
            vwmaBuffer[i] = close[i];
        }
    }
    return (rates_total);
}