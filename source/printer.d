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

	writefln("Quantils: %10.2f%15.2f%15.2f%15.2f%15.2f",
		   	0.01, 0.25, 0.5, 0.75, 0.99);
	foreach(ref it; benchs) {
		writefln("%80s", it.funcname);
		writefln("     %15.11f%15.11f%15.11f%15.11f%15.11f",
			getQuantilTick(it.ticks, 0.01).total!("hnsecs")() * 1_000_000.0,
			getQuantilTick(it.ticks, 0.25).total!("hnsecs")() * 1_000_000.0,
			getQuantilTick(it.ticks, 0.5).total!("hnsecs")() * 1_000_000.0,
			getQuantilTick(it.ticks, 0.75).total!("hnsecs")() * 1_000_000.0,
			getQuantilTick(it.ticks, 0.99).total!("hnsecs")() * 1_000_000.0
		);
	}
}
