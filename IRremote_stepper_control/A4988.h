

#ifndef A4988_HDR
#define A4988_HDR

#include <stdint.h>
#include "Arduino.h"
#define  LC_INCLUDE "lc-addrlabels.h"
#include "pt.h"
#include "pt_sem_kdp.h"
#include "swtimer.h"


class A4988 {
  private:
    bool      _dir;
    uint8_t   _microstep;
    uint8_t   _steps_per_rev;
    uint8_t   _dwell_time_per_step;
    //Pins    
    uint8_t   _step_pin;
    uint8_t   _dir_pin;
    uint8_t   _enable_pin;
    uint8_t   _reset_pin;
    uint8_t   _sleep_pin;
    uint8_t   _ms1_pin;
    uint8_t   _ms2_pin;
    uint8_t   _ms3_pin;
    
    pt_sem    _step_semaphore;
    struct pt _pt_step_thread;
    
    timertype *_step_timer;
    
  private:    
  void strobe_step(void);
  int step_thread(struct pt *pt);
    
    
  public:
    A4988(uint8_t steps_per_rev, uint8_t step_pin, uint8_t dir_pin);
    void set_dir(bool dir);
    void set_timer(timertype *timer, uint8_t time_per_step);
    void step(uint8_t steps);
    void rotate_degrees(float degrees, bool dir);
    
    void schedule_thread(void);
};


#endif //A4988_HDR
