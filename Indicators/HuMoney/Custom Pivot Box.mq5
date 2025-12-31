//+------------------------------------------------------------------+
//|                                              CustomPivotBox.mq5  |
//|                                        Copyright 2025, p3pwp3p   |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, p3pwp3p"
#property link "https://www.mql5.com"
#property version "1.0"
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
input color BullBoxColor = clrLime;    // 상승 박스 색상 (O < C)
input color BearBoxColor = clrViolet;  // 하락 박스 색상 (O > C)
input int FontSize = 10;               // 텍스트 크기

//--- Global Variables (CamelCase)
bool showPivot = true;       // 피벗 보이기 상태
bool showHL = true;          // 박스 보이기 상태
string prefixName = "CPB_";  // 객체 이름 접두사
datetime lastCalculationTime = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    createButton("Btn_Pivot", "Pivot", 60, 20);
    createButton("Btn_HL", "HL", 60, 50);

    updateChart(true);

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
    // [최적화 1] 날짜 변경 혹은 최초 실행 시에만 전체 갱신
    bool needFullRedraw = (prev_calculated == 0);
    datetime currentBarTime = iTime(_Symbol, PERIOD_D1, 0);

    if (lastCalculationTime != currentBarTime) {
        needFullRedraw = true;
        lastCalculationTime = currentBarTime;
    }

    updateChart(needFullRedraw);
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
            } else
                updateChart(true);

            ChartRedraw();
        } else if (sparam == "Btn_HL") {
            showHL = !showHL;
            toggleButtonState("Btn_HL", showHL);

            if (!showHL) {
                ObjectsDeleteAll(0, prefixName + "Box_");
                ObjectsDeleteAll(0, prefixName + "Txt_");
            } else
                updateChart(true);

            ChartRedraw();
        }
    }
}

//+------------------------------------------------------------------+
//| 사용자 함수: 차트 업데이트 (CamelCase)                              |
//+------------------------------------------------------------------+
void updateChart(bool fullRedraw) {
    int maxLookBack = MathMax(LookBackDaysPivot, LookBackDaysRange);

    MqlRates rates[];
    ArraySetAsSeries(rates, true);

    // rates[i-1]을 참조해야 하므로 안전하게 +1개 더 복사합니다.
    int copied = CopyRates(_Symbol, PERIOD_D1, 0, maxLookBack + 2, rates);
    if (copied < 2) return;

    // [최적화 2] 전체 갱신이 아니면 오늘(0번 인덱스)만 루프 실행
    int loopLimit = fullRedraw ? (copied - 1) : 1;

    // 루프 범위 안전장치: copied-1 까지 돌면 rates[i+1] 참조시 오버플로우
    // 가능성 차단
    if (loopLimit > copied - 1) loopLimit = copied - 1;

    for (int i = 0; i < loopLimit; i++) {
        MqlRates today = rates[i];
        MqlRates yesterday = rates[i + 1];

        datetime tStart = today.time;
        datetime tEnd;

        // [수정된 부분: X축 종료 시간 계산 로직]
        if (i == 0) {
            // 오늘(현재 진행 중): 미래 데이터가 없으므로 기존 방식대로 하루치
            // 초를 더함
            tEnd = tStart + PeriodSeconds(PERIOD_D1);
        } else {
            // 과거: 다음 봉(i-1)의 시작 시간을 종료 시간으로 설정
            // 이렇게 하면 갭이나 주말 상관없이 다음 기간구분선에 정확히 붙음
            tEnd = rates[i - 1].time;
        }

        bool isToday = (i == 0);

        if (showPivot && i < LookBackDaysPivot) {
            drawPivots(tStart, tEnd, yesterday.high, yesterday.low,
                       yesterday.close, isToday);
        }

        if (!isToday && fullRedraw) deletePivotLabels(tStart);

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

    // [최적화] 각 함수는 내부적으로 생성 여부를 체크하여 속성을 차별 업데이트함
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

    string boxName = prefixName + "Box_" + suffix;

    // [최적화 3] ObjectCreate의 리턴값을 활용하여 '처음 생성 시에만' 정적 속성
    // 설정
    if (ObjectCreate(0, boxName, OBJ_RECTANGLE, 0, start, h, end, l)) {
        ObjectSetInteger(0, boxName, OBJPROP_FILL, false);
        ObjectSetInteger(0, boxName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, boxName, OBJPROP_BACK, false);
    }

    // 실시간 갱신 필요한 값들
    // [중요] Time2(end)가 rates[i-1].time으로 들어가므로 기간구분선에 정확히
    // 붙음
    ObjectSetDouble(0, boxName, OBJPROP_PRICE, 0, h);
    ObjectSetDouble(0, boxName, OBJPROP_PRICE, 1, l);
    ObjectSetInteger(0, boxName, OBJPROP_TIME, 0, start);
    ObjectSetInteger(0, boxName, OBJPROP_TIME, 1, end);
    ObjectSetInteger(0, boxName, OBJPROP_COLOR, drawColor);

    // 텍스트 그리기
    string textName = prefixName + "Txt_" + suffix;
    int rangePoints = (int)MathRound((h - l) / _Point);

    if (ObjectCreate(0, textName, OBJ_TEXT, 0, start, h)) {
        ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, FontSize);
        ObjectSetInteger(0, textName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
    }

    // 텍스트 값 업데이트
    ObjectSetString(0, textName, OBJPROP_TEXT,
                    " " + IntegerToString(rangePoints));
    ObjectSetDouble(0, textName, OBJPROP_PRICE, 0, h);
    ObjectSetInteger(0, textName, OBJPROP_TIME, start);
    ObjectSetInteger(0, textName, OBJPROP_COLOR, drawColor);
}

//+------------------------------------------------------------------+
//| 헬퍼 함수: 선 생성 (CamelCase) - 최적화 적용                          |
//+------------------------------------------------------------------+
void createLine(string name, datetime t1, datetime t2, double price, color clr,
                ENUM_LINE_STYLE style) {
    if (ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price)) {
        ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, LineWidth);
        ObjectSetInteger(0, name, OBJPROP_STYLE, style);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    }

    ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
    ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price);
    ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
    ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
}

//+------------------------------------------------------------------+
//| 헬퍼 함수: 라벨 생성 (CamelCase) - 최적화 적용                        |
//+------------------------------------------------------------------+
void createLabel(string name, datetime t, double price, string text,
                 color clr) {
    if (ObjectCreate(0, name, OBJ_TEXT, 0, t, price)) {
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    }

    ObjectSetString(0, name, OBJPROP_TEXT, "  " + text);
    ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
    ObjectSetInteger(0, name, OBJPROP_TIME, t);
}

//+------------------------------------------------------------------+
//| 헬퍼 함수: 특정 날짜의 피벗 라벨 삭제 (CamelCase)                     |
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
//| 헬퍼 함수: 버튼 생성 (CamelCase)                                    |
//+------------------------------------------------------------------+
void createButton(string name, string text, int x, int y) {
    if (ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0)) {
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_XSIZE, 50);
        ObjectSetInteger(0, name, OBJPROP_YSIZE, 25);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
        ObjectSetInteger(0, name, OBJPROP_STATE, true);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetString(0, name, OBJPROP_TEXT, text);
    }
}

//+------------------------------------------------------------------+
//| 헬퍼 함수: 버튼 상태 시각화 토글 (CamelCase)                          |
//+------------------------------------------------------------------+
void toggleButtonState(string name, bool state) {
    ObjectSetInteger(0, name, OBJPROP_STATE, state);
    ChartRedraw();
}
//+------------------------------------------------------------------+