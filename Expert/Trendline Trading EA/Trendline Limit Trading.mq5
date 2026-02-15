//+------------------------------------------------------------------+
//|                                        Trndline Limit Trading.mq5 |
//|                                  Copyright 2025, p3pwp3p  |
//|                                             https://github.com/hayan2 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, p3pwp3p"
#property link "https://github.com/hayan2"
#property version "1.00"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "Object Name Settings";     // 오브젝트 이름 설정 그룹;
input string InpBuyPrefix = "BUY_";     // 1. 매수 라인 접두사 (예: BUY_)
input string InpSellPrefix = "SELL_";   // 2. 매도 라인 접두사 (예: SELL_)
input string InpStopSuffix = "STOP";    // 3. 스탑 주문 식별자 (예: STOP)
input string InpLimitSuffix = "LIMIT";  // 4. 리밋 주문 식별자 (예: LIMIT)

input group "Trading Settings";    // 트레이딩 설정 그룹;
input double InpLotSize = 0.1;     // 1. 주문 랏(Lot) 크기
input int InpMagicNum = 20250129;  // 2. 매직 넘버
input int InpSlippage = 10;        // 3. 슬리피지 허용 범위 (Point)

input group "Risk Management";  // 리스크 관리 설정 그룹;
input int InpTakeProfit = 500;  // 1. 테이크 프로핏 (Point, 0=미사용)
input int InpStopLoss = 300;    // 2. 스탑 로스 (Point, 0=미사용)

input group "Trailing Stop Settings";  // 트레일링 스탑 설정 그룹;
input bool InpUseTSL = false;          // 1. 트레일링 스탑 사용 여부
input int InpTSLStart = 200;           // 2. 트레일링 시작 수익 (Point)
input int InpTSLStep = 50;             // 3. 트레일링 간격 (Point)

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    trade.SetExpertMagicNumber(InpMagicNum);
    trade.SetDeviationInPoints(InpSlippage);
    return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // 1. 추세선 및 오브젝트 스캔 후 주문 실행
    scanObjectsAndPlaceOrders();

    // 2. 트레일링 스탑 관리
    if (InpUseTSL) {
        manageTrailingStop();
    }
}

//+------------------------------------------------------------------+
//| Custom Functions                                                 |
//+------------------------------------------------------------------+

// 오브젝트를 스캔하고 추세선 가격을 계산하여 주문을 넣는 함수
void scanObjectsAndPlaceOrders() {
    int totalObjects = ObjectsTotal(0, -1, -1);

    for (int i = 0; i < totalObjects; i++) {
        string objName = ObjectName(0, i);

        // 이미 주문이 들어간 오브젝트인지 체크 (중복 진입 방지)
        if (isOrderExists(objName)) continue;

        // 오브젝트 타입 확인 (형변환 오류 방지를 위해 long 타입 사용)
        long objType = ObjectGetInteger(0, objName, OBJPROP_TYPE);

        // 추세선(Trendline)과 가로선(Horizontal Line) 모두 허용
        if (objType != OBJ_TREND && objType != OBJ_HLINE) continue;

        // 가격 계산 로직
        double price = 0.0;

        if (objType == OBJ_TREND) {
            // 추세선은 현재 시간 기준의 가격을 계산 (라인 ID 0)
            price = ObjectGetValueByTime(0, objName, TimeCurrent(), 0);
        } else {
            // 가로선은 고정 가격
            price = ObjectGetDouble(0, objName, OBJPROP_PRICE);
        }

        // 이름 분석 및 주문 분기 처리
        if (StringFind(objName, InpBuyPrefix) == 0)  // 매수(BUY_)로 시작
        {
            if (StringFind(objName, InpLimitSuffix) > 0)
                sendPendingOrder(ORDER_TYPE_BUY_LIMIT, price, objName);
            else if (StringFind(objName, InpStopSuffix) > 0)
                sendPendingOrder(ORDER_TYPE_BUY_STOP, price, objName);
        } else if (StringFind(objName, InpSellPrefix) ==
                   0)  // 매도(SELL_)로 시작
        {
            if (StringFind(objName, InpLimitSuffix) > 0)
                sendPendingOrder(ORDER_TYPE_SELL_LIMIT, price, objName);
            else if (StringFind(objName, InpStopSuffix) > 0)
                sendPendingOrder(ORDER_TYPE_SELL_STOP, price, objName);
        }
    }
}

// 펜딩 주문 전송 함수
void sendPendingOrder(ENUM_ORDER_TYPE type, double price, string comment) {
    double sl = 0;
    double tp = 0;
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // 가격 정규화
    price = NormalizeDouble(price, _Digits);

    // SL/TP 계산
    if (type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_BUY_STOP) {
        if (InpStopLoss > 0) sl = price - (InpStopLoss * point);
        if (InpTakeProfit > 0) tp = price + (InpTakeProfit * point);
    } else if (type == ORDER_TYPE_SELL_LIMIT || type == ORDER_TYPE_SELL_STOP) {
        if (InpStopLoss > 0) sl = price + (InpStopLoss * point);
        if (InpTakeProfit > 0) tp = price - (InpTakeProfit * point);
    }

    // 정규화
    sl = NormalizeDouble(sl, _Digits);
    tp = NormalizeDouble(tp, _Digits);

    // *** 수정됨: _Symbol 인자 추가 ***
    // OrderOpen(심볼, 주문타입, 랏, 가격, SL, TP, 유효기간, 만료일, 주석)
    if (!trade.OrderOpen(_Symbol, type, InpLotSize, price, sl, tp,
                         ORDER_TIME_GTC, 0, comment)) {
        // 주문 실패 시 로그 출력
        Print("OrderOpen Error: ", GetLastError());
    }
}

// 중복 주문 확인 함수
bool isOrderExists(string commentKey) {
    // 대기 주문 확인
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if (OrderGetInteger(ORDER_MAGIC) == InpMagicNum) {
            if (OrderGetString(ORDER_COMMENT) == commentKey) return true;
        }
    }
    // 포지션 확인
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if (PositionGetInteger(POSITION_MAGIC) == InpMagicNum) {
            if (PositionGetString(POSITION_COMMENT) == commentKey) return true;
        }
    }
    return false;
}

// 트레일링 스탑 함수
void manageTrailingStop() {
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if (PositionGetInteger(POSITION_MAGIC) != InpMagicNum) continue;
        if (PositionGetSymbol(i) != _Symbol) continue;

        ENUM_POSITION_TYPE type =
            (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentTP = PositionGetDouble(POSITION_TP);

        if (type == POSITION_TYPE_BUY) {
            if (currentPrice - openPrice > InpTSLStart * point) {
                double newSL = currentPrice - (InpTSLStep * point);
                newSL = NormalizeDouble(newSL, _Digits);
                if (newSL > currentSL && newSL < currentPrice)
                    trade.PositionModify(ticket, newSL, currentTP);
            }
        } else if (type == POSITION_TYPE_SELL) {
            if (openPrice - currentPrice > InpTSLStart * point) {
                double newSL = currentPrice + (InpTSLStep * point);
                newSL = NormalizeDouble(newSL, _Digits);
                if ((newSL < currentSL || currentSL == 0) &&
                    newSL > currentPrice)
                    trade.PositionModify(ticket, newSL, currentTP);
            }
        }
    }
}
//+------------------------------------------------------------------+