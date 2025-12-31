//+------------------------------------------------------------------+
//|                                   RSI_SubWindow_Monitor.mq5     |
//|                                  Copyright 2025, p3pwp3p  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, p3pwp3p"
#property link "https://www.mql5.com"
#property version "1.00"
#property strict
#property indicator_separate_window  // 차트 하단 별도 창에 표시
#property indicator_buffers 1
#property indicator_plots 1

//--- Plot settings for RSI Line
#property indicator_label1 "RSI"
#property indicator_type1 DRAW_LINE
#property indicator_color1 clrWhite
#property indicator_style1 STYLE_SOLID
#property indicator_width1 1

//--- Levels
#property indicator_level1 30
#property indicator_level2 70
#property indicator_levelcolor clrGray
#property indicator_levelstyle STYLE_DOT

//--- Input Parameters
input group "RSI Settings";
input int RSIPeriod = 14;                         // RSI 기간
input ENUM_APPLIED_PRICE RSIPrice = PRICE_CLOSE;  // RSI 적용 가격

input group "Divergence Settings";
input int PeakDepth = 5;      // 꼭지점 감지 깊이
input bool DrawLines = true;  // RSI 위에 선 그리기

//--- Indicator Buffers
double RSIBuffer[];

//--- Global Variables
int rsiHandle;
string objPrefix = "RSI_Sub_";
int subWindowIndex = 0;  // 서브윈도우 번호

//+------------------------------------------------------------------+
//| Custom Indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    // 1. 버퍼 매핑
    SetIndexBuffer(0, RSIBuffer, INDICATOR_DATA);
    ArraySetAsSeries(RSIBuffer, true);

    // 2. RSI 핸들 생성
    rsiHandle = iRSI(_Symbol, _Period, RSIPeriod, RSIPrice);
    if (rsiHandle == INVALID_HANDLE) {
        Print("Failed to create RSI handle.");
        return (INIT_FAILED);
    }

    // 지표 짧은 이름 설정 (윈도우 식별용)
    IndicatorSetString(INDICATOR_SHORTNAME, "RSI Divergence Monitor");

    return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom Indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    IndicatorRelease(rsiHandle);
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
    // 현재 지표가 실행 중인 윈도우 번호 찾기 (선 그리기 위해 필요)
    subWindowIndex = ChartWindowFind(0, "RSI Divergence Monitor");

    if (rates_total < RSIPeriod + PeakDepth * 2) return (0);

    // 1. RSI 데이터 복사
    if (CopyBuffer(rsiHandle, 0, 0, rates_total, RSIBuffer) <= 0) return (0);
    ArraySetAsSeries(RSIBuffer, true);
    ArraySetAsSeries(time, true);  // 시간 배열도 역순 정렬

    // 2. 계산 범위 설정
    int limit = prev_calculated == 0
                    ? rates_total - PeakDepth - 2
                    : rates_total - prev_calculated + PeakDepth;
    if (limit >= rates_total - PeakDepth - 1)
        limit = rates_total - PeakDepth - 2;

    static int lastHighIndex = -1;
    static int lastLowIndex = -1;

    // 메인 루프
    for (int i = limit; i >= PeakDepth + 1; i--) {
        // --- RSI 고점(Peak) 탐지 ---
        // 가격(High) 대신 RSI값(RSIBuffer)을 기준으로 고점 판별
        if (IsPeak(i, RSIBuffer, PeakDepth)) {
            if (lastHighIndex != -1) {
                // 하락 다이버전스 확인용 (가격 고점은 높아지는데 RSI 고점은
                // 낮아질 때) 여기서는 RSI 차트에만 그리므로 RSI가 낮아지는 것만
                // 시각적으로 연결
                if (RSIBuffer[i] < RSIBuffer[lastHighIndex]) {
                    if (DrawLines)
                        DrawLineOnRSI(time[lastHighIndex],
                                      RSIBuffer[lastHighIndex], time[i],
                                      RSIBuffer[i], clrMagenta, "BearRSI_");
                }
            }
            lastHighIndex = i;
        }

        // --- RSI 저점(Valley) 탐지 ---
        if (IsValley(i, RSIBuffer, PeakDepth)) {
            if (lastLowIndex != -1) {
                // 상승 다이버전스 확인용
                if (RSIBuffer[i] > RSIBuffer[lastLowIndex]) {
                    if (DrawLines)
                        DrawLineOnRSI(time[lastLowIndex],
                                      RSIBuffer[lastLowIndex], time[i],
                                      RSIBuffer[i], clrAqua, "BullRSI_");
                }
            }
            lastLowIndex = i;
        }
    }

    return (rates_total);
}

//+------------------------------------------------------------------+
//| Helper: 피크 판별 (RSI 값 기준)                                  |
//+------------------------------------------------------------------+
bool IsPeak(int index, const double& arr[], int depth) {
    double currentVal = arr[index];
    for (int k = 1; k <= depth; k++) {
        if (arr[index + k] >= currentVal || arr[index - k] >= currentVal)
            return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Helper: 밸리 판별 (RSI 값 기준)                                  |
//+------------------------------------------------------------------+
bool IsValley(int index, const double& arr[], int depth) {
    double currentVal = arr[index];
    for (int k = 1; k <= depth; k++) {
        if (arr[index + k] <= currentVal || arr[index - k] <= currentVal)
            return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Helper: 서브 윈도우에 선 그리기                                  |
//+------------------------------------------------------------------+
void DrawLineOnRSI(datetime t1, double v1, datetime t2, double v2, color clr,
                   string typePrefix) {
    string objName = objPrefix + TimeToString(t2);
    if (ObjectFind(0, objName) >= 0) return;

    // 중요: window 파라미터에 subWindowIndex를 넣어줘야 함
    ObjectCreate(0, objName, OBJ_TREND, subWindowIndex, t1, v1, t2, v2);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
    ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
}
//+------------------------------------------------------------------+