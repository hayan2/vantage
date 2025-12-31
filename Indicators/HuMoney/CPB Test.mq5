//+------------------------------------------------------------------+
//|                                       CustomPivotBox.mq5         |
//|                                  Copyright 2025, p3pwp3p         |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, p3pwp3p"
#property link "https://www.mql5.com"
#property version "1.08"
#property indicator_chart_window
#property strict

//--- Input Variables (PascalCase)
input group "General Settings";
input int LookBackDaysPivot = 50;  // Lookback Days (Pivot): 피벗 라인 표시 일수
input int LookBackDaysRange =
    50;  // Lookback Days (Range): 변동폭 박스 표시 일수

input group "Pivot Settings";
input ENUM_LINE_STYLE ResStyle = STYLE_DOT;  // 저항선(R) 스타일
input ENUM_LINE_STYLE SupStyle = STYLE_DOT;  // 지지선(S) 스타일
input int LineWidth = 1;                     // 선 두께
input bool ShowPivotLabels = true;           // 우측 수치 라벨 표시 여부

input group "Box Settings";
input color BullBoxColor = clrLime;  // 상승 박스 색상 (O < C)
input color BearBoxColor = clrRed;   // 하락 박스 색상 (O > C)
input int FontSize = 10;             // 텍스트 크기

//--- Global Variables (CamelCase)
bool showPivot = true;       // 피벗 보이기 상태
bool showHL = true;          // 박스 보이기 상태
string prefixName = "CPB_";  // 객체 이름 접두사

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    // 버튼 위치 설정
    createButton("Btn_Pivot", "Pivot", 60, 20);
    createButton("Btn_HL", "HL", 60, 50);

    updateChart();

    return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    ObjectsDeleteAll(0, prefixName);
    ObjectsDeleteAll(0, "Btn_Pivot");
    ObjectsDeleteAll(0, "Btn_HL");
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Custom indicator calculation function                            |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime& time[], const double& open[],
                const double& high[], const double& low[],
                const double& close[], const long& tick_volume[],
                const long& volume[], const int& spread[]) {
    updateChart();
    return (rates_total);
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam,
                  const string& sparam) {
    if (id == CHARTEVENT_OBJECT_CLICK) {
        if (sparam == "Btn_Pivot") {
            showPivot = !showPivot;
            toggleButtonState("Btn_Pivot", showPivot);

            if (!showPivot) {
                ObjectsDeleteAll(0, prefixName + "P_");
                ObjectsDeleteAll(0, prefixName + "R");
                ObjectsDeleteAll(0, prefixName + "S");
                ObjectsDeleteAll(0, prefixName + "Lb_");
            }
            ChartRedraw();
        } else if (sparam == "Btn_HL") {
            showHL = !showHL;
            toggleButtonState("Btn_HL", showHL);

            if (!showHL) {
                ObjectsDeleteAll(0, prefixName + "Box_");
                ObjectsDeleteAll(0, prefixName + "Txt_");
            }
            ChartRedraw();
        }

        updateChart();
    }
}

//+------------------------------------------------------------------+
//| 사용자 함수: 차트 전체 업데이트 (CamelCase)                          |
//+------------------------------------------------------------------+
void updateChart() {
    int maxLookBack = MathMax(LookBackDaysPivot, LookBackDaysRange);

    MqlRates rates[];
    ArraySetAsSeries(rates, true);

    int copied = CopyRates(_Symbol, PERIOD_D1, 0, maxLookBack + 1, rates);
    if (copied < 2) return;

    for (int i = 0; i < copied - 1; i++) {
        MqlRates today = rates[i];
        MqlRates yesterday = rates[i + 1];

        datetime tStart = today.time;
        datetime tEnd = tStart + PeriodSeconds(PERIOD_D1);

        bool isToday = (i == 0);

        if (showPivot && i < LookBackDaysPivot) {
            drawPivots(tStart, tEnd, yesterday.high, yesterday.low,
                       yesterday.close, isToday);
        }

        if (!isToday) deletePivotLabels(tStart);

        if (showHL && i < LookBackDaysRange) {
            drawBoxes(tStart, tEnd, today.open, today.close, today.high,
                      today.low);
        }
    }

    ChartRedraw();
}

