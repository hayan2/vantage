//+------------------------------------------------------------------+
//|                                       Reverse Tunneling VPS.mq5  |
//|                                         Copyright 2026, p3pwp3p  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, p3pwp3p"
#property link "https://www.mql5.com"
#property version "1.00"
#property strict
#include <Trade\Trade.mqh>

CTrade tradeManager;

#import "libzmq.dll"
long zmq_ctx_new();
int zmq_ctx_term(long context);
long zmq_socket(long context, int type);
int zmq_close(long socket);
int zmq_bind(long socket, const uchar& endpoint[]);
int zmq_recv(long socket, uchar& buf[], int len, int flags);
#import

#define ZmqPull 7
#define ZmqDontwait 1

input group "VPS Network Settings";
input int InputBindPort = 5555;
input group "Lot Size Settings";
input bool InputUseAutoLot = true;
input double InputLotMultiplier = 1.0;

long globalZmqContext = 0;
long globalZmqSocket = 0;

bool bindVpsServer() {
    globalZmqContext = zmq_ctx_new();
    if (globalZmqContext == 0) return false;
    globalZmqSocket = zmq_socket(globalZmqContext, ZmqPull);
    if (globalZmqSocket == 0) return false;
    string addr = "tcp://*:" + IntegerToString(InputBindPort);
    uchar arr[];
    StringToCharArray(addr, arr);
    return (zmq_bind(globalZmqSocket, arr) == 0);
}

void checkTradeSignal() {
    uchar receiveBuffer[1024];
    int bytesRead = zmq_recv(globalZmqSocket, receiveBuffer, 1024, ZmqDontwait);
    if (bytesRead <= 0) return;
    string receivedData = CharArrayToString(receiveBuffer, 0, bytesRead);
    string parts[];
    int count = StringSplit(receivedData, '|', parts);
    if (count < 2) return;
    string action = parts[0];

    // 영문 키워드를 한글로 매핑하여 출력 (폰트 깨짐 완벽 해결)
    if (action == "STATUS" && count == 4) {
        string key = parts[1];
        string msg = "";
        if (key == "BTN_ON")
            msg = "버튼이 켜졌습니다. (AUTO ON ✅)";
        else if (key == "BTN_OFF")
            msg = "버튼이 꺼졌습니다. (AUTO OFF ❌)";
        else if (key == "BAL_CHG")
            msg = "💰 잔고 변화가 감지되었습니다.";
        else if (key == "EA_START")
            msg = "EA가 실행되었습니다. (Ready)";
        else if (key == "EA_STOP")
            msg = "⚠️ 마스터 EA 가동이 중단되었습니다.";
        else if (key == "EA_MT5_CLOSE")
            msg = "❌ 마스터 MT5 터미널이 종료되었습니다.";
        else if (key == "EA_REMOVE")
            msg = "🗑️ 사용자가 마스터 EA를 삭제했습니다.";
        else
            msg = key;

        Print("📢 [Master Alert] ", msg);
        Print("   └ 마스터 현재 - 잔고: ", parts[2], " | 평가금: ", parts[3]);
        return;
    }

    if (action == "OPEN" && count == 5) {
        double mLot = StringToDouble(parts[3]), mBal = StringToDouble(parts[4]);
        double finalLot =
            (InputUseAutoLot && mBal > 0)
                ? NormalizeDouble(
                      mLot * (AccountInfoDouble(ACCOUNT_BALANCE) / mBal) *
                          InputLotMultiplier,
                      2)
                : NormalizeDouble(mLot * InputLotMultiplier, 2);
        if (finalLot < 0.01) finalLot = 0.01;
        if (parts[2] == "BUY")
            tradeManager.Buy(finalLot, parts[1], 0);
        else
            tradeManager.Sell(finalLot, parts[1], 0);
        Print("📡 [카피 성공] ", parts[1], " | 최종랏: ", finalLot);
        return;
    }

    if (action == "PING" && count == 4) {
        Print("💓 [Master Alive] 잔고: ", parts[2], " | 자산: ", parts[3]);
        return;
    }

    if (action == "CLOSE" && count == 3) tradeManager.PositionClose(parts[1]);
}

int OnInit() {
    if (!bindVpsServer()) return INIT_FAILED;
    EventSetMillisecondTimer(50);
    tradeManager.SetDeviationInPoints(10);
    return (INIT_SUCCEEDED);
}

void OnTimer() { checkTradeSignal(); }

void OnDeinit(const int reason) {
    EventKillTimer();
    if (globalZmqSocket != 0) zmq_close(globalZmqSocket);
    if (globalZmqContext != 0) zmq_ctx_term(globalZmqContext);
}