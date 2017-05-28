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
	import std.stdio : File;
	import std.container.array : Array;
	import std.format : formattedWrite;
	import std.datetime : DateTime;
	import core.time : Duration;

	struct ResultEntry {
		DateTime datetime;
		Array!Duration entries;
	}

	struct Result {
		string functionName;
		Array!ResultEntry entries;

		this(string functionName, ResultEntry re) {
			this.functionName = functionName;
			entries.insertBack(re);
		}
	}

	this(BenchmarkResult results) {
		this(results, buildFilenamePrefix(results));
	}

	this(BenchmarkResult results, string filenamePrefix) {
		import std.stdio;

		this.writeDataFile(results, filenamePrefix);
		Array!Result oldResults = readResults(filenamePrefix);
	}

	static string buildFilenamePrefix(BenchmarkResult results) {
		import std.array : appender, empty;
		if(!results.options.name.empty) {
			return results.options.name;
		} else {
			auto app = appender!string();
			size_t idx;
			foreach(ref it; results.results) {
				if(idx > 0) {
					app.put('_');
				}
				app.put(it.funcname);
				++idx;
			}
			return app.data;
		}
	}

	void writeDataFile(BenchmarkResult results, string filenamePrefix) {
		import std.datetime : Clock;
		import std.algorithm.sorting : sort;

		auto data = File(filenamePrefix ~ ".data", "a");
		auto dataLTW = data.lockingTextWriter();

		auto currentTime = Clock.currTime();
		string timeString = currentTime.toISOExtString();

		foreach(ref it; results.results) {
			sort(it.ticks[]);	
			writeData(it, dataLTW, timeString);
		}
	}

	private static bool cmp(char[] a, Result b) {
		return b.functionName == a;
	}

	private static Array!Result readResults(string filenamePrefix) {
		import std.algorithm.iteration : splitter;
		import std.algorithm.searching : find;
		import std.conv : to;
		Array!Result ret;
		auto data = File(filenamePrefix ~ ".data", "r");
		foreach(line; data.byLine()) {
			auto sp = line.splitter(',');
			char[] name = sp.front;
			sp.popFront();

			auto entry = find!(a => a.functionName == name)(ret[]);
			if(entry.empty) {
				ret.insertBack(Result(to!string(name), parseLine(sp)));
			} else {
				entry.front.entries.insertBack(parseLine(sp));
			}
		}

		return ret;
	}

	private static ResultEntry parseLine(Line)(ref Line line) {
		import std.conv : to;
		import core.time : dur;
		ResultEntry ret;

		ret.datetime = cast(DateTime)SysTime.fromISOExtString(line.front);
		line.popFront();
		while(!line.empty) {
			ret.entries.insertBack(dur!"hnsecs"(to!long(line.front)));
			line.popFront();
		}

		return ret;
	}

	private static void writeData(Out)(ref Benchmark bench, ref Out ltw, 
			string date) 
	{
		import std.range : assumeSorted;
	
		formattedWrite(ltw, "%s,%s", bench.funcname, date);
		foreach(ref it; bench.ticks[]) {
			formattedWrite(ltw, ",%s", it.total!"hnsecs"());
		}
		formattedWrite(ltw, "\n");
	}

	private static void writeOutSelectedData(Out, St...)(ref Array!Result result, 
			ref Out ltw)
	{
		foreach(ref it; result[]) {
			formattedWrite(ltw, "%s %s %s\n", it.funcname);
		}

	}
}
