//opti_O1.c
#include "struct.h"

extern SAMPLESTRUCT Struct[2];

int opti_Od(void** rsp)
{

    Struct[0].c = 0x11;
    Struct[0].s = 0x2222;
    Struct[0].i = 0x44444444;
    Struct[0].ll = 0x8888888888888888;

    return -1;
}
