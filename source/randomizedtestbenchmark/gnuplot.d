module randomizedtestbenchmark.gnuplot;

import randomizedtestbenchmark.benchmark;
import randomizedtestbenchmark.execution;

/** gnuplot based benchmark result printer.

Params:
	Stats = The statistic values to print for the past $(D results)
	results = The $(D BenchmarkResult) to print the statistics for
	filenamePrefix = The prefix of the filenames of the gnuplot data file and
		the gnuplot file
*/
struct gnuplot(Stats...)
{
	this(BenchmarkResult results) {
		this(results, results.options.name);
	}

	this(BenchmarkResult results, string filenamePrefix) {
		import std.stdio : File;
		import std.datetime : Clock;
		import std.algorithm.sorting : sort;

		auto data = File(filenamePrefix ~ ".data", "a");
		auto dataLTW = data.lockingTextWriter();

		auto currentTime = Clock.currTime();
		string timeString = currentTime.toISOExtString();

		foreach(ref it; results.results) {
			sort(it.ticks[]);	
			gnuplotImpl!(Stats).print(it, dataLTW, timeString);
		}
	}
}

private template gnuplotImpl(Stats...) {
	void print(Out)(ref Benchmark bench, ref Out ltw, string date) {
		import std.format : formattedWrite;
		import std.range : assumeSorted;

		formattedWrite(ltw, "%s %s %s %s\n", bench.funcname, Stats[0].name,
				date, Stats[0].compute(assumeSorted(bench.ticks[])).total!"hnsecs"
			);
		static if(Stats.length > 1) {
			gnuplotImpl!(Stats[1 .. $]).print(bench, ltw, date);
		}
	}
}
