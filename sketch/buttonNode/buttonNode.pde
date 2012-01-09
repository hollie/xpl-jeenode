// Button node. Used to report the status of a button press of switch closure/
// opening.
// Lieven Hollevoet, based on example code of JeeLabs
// http://opensource.org/licenses/mit-license.php

#include <Ports.h>
#include <RF12.h>

#define RETRY_PERIOD    10  // how soon to retry if ACK didn't come in
#define RETRY_LIMIT     5   // maximum number of times to retry
#define ACK_TIME        10  // number of milliseconds to wait for an ack

#define SERIAL 1

// set the sync mode to 2 if the fuses are still the Arduino default
// mode 3 (full powerdown) can only be used with 258 CK startup fuses
#define RADIO_SYNC_MODE 2

static byte myNodeID;  

// This defines the structure of the packets which get sent out by wireless:

struct {
    byte buttons;     // byte showing the button states 0..255
    byte lobat :1;  // supply voltage dropped under 3.1V: 0..1
} payload;

BlinkPlug blink (2); // Blink plug on port 2
MilliTimer everySecond;

void loop () {
    byte event = blink.buttonCheck();
    switch (event) {
        
    case BlinkPlug::ON1:
        Serial.println("  Button 1 pressed"); 
        break;
    
    case BlinkPlug::OFF1:
        Serial.println("  Button 1 released"); 
        break;
    
    case BlinkPlug::ON2:
        Serial.println("  Button 2 pressed"); 
        break;
    
    case BlinkPlug::OFF2:
        Serial.println("  Button 2 released"); 
        break;
    
    default:
        // report these other events only once a second
        if (everySecond.poll(1000)) {
            switch (event) {
                case BlinkPlug::SOME_ON:
                    Serial.println("SOME button is currently pressed");
                    break;
                case BlinkPlug::ALL_OFF:
                    Serial.println("NO buttons are currently pressed");
                    break;
            }
        }
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
        //set_sleep_mode(SLEEP_MODE_IDLE);
        //sleep_mode();
    }
    return 0;
}

// periodic report, i.e. send out a packet and optionally report on serial port
static void doReport() {
    rf12_sleep(RF12_WAKEUP);
    while (!rf12_canSend())
        rf12_recvDone();
    rf12_sendStart(0, &payload, sizeof payload, RADIO_SYNC_MODE);
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
        Serial.print("PIR ");
        Serial.print((int) payload.moved);
        delay(2);
    #endif

    for (byte i = 0; i < RETRY_LIMIT; ++i) {
        rf12_sleep(RF12_WAKEUP);
        while (!rf12_canSend())
            rf12_recvDone();
        rf12_sendStart(RF12_HDR_ACK, &payload, sizeof payload, RADIO_SYNC_MODE);
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
        myNodeID = rf12_config();
    #else
        myNodeID = rf12_config(0); // don't report info on the serial port
    #endif
    
    rf12_sleep(RF12_SLEEP); // power down
    
}



