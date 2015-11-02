void doNotOptimizeAway(void* p) 
{
	asm volatile("" : : "g"(p) : "memory");
}
