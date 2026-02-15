//+------------------------------------------------------------------+
//|                                            AIO Calculator.mq5    |
//|                                       Copyright 2026, p3pwp3p    |
//|                                          https://www.mql5.com    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, p3pwp3p"
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

//+------------------------------------------------------------------+
//| Enums                                                            |
//+------------------------------------------------------------------+
enum ENUM_UNIT_MODE {
    UNIT_POINT,  // Points (최소 단위)
    UNIT_PIP     // Pips (표준 10 Points)
};

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "UI Style";
input int UI_X = 50;                      // 패널 가로 위치
input int UI_Y = 50;                      // 패널 세로 위치
input color Color_BG = clrDarkSlateGray;  // 배경색
input color Color_Header = clrGold;       // 헤더 글씨
input color Color_Text = clrWhite;        // 일반 글씨
input color Color_Info = clrAqua;         // 정보/가치 글씨 (통일됨)
input color Color_InputBG = clrWhite;     // 입력창 배경
input color Color_InputText = clrBlack;   // 입력창 글씨
input color Color_Risk = clrTomato;       // 위험 표시

input group "Defaults";
input ENUM_UNIT_MODE UnitMode = UNIT_POINT;  // 단위 모드
input double Default_Lot = 1.0;              // 기본 랏수
input double Default_LossPt = 100.0;         // 기본 손절 포인트

//+------------------------------------------------------------------+
//| Class: Calculator Engine (계산 로직)                               |
//+------------------------------------------------------------------+
class CalculatorEngine {
   private:
    double pointSize, tickValue, tickSize, contractSize;
    string symbol;
    string baseCurrency;     // 기준 통화
    string accountCurrency;  // 내 계좌 통화
    ENUM_SYMBOL_CALC_MODE calcMode;

    double getExchangeRate(string from, string to) {
        if (from == to) return 1.0;
        string pair = from + to;
        if (SymbolInfoDouble(pair, SYMBOL_ASK) > 0)
            return SymbolInfoDouble(pair, SYMBOL_ASK);
        pair = to + from;
        double bid = SymbolInfoDouble(pair, SYMBOL_BID);
        if (bid > 0) return 1.0 / bid;
        return 0.0;
    }

   public:
    CalculatorEngine() {}

    void refresh() {
        symbol = _Symbol;
        pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
        tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
        contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);

        baseCurrency = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
        accountCurrency = AccountInfoString(ACCOUNT_CURRENCY);
        calcMode = (ENUM_SYMBOL_CALC_MODE)SymbolInfoInteger(
            symbol, SYMBOL_TRADE_CALC_MODE);
    }

    double getMultiplier() { return (UnitMode == UNIT_PIP) ? 10.0 : 1.0; }

    double getPipValue(double lots) {
        if (tickSize == 0) return 0;
        double val = tickValue * (pointSize / tickSize) * getMultiplier();
        return val * lots;
    }

    double getMargin(double lots) {
        double margin = 0.0;
        double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
        if (!OrderCalcMargin(ORDER_TYPE_BUY, symbol, lots, price, margin))
            return 0.0;
        return margin;
    }

    double getBalance() { return AccountInfoDouble(ACCOUNT_BALANCE); }
    string getSymbolName() { return symbol; }
    string getAccountCurrency() { return accountCurrency; }

    // [New] 입력된 랏수에 비례하여 실제 계약 크기 표시 (예: 0.1 Lot = 10,000
    // GBP)
    string getContractDesc(double lots) {
        double totalSize = contractSize * lots;
        // 소수점 깔끔하게 처리 (정수면 .0 없애기)
        string sSize = DoubleToString(totalSize, 2);
        if (StringSubstr(sSize, StringLen(sSize) - 2) == "00")
            sSize = DoubleToString(totalSize, 0);

        string sLot = DoubleToString(lots, 2);
        if (StringSubstr(sLot, StringLen(sLot) - 2) == "00")
            sLot = DoubleToString(lots, 0);

        return StringFormat("%s Lot = %s %s", sLot, sSize, baseCurrency);
    }

    // [New] 내 계좌 환산 가치
    double getAccountNominalValue(double lots) {
        double rate = getExchangeRate(baseCurrency, accountCurrency);
        if (rate <= 0) return 0.0;
        return contractSize * lots * rate;
    }
};

