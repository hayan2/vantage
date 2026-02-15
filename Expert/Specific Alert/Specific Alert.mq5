//+------------------------------------------------------------------+
//|                                              Sepcific Alert.mq5  |
//|                                         Copyright 2025, p3pwp3p  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, p3pwp3p"
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input group "========== 1. Bollinger Bands Signal ==========";
input bool InputUseBbSignal = true;       // 볼린저 밴드 알람 사용 여부
input int InputBbPeriod = 20;             // 기간
input double InputBbDev = 2.0;            // 승수
input int InputSqueezeCheckPeriod = 20;   // 수렴 판단을 위한 평균 산출 기간
input double InputSqueezeFactor = 0.8;    // 수렴 강도 (평균 밴드폭 대비 비율)
input double InputBodyMultiplier = 1.5;   // 돌파 강도 (평균 몸통 대비 배수)
input string InputSoundBb = "alert.wav";  // [알람음] 볼린저 밴드

input group "========== 2. MA Cross Signal ==========";
input bool InputUseMaCross = true;              // 이평선 크로스 알람 사용 여부
input int InputFastMaPeriod = 10;               // 단기 이평선 기간
input int InputSlowMaPeriod = 50;               // 장기 이평선 기간
input ENUM_MA_METHOD InputMaMethod = MODE_SMA;  // 이평선 종류
input string InputSoundMaCross = "news.wav";    // [알람음] MA 크로스

input group "========== 3. Object Breakout Signal ==========";
input bool InputUseLineBreak = true;      // 지지/저항선 돌파 알람 사용 여부
input string InputLinePrefix = "ALARM_";  // 감지할 오브젝트 이름 접두사
input string InputSoundLine = "alert2.wav";   // [알람음] 라인 돌파

input group "========== 4. Specific MA Breakout ==========";
input bool InputUseSpecificMa = true;   // 특정 이평선 돌파 알람 사용 여부
input int InputSpecificMaPeriod = 200;  // 특정 이평선 기간
input string InputSoundSpecificMa = "tick.wav";  // [알람음] 특정 MA 돌파

input group "========== System Settings ==========";
input bool InputUseAlert = true;    // 팝업 알람 사용
input bool InputUsePush = true;     // 모바일 푸시 알람 사용
input bool InputPlaySound = true;   // 소리 재생 사용
input int InputAlarmCooldown = 10;  // 알람 쿨타임 (초단위 재알림 대기)

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
int handleBb, handleFastMa, handleSlowMa, handleSpecificMa;

// 쿨타임 관리를 위한 마지막 알람 시간 (Timestamp)
datetime lastAlertTimeBb = 0;
datetime lastAlertTimeMa = 0;
datetime lastAlertTimeLine = 0;
datetime lastAlertTimeSpec = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    // 지표 핸들 초기화
    handleBb =
        iBands(_Symbol, _Period, InputBbPeriod, 0, InputBbDev, PRICE_CLOSE);
    handleFastMa =
        iMA(_Symbol, _Period, InputFastMaPeriod, 0, InputMaMethod, PRICE_CLOSE);
    handleSlowMa =
        iMA(_Symbol, _Period, InputSlowMaPeriod, 0, InputMaMethod, PRICE_CLOSE);
    handleSpecificMa = iMA(_Symbol, _Period, InputSpecificMaPeriod, 0,
                           InputMaMethod, PRICE_CLOSE);

    if (handleBb == INVALID_HANDLE || handleFastMa == INVALID_HANDLE ||
        handleSlowMa == INVALID_HANDLE || handleSpecificMa == INVALID_HANDLE) {
        Print("지표 핸들 생성 실패");
        return (INIT_FAILED);
    }

    return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // 현재 서버 시간 가져오기
    datetime currentTime = TimeCurrent();

    // 1. 볼린저 밴드 (쿨타임 체크)
    if (InputUseBbSignal && currentTime >= lastAlertTimeBb + InputAlarmCooldown)
        checkBollingerBreakout(currentTime);

    // 2. 이평선 크로스 (쿨타임 체크)
    if (InputUseMaCross && currentTime >= lastAlertTimeMa + InputAlarmCooldown)
        checkMaCross(currentTime);

    // 3. 지지/저항선 돌파 (쿨타임 체크)
    if (InputUseLineBreak &&
        currentTime >= lastAlertTimeLine + InputAlarmCooldown)
        checkObjectBreakout(currentTime);

    // 4. 특정 이평선 돌파 (쿨타임 체크)
    if (InputUseSpecificMa &&
        currentTime >= lastAlertTimeSpec + InputAlarmCooldown)
        checkSpecificMaBreakout(currentTime);
}

