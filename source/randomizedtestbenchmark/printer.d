module randomizedtestbenchmark.printer;

import core.time : Duration;
import std.container.array : Array;
import std.range : isOutputRange;

import randomizedtestbenchmark.benchmark;
import randomizedtestbenchmark.execution;

/** Console based benchmark result printer.

Params:
	Stats = The statistic values to print for the past $(D results)
	results = The $(D BenchmarkResult) to print the statistics for
*/
struct stdoutPrinter(Stats...)
{
	this(BenchmarkResult results) {
		import std.stdio : writefln;
		import std.algorithm.sorting : sort;
		writefln("Results of Benchmark '%s'\nRandom number seed '%s'", 
				results.options.name,
				results.options.seed
			);
		foreach(ref it; results.results) {
			sort(it.ticks[]);	
			writefln("Function %-43s ran %5d times", it.funcname,
					it.curRound
				);
			stdoutImpl!(Stats).print(it);
		}
	}
}

private template stdoutImpl(Stats...) {
	void print(ref Benchmark bench) {
		import std.stdio : writefln;
		import std.range : assumeSorted;

		writefln("%-20s %40s hnsecs", Stats[0].name, 
				Stats[0].compute(assumeSorted(bench.ticks[])).total!"hnsecs"
			);
		static if(Stats.length > 1) {
			stdoutImpl!(Stats[1 .. $]).print(bench);
		}
	}
}
