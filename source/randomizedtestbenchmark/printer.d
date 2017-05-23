module randomizedtestbenchmark.printer;

import core.time : Duration;
import std.container.array : Array;
import std.range : isOutputRange;

import randomizedtestbenchmark.benchmark;
import randomizedtestbenchmark.execution;

__EOF__

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
