/*
  compile with:
    cl / TC / DLINUXTARGET = 1 / DUSEPRINTF4OUTPUT = 0 / nologo / c / O1 / GS - / Ob0 / FoBareCode4Linux.obj / DBREAKORNOP = __debugbreak() main.c
    cl / TC / DLINUXTARGET = 0 / DUSEPRINTF4OUTPUT = 0 / nologo / c / O1 / GS - / Ob0 / FoBareCode4Windo.obj / DBREAKORNOP = __nop()        main.c
    cl / TC / DLINUXTARGET = 0 / DUSEPRINTF4OUTPUT = 1 / nologo / O1 / GS - / Ob0 / FoWinConsole.obj / DBREAKORNOP = __nop() main.c
*/
volatile int deadloopvar = 1;

void xfunc(const char c)
{
    //
    // GDB: info registers 
    // GDB: check register CL to hold the expected value 0,1,2 .. A,B,C
    //
    __debugbreak();
}

void xstring(char* str)
{
    int i = 0;

    while (str[i])
        xfunc(str[i++]);
}

int main(int argc, char** argv)
{
    unsigned long long tsc; // tsc is just inserted to get BREAKORNOP generated 0xCC/0x90 opcode
                            // sync in the .OBJ/binary

    if (1) {
    //
    // NOTE: this arrangement of source code is just to have similiar machine code for Windows and Linux
    //
        BREAKORNOP;                     // NOP or INT3 depending on /DBREAKORNOP=__debugbreak() or /DBREAKORNOP=__nop()
        while (1 == deadloopvar)        // deadloop for Windows debugging
            ;

        tsc = __rdtsc();
    }

    if (tsc/*TSC is never, never 0*/)
    {
#define STRING0 "AB"

        int i, j, x;
        static char buffer[5] = { "1234" };                 // pre-inialized array
        //
        // NOTE: when accessing static data "indexed", the compiler uses __ImageBase addressing scheme
        //       (with optimization enabled only)
        //
        static size_t   sizeTable[] = { sizeof(STRING0) };  // array that is accessed "indexed"
        static char* stringTable[] = { STRING0 };           // array that is accessed "indexed"

        for (j = 0; j < sizeof(sizeTable) / sizeof(sizeTable[0]); j++)
        {

            x = (int)(sizeof(buffer) - sizeTable[j]) / 2;
            i = 0;

            while (stringTable[j][i])
                buffer[x++] = stringTable[j][i++];
            //
            // print/write "1AB4"
            //

#if     0 == USEPRINTF4OUTPUT
            xstring(buffer);
#else// 0 == USEPRINTF4OUTPUT
            printf("%s\n", buffer);
#endif//0 == USEPRINTF4OUTPUT
        }
    }
#if     0 == USEPRINTF4OUTPUT
    xfunc(0xAA);    // signal end of second loop
#endif//0 == USEPRINTF4OUTPUT
    return 0;
}
