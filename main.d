import std.experimental.logger;
import std.experimental.randomized_unittest_benchmark;

void fun(int a, float b) {
	logf("%s %s", a, b);
	doNotOptimizeAway(&a);
}

void main(string[] args)
{
	benchmark!fun();
}
