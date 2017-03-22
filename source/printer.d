module printer;

import core.time : Duration;
import std.container.array : Array;

import benchmarkmodule;

private Duration getQuantilTick(A)(const auto ref A ticks, double q) pure @safe
{
    size_t idx = cast(size_t)(ticks.length * q);

    if (ticks.length % 2 == 1)
    {
        return ticks[idx];
    }
    else
    {
        return (ticks[idx] + ticks[idx - 1]) / 2;
    }
}

void stdoutPrinter(Array!Benchmark benchs) {
	import std.stdio : writefln;
	import std.algorithm.sorting : sort;
	foreach(ref it; benchs) {
		sort(it.ticks[]);
	}

	auto mst = medianStopWatchTime();
	writefln("Median Duration to start and stop StopWatch: %2d hnsecs", mst);
	auto qu = [0.01, 0.25, 0.5, 0.75, 0.99];
	foreach(ref it; benchs) {
		writefln("Function: %44s", it.funcname);
		foreach(q; qu) {
			writefln("Quantil %3.2f: %33d hnsecs", q, 
				getQuantilTick(it.ticks, q).total!("hnsecs")()
			);
		}
	}
}
