//opti_O1.c
#include "struct.h"

extern SAMPLESTRUCT Struct[2];

int opti_O1(void** rsp)
{

    Struct[0].c = 0x12;
    Struct[0].s = 0x2233;
    Struct[0].i = 0x44445555;
    Struct[0].ll = 0x8888888899999999;

    return -1;
}
