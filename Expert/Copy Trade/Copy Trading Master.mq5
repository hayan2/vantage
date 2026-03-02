//+------------------------------------------------------------------+
//|                                         Copy Trading Master.mq5  |
//|                                         Copyright 2026, p3pwp3p  |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, p3pwp3p"
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

#import "libzmq.dll"
long zmq_ctx_new();
int zmq_ctx_term(long context);
long zmq_socket(long context, int type);
int zmq_close(long socket);
int zmq_bind(long socket, const uchar& endpoint[]);
int zmq_connect(long socket, const uchar& endpoint[]);
int zmq_send(long socket, const uchar& buf[], int len, int flags);
#import

#define ZmqPub 1
#define ZmqPush 8

int InputLocalBindPort = 5556;
string InputTargetVpsIp = "139.180.164.225";
int InputTargetVpsPort = 5555;

long globalZmqContext = 0;
long globalLocalSocket = 0;
long globalVpsSocket = 0;

bool lastBtnState = false;
double lastKnownBalance = 0;
datetime lastHeartbeatTime = 0;

// 영문 키워드로 상태 전송 (인코딩 깨짐 방지 핵심)
void sendStatusSignal(string statusKey) {
    string signalData = "STATUS|" + statusKey + "|" +
                        DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) +
                        "|" +
                        DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2);
    sendDualSignal(signalData);
}

bool startMasterServer() {
    globalZmqContext = zmq_ctx_new();
    if (globalZmqContext == 0) return false;
    globalLocalSocket = zmq_socket(globalZmqContext, ZmqPub);
    string locAddr = "tcp://127.0.0.1:" + IntegerToString(InputLocalBindPort);
    uchar locArr[];
    StringToCharArray(locAddr, locArr);
    zmq_bind(globalLocalSocket, locArr);

    globalVpsSocket = zmq_socket(globalZmqContext, ZmqPush);
    string vpsAddr =
        "tcp://" + InputTargetVpsIp + ":" + IntegerToString(InputTargetVpsPort);
    uchar vpsArr[];
    StringToCharArray(vpsAddr, vpsArr);
    zmq_connect(globalVpsSocket, vpsArr);
    return true;
}

void sendDualSignal(string signalData) {
    uchar sendBuffer[];
    int dataLength = StringToCharArray(signalData, sendBuffer) - 1;
    zmq_send(globalLocalSocket, sendBuffer, dataLength, 1);
    zmq_send(globalVpsSocket, sendBuffer, dataLength, 1);
}

int OnInit() {
    if (!startMasterServer()) return INIT_FAILED;
    lastKnownBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    lastBtnState = (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
    sendStatusSignal("EA_START");
    EventSetTimer(1);
    return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
    string key = "EA_STOP";
    if (reason == REASON_CHARTCLOSE) key = "EA_CHART_CLOSE";
    if (reason == REASON_REMOVE) key = "EA_REMOVE";
    if (reason == REASON_CLOSE) key = "EA_MT5_CLOSE";
    sendStatusSignal(key);
    EventKillTimer();
    if (globalLocalSocket != 0) zmq_close(globalLocalSocket);
    if (globalVpsSocket != 0) zmq_close(globalVpsSocket);
    if (globalZmqContext != 0) zmq_ctx_term(globalZmqContext);
}

void OnTimer() {
    bool currentBtn = (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
    if (currentBtn != lastBtnState) {
        sendStatusSignal(currentBtn ? "BTN_ON" : "BTN_OFF");
        lastBtnState = currentBtn;
    }
    double currentBal = AccountInfoDouble(ACCOUNT_BALANCE);
    if (lastKnownBalance > 0 && MathAbs(currentBal - lastKnownBalance) > 0.01) {
        sendStatusSignal("BAL_CHG");
        lastKnownBalance = currentBal;
    }
    if (TimeCurrent() - lastHeartbeatTime >= 300) {
        double bal = AccountInfoDouble(ACCOUNT_BALANCE);
        double eq = AccountInfoDouble(ACCOUNT_EQUITY);
        sendDualSignal("PING|MASTER|" + DoubleToString(bal, 2) + "|" +
                       DoubleToString(eq, 2));
        lastHeartbeatTime = TimeCurrent();
    }
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result) {
    if (trans.type == TRADE_TRANSACTION_DEAL_ADD) {
        ulong ticket = trans.deal;
        if (HistoryDealSelect(ticket)) {
            long dealEntry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
            string sym = HistoryDealGetString(ticket, DEAL_SYMBOL);
            double vol = HistoryDealGetDouble(ticket, DEAL_VOLUME);
            if (dealEntry == DEAL_ENTRY_IN) {
                string type =
                    (HistoryDealGetInteger(ticket, DEAL_TYPE) == DEAL_TYPE_BUY)
                        ? "BUY"
                        : "SELL";
                sendDualSignal(
                    "OPEN|" + sym + "|" + type + "|" + DoubleToString(vol, 2) +
                    "|" +
                    DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
            }
            if (dealEntry == DEAL_ENTRY_OUT)
                sendDualSignal("CLOSE|" + sym + "|" + DoubleToString(vol, 2));
        }
    }
}