//+------------------------------------------------------------------+
//|                              Copy trade sender and receiver.mq5  |
//|                                         Copyright 2025, p3pwp3p  | 
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, p3pwp3p"
#property link "https://www.mql5.com"
#property version "1.00"
#property strict

#include <Trade\Trade.mqh>

//--- Enums
enum ENUM_APP_MODE {
    MODE_SENDER,   // Sender (Account A)
    MODE_RECEIVER  // Receiver (Account B)
};

//--- Data Structure for File Communication
struct SignalData {
    long ticket;      // Original Ticket (Sender's)
    double volume;    // Volume
    long type;        // ENUM_POSITION_TYPE
    char symbol[32];  // Symbol Name
};

//--- Input Parameters
input group "Mode Settings";
input ENUM_APP_MODE AppMode = MODE_SENDER;       // Operation Mode
input string CommFileName = "CopyTrade_Sync.bin";  // Sync File Name
input int SyncTimerMs = 20;                     // Timer Interval (ms)

input group "Receiver Settings";
input double VolumeMultiplier = 1.0;  // Volume Multiplier
input int Slippage = 10;              // Slippage Points
input long MagicNum = 20260108;       // Magic Number;

//--- Global Objects & Variables
CTrade trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    if (AppMode == MODE_RECEIVER) {
        trade.SetExpertMagicNumber(MagicNum);
        trade.SetDeviationInPoints(Slippage);
        trade.SetTypeFilling(ORDER_FILLING_IOC);
        // Note: Filling type might need adjustment depending on the broker
    }

    // High-frequency timer for fast syncing
    EventSetMillisecondTimer(SyncTimerMs);

    Print("HuMoney Trade Copier Started: ", EnumToString(AppMode));
    return (INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) { EventKillTimer(); }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Logic is handled in OnTimer for consistency
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer() {
    if (AppMode == MODE_SENDER)
        processSender();
    else
        processReceiver();
}

//+------------------------------------------------------------------+
//| Logic: Sender (Write Positions to File)                          |
//+------------------------------------------------------------------+
void processSender() {
    int handle = FileOpen(CommFileName, FILE_WRITE | FILE_BIN | FILE_COMMON);

    if (handle == INVALID_HANDLE) return;

    int total = PositionsTotal();
    int writeCount = 0;

    // 1. Write placeholder for count
    FileWriteInteger(handle, 0);

    for (int i = 0; i < total; i++) {
        ulong ticket = PositionGetTicket(i);
        if (ticket <= 0) continue;

        SignalData data;
        data.ticket = (long)ticket;
        data.volume = PositionGetDouble(POSITION_VOLUME);
        data.type = PositionGetInteger(POSITION_TYPE);

        string sym = PositionGetString(POSITION_SYMBOL);
        StringToCharArray(sym, data.symbol);

        FileWriteStruct(handle, data);
        writeCount++;
    }

    // 2. Go back to start and write actual count
    FileSeek(handle, 0, SEEK_SET);
    FileWriteInteger(handle, writeCount);

    FileClose(handle);
}

//+------------------------------------------------------------------+
//| Logic: Receiver (Read & Sync)                                    |
//+------------------------------------------------------------------+
void processReceiver() {
    // 1. Read Sender Data
    int handle = FileOpen(CommFileName,
                          FILE_READ | FILE_BIN | FILE_COMMON | FILE_SHARE_READ);

    if (handle == INVALID_HANDLE) return;

    int senderCount = FileReadInteger(handle);
    SignalData senderList[];

    if (senderCount > 0) {
        ArrayResize(senderList, senderCount);
        for (int i = 0; i < senderCount; i++)
            FileReadStruct(handle, senderList[i]);
    }
    FileClose(handle);

    // 2. Synchronization
    syncEntry(senderList, senderCount);
    syncExit(senderList, senderCount);
}

//+------------------------------------------------------------------+
//| Helper: Handle New Entries                                       |
//+------------------------------------------------------------------+
void syncEntry(SignalData& src[], int count) {
    for (int i = 0; i < count; i++) {
        // Check if we already have this ticket
        if (isTicketExistInReceiver(src[i].ticket)) continue;

        // New Trade logic
        string sym = CharArrayToString(src[i].symbol);
        double vol = src[i].volume * VolumeMultiplier;

        // Store Sender's Ticket in Comment for mapping
        string comment = IntegerToString(src[i].ticket);

        if (src[i].type == POSITION_TYPE_BUY)
            trade.Buy(vol, sym, 0, 0, 0, comment);
        else if (src[i].type == POSITION_TYPE_SELL)
            trade.Sell(vol, sym, 0, 0, 0, comment);
    }
}

//+------------------------------------------------------------------+
//| Helper: Handle Exits (Closings)                                  |
//+------------------------------------------------------------------+
void syncExit(SignalData& src[], int count) {
    int total = PositionsTotal();

    // Loop through Receiver's positions
    for (int i = total - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);

        // Filter by Magic Number to touch only Copier trades
        if (PositionGetInteger(POSITION_MAGIC) != MagicNum) continue;

        string comment = PositionGetString(POSITION_COMMENT);
        long senderTicketID =
            StringToInteger(comment);  // Extract Sender Ticket

        // If the comment is not a valid ID, skip
        if (senderTicketID == 0) continue;

        // Check if this ID still exists in Sender's list
        bool stillOpen = false;
        for (int k = 0; k < count; k++) {
            if (src[k].ticket == senderTicketID) {
                stillOpen = true;
                break;
            }
        }

        // If Sender doesn't have it anymore, Close it.
        if (!stillOpen) {
            trade.PositionClose(ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Check if Receiver already holds a trade for Sender's Ticket      |
//+------------------------------------------------------------------+
bool isTicketExistInReceiver(long targetSenderTicket) {
    int total = PositionsTotal();
    for (int i = 0; i < total; i++) {
        if (PositionSelectByTicket(PositionGetTicket(i))) {
            if (PositionGetInteger(POSITION_MAGIC) == MagicNum) {
                string comment = PositionGetString(POSITION_COMMENT);
                if (StringToInteger(comment) == targetSenderTicket) return true;
            }
        }
    }
    return false;
}
//+------------------------------------------------------------------+