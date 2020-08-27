//main.c
#include "struct.h"

extern SAMPLESTRUCT Struct[2];
extern int opti_Od(void);
extern int opti_O1(void);

void begin(void)
{
    opti_Od();
    opti_O1();
}
