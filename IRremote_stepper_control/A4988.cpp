

#include "A4988.h"
extern timertype timers[];

A4988::A4988(uint8_t steps_per_rev, uint8_t step_pin, uint8_t dir_pin)
	{
		_steps_per_rev = steps_per_rev;
		_step_pin = step_pin;
		_dir_pin = dir_pin;
		
		pinMode(_step_pin, OUTPUT);
		pinMode(_dir_pin, OUTPUT);
		digitalWrite(_dir_pin, _dir);
		
		PT_INIT(&_pt_step_thread);
  
	}
/*
void A4988::do_full_revolution(float degrees)
{
	
}
*/

void A4988::rotate_degrees(float degrees, bool dir)
{
	uint16_t steps;
	
	set_dir(dir);
	steps = (uint16_t)((((float)(_steps_per_rev) * 6.2) * (degrees / 360.0)) + 0.5);
	Serial.print("Rotate steps: ");
	Serial.print(steps, DEC);
	Serial.println("");
	step(steps);
}

void A4988::set_dir(bool dir)
{
	if(_dir != dir)
		{
			_dir = dir;
			digitalWrite(_dir_pin, _dir);
		}
}

void A4988::step(uint8_t steps)
{
	//Serial.println("Signal semaphore");
	PT_SEM_SET(&_step_semaphore, steps);
}

void A4988::strobe_step(void)
{
	digitalWrite(_step_pin, HIGH);
	digitalWrite(_step_pin, HIGH);		
}

void A4988::set_timer(timertype *timer, uint8_t time_per_step)
{
	PT_SEM_INIT(&_step_semaphore, 0);
	
	_dwell_time_per_step = time_per_step;
	_step_timer = timer;
	_step_timer->_sem = &_step_semaphore;
	_step_timer->timer = 0;
	_step_timer->reloadtimer = 0;
}

void A4988::schedule_thread(void)
{
	step_thread(&_pt_step_thread);
}

int A4988::step_thread(struct pt *pt)
{
	PT_BEGIN(pt);
	
	Serial.println("Wait step thread");
		
	while(1) {
		PT_SEM_WAIT(pt, &_step_semaphore);
		strobe_step();		//Step the stepper
		Serial.println("Step");
		
		//Auto reload timer??
		if((PT_SEM_GET(&_step_semaphore)) && (_step_timer->reloadtimer == 0))
			{
				//If sw timer isn't running, start it.
				if(_step_timer->timer == 0)
					{
						noInterrupts();
						_step_timer->timer = _dwell_time_per_step;
						interrupts();
					}
				_step_timer->reloadtimer = _dwell_time_per_step; //More than one step remaining and AR not set
			}
		else
			{ //None are left, wait one more and then fire camera		
				_step_timer->reloadtimer = 0;  //First kill AR		
				PT_SEM_SIGNAL(&_step_semaphore);
				PT_SEM_WAIT(pt, &_step_semaphore);
				
				Serial.println("Fire camera");
				//fire_camera();  //TODO: define
			}
		}
	PT_END(pt);
}

