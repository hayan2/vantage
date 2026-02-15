#property strict

input group "Risk Settings";
input double RiskPercent = 1.2;
input int RR = 2;
input int MagicNumber = 2026;
input int MaxTradesDay = 1;

int ema20H1;
int ema50H1;
int ema200H1;
int ema20M15;
int ema50M15;
int rsiM5;
int macdM5;
int atrM15;

datetime lastTradeDay = 0;

int OnInit() {
    ema20H1 = iMA(_Symbol, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE);
    ema50H1 = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
    ema200H1 = iMA(_Symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);

    ema20M15 = iMA(_Symbol, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE);
    ema50M15 = iMA(_Symbol, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE);

    rsiM5 = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
    macdM5 = iMACD(_Symbol, PERIOD_M5, 12, 26, 9, PRICE_CLOSE);
    atrM15 = iATR(_Symbol, PERIOD_M15, 14);

    if (ema20H1 == INVALID_HANDLE || ema50H1 == INVALID_HANDLE ||
        ema200H1 == INVALID_HANDLE || ema20M15 == INVALID_HANDLE ||
        ema50M15 == INVALID_HANDLE || rsiM5 == INVALID_HANDLE ||
        macdM5 == INVALID_HANDLE || atrM15 == INVALID_HANDLE) {
        return INIT_FAILED;
    }

    return INIT_SUCCEEDED;
}

bool isTradeSession() {
    MqlDateTime gmtTime;
    TimeGMT(gmtTime);
    return (gmtTime.hour >= 13 && gmtTime.hour < 16);
}

bool isNewsTime() {
    MqlDateTime gmtTime;
    TimeGMT(gmtTime);

    if (gmtTime.hour == 13 && gmtTime.min >= 30) return true;
    if (gmtTime.hour == 14 && gmtTime.min < 1) return true;

    return false;
}

bool canTradeToday() {
    datetime today = iTime(_Symbol, PERIOD_D1, 0);
    if (today == lastTradeDay) return false;
    return true;
}

ENUM_ORDER_TYPE_FILLING getFillingMode() {
    long filling = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);

    if ((filling & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
    if ((filling & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;

    return ORDER_FILLING_RETURN;
}

void OnTick() {
    if (!isTradeSession()) return;
    if (isNewsTime()) return;
    if (PositionSelect(_Symbol)) return;
    if (!canTradeToday()) return;

    double ema20h1Val[], ema50h1Val[], ema200h1Val[];
    double ema20m15Val[], ema50m15Val[];
    double rsiVal[], macdMainVal[], macdSignalVal[], atrVal[];

    ArraySetAsSeries(ema20h1Val, true);
    ArraySetAsSeries(ema50h1Val, true);
    ArraySetAsSeries(ema200h1Val, true);
    ArraySetAsSeries(ema20m15Val, true);
    ArraySetAsSeries(ema50m15Val, true);
    ArraySetAsSeries(rsiVal, true);
    ArraySetAsSeries(macdMainVal, true);
    ArraySetAsSeries(macdSignalVal, true);
    ArraySetAsSeries(atrVal, true);

    if (CopyBuffer(ema20H1, 0, 0, 1, ema20h1Val) <= 0) return;
    if (CopyBuffer(ema50H1, 0, 0, 1, ema50h1Val) <= 0) return;
    if (CopyBuffer(ema200H1, 0, 0, 1, ema200h1Val) <= 0) return;
    if (CopyBuffer(ema20M15, 0, 0, 1, ema20m15Val) <= 0) return;
    if (CopyBuffer(ema50M15, 0, 0, 1, ema50m15Val) <= 0) return;
    if (CopyBuffer(rsiM5, 0, 0, 1, rsiVal) <= 0) return;
    if (CopyBuffer(macdM5, 0, 0, 1, macdMainVal) <= 0) return;
    if (CopyBuffer(macdM5, 1, 0, 1, macdSignalVal) <= 0) return;
    if (CopyBuffer(atrM15, 0, 0, 1, atrVal) <= 0) return;

    double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    if (ema20h1Val[0] > ema50h1Val[0] && ema50h1Val[0] > ema200h1Val[0]) {
        if (currentBid < ema20m15Val[0] && currentBid > ema50m15Val[0]) {
            if (rsiVal[0] > 45 && macdMainVal[0] > macdSignalVal[0]) {
                openTrade(ORDER_TYPE_BUY, atrVal[0]);
            }
        }
    }

    if (ema20h1Val[0] < ema50h1Val[0] && ema50h1Val[0] < ema200h1Val[0]) {
        if (currentAsk > ema20m15Val[0] && currentAsk < ema50m15Val[0]) {
            if (rsiVal[0] < 55 && macdMainVal[0] < macdSignalVal[0]) {
                openTrade(ORDER_TYPE_SELL, atrVal[0]);
            }
        }
    }
}

void openTrade(ENUM_ORDER_TYPE type, double atrValue) {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskUSD = balance * RiskPercent / 100.0;

    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    if (tickValue == 0 || tickSize == 0) return;

    double slDist = atrValue * 1.2;
    double lot = riskUSD / (slDist / tickSize * tickValue);

    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    lot = MathMax(minLot, MathMin(maxLot, lot));
    if (step > 0) lot = MathFloor(lot / step) * step;

    double price = (type == ORDER_TYPE_BUY)
                       ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = (type == ORDER_TYPE_BUY) ? price - slDist : price + slDist;
    double tp = (type == ORDER_TYPE_BUY) ? price + (slDist * RR)
                                         : price - (slDist * RR);

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
    req.type_filling = getFillingMode();

    if (OrderSend(req, res)) {
        if (res.retcode == TRADE_RETCODE_DONE) {
            lastTradeDay = iTime(_Symbol, PERIOD_D1, 0);
        }
    }
}