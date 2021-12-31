/*
    Based on Neil Kolban example for IDF: https://github.com/nkolban/esp32-snippets/blob/master/cpp_utils/tests/BLE%20Tests/SampleServer.cpp
    Ported to Arduino ESP32 by Evandro Copercini
    updates by chegewara
*/

#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

// See the following for generating UUIDs:
// https://www.uuidgenerator.net/

// constants
#define SERVICE_UUID        "deadbeef-1fb5-459e-8fcc-555555555555"
#define CHARACTERISTIC_UUID "b000b135-36e1-4688-b7f5-666666666666"
const std::string CMD_ON = "fan_on";
const std::string CMD_OFF = "fan_off";
#define LED_PIN 12

// member vars
BLECharacteristic *pCharacteristic = NULL;

/**
 * enableLED - turn the LED on or off
 */
void enableLED(bool en)
{
  digitalWrite(LED_PIN, (en ? HIGH : LOW));
}

/**
 * setup the pins and the BLE server
 */
void setup() 
{
  Serial.begin(115200);
  Serial.println("Starting BLE work!");

  // set the led as output
  pinMode(LED_PIN, OUTPUT);
  enableLED(false);

  BLEDevice::init("Fan Controller");
  BLEServer *pServer = BLEDevice::createServer();
  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
                                   CHARACTERISTIC_UUID,
                                   BLECharacteristic::PROPERTY_READ |
                                   BLECharacteristic::PROPERTY_WRITE
                                   );

  pCharacteristic->setValue("Hello World says Dan");
  pService->start();
  // BLEAdvertising *pAdvertising = pServer->getAdvertising();  // this still is working for backward compatibility
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  // functions that help with iPhone connections issue
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  Serial.println("Characteristic defined! Now you can read it in your phone!");
}

void loop() {
  // put your main code here, to run repeatedly:
  delay(2000);
  std::string val = pCharacteristic->getValue();
  Serial.print(" The Characteristic value is ");
  Serial.println(val.c_str());

  if (val == CMD_ON)
  {
    enableLED(true);
  }
  else if (val == CMD_OFF)
  {
    enableLED(false);
  }
}
