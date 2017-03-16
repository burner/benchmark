module execution;


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
}

struct BenchmarkResult {
	import core.time : Duration;
	import std.container.array : Array;
	/* where to write the benchmark result to */
    string filename; 
	/* the name of the benchmark */
    string funcname; 
	/* the number of times the functions was run */
	size_t runs;
	/* the duration the benchmark was run */
    Duration maxTime;
	/* the times it took to execute the function */
    Array!(Duration) ticks; 
}

template fillBenchmarkResult(Funcs...) if(Funcs.length > 1) {
	void fill(BenchmarkResult[] bmr) {
		import std.traits : fullyQualifiedName;
		bmr[0].funcname = fullyQualifiedName!(Funcs[0]);
		
		alias rest = fillBenchmarkResult!(Funcs[1 .. $]);
		rest.fill(bmr[1 .. $]);
	}	
}

template fillBenchmarkResult(Funcs...) if(Funcs.length == 1) {
	void fill(BenchmarkResult[] bmr) {
		import std.traits : fullyQualifiedName;
		bmr[0].funcname = fullyQualifiedName!(Funcs[0]);
	}
}

template benchmark(Funcs...) {

	BenchmarkResult[] execute() {
		import std.random : Random;
		import std.stdio;
		import std.traits : ParameterIdentifierTuple, Parameters;

		import benchmarkmodule : Benchmark;
		import valuegenerators;

		BenchmarkResult[] rslt = new BenchmarkResult[Funcs.length];
		alias filler = fillBenchmarkResult!(Funcs);
		filler.fill(rslt);

    	auto rnd = Random(1337);

    	enum parameterNames = [ParameterIdentifierTuple!(Funcs[0])];
    	auto valueGenerator = RndValueGen!(parameterNames, Parameters!(Funcs[0]))(&rnd);

		writefln("%s", rslt);

		Benchmark[Funcs.length] benchmarks;
		return rslt;
	}	
}

unittest {
	void fun1() { }
	void delegate() fun2 = () {};
	alias bench = benchmark!(fun1,fun2);
	auto rslt = bench.execute();
}
