#include <stdio.h>

#if defined(__DMC__)
static void* globalVariableToFroceDMCnotNoOptimze;
#endif

#if defined(WIN32) || defined(_WIN32) || defined(__WIN32) && !defined(__CYGWIN__)
extern int _getpid();
#else
extern int getpid();
#endif

void doNotOptimizeAwayImpl(void* p)
{
#if defined(__clang__) && defined(__GNUC__)
    asm volatile("" : : "g"(p) : "memory");
#elif defined(__DMC__)
    globalVariableToFroceDMCnotNoOptimze = p;
#else
#endif
#if defined(WIN32) || defined(_WIN32) || defined(__WIN32) && !defined(__CYGWIN__)
    if (_getpid() == 1)
#else
    if (getpid() == 1)
#endif
    {
        putchar(*((char*)p));
    }
}
