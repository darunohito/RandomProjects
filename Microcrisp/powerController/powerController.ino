//Microcrisp power manager

const int ledPin = 13;
const int powerSwitchPin = 2; //active low, inactive float
const int batteryVoltagePin = A0; //analog pin 0

uint32_t timerStart;
uint32_t timer;
uint32_t counter;
const float voltageScaleFactor = 0.0256348; // (51+12)/12 / 1024 * 5
float batteryVoltageOld;
float batteryVoltage;
uint8_t i; //index


const uint32_t batteryDebounce = 2000; //milliseconds before arduino will
//hibernate the PC after battery voltage drops below setpoint
const float batteryHysteresis = 2.2; //volts before PC will skip time wait and power up
const uint32_t longWait = 60000; //milliseconds before arduino will
//move from "startup" to "on" state, or from "on" to "hibernate" state

const float vMin = 11.2; //minimum battery voltage for operation

enum states {on, hibernate, startup} powerState = on;

float readBatteryVoltage(void);

void setup() {
  pinMode(ledPin, OUTPUT); digitalWrite(ledPin, HIGH);
  pinMode(powerSwitchPin, INPUT_PULLUP); digitalWrite(powerSwitchPin, LOW);
  pinMode(batteryVoltagePin, INPUT);
  Serial.begin(9600);
  Serial.println("Microcrisp Power Controller in Startup");
  Serial.print("Powerup voltage: ");  Serial.print(readBatteryVoltage());  Serial.println(" V");
  Serial.print("Lower limit: ");  Serial.print(vMin);  Serial.println(" V");
  delay(1000);
  digitalWrite(ledPin,LOW);
}

void loop() {
  // put your main code here, to run repeatedly:
  switch (powerState) {

    case on:
      batteryVoltage = readBatteryVoltage();
      for (i = 0; i < 10; i++) {
        Serial.print((char)8);
      }
      Serial.print(batteryVoltage); Serial.print(" V");
      if (batteryVoltage < vMin) {
        delay(batteryDebounce);
        if (readBatteryVoltage() < vMin) {
          Serial.print("\n HIBERNATING");
          pinMode(powerSwitchPin, OUTPUT);
          delay(500);
          pinMode(powerSwitchPin, INPUT_PULLUP);
          delay(longWait);
          powerState = hibernate;
          break;
        }
      }
      break;

    case hibernate:
      delay(longWait);
      batteryVoltage = readBatteryVoltage();
      if (batteryVoltage > (vMin + batteryHysteresis)) {
        delay(batteryDebounce);
        if (readBatteryVoltage() > (vMin + batteryHysteresis)) {
          powerState = startup;
        }
      }
      break;

    case startup:
      pinMode(powerSwitchPin, OUTPUT);
      delay(500);
      pinMode(powerSwitchPin, INPUT_PULLUP);
      delay(longWait);
      Serial.println("Started up");
      powerState = on;
      break;
  }
}

float readBatteryVoltage(void) {
  uint16_t vIn = analogRead(batteryVoltagePin);
  float voltage = vIn * voltageScaleFactor;
  return voltage;
};
