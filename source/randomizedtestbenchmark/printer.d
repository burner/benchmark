module randomizedtestbenchmark.printer;

import core.time : Duration;
import std.container.array : Array;
import std.range : isOutputRange;

import randomizedtestbenchmark.benchmark;
import randomizedtestbenchmark.execution;

/** Console based benchmark result printer.
This functions prints the results qrouped into by quantils of all passed
benchmarks.

Params:
	benchs = The $(D BenchmarkResult)
	quantils = The quantils to group the benchmarks results by, by default the
				quantils are $(D [0.01, 0.25, 0.5, 0.75, 0.99])
*/
template stdoutPrinter(Stats...)
{
	void execute(BenchmarkResult results) {

	}
}
