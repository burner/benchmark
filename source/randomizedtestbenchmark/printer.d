module randomizedtestbenchmark.printer;

import core.time : Duration;
import std.container.array : Array;
import std.range : isOutputRange;

import randomizedtestbenchmark.benchmark;
import randomizedtestbenchmark.execution;

private Duration getQuantilTick(A)(const auto ref A ticks, double q) pure @safe
{
	import std.exception : enforce;

	enforce(ticks.length > 0, "Can't take the quantil of an empty range");
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

unittest
{
	import core.time : dur;
	Duration[1] durs;	
	durs[0] = dur!"seconds"(2);
	foreach (q; defaultQuantils)
	{
		Duration r = getQuantilTick(durs[], q);
		assert(r == durs[0]);
	}
}

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

/** Console based benchmark result printer.
This functions prints the results qrouped into by quantils of all passed
benchmarks.

Params:
	benchs = The $(D BenchmarkResult)
	quantils = The quantils to group the benchmarks results by, by default the
				quantils are $(D [0.01, 0.25, 0.5, 0.75, 0.99])
*/
void stdoutPrinter(Stats, Out)(BenchmarkResult benchs, Stats stats,
	   	Out output) 
{
	stats.process(benchs, output);
}

void stdoutPrinter(Stats)(BenchmarkResult benchs, Stats stats)
{
	import std.stdio : stdout;

	auto ltw = stdout.lockingTextWriter();
	stats.process(ltw);
}

/// Ditto
void stdoutPrinter(BenchmarkResult benchs)
{
    stdoutPrinter(benchs, Quantils(defaultQuantils));
}

void gnuplotDataPrinter(BenchmarkResult benchs) 
{
	gnuplotDataPrinter(benchs, benchs.options.name);
}

void gnuplotDataPrinter(BenchmarkResult benchs, string filename) 
{
	import std.stdio : File;

	auto f = File(filename, "a");

	gnuplotDataPrinter(benchs, f.lockingTextWriter(), defaultQuantils);
}

void gnuplotDataPrinter(LTW)(BenchmarkResult benchs, LTW ltw, 
		immutable(double[]) quantils) if (isOutputRange!(LTW, string))
{
	import std.datetime : Clock;
    import std.algorithm.sorting : sort;
	import std.format : formattedWrite;

	string now = Clock.currTime.toISOExtString();
    auto mst = medianStopWatchTime();

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

	foreach (ref it; benchs.results) 
	{
		formattedWrite!"%s %s %s"(ltw, it.funcname, now, mst);
		foreach (q; quantils)
		{
			formattedWrite!" %s"(ltw,
				getQuantilTick(it.ticks, q).total!("hnsecs")()
			);
		}
		formattedWrite!"\n"(ltw);
	}
}
