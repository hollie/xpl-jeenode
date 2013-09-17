// The is a JeeNode sketch that enables reporting the state of inputs and that
// can receive commands from other nodes. Used to report the status of a button
// press and to control remote relays
//
// RF packets generated by this node follow the usual packet structure. 
// Payload is:
//   Byte1 : state of the inputs (every input is mapped onto a bit)
//   Byte2 : battery state
//
// RF packets received by this node follow the usual packet structure
// Payload is:
//   Byte1 : command to control the outputs (every output is mapped to a bit)
//
// Use this sketch in combination with the gateway sketch that maps RF packets
// into a format that is supported by the xpl_jeenodes toolflow.

// Lieven Hollevoet, based on example code of JeeLabs
// http://opensource.org/licenses/mit-license.php

#include <JeeLib.h>
#include <avr/sleep.h>

#define RETRY_PERIOD    10  // how soon to retry if ACK didn't come in
#define RETRY_LIMIT     5   // maximum number of times to retry
#define ACK_TIME        10  // number of milliseconds to wait for an ack

//#define SERIAL 1
//#define DEBUG 1

// set the sync mode to 2 if the fuses are still the Arduino default
// mode 3 (full powerdown) can only be used with 258 CK startup fuses
#define RADIO_SYNC_MODE 2

static byte myNodeID = 1;  
static byte myGroupID = 100;

// This defines the structure of the packets which get sent out by wireless:

struct {
    byte buttons;     // byte showing the button states 0..255
    byte lobat :1;  // supply voltage dropped under 3.1V: 0..1
} payload;

BlinkPlug blink (1); // Blink plug on port 2
MilliTimer everySecond;

byte btn_state = 0;
byte btn_state_prev = 0;

#define LED_PIN 9
static void activityLed (byte on) {
#ifdef LED_PIN
    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, !on);
#endif
}

// has to be defined because we're using the watchdog for low-power waiting
ISR(WDT_vect) { Sleepy::watchdogEvent(); }

void loop () {
    byte event = blink.buttonCheck();
    switch (event) {
        
    case BlinkPlug::ON1:
#ifdef SERIAL
        Serial.println("  Button 1 pressed"); 
#endif
        payload.buttons = 1;
        payload.lobat   = 1; // See protocol description in gateway, lobat is re-used here as button status
        btn_state = 1;
        break;
    
    case BlinkPlug::OFF1:
#ifdef SERIAL
        Serial.println("  Button 1 released"); 
#endif
        payload.buttons = 1;
        payload.lobat   = 0;
        btn_state = 2;
        break;
    
    case BlinkPlug::ON2:
#ifdef SERIAL
        Serial.println("  Button 2 pressed"); 
#endif
        payload.buttons = 2;
        payload.lobat   = 1;
        btn_state = 3;
        break;
    
    case BlinkPlug::OFF2:
#ifdef SERIAL
        Serial.println("  Button 2 released"); 
#endif
        payload.buttons = 2;
        payload.lobat   = 0;
        btn_state = 4;
        break;
    
    default:
        // Send a heartbeat every 60 seconds
        if (everySecond.poll(60000)) {
#ifdef SERIAL
        Serial.println("Sending status report"); 
#endif
           doReport();
        }
        break;
    }
    
    // If the button state changed, transmit it
    if (btn_state != btn_state_prev) {
      btn_state_prev = btn_state;
      doTrigger();
    }

}

// wait a few milliseconds for proper ACK to me, return true if indeed received
static byte waitForAck() {
    MilliTimer ackTimer;
    while (!ackTimer.poll(ACK_TIME)) {
        if (rf12_recvDone() && rf12_crc == 0 &&
                // see http://talk.jeelabs.net/topic/811#post-4712
                rf12_hdr == (RF12_HDR_DST | RF12_HDR_CTL | myNodeID))
            return 1;
        set_sleep_mode(SLEEP_MODE_IDLE);
        sleep_mode();
    }
    return 0;
}

// Periodic report, i.e. send out a packet and optionally report on serial port
// We use this for telling the base the node is still alive
// The gateway will know this is a status message because it doesn't need an ACK
static void doReport() {
    rf12_sleep(RF12_WAKEUP);
    
    // Update battery status
    payload.lobat = rf12_lowbat();

    while (!rf12_canSend())
        rf12_recvDone();
    activityLed(1); 
    rf12_sendStart(0, &payload, sizeof payload, RADIO_SYNC_MODE);
    activityLed(0); 
    rf12_sleep(RF12_SLEEP);

    #if SERIAL
        Serial.print("BTN ");
        Serial.print((int) payload.buttons);
        Serial.print(' ');
        Serial.print((int) payload.lobat);
        Serial.println();
        delay(2); // make sure tx buf is empty before going back to sleep
    #endif
}

// send packet and wait for ack when there is a motion trigger
static void doTrigger() {
    #if DEBUG
        Serial.print("Buttonpress, going for TX ");
        Serial.print((int) payload.buttons);
        delay(2);
    #endif

    // Update battery status
    //payload.lobat = rf12_lowbat();

    // Send with ack
    for (byte i = 0; i < RETRY_LIMIT; ++i) {
        rf12_sleep(RF12_WAKEUP);
        while (!rf12_canSend())
            rf12_recvDone();
        activityLed(1); 
        rf12_sendStart(RF12_HDR_ACK, &payload, sizeof payload, RADIO_SYNC_MODE);
        activityLed(0); 
        byte acked = waitForAck();
        rf12_sleep(RF12_SLEEP);

        if (acked) {
            #if DEBUG
                Serial.print(" ack ");
                Serial.println((int) i);
                delay(2);
            #endif
            return;
        }
        
        Sleepy::loseSomeTime(RETRY_PERIOD * 100);
    }
    #if DEBUG
        Serial.println(" no ack!");
        delay(2);
    #endif
}

void setup () {
    #if SERIAL || DEBUG
        Serial.begin(57600);
        Serial.print("\n[buttonNode.1]");
    #endif
    rf12_initialize(myNodeID, RF12_868MHZ, myGroupID); // Init with node id 2, 868 MHz, fixed group 3    
    rf12_sleep(RF12_SLEEP); // power down RF module
}