//+------------------------------------------------------------------+
//| 사용자 함수: 피벗 라인 그리기 (CamelCase)                            |
//+------------------------------------------------------------------+
void drawPivots(datetime start, datetime end, double h, double l, double c,
                bool isToday) {
    double p = (h + l + c) / 3.0;
    double r1 = (2 * p) - l;
    double s1 = (2 * p) - h;
    double r2 = p + (h - l);
    double s2 = p - (h - l);
    double r3 = h + 2 * (p - l);
    double s3 = l - 2 * (h - p);

    double range = h - l;
    double r4 = p + (2 * range);
    double s4 = p - (2 * range);

    string suffix = IntegerToString(start);

    createLine(prefixName + "P_" + suffix, start, end, p, clrYellow,
               STYLE_SOLID);
    createLine(prefixName + "R1_" + suffix, start, end, r1, clrDodgerBlue,
               ResStyle);
    createLine(prefixName + "R2_" + suffix, start, end, r2, clrDodgerBlue,
               ResStyle);
    createLine(prefixName + "R3_" + suffix, start, end, r3, clrDodgerBlue,
               ResStyle);
    createLine(prefixName + "R4_" + suffix, start, end, r4, clrDodgerBlue,
               ResStyle);
    createLine(prefixName + "S1_" + suffix, start, end, s1, clrRed, SupStyle);
    createLine(prefixName + "S2_" + suffix, start, end, s2, clrRed, SupStyle);
    createLine(prefixName + "S3_" + suffix, start, end, s3, clrRed, SupStyle);
    createLine(prefixName + "S4_" + suffix, start, end, s4, clrRed, SupStyle);

    if (isToday && ShowPivotLabels) {
        createLabel(prefixName + "Lb_P_" + suffix, end, p,
                    "P: " + DoubleToString(p, _Digits), clrYellow);
        createLabel(prefixName + "Lb_R1_" + suffix, end, r1,
                    "R1: " + DoubleToString(r1, _Digits), clrDodgerBlue);
        createLabel(prefixName + "Lb_R2_" + suffix, end, r2,
                    "R2: " + DoubleToString(r2, _Digits), clrDodgerBlue);
        createLabel(prefixName + "Lb_R3_" + suffix, end, r3,
                    "R3: " + DoubleToString(r3, _Digits), clrDodgerBlue);
        createLabel(prefixName + "Lb_R4_" + suffix, end, r4,
                    "R4: " + DoubleToString(r4, _Digits), clrDodgerBlue);
        createLabel(prefixName + "Lb_S1_" + suffix, end, s1,
                    "S1: " + DoubleToString(s1, _Digits), clrRed);
        createLabel(prefixName + "Lb_S2_" + suffix, end, s2,
                    "S2: " + DoubleToString(s2, _Digits), clrRed);
        createLabel(prefixName + "Lb_S3_" + suffix, end, s3,
                    "S3: " + DoubleToString(s3, _Digits), clrRed);
        createLabel(prefixName + "Lb_S4_" + suffix, end, s4,
                    "S4: " + DoubleToString(s4, _Digits), clrRed);
    }
}

