//+------------------------------------------------------------------+
//|                                          Copy Trading Slave.mq5  |
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
int zmq_connect(long socket, const uchar& endpoint[]);
int zmq_setsockopt(long socket, int option, const uchar& optval[],
                   int optvallen);
int zmq_recv(long socket, uchar& buf[], int len, int flags);
#import

#define ZmqSub 2
#define ZmqSubscribe 6
#define ZmqDontwait 1

string InputMasterIp = "127.0.0.1";
int InputMasterPort = 5556;

input group "Lot Size Settings";
input bool InputUseAutoLot = true;      // true: 잔고 비례, false: 단순 배수
input double InputLotMultiplier = 1.0;  // 추가 조절 배수

long globalZmqContext = 0;
long globalZmqSocket = 0;
bool isAlertSent = false;

bool connectToLocalMaster() {
    globalZmqContext = zmq_ctx_new();
    if (globalZmqContext == 0) return false;
    globalZmqSocket = zmq_socket(globalZmqContext, ZmqSub);
    if (globalZmqSocket == 0) return false;

    string connectAddress =
        "tcp://" + InputMasterIp + ":" + IntegerToString(InputMasterPort);
    uchar endpointArray[];
    StringToCharArray(connectAddress, endpointArray);

    if (zmq_connect(globalZmqSocket, endpointArray) == 0) {
        uchar filterArray[] = {0};
        zmq_setsockopt(globalZmqSocket, ZmqSubscribe, filterArray, 0);
        return true;
    }
    return false;
}

void checkTradeSignal() {
    uchar receiveBuffer[1024];
    int bytesRead = zmq_recv(globalZmqSocket, receiveBuffer, 1024, ZmqDontwait);

    if (bytesRead > 0) {
        string receivedData = CharArrayToString(receiveBuffer, 0, bytesRead);
        string signalParts[];
        int partsCount = StringSplit(receivedData, '|', signalParts);

        if (partsCount >= 3) {
            string action = signalParts[0];
            string symbol = signalParts[1];

            // 1. OPEN 신호 처리 (인자 5개: ACTION|SYMBOL|TYPE|LOT|BALANCE)
            if (action == "OPEN" && partsCount == 5) {
                string type = signalParts[2];
                double masterLot = StringToDouble(signalParts[3]);
                double masterBalance = StringToDouble(signalParts[4]);
                double finalLot = 0;

                if (InputUseAutoLot && masterBalance > 0) {
                    // [자동 잔고 비례] 내 잔고 / 마스터 잔고 비율 적용
                    double myBalance = AccountInfoDouble(ACCOUNT_BALANCE);
                    finalLot = masterLot * (myBalance / masterBalance) *
                               InputLotMultiplier;
                } else {
                    // [단순 배수] 설정된 배수만 적용
                    finalLot = masterLot * InputLotMultiplier;
                }

                finalLot = NormalizeDouble(finalLot, 2);
                if (finalLot < 0.01) finalLot = 0.01;

                if (type == "BUY")
                    tradeManager.Buy(finalLot, symbol, 0);
                else if (type == "SELL")
                    tradeManager.Sell(finalLot, symbol, 0);

                Print("📡 [로컬 카피] ", symbol,
                      " | 모드: ", (InputUseAutoLot ? "비례" : "배수"),
                      " | 최종랏: ", finalLot);
                return;
            }

            // 2. CLOSE 신호 처리
            if (action == "CLOSE") {
                tradeManager.PositionClose(symbol);
                return;
            }

            // 3. PING 신호 처리 (로그 기록용)
            if (action == "PING" && partsCount == 4) {
                Print("💓 [Master] Bal: ", signalParts[2],
                      " | Eq: ", signalParts[3]);
                return;
            }
        }
    }
}

int OnInit() {
    if (!connectToLocalMaster()) return INIT_FAILED;

    tradeManager.SetDeviationInPoints(
        50);  // 슬리피지 허용치를 더 높여서 재쿼트 방지

    // 1ms 단위로 신호 감시 (CPU 사용량 증가하지만 속도는 최상)
    EventSetMillisecondTimer(1);
    return (INIT_SUCCEEDED);
}

void OnTimer() {
    checkSystemStatus();
    checkTradeSignal();
}

void OnDeinit(const int reason) {
    string subject = "🚨 [슬레이브] 카피 시스템 종료 알림";
    string message =
        "로컬 카피 EA가 중단되었습니다.\n사유 코드: " + IntegerToString(reason);
    SendMail(subject, message);

    EventKillTimer();
    if (globalZmqSocket != 0) zmq_close(globalZmqSocket);
    if (globalZmqContext != 0) zmq_ctx_term(globalZmqContext);
}

void checkSystemStatus() {
    bool isTradingEnabled = (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
    if (!isTradingEnabled) {
        if (!isAlertSent) {
            string subject = "🚨 [슬레이브] 시스템 트레이딩 버튼 꺼짐!";
            string message =
                "슬레이브 터미널 트레이딩 버튼이 비활성화되었습니다.\n카피 "
                "주문이 중단된 상태입니다.";
            if (SendMail(subject, message)) {
                Print("📧 메일 발송 성공!");
                isAlertSent = true;
            }
        }
    } else {
        isAlertSent = false;
    }
}