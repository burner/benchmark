module randomizedtestbenchmark.execution;

import randomizedtestbenchmark.benchmark : Benchmark, BenchmarkOptions,
	   BenchmarkResult;

import std.container.array : Array;

/** This template creates a benchmark object.
$(D Funcs) is the list of callable things that should be benchmarks.
The signatures of the elements of $(D Funcs) must be equals.
After the benchmark is constructed it is executed by calling execute.
*/
template benchmark(Funcs...)
{
	import std.container.array : Array;

    void initBenchmarks(ref Array!Benchmark benchmarks, 
			ref const(BenchmarkOptions) options)
    {
		initBenchmarksImpl!(Funcs)(benchmarks, options);
    }

	/** Start the benchmark process
	Params:
		options = The Options to use. By default the benchmark will run for 5
		seconds or no more than 2000 rounds.
	*/
    BenchmarkResult execute()
    {
        import core.time : dur;

        auto options = BenchmarkOptions("", 2000, dur!"seconds"(5), 1337);
        return execute(options);
    }

	/// Ditto
    BenchmarkResult execute(BenchmarkOptions options)
    {
        import std.random : Random;
        import std.traits : ParameterIdentifierTuple, Parameters;

        import randomizedtestbenchmark.valuegenerators;

        Array!Benchmark benchmarks;
        initBenchmarks(benchmarks, options);

        auto rnd = Random(options.seed);

        enum parameterNames = [ParameterIdentifierTuple!(Funcs[0])];
        auto valueGenerator = RndValueGen!(
				parameterNames, 
				Parameters!(Funcs[0])
			)(&rnd);

        bool condition = false;
        while (!condition)
        {
            valueGenerator.genValues();
            alias exe = executeImpl!(Funcs);
            condition = exe.impl(options, benchmarks[], valueGenerator);
        }

		return BenchmarkResult(options, benchmarks);
    }
}

private bool shouldBeStopped(const ref Benchmark benchmark,
		const ref BenchmarkOptions options)
{
    return benchmark.curRound > options.maxRounds 
		|| benchmark.timeSpend > options.maxTime;
}

private bool realExecuter(alias Fun, Values)(ref BenchmarkOptions options,
    ref Benchmark bench, ref Values values)
{
	import std.traits : ReturnType;

    bench.start();
    static if (is(ReturnType!(Fun) == void))
    {
        Fun(values.values);
    }
    else
    {
        import randomizedtestbenchmark.benchmark : doNotOptimizeAway;

        doNotOptimizeAway(Fun(values.values));
    }
    bench.stop();

    return shouldBeStopped(bench, options);
}

private template executeImpl(Funcs...) if (Funcs.length == 1)
{
	import std.container.array : Array;

    bool impl(Values)(BenchmarkOptions options, Array!(Benchmark).Range benchmarks,
        ref Values values)
    {
        return realExecuter!(Funcs[0])(options, benchmarks[0], values);
    }
}

private template executeImpl(Funcs...) if (Funcs.length > 1)
{
	import std.container.array : Array;

    bool impl(Values)(BenchmarkOptions options, Array!(Benchmark).Range benchmarks,
        ref Values values)
    {
        bool rslt = realExecuter!(Funcs[0])(options, benchmarks[0], values);
        alias tail = executeImpl!(Funcs[1 .. $]);
		bool tailResult = tail.impl(options, benchmarks[1 .. $], values);
        return rslt || tailResult;
    }
}

private void initBenchmarksImpl(Funcs...)(ref Array!Benchmark benchs, 
		ref const(BenchmarkOptions) options)
{
    import std.traits : fullyQualifiedName;

    benchs.insertBack(
		Benchmark(
			options.maxRounds, 
			fullyQualifiedName!(Funcs[0])
		)
	);

	static if(Funcs.length > 1)
	{
		initBenchmarksImpl!(Funcs[1 .. $])(benchs, options);
	}
}

version (unittest)
{
    private bool fun1(uint i)
    {
        if (i == 2)
            return false;
        for (uint j = 3; j < i / 2; j += 3)
        {
            if (i % j == 0)
            {
                return false;
            }
        }
        return true;
    }
}

unittest
{
    import core.time : dur;
    import randomizedtestbenchmark.printer;

    int c;
    bool delegate(uint i) fun2 = (uint i) {
        ++c;
        for (uint j = 2; j < i; ++j)
        {
            if (i % j == 0)
            {
                return false;
            }
        }
        return false;
    };

    auto opt = BenchmarkOptions("FastPrime", 10, dur!"seconds"(4), 1338);
    alias bench = benchmark!(fun1, fun2);
    auto rslt = bench.execute(opt);
    assert(c > 0);
    stdoutPrinter(rslt);
}

unittest
{
    import core.time : dur;
    import randomizedtestbenchmark.printer;
    import randomizedtestbenchmark.valuegenerators;

    class DummyClass
    {
        int c;

        bool fun(ulong i)
        {
            import std.stdio;

            this.c++;
            if (i == 2)
                return false;
            for (long j = 3; j < i / 2; j += 3)
            {
                if (i % j == 0)
                {
                    return false;
                }
            }
            return true;
        }
    }

    auto c = new DummyClass();
    auto del = delegate(Gen!(ulong, 0, 1024) i) {
		import randomizedtestbenchmark.benchmark : doNotOptimizeAway;
        bool tmp = c.fun(i);
        doNotOptimizeAway(tmp);
        return tmp;
    };

    auto opt = BenchmarkOptions("ClassTest", 10, dur!"seconds"(3), 1333);
    alias bench = benchmark!(del);
    auto rslt = bench.execute(opt);
    assert(c.c > 0);
    stdoutPrinter(rslt);
}
