module randomizedtestbenchmark.gnuplot;

import std.container.array : Array;

import randomizedtestbenchmark.benchmark;
import randomizedtestbenchmark.execution;
import randomizedtestbenchmark.statistics;

struct ResultEntry {
	import std.datetime : DateTime;
	import core.time : Duration;

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
	import std.datetime : DateTime, SysTime;
	import core.time : Duration;

	this(BenchmarkResult results) {
		this(results, buildFilenamePrefix(results));
	}

	this(BenchmarkResult results, string filenamePrefix) {
		import std.stdio;

		this.writeDataFile(results, filenamePrefix);
		Array!Result oldResults = readResults(filenamePrefix);
		writeGnuplotData!(Stats)(oldResults, filenamePrefix);
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
}

//set format x %s
auto gnuplotString = q"{set title "%s"
set terminal pngcairo enhanced font 'Verdana,10'
set ylabel "Time (hnsecs) Single Call"
set term png
set output "%s"
set key invert reverse Left outside
set key autotitle columnheader
set style data histograms
set style histogram rowstacked
set style fill solid border
set offset graph 0.10, 0.10
set xtics rotate by -90 offset 0,0
set grid
plot '%s' }";

private void writeGnuplotData(St...)(ref Array!Result result, 
		string filenamePrefix)
{
	import std.range : assumeSorted;
	import std.stdio : File;
	import std.format : formattedWrite;
	import std.array : replace;

	foreach(ref it; result[]) {
		string dataFilename = filenamePrefix ~ it.functionName ~ ".data";
		auto f = File(dataFilename, "w");
		auto ltw = f.lockingTextWriter();
		foreach(ref jt; it.entries[]) {
			formattedWrite(ltw, "%s", jt.datetime.toISOExtString());
			writeGnuplotDataImpl!(typeof(ltw),St)(
					ltw, assumeSorted(jt.entries[])
				);
			formattedWrite(ltw, "\n");
		}

		auto gf = File(filenamePrefix ~ it.functionName ~ ".gp", "w");
		auto ltw2 = gf.lockingTextWriter();
		formattedWrite(ltw2, gnuplotString, 
				it.functionName.replace("_", "\\\\_"),
				filenamePrefix ~ it.functionName ~ ".png",
				dataFilename
			);
		writeGnuplotImpl!(typeof(ltw2), St)(ltw2, 2);
	}
}

private void writeGnuplotDataImpl(Out, St...)(ref Out ltw, 
		SortedDurationArray durs) 
{
	import std.format : formattedWrite;

	formattedWrite(ltw, " %s", St[0].compute(durs).total!"hnsecs"());
	static if(St.length > 1) {
		writeGnuplotDataImpl!(Out, St[1 .. $])(ltw, durs);
	}	
}

private void writeGnuplotImpl(Out, St...)(ref Out ltw, size_t idx) {
	import std.format : formattedWrite;

	if(idx > 2) {
		formattedWrite(ltw, ", ''");
	}

	formattedWrite(ltw, " using %d:xtic(1) title \"%s\"", 
			idx, St[0].name
		);
	static if(St.length > 1) {
		writeGnuplotImpl!(Out, St[1 .. $])(ltw, idx + 1);
	}	
}
