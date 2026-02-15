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
input group "Object Name Settings";
input string InpBuyPrefix = "BUY_";    // 매수 라인 접두사
input string InpSellPrefix = "SELL_";  // 매도 라인 접두사
// (참고: 시장가 진입으로 바뀌었으므로 STOP/LIMIT 접미사는 사용하지 않음)

input group "Trading Settings";
input double InpLotSize = 0.1;     // 주문 랏(Lot)
input int InpMagicNum = 20250129;  // 매직 넘버
input int InpSlippage = 10;        // 슬리피지

input group "Risk Management";
input int InpTakeProfit = 500;  // 테이크 프로핏 (Point)
input int InpStopLoss = 300;    // 스탑 로스 (Point)

input group "Trailing Stop Settings";
input bool InpUseTSL = false;  // 트레일링 스탑 사용 여부
input int InpTSLStart = 200;   // 시작 수익
input int InpTSLStep = 50;     // 간격

//+------------------------------------------------------------------+
//| Global Objects                                                   |
//+------------------------------------------------------------------+
CTrade trade;

int OnInit() {
    trade.SetExpertMagicNumber(InpMagicNum);
    trade.SetDeviationInPoints(InpSlippage);
    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {}

void OnTick() {
    // 1. 라인 터치 감시 및 주문 실행
    checkLinesAndTrade();

    // 2. 트레일링 스탑
    if (InpUseTSL) manageTrailingStop();
}

//+------------------------------------------------------------------+
//| Custom Functions                                                 |
//+------------------------------------------------------------------+

// 라인을 감시하다가 터치 시 시장가 주문 실행
void checkLinesAndTrade() {
    int total = ObjectsTotal(0, -1, -1);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // 오브젝트 루프
    for (int i = total - 1; i >= 0; i--) {
        string name = ObjectName(0, i);

        // *** [핵심 수정] 이름에 "_DONE"이 포함되어 있으면 무조건 건너뜀 ***
        if (StringFind(name, "_DONE") != -1) continue;

        // 오브젝트 타입 확인 (추세선, 가로선)
        long type = ObjectGetInteger(0, name, OBJPROP_TYPE);
        if (type != OBJ_TREND && type != OBJ_HLINE) continue;

        // 라인의 현재 가격 계산
        double linePrice = 0.0;
        if (type == OBJ_TREND)
            linePrice = ObjectGetValueByTime(0, name, TimeCurrent(), 0);
        else
            linePrice = ObjectGetDouble(0, name, OBJPROP_PRICE);

        bool isTraded = false;

        // --- 매수 (BUY) 감시 로직 ---
        // 이름이 BUY_로 시작하는지 확인
        if (StringFind(name, InpBuyPrefix) == 0) {
            // 5포인트 내 접근 시 진입
            if (MathAbs(ask - linePrice) <= 5 * point) {
                // 주문 성공 시 true 반환
                if (openMarketOrder(ORDER_TYPE_BUY, ask, name)) isTraded = true;
            }
        }
        // --- 매도 (SELL) 감시 로직 ---
        // 이름이 SELL_로 시작하는지 확인
        else if (StringFind(name, InpSellPrefix) == 0) {
            if (MathAbs(bid - linePrice) <= 5 * point) {
                // 주문 성공 시 true 반환
                if (openMarketOrder(ORDER_TYPE_SELL, bid, name))
                    isTraded = true;
            }
        }

        // 거래가 체결되었다면 선의 이름을 바꾸고 색을 변경
        if (isTraded) {
            string newName = name + "_DONE";  // 이름 뒤에 _DONE 붙임

            // 1. 이름 변경
            if (ObjectSetString(0, name, OBJPROP_NAME, newName)) {
                // 2. 색상 변경 (회색으로)
                ObjectSetInteger(0, newName, OBJPROP_COLOR, clrGray);

                Print("Line processed completely: ", name, " -> ", newName);
            }
        }
    }
}

// 시장가 주문 전송 함수 (성공 여부 bool 반환)
bool openMarketOrder(ENUM_ORDER_TYPE type, double price, string comment) {
    double sl = 0, tp = 0;
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // SL/TP 단순 계산
    if (type == ORDER_TYPE_BUY) {
        if (InpStopLoss > 0) sl = price - (InpStopLoss * point);
        if (InpTakeProfit > 0) tp = price + (InpTakeProfit * point);

        if (trade.Buy(InpLotSize, _Symbol, price, sl, tp, comment)) return true;
    } else if (type == ORDER_TYPE_SELL) {
        if (InpStopLoss > 0) sl = price + (InpStopLoss * point);
        if (InpTakeProfit > 0) tp = price - (InpTakeProfit * point);

        if (trade.Sell(InpLotSize, _Symbol, price, sl, tp, comment))
            return true;
    }

    return false;
}

// 트레일링 스탑
void manageTrailingStop() {
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if (PositionGetInteger(POSITION_MAGIC) != InpMagicNum) continue;

        if (PositionGetSymbol(i) == _Symbol) {
            long type = PositionGetInteger(POSITION_TYPE);
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
}
//+------------------------------------------------------------------+