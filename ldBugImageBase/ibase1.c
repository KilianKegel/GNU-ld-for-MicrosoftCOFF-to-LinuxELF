extern const char* wday_name_short[7];
extern const char* xday_name_short[7];
extern xfunc(const char*);
extern int i;
extern volatile int deadloopvar;
void begin1(void) 
{
    while (1 == deadloopvar)
        ;
    xfunc(wday_name_short[i]);
    xfunc(wday_name_short[i]); // use wday_name_short a second time
}
