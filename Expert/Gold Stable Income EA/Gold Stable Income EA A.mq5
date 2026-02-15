//+------------------------------------------------------------------+
//| GOLD_Stable_Income_Vantage.mq5                                   |
//| Target: $1000 balance -> ~$80/month                              |
//| Broker: Vantage | Leverage: 1:500                                |
//+------------------------------------------------------------------+
#property strict

input group "Risk Settings";
input double RiskPercent = 0.8;  // % risk per trade
input double RR = 2.0;
input int MagicNumber = 202601;

int ema50H1, ema200H1;
int ema20M15, ema50M15;
int rsiM5, macdM5, atrM15;

datetime lastTradeDay = 0;

//+------------------------------------------------------------------+
int OnInit() {
    ema50H1 = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
    ema200H1 = iMA(_Symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);

    ema20M15 = iMA(_Symbol, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE);
    ema50M15 = iMA(_Symbol, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE);

    rsiM5 = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
    macdM5 = iMACD(_Symbol, PERIOD_M5, 12, 26, 9, PRICE_CLOSE);
    atrM15 = iATR(_Symbol, PERIOD_M15, 14);

    if (ema50H1 == INVALID_HANDLE || ema200H1 == INVALID_HANDLE ||
        ema20M15 == INVALID_HANDLE || ema50M15 == INVALID_HANDLE ||
        rsiM5 == INVALID_HANDLE || macdM5 == INVALID_HANDLE ||
        atrM15 == INVALID_HANDLE)
        return INIT_FAILED;

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
bool IsTradeSession() {
    MqlDateTime t;
    TimeGMT(t);
    return (t.hour >= 13 && t.hour < 16);  // London-NY overlap
}

bool IsNewsTime() {
    MqlDateTime t;
    TimeGMT(t);
    if (t.hour == 13 && t.min >= 30) return true;
    if (t.hour == 14 && t.min < 1) return true;
    return false;
}

bool CanTradeToday() {
    datetime today = iTime(_Symbol, PERIOD_D1, 0);
    return (today != lastTradeDay);
}

//+------------------------------------------------------------------+
void OnTick() {
    if (!IsTradeSession()) return;
    if (IsNewsTime()) return;
    if (PositionSelect(_Symbol)) return;
    if (!CanTradeToday()) return;

    double ema50h1[], ema200h1[];
    double ema20m15[], ema50m15[];
    double rsi[], macdMain[], macdSignal[], atr[];

    ArraySetAsSeries(ema50h1, true);
    ArraySetAsSeries(ema200h1, true);
    ArraySetAsSeries(ema20m15, true);
    ArraySetAsSeries(ema50m15, true);
    ArraySetAsSeries(rsi, true);
    ArraySetAsSeries(macdMain, true);
    ArraySetAsSeries(macdSignal, true);
    ArraySetAsSeries(atr, true);

    if (CopyBuffer(ema50H1, 0, 0, 1, ema50h1) <= 0) return;
    if (CopyBuffer(ema200H1, 0, 0, 1, ema200h1) <= 0) return;
    if (CopyBuffer(ema20M15, 0, 0, 1, ema20m15) <= 0) return;
    if (CopyBuffer(ema50M15, 0, 0, 1, ema50m15) <= 0) return;
    if (CopyBuffer(rsiM5, 0, 0, 1, rsi) <= 0) return;
    if (CopyBuffer(macdM5, 0, 0, 1, macdMain) <= 0) return;
    if (CopyBuffer(macdM5, 1, 0, 1, macdSignal) <= 0) return;
    if (CopyBuffer(atrM15, 0, 0, 1, atr) <= 0) return;

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    // BUY
    if (ema50h1[0] > ema200h1[0])
        if (bid < ema20m15[0] && bid > ema50m15[0])
            if (rsi[0] >= 45 && rsi[0] <= 55 && macdMain[0] > macdSignal[0])
                OpenTrade(ORDER_TYPE_BUY, atr[0]);

    // SELL
    if (ema50h1[0] < ema200h1[0])
        if (ask > ema20m15[0] && ask < ema50m15[0])
            if (rsi[0] <= 55 && rsi[0] >= 45 && macdMain[0] < macdSignal[0])
                OpenTrade(ORDER_TYPE_SELL, atr[0]);
}
//+------------------------------------------------------------------+
//| OpenTrade 함수: FillingMode 자동 감지 로직 추가됨                      |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE type, double atr) {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskUSD = balance * RiskPercent / 100.0;

    double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if (tickVal <= 0 || tickSize <= 0) return;

    double slDist = atr * 1.2;
    double lot = riskUSD / ((slDist / tickSize) * tickVal);

    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    lot = MathMax(minLot, MathMin(maxLot, lot));
    lot = MathFloor(lot / step) * step;

    double price = (type == ORDER_TYPE_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);

    double sl = (type == ORDER_TYPE_BUY) ? price - slDist : price + slDist;
    double tp =
        (type == ORDER_TYPE_BUY) ? price + slDist * RR : price - slDist * RR;

    MqlTradeRequest req = {};
    MqlTradeResult res = {};

    req.action = TRADE_ACTION_DEAL;
    req.symbol = _Symbol;
    req.volume = lot;
    req.type = type;
    req.price = price;
    req.sl = sl;
    req.tp = tp;
    req.magic = MagicNumber;
    req.deviation = 20;

    // --- Filling Mode 자동 설정 로직 시작 ---
    uint fillingMode = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    
    if((fillingMode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) {
        req.type_filling = ORDER_FILLING_FOK; // Fill or Kill
    }
    else if((fillingMode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) {
        req.type_filling = ORDER_FILLING_IOC; // Immediate or Cancel
    }
    else {
        req.type_filling = ORDER_FILLING_RETURN; // Return
    }
    // --- Filling Mode 자동 설정 로직 끝 ---

    if (OrderSend(req, res)) {
        if (res.retcode == TRADE_RETCODE_DONE) {
            lastTradeDay = iTime(_Symbol, PERIOD_D1, 0);
        }
    } else {
        // 오류 확인을 위한 로그 출력 (선택 사항)
        Print("OrderSend Error: ", GetLastError(), ", Retcode: ", res.retcode);
    }
}