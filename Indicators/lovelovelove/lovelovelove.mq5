//+------------------------------------------------------------------+
//|                                        프로그램 제목.mq5  |
//|                                  Copyright 2025, p3pwp3p  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, p3pwp3p"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

input group "Hoga Panel Settings";
input int InputGridRows = 10;       // 위아래 보여줄 호가 틱 개수
input double InputDefaultLot = 0.1; // 클릭 시 기본 주문 랏수
input int InputPanelX = 50;         // 패널 X 좌표
input int InputPanelY = 50;         // 패널 Y 좌표

CTrade TradeController;

// 차트 초기화 함수
int OnInit() {
    createHogaPanel();
    EventSetMillisecondTimer(500); // 0.5초마다 틱 갱신 감지용 타이머
    return(INIT_SUCCEEDED);
}

// 종료 함수 (차트에서 EA 제거 시 버튼 싹 다 지우기)
void OnDeinit(const int reason) {
    EventKillTimer();
    ObjectsDeleteAll(0, "Hoga_"); 
}

// 타이머 함수 (가격 텍스트 갱신용)
void OnTimer() {
    updatePriceLevels();
}

// 차트 이벤트 감지 (가장 핵심: 마우스 클릭)
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
    // 사용자가 차트의 특정 오브젝트(버튼)를 클릭했을 때
    if(id == CHARTEVENT_OBJECT_CLICK) {
        handleGridClick(sparam);
    }
}

//+------------------------------------------------------------------+
//| 사용자 지정 함수 영역 (카멜 케이스 적용)
//+------------------------------------------------------------------+

// 1. 호가창 UI 뼈대 생성
void createHogaPanel() {
    int buttonWidth = 80;
    int buttonHeight = 20;

    // 현재가 위아래로 InputGridRows 만큼 반복하며 셀(버튼) 생성
    for(int i = 0; i < InputGridRows * 2 + 1; i++) {
        int currentY = InputPanelY + (i * buttonHeight);

        // 매도 버튼 (왼쪽)
        string sellBtnName = "Hoga_Sell_" + IntegerToString(i);
        ObjectCreate(0, sellBtnName, OBJ_BUTTON, 0, 0, 0);
        ObjectSetInteger(0, sellBtnName, OBJPROP_XDISTANCE, InputPanelX);
        ObjectSetInteger(0, sellBtnName, OBJPROP_YDISTANCE, currentY);
        ObjectSetInteger(0, sellBtnName, OBJPROP_XSIZE, buttonWidth);
        ObjectSetInteger(0, sellBtnName, OBJPROP_YSIZE, buttonHeight);
        ObjectSetString(0, sellBtnName, OBJPROP_TEXT, "Sell Zone");
        ObjectSetInteger(0, sellBtnName, OBJPROP_BGCOLOR, clrLightBlue);

        // 가격 표시 라벨 (중앙)
        string priceLblName = "Hoga_Price_" + IntegerToString(i);
        ObjectCreate(0, priceLblName, OBJ_BUTTON, 0, 0, 0); // 배경색을 위해 버튼으로 임시 생성
        ObjectSetInteger(0, priceLblName, OBJPROP_XDISTANCE, InputPanelX + buttonWidth);
        ObjectSetInteger(0, priceLblName, OBJPROP_YDISTANCE, currentY);
        ObjectSetInteger(0, priceLblName, OBJPROP_XSIZE, buttonWidth);
        ObjectSetInteger(0, priceLblName, OBJPROP_YSIZE, buttonHeight);
        ObjectSetString(0, priceLblName, OBJPROP_TEXT, "Price");
        ObjectSetInteger(0, priceLblName, OBJPROP_BGCOLOR, clrWhite);
        ObjectSetInteger(0, priceLblName, OBJPROP_STATE, false); // 눌리지 않게

        // 매수 버튼 (오른쪽)
        string buyBtnName = "Hoga_Buy_" + IntegerToString(i);
        ObjectCreate(0, buyBtnName, OBJ_BUTTON, 0, 0, 0);
        ObjectSetInteger(0, buyBtnName, OBJPROP_XDISTANCE, InputPanelX + (buttonWidth * 2));
        ObjectSetInteger(0, buyBtnName, OBJPROP_YDISTANCE, currentY);
        ObjectSetInteger(0, buyBtnName, OBJPROP_XSIZE, buttonWidth);
        ObjectSetInteger(0, buyBtnName, OBJPROP_YSIZE, buttonHeight);
        ObjectSetString(0, buyBtnName, OBJPROP_TEXT, "Buy Zone");
        ObjectSetInteger(0, buyBtnName, OBJPROP_BGCOLOR, clrPink);
    }
    ChartRedraw(0);
}

// 2. 실시간 가격 업데이트 로직 (차후 구현)
void updatePriceLevels() {
    // 여기에 현재가(SymbolInfoDouble)를 가져와서 
    // Hoga_Price_ 버튼들의 텍스트를 실시간 가격으로 바꿔주는 로직이 들어갑니다.
}

// 3. 클릭된 버튼 처리 로직
void handleGridClick(string clickedObjectName) {
    // 클릭된 버튼을 원래 상태(튀어나온 상태)로 되돌림
    ObjectSetInteger(0, clickedObjectName, OBJPROP_STATE, false);

    // 이름에 "Sell"이 포함되어 있으면 매도 로직 실행
    if(StringFind(clickedObjectName, "Hoga_Sell_") >= 0) {
        Print("매도 존 클릭됨! 대상 버튼: ", clickedObjectName);
        // 여기서 해당 버튼 옆의 가격을 읽어와 TradeController.SellLimit() 실행
    }
    
    // 이름에 "Buy"가 포함되어 있으면 매수 로직 실행
    else if(StringFind(clickedObjectName, "Hoga_Buy_") >= 0) {
        Print("매수 존 클릭됨! 대상 버튼: ", clickedObjectName);
        // 여기서 해당 버튼 옆의 가격을 읽어와 TradeController.BuyLimit() 실행
    }
}