//+------------------------------------------------------------------+
//| Class: Interactive UI (입력 및 표시)                               |
//+------------------------------------------------------------------+
class InteractiveUI {
   private:
    string prefix;
    int x, y;
    int w, h;

    void CreateObj(string name, ENUM_OBJECT type) {
        if (ObjectFind(0, name) < 0) ObjectCreate(0, name, type, 0, 0, 0);
    }

    void DrawLabel(string name, int dx, int dy, string text, int size,
                   color clr, bool bold = false) {
        string obj = prefix + name;
        CreateObj(obj, OBJ_LABEL);
        ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x + dx);
        ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y + dy);
        ObjectSetString(0, obj, OBJPROP_TEXT, text);
        ObjectSetInteger(0, obj, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, size);
        ObjectSetString(0, obj, OBJPROP_FONT, bold ? "Arial Black" : "Arial");
    }

    void DrawEdit(string name, int dx, int dy, int width, string defaultVal) {
        string obj = prefix + "EDIT_" + name;
        if (ObjectFind(0, obj) < 0) {
            CreateObj(obj, OBJ_EDIT);
            ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x + dx);
            ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y + dy);
            ObjectSetInteger(0, obj, OBJPROP_XSIZE, width);
            ObjectSetInteger(0, obj, OBJPROP_YSIZE, 20);
            ObjectSetInteger(0, obj, OBJPROP_BGCOLOR, Color_InputBG);
            ObjectSetInteger(0, obj, OBJPROP_COLOR, Color_InputText);
            ObjectSetInteger(0, obj, OBJPROP_BORDER_COLOR, clrGray);
            ObjectSetInteger(0, obj, OBJPROP_ALIGN, ALIGN_CENTER);
            ObjectSetString(0, obj, OBJPROP_TEXT, defaultVal);
            ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, 10);
        }
    }

    void DrawPanel() {
        string obj = prefix + "BG";
        CreateObj(obj, OBJ_RECTANGLE_LABEL);
        ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, obj, OBJPROP_XSIZE, w);
        ObjectSetInteger(0, obj, OBJPROP_YSIZE, h);
        ObjectSetInteger(0, obj, OBJPROP_BGCOLOR, Color_BG);
        ObjectSetInteger(0, obj, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    }

   public:
    InteractiveUI() {
        prefix = "SmartCalc_";
        w = 260;
        h = 290;
    }

    void Init() {
        x = UI_X;
        y = UI_Y;
        DrawPanel();

        // Header
        DrawLabel("Title", 10, 10, "", 11, Color_Header, true);

        // [Contract Info]
        int curY = 35;
        DrawLabel("Info_Title", 15, curY, "[ Contract Info ]", 8, clrSilver);

        // 1. Contract Size (예: 0.1 Lot = 10,000 GBP)
        curY += 18;
        DrawLabel("Info_Desc", 15, curY, "? Lot = ???", 9, Color_Info, true);

        // 2. Account Value (예: Value: USD 13,000)
        // [수정] 폰트, 색상, 굵기를 위 Info_Desc와 완벽히 통일
        curY += 15;
        DrawLabel("Info_Val", 15, curY, "Value: ???", 9, Color_Info, true);

        // --- INPUT SECTION ---
        curY += 25;
        DrawLabel("Div1", 15, curY, "------------------------------------", 8,
                  clrDimGray);
        curY += 15;

        DrawLabel("Lbl_Lot", 15, curY + 2, "Lot Size:", 10, Color_Text);
        DrawEdit("LOT", 100, curY, 60, DoubleToString(Default_Lot, 2));
        DrawLabel("Lbl_Unit", 170, curY + 2, "(Lots)", 8, clrGray);

        curY += 30;
        DrawLabel("Lbl_Loss", 15, curY + 2, "Stop Loss:", 10, Color_Text);
        DrawEdit("LOSS", 100, curY, 60, DoubleToString(Default_LossPt, 0));
        DrawLabel("Lbl_Pt", 170, curY + 2,
                  UnitMode == UNIT_POINT ? "(Pts)" : "(Pips)", 8, clrGray);

        // --- OUTPUT SECTION ---
        curY += 25;
        DrawLabel("Div2", 15, curY, "------------------------------------", 8,
                  clrDimGray);
        curY += 15;

        DrawLabel("Res_RiskTxt", 15, curY, "Est. Risk:", 10, Color_Text);
        DrawLabel("Res_RiskVal", 100, curY, "$ 0.00", 10, Color_Risk, true);

        curY += 25;
        DrawLabel("Res_MrgTxt", 15, curY, "Req Margin:", 10, Color_Text);
        DrawLabel("Res_MrgVal", 100, curY, "$ 0.00", 10, Color_Text);

        curY += 25;
        DrawLabel("Res_BalTxt", 15, curY, "Acc. Impact:", 10, Color_Text);
        DrawLabel("Res_BalVal", 100, curY, "0.0 %", 10, clrSilver);
    }

    void UpdateInfo(string symbol, string contractDesc, double accountVal,
                    string accCurrency) {
        ObjectSetString(0, prefix + "Title", OBJPROP_TEXT,
                        ":: " + symbol + " Calc ::");

        // [수정] 동적 텍스트 적용 (입력 랏수에 비례)
        ObjectSetString(0, prefix + "Info_Desc", OBJPROP_TEXT, contractDesc);

        if (accountVal > 0)
            ObjectSetString(
                0, prefix + "Info_Val", OBJPROP_TEXT,
                StringFormat(
                    "Value: %s %s", accCurrency,
                    DoubleToString(accountVal, 0)));  // 소수점 제거 깔끔하게
        else
            ObjectSetString(0, prefix + "Info_Val", OBJPROP_TEXT,
                            "Value: (Calculating...)");
    }

    double GetInputLot() {
        string txt = ObjectGetString(0, prefix + "EDIT_LOT", OBJPROP_TEXT);
        return StringToDouble(txt);
    }

    double GetInputLoss() {
        string txt = ObjectGetString(0, prefix + "EDIT_LOSS", OBJPROP_TEXT);
        return StringToDouble(txt);
    }

    void UpdateResults(double riskMoney, double margin, double balance) {
        ObjectSetString(0, prefix + "Res_RiskVal", OBJPROP_TEXT,
                        StringFormat("-$ %.2f", riskMoney));
        ObjectSetString(0, prefix + "Res_MrgVal", OBJPROP_TEXT,
                        StringFormat("$ %.2f", margin));

        double impact = (balance > 0) ? (riskMoney / balance * 100.0) : 0.0;
        ObjectSetString(0, prefix + "Res_BalVal", OBJPROP_TEXT,
                        StringFormat("%.2f %% of Balance", impact));

        ChartRedraw();
    }

    void Destroy() { ObjectsDeleteAll(0, prefix); }
};

