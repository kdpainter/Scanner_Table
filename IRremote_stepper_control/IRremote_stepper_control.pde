#include <stdint.h>
#include <TimerOne.h>
#include "Arduino.h"
//#include <avr/pgmspace.h>
#include <IRremote.h>
#include "swtimer.h"
#include "A4988.h"

#define  LC_INCLUDE "lc-addrlabels.h"
#include "pt.h"
#include "pt_sem_kdp.h"

typedef struct IRcodestype {
  uint32_t code;
  char *text_code;
  uint8_t id_code;
};

enum KEYS {ZERO, ONE, TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE,
					 CH_MINUS, CH, CH_PLUS, REV, FWD, PLAY, MINUS, PLUS, EQ, 
					 ONE_HUNDRED_PLUS, TWO_HUNDRED_PLUS};
					 
const IRcodestype remote_codes[] = {
  {0xFFA25D, "CH-",  CH_MINUS},
  {0xFF629D, "CH",   CH},
  {0xFFE21D, "CH+",  CH_PLUS},
  {0xFF22DD, "<<",   REV},
  {0xFF02FD, ">>",   FWD},
  {0xFFC23D, ">|",   PLAY},
  {0xFFE01F, "-",    MINUS},
  {0xFFA857, "+",    PLUS},
  {0xFF906F, "EQ",   EQ},
  {0xFF6897, "0",    ZERO},
  {0xFF9867, "100+", ONE_HUNDRED_PLUS},
  {0xFFB04F, "200+", TWO_HUNDRED_PLUS},
  {0xFF30CF, "1",    ONE},
  {0xFF18E7, "2",    TWO},
  {0xFF7A85, "3",    THREE},
  {0xFF10EF, "4",    FOUR},
  {0xFF38C7, "5",    FIVE},
  {0xFF5AA5, "6",    SIX},
  {0xFF42BD, "7",    SEVEN},
  {0xFF4AB5, "8",    EIGHT},
  {0xFF52AD, "9",    NINE},
};

int16_t RECV_PIN = 12;


IRrecv irrecv(RECV_PIN);
decode_results results;

//declare protothreads
static struct pt pt_ir_receiver, pt_heartbeat;

bool hb_blink = true;

//Software timers
#define NUM_OF_TIMERS (4)
enum {IR_TIMER, HB_TIMER, STEP_TIMER, EXPOSURE_TIMER};
timertype timers[NUM_OF_TIMERS];

A4988 stepper(200, 1, 2);

void setup() {
  // Initialize protothreads:
  PT_INIT(&pt_ir_receiver);
  PT_INIT(&pt_heartbeat);

  pinMode(LED_BUILTIN, OUTPUT);
  pinMode(RECV_PIN, INPUT);
  irrecv.enableIRIn(); // Start the receiver

  // Open serial communications and wait for port to open:
  Serial.begin(115200);
  while (!Serial)
    ; // wait for serial port to connect. Needed for native USB port only
  delay(100);
  Serial.println("Turntable controller");

	//stepper 
	Serial.println("Init stepper driver");
;
	stepper.set_timer(&timers[STEP_TIMER], 0);
	//stepper.set_dir(1);
	
	//Timer setup
  Timer1.initialize(1000); // set timer1 to 1000 microseconds
  Timer1.attachInterrupt( timer1Isr ); // attach the service routine here
}

void loop() {
  // Reschedule threads here:
  IR_Receiver_thread(&pt_ir_receiver);
  Heartbeat_thread(&pt_heartbeat);
  stepper.schedule_thread();
}


static int IR_Receiver_thread(struct pt *pt) {
  static pt_sem irreceiver_timer_semaphore;

  PT_BEGIN(pt);

  noInterrupts ();
  timers[IR_TIMER]._sem = &irreceiver_timer_semaphore;
  timers[IR_TIMER].timer = timers[IR_TIMER].reloadtimer = 0;  //Timer disabled, do not auto reload
  interrupts ();

  PT_SEM_INIT(&irreceiver_timer_semaphore, 0);
  Serial.println("Waiting IR Receiver");
  while (1) {
    PT_WAIT_UNTIL(pt, irrecv.decode(&results));
    for (uint8_t k = 0; k <= 20; k++)
    {
      if (results.value == remote_codes[k].code)
      {
        Serial.println(remote_codes[k].text_code);
        switch(remote_codes[k].id_code) {
        	case CH_MINUS:
        	  hb_blink = false;
        	  break;
        	case CH_PLUS:
        	  hb_blink = true;
        	  break;
        	case PLAY:
        		stepper.rotate_degrees(10.0, 1);
        		break;
        	default:
        		break;
        	};
        
        break;
      }
    }
    timers[IR_TIMER].timer = 250; // Wait 250 ms, do not auto reload
    PT_SEM_WAIT(pt, &irreceiver_timer_semaphore);
    irrecv.resume(); // Receive the next value
  }
  PT_END(pt);
}


uint16_t Heartbeat_thread(struct pt *pt) {
  static pt_sem heartbeat_timer_semaphore;
  static uint8_t led = 0;

  PT_BEGIN(pt);
  noInterrupts ();
  timers[HB_TIMER]._sem = &heartbeat_timer_semaphore;
  timers[HB_TIMER].timer = timers[1].reloadtimer = 1000; //auto reload
  interrupts ();

  PT_SEM_INIT(&heartbeat_timer_semaphore, 0);
  digitalWrite(LED_BUILTIN, led);
  Serial.println("Starting heartbeat LED");
  while (1) {
    PT_SEM_WAIT(pt, &heartbeat_timer_semaphore);
    led = ~led;
    if(hb_blink)
      digitalWrite(LED_BUILTIN, led);
    else
      digitalWrite(LED_BUILTIN, LOW);
  }
  PT_END(pt);
}


/// --------------------------
/// Timer1 ISR
/// --------------------------
void timer1Isr()
{
  for (uint8_t i = 0; i < NUM_OF_TIMERS; i++)
    if (timers[i].timer != 0)
      if (--timers[i].timer == 0)
      {
        PT_SEM_SIGNAL(timers[i]._sem);
        if (timers[i].reloadtimer != 0)
          timers[i].timer = timers[i].reloadtimer;
      }
}




