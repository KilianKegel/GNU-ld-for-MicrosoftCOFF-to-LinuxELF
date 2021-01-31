extern const char* wday_name_short[7];
extern const char* xday_name_short[7];
extern xfunc(const char*);
extern int i;

volatile int deadloopvar = 1;

void begin(void) 
{
    while (1 == deadloopvar)
        ;
    xfunc(wday_name_short[i]);
    xfunc(xday_name_short[i]);
}