//+------------------------------------------------------------------+
//| Global Instances                                                 |
//+------------------------------------------------------------------+
CalculatorEngine engine;
InteractiveUI ui;

//+------------------------------------------------------------------+
//| Main Logic                                                       |
//+------------------------------------------------------------------+
int OnInit() {
    engine.refresh();
    ui.Init();
    CalculateAndShow();
    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason) { ui.Destroy(); }

void OnTick() { CalculateAndShow(); }

void OnChartEvent(const int id, const long& lparam, const double& dparam,
                  const string& sparam) {
    if (id == CHARTEVENT_OBJECT_ENDEDIT) {
        if (StringFind(sparam, "SmartCalc_EDIT_") >= 0) CalculateAndShow();
    }
    if (id == CHARTEVENT_CLICK || id == CHARTEVENT_CHART_CHANGE) {
        // 차트 변경 시 엔진 데이터도 갱신
        if (id == CHARTEVENT_CHART_CHANGE) engine.refresh();
        CalculateAndShow();
    }
}

void CalculateAndShow() {
    double lot = ui.GetInputLot();

    // [New] 랏수를 인자로 전달하여 동적 텍스트 생성
    string desc = engine.getContractDesc(lot);
    double accVal = engine.getAccountNominalValue(lot);

    ui.UpdateInfo(engine.getSymbolName(), desc, accVal,
                  engine.getAccountCurrency());

    double lossPt = ui.GetInputLoss();
    if (lot <= 0) return;

    double pipVal = engine.getPipValue(lot);
    double riskMoney = pipVal * lossPt;
    double margin = engine.getMargin(lot);
    double balance = engine.getBalance();

    ui.UpdateResults(riskMoney, margin, balance);
}
//+------------------------------------------------------------------+