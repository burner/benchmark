module randomizedbenchmark.printer;

import core.time : Duration;
import std.container.array : Array;

import randomizedbenchmark.benchmark;

private Duration getQuantilTick(A)(const auto ref A ticks, double q) pure @safe
{
    size_t idx = cast(size_t)(ticks.length * q);

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

/** Console based benchmark result printer.
This functions prints the results qrouped into by quantils of all passed
benchmarks.

Params:
	benchs = The benchmarks
	quantils = The quantils to group the benchmarks results by, by default the
				quantils are $(D [0.01, 0.25, 0.5, 0.75, 0.99])
*/
void stdoutPrinter(Array!Benchmark benchs, double[] quantils) {
	import std.stdio : writefln;
	import std.algorithm.sorting : sort;
	version(unittest) {
		foreach(it; quantils) {
			assert(it <= 1.0, "Quantils must be less equal to 1.0");
		}
	}
	foreach(ref it; benchs) {
		sort(it.ticks[]);
	}

	auto mst = medianStopWatchTime();
	writefln("Median Duration to start and stop StopWatch: %2d hnsecs", mst);
	foreach(ref it; benchs) {
		writefln("Function: %44s", it.funcname);
		foreach(q; quantils) {
			writefln("Quantil %3.2f: %33d hnsecs", q, 
				getQuantilTick(it.ticks, q).total!("hnsecs")()
			);
		}
	}
}

/// Ditto
void stdoutPrinter(Array!Benchmark benchs) {
	stdoutPrinter(benchs, [0.01, 0.25, 0.5, 0.75, 0.99]);
}
