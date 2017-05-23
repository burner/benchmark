module randomizedtestbenchmark.statistics;

import std.container.array : Array, RangeT;
import core.time : Duration;
import std.range : SortedRange;

immutable defaultQuantils = [0.01, 0.25, 0.5, 0.75, 0.99];

alias SortedDurationArray = SortedRange!(RangeT!(Array!(Duration)), "a < b");

struct Quantil(double quantil) {
	static Duration compute(SortedDurationArray ticks)
	{
		import std.exception : enforce;
	
		enforce(ticks.length > 0, "Can't take the quantil of an empty range");
	    size_t idx = cast(size_t)(ticks.length * quantil);
	
	    if (ticks.length % 2 == 1)
	    {
	        return ticks[idx];
	    }
	    else
	    {
	        if (idx == 0)
	        {
	            return ticks[idx];
	        }
	        else
	        {
	            return (ticks[idx] + ticks[idx - 1]) / 2;
	        }
	    }
	}
}

unittest
{
	import core.time : dur;
	import std.meta : aliasSeqOf;

	Array!(Duration) durs;
	durs.insertBack(dur!"seconds"(2));

	void test(double q)() {
		import std.range : assumeSorted;

		alias Quan = Quantil!q;
		Duration r = Quan.compute(assumeSorted(durs[]));
		assert(r == durs[0]);
	}

	foreach(q; aliasSeqOf!(defaultQuantils)) {
		test!(q)();
	}
}

__EOF__

unittest
{
	import core.time : dur;
	Duration[2] durs;	
	durs[0] = dur!"seconds"(2);
	durs[1] = dur!"seconds"(2);
	foreach (q; defaultQuantils)
	{
		Duration r = getQuantilTick(durs[], q);
		assert(r == durs[0] || r == durs[1] 
			|| r == (durs[0] + durs[1]) / 2
		);
	}
}

void validateData(const(BenchmarkResults) benchs) 
{
	foreach (it; benchs.quantils)
	{
	    assert(it <= 1.0, "Quantils must be less equal to 1.0");
	}
}
