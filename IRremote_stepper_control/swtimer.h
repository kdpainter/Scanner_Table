
#ifndef SWTIMER_HDR
#define SWTIMER_HDR


#include <stdint.h>
#include "pt.h"
#include "pt_sem_kdp.h"

typedef struct timertype {
  uint16_t timer;
  uint16_t reloadtimer;
  struct pt_sem *_sem;
};

#endif //SWTIMER_HDR