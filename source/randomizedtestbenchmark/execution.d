module randomizedtestbenchmark.execution;

import randomizedtestbenchmark.benchmark : Benchmark, BenchmarkOptions,
	   BenchmarkResult;

bool shouldBeStopped(const ref Benchmark benchmark,
		const ref BenchmarkOptions options)
{
    return benchmark.curRound > options.maxRounds 
		|| benchmark.timeSpend > options.maxTime;
}

bool realExecuter(alias Fun, Values)(ref BenchmarkOptions options,
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

template executeImpl(Funcs...) if (Funcs.length == 1)
{
	import std.container.array : Array;

    bool impl(Values)(BenchmarkOptions options, Array!(Benchmark).Range benchmarks,
        ref Values values)
    {
        return realExecuter!(Funcs[0])(options, benchmarks[0], values);
    }
}

template executeImpl(Funcs...) if (Funcs.length > 1)
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

template benchmark(Funcs...)
{
	import std.container.array : Array;

    void initBenchmarks(ref Array!Benchmark benchmarks, 
			ref const(BenchmarkOptions) options)
    {
        import std.traits : fullyQualifiedName;

        for (size_t i = 0; i < Funcs.length; ++i)
        {
            benchmarks.insertBack(
				Benchmark(
					options.maxRounds, 
					fullyQualifiedName!(Funcs[0])
				)
			);
        }
    }

    BenchmarkResult execute()
    {
        import core.time : dur;

        auto options = BenchmarkOptions("", 2000, dur!"seconds"(5), 1337);
        return execute(options);
    }

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

version (unittest)
{
    private bool fun1(uint i)
    {
        static int c;
        //writefln("c %s %d", c++, i);
        for (uint j = 2; j < i; ++j)
        {
            if (i % j == 0)
            {
                return false;
            }
        }
        return false;
    }
}

unittest
{
    import core.time : dur;
    import randomizedtestbenchmark.printer;

    int c;
    bool delegate(uint i) fun2 = (uint i) {
        ++c;
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