//+------------------------------------------------------------------+
//| 사용자 함수: HL 박스 및 텍스트 그리기 (CamelCase)                     |
//+------------------------------------------------------------------+
void drawBoxes(datetime start, datetime end, double o, double c, double h,
               double l) {
    bool isBull = (o < c);
    color drawColor = isBull ? BullBoxColor : BearBoxColor;
    string suffix = IntegerToString(start);

    // 1. 박스 그리기
    string boxName = prefixName + "Box_" + suffix;

    if (ObjectFind(0, boxName) < 0) {
        ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, start, h, end, l);
        ObjectSetInteger(0, boxName, OBJPROP_FILL, false);
        ObjectSetInteger(0, boxName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, boxName, OBJPROP_BACK, false);
    }

    ObjectSetDouble(0, boxName, OBJPROP_PRICE, 0, h);
    ObjectSetDouble(0, boxName, OBJPROP_PRICE, 1, l);
    ObjectSetInteger(0, boxName, OBJPROP_COLOR, drawColor);

    // 2. 텍스트 그리기
    string textName = prefixName + "Txt_" + suffix;
    int rangePoints = (int)MathRound((h - l) / _Point);

    if (ObjectFind(0, textName) < 0) {
        ObjectCreate(0, textName, OBJ_TEXT, 0, start, h);
        ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, FontSize);
    }

    // 텍스트 설정
    ObjectSetString(
        0, textName, OBJPROP_TEXT,
        " " +
            IntegerToString(rangePoints));  // 약간의 공백으로 라인과 겹침 방지
    ObjectSetDouble(0, textName, OBJPROP_PRICE, 0, h);  // 가격 위치: 고가(High)
    ObjectSetInteger(0, textName, OBJPROP_TIME,
                     start);  // 시간 위치: 시작 시간(Start)
    ObjectSetInteger(0, textName, OBJPROP_COLOR, drawColor);

    // [중요 수정]
    // ANCHOR_LEFT: 텍스트의 왼쪽이 기준점(시작 시간)에 맞음 -> 기간 구분선
    // 안쪽(오른쪽)으로 그려짐 ANCHOR_LOWER: 텍스트의 하단이 기준점(고가)에 맞음
    // -> 박스 위쪽(바깥)으로 그려짐
    ObjectSetInteger(0, textName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
}

//+------------------------------------------------------------------+
//| 헬퍼 함수: 선 생성 (CamelCase)                                     |
//+------------------------------------------------------------------+
void createLine(string name, datetime t1, datetime t2, double price, color clr,
                ENUM_LINE_STYLE style) {
    if (ObjectFind(0, name) < 0) {
        ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);
        ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    }

    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_STYLE, style);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, LineWidth);
    ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
    ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price);
    ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
    ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
}

//+------------------------------------------------------------------+
//| 헬퍼 함수: 라벨 생성 (CamelCase)                                    |
//+------------------------------------------------------------------+
void createLabel(string name, datetime t, double price, string text,
                 color clr) {
    if (ObjectFind(0, name) < 0) {
        ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
    }

    ObjectSetString(0, name, OBJPROP_TEXT, "  " + text);
    ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
    ObjectSetInteger(0, name, OBJPROP_TIME, t);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

//+------------------------------------------------------------------+
//| 헬퍼 함수: 특정 날짜의 피벗 라벨 삭제 (CamelCase)                      |
//+------------------------------------------------------------------+
void deletePivotLabels(datetime t) {
    string suffix = IntegerToString(t);
    ObjectDelete(0, prefixName + "Lb_P_" + suffix);
    ObjectDelete(0, prefixName + "Lb_R1_" + suffix);
    ObjectDelete(0, prefixName + "Lb_R2_" + suffix);
    ObjectDelete(0, prefixName + "Lb_R3_" + suffix);
    ObjectDelete(0, prefixName + "Lb_R4_" + suffix);
    ObjectDelete(0, prefixName + "Lb_S1_" + suffix);
    ObjectDelete(0, prefixName + "Lb_S2_" + suffix);
    ObjectDelete(0, prefixName + "Lb_S3_" + suffix);
    ObjectDelete(0, prefixName + "Lb_S4_" + suffix);
}

//+------------------------------------------------------------------+
//| 헬퍼 함수: 버튼 생성 (CamelCase)                                   |
//+------------------------------------------------------------------+
void createButton(string name, string text, int x, int y) {
    if (ObjectFind(0, name) < 0) {
        ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_XSIZE, 50);
        ObjectSetInteger(0, name, OBJPROP_YSIZE, 25);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, name, OBJPROP_STATE, true);
    }

    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| 헬퍼 함수: 버튼 상태 시각화 토글 (CamelCase)                          |
//+------------------------------------------------------------------+
void toggleButtonState(string name, bool state) {
    ObjectSetInteger(0, name, OBJPROP_STATE, state);
    ChartRedraw();
}
//+------------------------------------------------------------------+