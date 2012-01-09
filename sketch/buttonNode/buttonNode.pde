// Button node. Used to report the status of a button press of switch closure/
// opening.
// Lieven Hollevoet, based on example code of Jean-Claude Wippler.

#include <Ports.h>
#include <RF12.h>

BlinkPlug blink (2); // Blink plug on port 2
MilliTimer everySecond;

void setup () {
    Serial.begin(57600);
    Serial.println("\n[button_demo]");
}

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


