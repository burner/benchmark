module execution;

import std.container.array : Array;

import benchmarkmodule : Benchmark;

struct BenchmarkOptions {
	import core.time : Duration;
	/* the name of the benchmark */
	const(string) name;
	/* the number of times the functions is supposed to be
   	executed */
    const(size_t) maxRounds; 
	/* the maximum time the benchmark should take*/
    const(Duration) maxTime;
	/* a seed value for the random number generator */
	const(uint) seed;

	this(string name, size_t maxRounds, Duration maxTime, uint seed) {
		this.name = name;
		this.maxRounds = maxRounds;
		this.maxTime = maxTime;
		this.seed = seed;
	}
}

bool realExecuter(alias Fun, Values)(ref BenchmarkOptions options, 
		ref Benchmark bench, ref Values values) 
{
	bench.start();
	static if(is(typeof(Fun) == void)) {
		Fun(values.values);
	} else {
		import benchmarkmodule : doNotOptimizeAway;
		doNotOptimizeAway(Fun(values.values));
	}
	bench.stop();
	bench.curRound++;

	return bench.curRound > options.maxRounds 
		|| bench.timeSpend > options.maxTime;
}

template executeImpl(Funcs...) if(Funcs.length == 1) {
	bool impl(Values)(BenchmarkOptions options, 
			Array!(Benchmark).Range benchmarks, ref Values values) 
	{
		return realExecuter!(Funcs[0])(options, benchmarks[0], values);
	}
}	

template executeImpl(Funcs...) if(Funcs.length > 1) {
	bool impl(Values)(BenchmarkOptions options, 
			Array!(Benchmark).Range benchmarks, ref Values values) 
	{
		bool rslt = realExecuter!(Funcs[0])(options, benchmarks[0], values);

		alias tail = executeImpl!(Funcs[1 .. $]);
		rslt = rslt || tail.impl(options, benchmarks[1 .. $], values);
		return rslt;
	}
}

template benchmark(Funcs...) {
	void initBenchmarks(ref Array!Benchmark benchmarks,
			ref const(BenchmarkOptions) options) 
	{
		import std.traits : fullyQualifiedName;
		for(size_t i = 0; i < Funcs.length; ++i) {
			benchmarks.insertBack( 
				Benchmark(
					options.maxRounds, 
					fullyQualifiedName!(Funcs[0])
				)
			);
		}
	}

	Array!Benchmark execute() {
		import core.time : dur;
		auto options = BenchmarkOptions("", 2000, dur!"seconds"(5), 1337);
		return execute(options);
	}

	Array!Benchmark execute(BenchmarkOptions options) {
		import std.random : Random;
		import std.stdio;
		import std.traits : ParameterIdentifierTuple, Parameters;

		import valuegenerators;

		Array!Benchmark benchmarks;
		initBenchmarks(benchmarks, options);

    	auto rnd = Random(options.seed);

    	enum parameterNames = [ParameterIdentifierTuple!(Funcs[0])];
    	auto valueGenerator = RndValueGen!(parameterNames, Parameters!(Funcs[0]))(&rnd);

		bool condition = false;
		while(!condition) {
        	valueGenerator.genValues();
			alias exe = executeImpl!(Funcs);
			condition = exe.impl(options, benchmarks[], valueGenerator);
		}

		writefln("%(%s\n%)", benchmarks[]);

		return benchmarks;
	}	
}

bool fun1(uint i) { 
	static int c;
	//writefln("c %s %d", c++, i);
	for(uint j = 2; j < i; ++j) {
		if(i % j == 0) {
			return false;
		}
	}
	return false;
}

unittest {
	import core.time : dur;
	import printer;

	bool delegate(uint i) fun2 = (uint i) {
		static int c;
		//writefln("d %s %d", c++, i);
		if(i == 2) return false;
		for(uint j = 3; j < i/2; j+=3) {
			if(i % j == 0) {
				return false;
			}
		}
		return true;
	};
	auto opt = BenchmarkOptions("", 10, dur!"seconds"(4), 1338);
	alias bench = benchmark!(fun1,fun2);
	auto rslt = bench.execute(opt);
	stdoutPrinter(rslt);
}
