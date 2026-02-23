//+------------------------------------------------------------------+
//|                                        Copy Trade.mq5  |
//|                                  Copyright 2025, p3pwp3p  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, p3pwp3p"
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

#include <Trade\Trade.mqh>

// ZeroMQ 상수 정의 (PascalCase)
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

// EA 역할 Enum (PascalCase)
enum EnumEaRole {
    RoleMaster,  // 마스터 (송신, 터미널 a)
    RoleSlave    // 슬레이브 (수신, 터미널 b 및 a')
};

// 사용자 Input 변수 (PascalCase, input group 세미콜론 규칙)
input group "Common Settings";
input EnumEaRole EaRole = RoleSlave;
input string ZmqPort = "5555";

input group "Receiver Settings";
input string MasterIpAddress = "127.0.0.1";
input bool UseManualLot = true;
input double LotMultiplier = 1.0;

// 전역 변수 (camelCase)
long zmqContext = 0;
long zmqSocket = 0;
CTrade tradeCopier;

// 문자열을 uchar 배열로 변환 (camelCase)
void stringToUcharArray(string str, uchar& arr[]) {
    StringToCharArray(str, arr, 0, WHOLE_ARRAY, CP_UTF8);
}

// 랏 사이즈 계산 및 브로커 규격에 맞게 보정 (camelCase)
double calculateLotSize(string symbol, double originalVol) {
    double finalVol = originalVol;

    // 수동 배수 조절
    if (UseManualLot) {
        finalVol = originalVol * LotMultiplier;
    }

    // 브로커 규격 가져오기 (최소 랏, 최대 랏, 랏 증감 단위)
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

    // 브로커의 증감 단위(step)에 맞게 정밀 반올림
    if (step > 0) {
        finalVol = MathRound(finalVol / step) * step;
    }

    // 최소/최대치 제한
    if (finalVol < minLot) finalVol = minLot;
    if (finalVol > maxLot) finalVol = maxLot;

    // [확인용 로그] 슬레이브에서만 계산 결과를 출력하여 배수 작동 확인
    // (마스터는 무음)
    Print("마스터 진입 랏: ", originalVol,
          " -> 슬레이브 최종 진입 랏: ", NormalizeDouble(finalVol, 2));

    return NormalizeDouble(finalVol, 2);
}

// 수신된 청산 신호 처리 (camelCase)
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

// 신호 파싱 및 매매 실행 (camelCase)
void processSignal(string msg) {
    string parts[];
    StringSplit(msg, '|', parts);

    if (ArraySize(parts) == 4) {
        string action = parts[0];
        string symbol = parts[1];
        long type = StringToInteger(parts[2]);
        double originalVol = StringToDouble(parts[3]);

        double finalVol = calculateLotSize(symbol, originalVol);

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

        // [중요 수정] 10ms(0.01초) 단위로 소켓을 감시하도록 타이머 설정
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
                string msg = action + "|" + symbol + "|" +
                             IntegerToString(dealType) + "|" +
                             DoubleToString(volume, 2);
                uchar msgBuf[];
                stringToUcharArray(msg, msgBuf);

                zmq_send(zmqSocket, msgBuf, ArraySize(msgBuf) - 1, 0);
            }
        }
    }
}

// 기존 OnTick 대신 OnTimer를 사용하여 틱 속도와 무관하게 즉각 반응
void OnTimer() {
    if (EaRole != RoleSlave) return;

    uchar recvBuf[256];

    // 큐에 쌓인 신호가 여러 개일 경우를 대비해 while문으로 모두 처리
    while (true) {
        int size = zmq_recv(zmqSocket, recvBuf, 256, ZmqDontwait);
        if (size > 0) {
            string msg = CharArrayToString(recvBuf, 0, size, CP_UTF8);
            processSignal(msg);
        } else {
            break;  // 더 이상 읽을 신호가 없으면 루프 탈출
        }
    }
}

// 사용하지 않는 OnTick은 비워둡니다
void OnTick() {}

void OnDeinit(const int reason) {
    if (EaRole == RoleSlave) EventKillTimer();  // 슬레이브일 경우 타이머 해제
    if (zmqSocket != 0) zmq_close(zmqSocket);
    if (zmqContext != 0) zmq_ctx_term(zmqContext);
}