//+------------------------------------------------------------------+
//|                                        프로그램 제목.mq5  |
//|                                  Copyright 2025, p3pwp3p  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, p3pwp3p"
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

#include <Trade\Trade.mqh>

// ZeroMQ 상수 정의
#define ZmqPub 1
#define ZmqSub 2
#define ZmqSubscribe 6
#define ZmqDontwait 1

// DLL 임포트
#import "libzmq.dll"
long zmq_ctx_new();
long zmq_socket(long context, int type);
int zmq_bind(long socket, const uchar& endpoint[]);
int zmq_connect(long socket, const uchar& endpoint[]);
int zmq_setsockopt(long socket, int option, const uchar& optval[],
                   int optvallen);
int zmq_send(long socket, const uchar& buf[], int len, int flags);
int zmq_recv(long socket, uchar& buf[], int len, int flags);
int zmq_close(long socket);
int zmq_ctx_term(long context);
#import

// EA 역할 Enum
enum EnumEaRole {
    RoleMaster,  // 마스터 (송신, 터미널 a)
    RoleSlave    // 슬레이브 (수신, 터미널 b 및 a')
};

// 사용자 Input 변수
input group "Common Settings";
input EnumEaRole EaRole = RoleSlave;
input string ZmqPort = "5555";

input group "Receiver Settings";
input string MasterIpAddress = "175.124.23.164";
input bool UseManualLot = false;
input double LotMultiplier = 1.0;

// 전역 변수
long zmqContext = 0;
long zmqSocket = 0;
CTrade tradeCopier;

// 문자열을 uchar 배열로 변환
void stringToUcharArray(string str, uchar& arr[]) {
    StringToCharArray(str, arr, 0, WHOLE_ARRAY, CP_UTF8);
}

// 랏 사이즈 계산 (자동 및 수동 배수 조절)
double calculateLotSize(string symbol, double originalVol,
                        double masterBalance) {
    double finalVol = originalVol;
    double slaveBalance = AccountInfoDouble(ACCOUNT_BALANCE);

    if (UseManualLot) {
        // 수동 배수 모드
        finalVol = originalVol * LotMultiplier;
    } else {
        // 자동 비례 배수 모드
        if (masterBalance > 0) {
            finalVol = originalVol * (slaveBalance / masterBalance);
        }
    }

    // 브로커 규격에 맞게 랏 사이즈 보정
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

    if (step > 0) {
        finalVol = MathRound(finalVol / step) * step;
    }

    // 최소/최대치 제한
    if (finalVol < minLot) finalVol = minLot;
    if (finalVol > maxLot) finalVol = maxLot;

    // 슬레이브에서 작동 확인용 로그 출력
    Print("마스터 진입 랏: ", originalVol,
          " | 마스터 잔고: ", NormalizeDouble(masterBalance, 2),
          " | 슬레이브 잔고: ", NormalizeDouble(slaveBalance, 2),
          " -> 최종 진입 랏: ", NormalizeDouble(finalVol, 2));

    return NormalizeDouble(finalVol, 2);
}

// 수신된 청산 신호 처리
void closePositions(string targetSymbol, long dealType) {
    long posTypeToClose =
        (dealType == DEAL_TYPE_BUY) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;

    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        string posSymbol = PositionGetSymbol(i);
        long posType = PositionGetInteger(POSITION_TYPE);
        ulong ticket = PositionGetTicket(i);

        if (posSymbol == targetSymbol && posType == posTypeToClose) {
            tradeCopier.PositionClose(ticket);
        }
    }
}

// 신호 파싱 및 매매 실행
void processSignal(string msg) {
    string parts[];
    StringSplit(msg, '|', parts);

    // 메시지 구조: ACTION|SYMBOL|TYPE|VOL|BALANCE (총 5개)
    if (ArraySize(parts) == 5) {
        string action = parts[0];
        string symbol = parts[1];
        long type = StringToInteger(parts[2]);
        double originalVol = StringToDouble(parts[3]);
        double masterBalance = StringToDouble(parts[4]);

        double finalVol = calculateLotSize(symbol, originalVol, masterBalance);

        if (action == "IN") {
            if (type == DEAL_TYPE_BUY)
                tradeCopier.Buy(finalVol, symbol);
            else if (type == DEAL_TYPE_SELL)
                tradeCopier.Sell(finalVol, symbol);
        } else if (action == "OUT") {
            closePositions(symbol, type);
        }
    }
}

int OnInit() {
    zmqContext = zmq_ctx_new();

    if (EaRole == RoleMaster) {
        // 송신 모드
        zmqSocket = zmq_socket(zmqContext, ZmqPub);
        string bindAddr = "tcp://*:" + ZmqPort;
        uchar bindBuf[];
        stringToUcharArray(bindAddr, bindBuf);
        zmq_bind(zmqSocket, bindBuf);
    } else {
        // 수신 모드
        zmqSocket = zmq_socket(zmqContext, ZmqSub);
        string connAddr = "tcp://" + MasterIpAddress + ":" + ZmqPort;
        uchar connBuf[];
        stringToUcharArray(connAddr, connBuf);
        zmq_connect(zmqSocket, connBuf);

        uchar filter[] = {0};
        zmq_setsockopt(zmqSocket, ZmqSubscribe, filter, 0);

        // 10ms 단위로 소켓 감시
        EventSetMillisecondTimer(10);

        Print("[수신 모드] 마스터 연결 대기 및 10ms 타이머 가동: ", connAddr);
    }

    return (INIT_SUCCEEDED);
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result) {
    if (EaRole != RoleMaster) return;

    if (trans.type == TRADE_TRANSACTION_DEAL_ADD) {
        if (HistoryDealSelect(trans.deal)) {
            string symbol = trans.symbol;
            double volume = trans.volume;
            long dealType = trans.deal_type;
            long entryType = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);

            string action = "";
            if (entryType == DEAL_ENTRY_IN)
                action = "IN";
            else if (entryType == DEAL_ENTRY_OUT)
                action = "OUT";

            if (action != "") {
                double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);

                // 마스터 잔고(currentBalance)를 메시지 맨 끝에 추가하여 발송
                string msg = action + "|" + symbol + "|" +
                             IntegerToString(dealType) + "|" +
                             DoubleToString(volume, 2) + "|" +
                             DoubleToString(currentBalance, 2);
                uchar msgBuf[];
                stringToUcharArray(msg, msgBuf);

                zmq_send(zmqSocket, msgBuf, ArraySize(msgBuf) - 1, 0);
            }
        }
    }
}

void OnTimer() {
    if (EaRole != RoleSlave) return;

    uchar recvBuf[256];

    while (true) {
        int size = zmq_recv(zmqSocket, recvBuf, 256, ZmqDontwait);
        if (size > 0) {
            string msg = CharArrayToString(recvBuf, 0, size, CP_UTF8);
            processSignal(msg);
        } else {
            break;
        }
    }
}

void OnTick() {}

void OnDeinit(const int reason) {
    if (EaRole == RoleSlave) EventKillTimer();
    if (zmqSocket != 0) zmq_close(zmqSocket);
    if (zmqContext != 0) zmq_ctx_term(zmqContext);
}