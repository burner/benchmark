void doNotOptimizeAwayImpl(void* p) 
{
	asm volatile("" : : "g"(p) : "memory");
}
