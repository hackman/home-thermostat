/*
  Arduino Yún Bridge example

  This example for the Arduino Yún shows how to use the
  Bridge library to access the digital and analog pins
  on the board through REST calls. It demonstrates how
  you can create your own API when using REST style
  calls through the browser.

  Possible commands created in this shetch:

  "/arduino/digital/13"     -> digitalRead(13)
  "/arduino/digital/13/1"   -> digitalWrite(13, HIGH)
  "/arduino/analog/2/123"   -> analogWrite(2, 123)
  "/arduino/analog/2"       -> analogRead(2)
  "/arduino/mode/13/input"  -> pinMode(13, INPUT)
  "/arduino/mode/13/output" -> pinMode(13, OUTPUT)

  This example code is part of the public domain

  http://www.arduino.cc/en/Tutorial/Bridge

  "/arduino/8"				-> gets you the current temperature 
							   and humidity as expored by the 
							   DHT22 sensor, connected on pin 8
 PIN 8 - DHT22 sensor
 PIN 7 - Heating pump relay
 PIN 6 - Floor pump relay

*/

#define VERSION 0.5
#include <Bridge.h>
#include <YunServer.h>
#include <YunClient.h>
#include <DHT.h>



#define DHTPIN 8
#define DHTTYPE DHT22
DHT dht(DHTPIN, DHTTYPE);

#define HEATER_PUMP 7
#define FLOOR_PUMP 6
// in miliseconds
#define STEP_BETWEEN_MEASUREMENTS 5000

// Listen to the default port 5555, the Yún webserver
// will forward there all the HTTP requests you send
YunServer server;

int pins[13] = { 0 };
unsigned long current_time = 0;
unsigned long last_time = 0;
float humidity = 0.0;
float temperature = 0.0;

void setup() {
  // Set the pumps to OFF
  pinMode(HEATER_PUMP, OUTPUT);
  pinMode(FLOOR_PUMP, OUTPUT);
  digitalWrite(HEATER_PUMP, HIGH);
  digitalWrite(FLOOR_PUMP, HIGH);
  pins[7]=1;
  pins[6]=1;

  // Bridge startup
  Serial.begin(9600);
  pinMode(13, OUTPUT);
  digitalWrite(13, LOW);
  Bridge.begin();
  digitalWrite(13, HIGH);

  // Listen for incoming connection only from localhost
  // (no one from the external network could connect)
  server.listenOnLocalhost();
  server.begin();
}

void loop() {
  // Get clients coming from server
  YunClient client = server.accept();

  // There is a new client?
  if (client) {
    // Process request
    process(client);

    // Close connection and free resources.
    client.stop();
  }

  delay(50); // Poll every 50ms
}

void process(YunClient client) {
  // read the command
  String command = client.readStringUntil('/');

  // is "digital" command?
  if (command == "digital") {
    digitalCommand(client);
  }

  // is "analog" command?
  if (command == "analog") {
    analogCommand(client);
  }

  // is "mode" command?
  if (command == "mode") {
    modeCommand(client);
  }
}

int ready_to_update() {
	current_time = millis();
	int ret = 0;
	// if the millis() have overflown
	// once every 50 days it will take 10secs to update the timer :). Which should be OK.
	if (current_time < last_time) {
		last_time = current_time;
	}
	if ((current_time - last_time) > STEP_BETWEEN_MEASUREMENTS) {
		ret = 1;
	}
	last_time = current_time;
	return ret;
}


void digitalCommand(YunClient client) {
  int pin, value;

  // Read pin number
  pin = client.parseInt();

  if (pin == 8) {
	if (ready_to_update()) {
	    humidity = dht.readHumidity();
	    temperature = dht.readTemperature();
	    if (isnan(humidity) || isnan(temperature)) {
	      client.println("Failed to read from the DHT sensor!");
	      return;
	    }
	}
    client.print("Temperature: ");
    client.print(temperature);
    client.print("C  Humidity: ");
    client.println(humidity);
    return;
  }


  // If the next character is a '/' it means we have an URL
  // with a value like: "/digital/13/1"
  if (client.read() == '/') {
    value = client.parseInt();
    digitalWrite(pin, value);
    pins[pin] = value;
  } else {
    //value = digitalRead(pin);
    value = pins[pin];
  }
  if (value) {
    client.println("off");
  } else {
    client.println("on");
  }

  // Update datastore key with the current pin value
  String key = "D";
  key += pin;
  Bridge.put(key, String(value));
}

void analogCommand(YunClient client) {
  int pin, value;

  // Read pin number
  pin = client.parseInt();

  // If the next character is a '/' it means we have an URL
  // with a value like: "/analog/5/120"
  if (client.read() == '/') {
    // Read value and execute command
    value = client.parseInt();
    analogWrite(pin, value);

    // Send feedback to client
    client.print(F("Pin D"));
    client.print(pin);
    client.print(F(" set to analog "));
    client.println(value);

    // Update datastore key with the current pin value
    String key = "D";
    key += pin;
    Bridge.put(key, String(value));
  } else {
    // Read analog pin
    value = analogRead(pin);

    // Send feedback to client
    client.print(F("Pin A"));
    client.print(pin);
    client.print(F(" reads analog "));
    client.println(value);

    // Update datastore key with the current pin value
    String key = "A";
    key += pin;
    Bridge.put(key, String(value));
  }
}

void modeCommand(YunClient client) {
  int pin;

  // Read pin number
  pin = client.parseInt();

  // If the next character is not a '/' we have a malformed URL
  if (client.read() != '/') {
    client.println(F("error"));
    return;
  }

  String mode = client.readStringUntil('\r');

  if (mode == "input") {
    pinMode(pin, INPUT);
    // Send feedback to client
    client.print(F("Pin D"));
    client.print(pin);
    client.print(F(" configured as INPUT!"));
    return;
  }

  if (mode == "output") {
    pinMode(pin, OUTPUT);
    // Send feedback to client
    client.print(F("Pin D"));
    client.print(pin);
    client.print(F(" configured as OUTPUT!"));
    return;
  }

  client.print(F("error: invalid mode "));
  client.print(mode);
}