//+------------------------------------------------------------------+
//| Logic 1: 볼린저 밴드 실시간 돌파                                 |
//+------------------------------------------------------------------+
void checkBollingerBreakout(datetime currentTime) {
    double upper[], lower[];
    MqlRates rates[];

    // 현재봉(0) 포함 데이터 가져오기
    if (CopyBuffer(handleBb, 1, 0, InputSqueezeCheckPeriod + 2, upper) < 0 ||
        CopyBuffer(handleBb, 2, 0, InputSqueezeCheckPeriod + 2, lower) < 0 ||
        CopyRates(_Symbol, _Period, 0, InputSqueezeCheckPeriod + 2, rates) < 0)
        return;

    int idx = 0;  // 실시간 현재 봉 인덱스

    // A. 실시간 돌파 여부
    bool upBreak = rates[idx].close > upper[idx];  // rates[0].close는 현재가
    bool downBreak = rates[idx].close < lower[idx];

    if (!upBreak && !downBreak) return;

    // B. 수렴(Squeeze) 확인 (안정성을 위해 직전 완성봉들 기준)
    double sumBandwidth = 0;
    for (int i = 1; i <= InputSqueezeCheckPeriod; i++) {
        double bw = upper[i] - lower[i];
        sumBandwidth += bw;
    }
    double avgBandwidth = sumBandwidth / InputSqueezeCheckPeriod;
    double prevBandwidth = upper[1] - lower[1];

    if (prevBandwidth > avgBandwidth * InputSqueezeFactor) return;

    // C. 강한 돌파(Body) 확인 (실시간 현재가 기준 몸통 크기)
    double sumBody = 0;
    for (int i = 1; i <= InputSqueezeCheckPeriod; i++) {
        sumBody += MathAbs(rates[i].open - rates[i].close);
    }
    double avgBody = sumBody / InputSqueezeCheckPeriod;

    double currentBody = MathAbs(rates[idx].open - rates[idx].close);

    if (currentBody < avgBody * InputBodyMultiplier) return;

    // 알람 발생
    string msg = upBreak ? "Bollinger 상단 실시간 돌파 (수렴 후)"
                         : "Bollinger 하단 실시간 돌파 (수렴 후)";
    sendAlert(msg, InputSoundBb);

    lastAlertTimeBb = currentTime;  // 쿨타임 리셋
}

//+------------------------------------------------------------------+
//| Logic 2: 이평선 실시간 크로스                                    |
//+------------------------------------------------------------------+
void checkMaCross(datetime currentTime) {
    double fast[], slow[];
    if (CopyBuffer(handleFastMa, 0, 0, 2, fast) < 0 ||
        CopyBuffer(handleSlowMa, 0, 0, 2, slow) < 0)
        return;

    double fastCurr = fast[0];
    double fastPrev = fast[1];
    double slowCurr = slow[0];
    double slowPrev = slow[1];

    // 골든 크로스
    if (fastPrev <= slowPrev && fastCurr > slowCurr) {
        sendAlert("MA 골든 크로스 (실시간)", InputSoundMaCross);
        lastAlertTimeMa = currentTime;
    }

    // 데드 크로스
    if (fastPrev >= slowPrev && fastCurr < slowCurr) {
        sendAlert("MA 데드 크로스 (실시간)", InputSoundMaCross);
        lastAlertTimeMa = currentTime;
    }
}

//+------------------------------------------------------------------+
//| Logic 3: 오브젝트 실시간 돌파                                    |
//+------------------------------------------------------------------+
void checkObjectBreakout(datetime currentTime) {
    int total = ObjectsTotal(0, 0, -1);
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double currentOpen = iOpen(_Symbol, _Period, 0);

    for (int i = 0; i < total; i++) {
        string name = ObjectName(0, i);
        // 지정된 접두사("ALARM_")로 시작하는지 확인
        if (StringFind(name, InputLinePrefix) == 0) {
            double priceLevel = getObjectPrice(name, 0);
            if (priceLevel == 0.0) continue;

            // 상향 돌파 (시가는 아래, 현재가는 위)
            if (currentOpen <= priceLevel && currentPrice > priceLevel) {
                sendAlert("라인 상향 돌파 (실시간): " + name, InputSoundLine);
                lastAlertTimeLine = currentTime;
                return;
            }

            // 하향 돌파 (시가는 위, 현재가는 아래)
            if (currentOpen >= priceLevel && currentPrice < priceLevel) {
                sendAlert("라인 하향 돌파 (실시간): " + name, InputSoundLine);
                lastAlertTimeLine = currentTime;
                return;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Logic 4: 특정 이평선 실시간 돌파                                 |
//+------------------------------------------------------------------+
void checkSpecificMaBreakout(datetime currentTime) {
    double ma[];
    if (CopyBuffer(handleSpecificMa, 0, 0, 2, ma) < 0) return;

    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double currentOpen = iOpen(_Symbol, _Period, 0);
    double maVal = ma[0];

    // 상향 돌파
    if (currentOpen <= maVal && currentPrice > maVal) {
        sendAlert("특정 MA 실시간 상향 돌파", InputSoundSpecificMa);
        lastAlertTimeSpec = currentTime;
    }

    // 하향 돌파
    if (currentOpen >= maVal && currentPrice < maVal) {
        sendAlert("특정 MA 실시간 하향 돌파", InputSoundSpecificMa);
        lastAlertTimeSpec = currentTime;
    }
}

//+------------------------------------------------------------------+
//| Helper: 오브젝트 가격 가져오기 (수평선 & 추세선 지원)            |
//+------------------------------------------------------------------+
double getObjectPrice(string name, int shift) {
    // [수정] 올바른 ENUM 타입 사용
    ENUM_OBJECT objType = (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE);
    datetime time = iTime(_Symbol, _Period, shift);

    if (objType == OBJ_HLINE) return ObjectGetDouble(0, name, OBJPROP_PRICE);

    if (objType == OBJ_TREND) return ObjectGetValueByTime(0, name, time, 0);

    return 0.0;
}

//+------------------------------------------------------------------+
//| Helper: 알람 전송 통합 함수                                      |
//+------------------------------------------------------------------+
void sendAlert(string msg, string soundFile) {
    string fullMsg = "[" + _Symbol + "] " + msg;

    if (InputUseAlert) Alert(fullMsg);
    if (InputUsePush) SendNotification(fullMsg);

    if (InputPlaySound && soundFile != "") PlaySound(soundFile);
}
//+------------------------------------------------------------------+