//+------------------------------------------------------------------+
//|                                        프로그램 제목.mq5  |
//|                                  Copyright 2025, p3pwp3p  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, p3pwp3p"
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

//--- Input Variables (PascalCase)
input group "Visual Settings";
input int LookBackCount = 50;          // 과거 몇 개의 봉을 보여줄지 설정
input color HighMarkerColor = clrRed;  // 고점 마커 색상
input int ArrowCode = 233;             // 화살표 코드 (Wingdings)

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    // [중요] 차트에 적용하자마자 과거 데이터를 기반으로 먼저 한 번 그립니다.
    // 이 부분이 없으면 다음 틱이 들어올 때까지 화면이 비어있게 됩니다.
    drawObjects();

    // 강제로 화면 갱신
    ChartRedraw();

    return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // EA가 제거될 때 생성한 오브젝트들을 모두 지웁니다.
    // 접두사("MyEA_Mark_")가 있는 것만 지워 사용자의 다른 작도 도구는
    // 보호합니다.
    ObjectsDeleteAll(0, "MyEA_Mark_");
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // 실시간으로 틱이 들어올 때마다 최신 상태를 반영해 그립니다.
    drawObjects();
}

//+------------------------------------------------------------------+
//| 사용자 정의 함수: 차트에 오브젝트 그리기 (CamelCase)                 |
//+------------------------------------------------------------------+
void drawObjects() {
    // 최근 LookBackCount 만큼의 봉을 순회하며 고점에 화살표를 찍습니다.
    for (int i = 1; i <= LookBackCount; i++) {
        // 각 봉마다 고유한 이름을 생성합니다 (시간값 활용)
        string objName = "MyEA_Mark_" + IntegerToString(Time[i]);

        // [최적화] 이미 해당 위치에 오브젝트가 있다면 다시 그리지 않고
        // 건너뜁니다.
        if (ObjectFind(0, objName) >= 0) continue;

        // 오브젝트가 없다면 생성 (화살표)
        if (ObjectCreate(0, objName, OBJ_ARROW, 0, Time[i], High[i])) {
            ObjectSetInteger(0, objName, OBJPROP_ARROWCODE,
                             ArrowCode);  // 화살표 모양
            ObjectSetInteger(0, objName, OBJPROP_COLOR,
                             HighMarkerColor);  // 색상
            ObjectSetInteger(0, objName, OBJPROP_ANCHOR,
                             ANCHOR_BOTTOM);                 // 앵커 위치
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);  // 크기

            // 툴팁 설정 (마우스 오버 시 정보 표시)
            ObjectSetString(0, objName, OBJPROP_TOOLTIP,
                            "High: " + DoubleToString(High[i], _Digits));
        }
    }

    // 모든 작업 후 화면 갱신 요청
    ChartRedraw();
}
//+------------------------------------------------------------------+