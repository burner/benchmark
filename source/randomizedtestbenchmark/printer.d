module randomizedtestbenchmark.printer;

import core.time : Duration;
import std.container.array : Array;

import randomizedtestbenchmark.benchmark;
import randomizedtestbenchmark.execution;

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
	benchs = The $(D BenchmarkResult)
	quantils = The quantils to group the benchmarks results by, by default the
				quantils are $(D [0.01, 0.25, 0.5, 0.75, 0.99])
*/
void stdoutPrinter(BenchmarkResult benchs, double[] quantils)
{
    import std.stdio : writefln;
    import std.algorithm.sorting : sort;

    version (unittest)
    {
        foreach (it; quantils)
        {
            assert(it <= 1.0, "Quantils must be less equal to 1.0");
        }
    }
    foreach (ref it; benchs.results)
    {
        sort(it.ticks[]);
    }

	writefln("Benchmark \"%s\" with maximal rounds \"%d\", "
			~ "maximal duration \"%s\", and seed \"%d\".",
			benchs.options.name, benchs.options.maxRounds, 
			benchs.options.maxTime, benchs.options.seed
	);

    auto mst = medianStopWatchTime();
    writefln("Median duration to start and stop the StopWatch: %2d hnsecs", mst);
    foreach (ref it; benchs.results)
    {
        writefln("Function: %44s run %d times", it.funcname, it.curRound);
        foreach (q; quantils)
        {
            writefln("Quantil %3.2f: %33d hnsecs", q, getQuantilTick(it.ticks,
                q).total!("hnsecs")());
        }
    }
}

/// Ditto
void stdoutPrinter(BenchmarkResult benchs)
{
    stdoutPrinter(benchs, [0.01, 0.25, 0.5, 0.75, 0.99]);
}
