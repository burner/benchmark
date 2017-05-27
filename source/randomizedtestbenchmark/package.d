module randomizedtestbenchmark;

public import randomizedtestbenchmark.printer;
public import randomizedtestbenchmark.gnuplot;
public import randomizedtestbenchmark.statistics;
public import randomizedtestbenchmark.benchmark;
public import randomizedtestbenchmark.execution;
public import randomizedtestbenchmark.valuegenerators;

/** $(D randomizedtestbenchmark) is a test data generation and benchmark
package. The below example shows a simple example of how to test a function
with this package.
*/
bool isPrime(uint a) 
{
	uint ret;
	for (uint i = 2; i < a; ++i)
	{
		if (ret % i == 0) {
			return false;
		}
	}
	return true;
}

/// 
unittest
{
    alias bench = benchmark!(isPrime);
    BenchmarkResult result = bench.execute();
	stdoutPrinter!(Min, Mode, Quantil!0.5, Max)(result);
	gnuplot!(Min, Mode, Quantil!0.5, Max)(result);

	/* this prints the results of the benchmark, by default the 0.01, 0.25, 0.50,
	0.75, and 0.99 runtime quantiles are printed in hnsecs.
	Additionally, the number number of executions of the functions are
	printed.
	*/
}

/*
$(D delegate)s can be tested as well as shown here.
*/
unittest 
{
	auto d = delegate(string randomString, char c) 
	{
		foreach (size_t idx, char it; randomString) 
		{
			if (it == c)
				return idx;
		}
		return size_t.max;
	};

    alias bench = benchmark!(d);
    BenchmarkResult result = bench.execute();
	stdoutPrinter!(Min, Mode, Quantil!0.5, Max)(result);
}

/*
Sometimes it is useful to compare multiple functions. To compare them properly
you have to pass them the same parameters. The following example shows you to
do that.
*/
unittest
{
	int fun(int a, int b) 
	{
		return a + b;
	}

	int fun2(int a, int b) 
	{
		return b + a;
	}

	// To test multiple functions with the same parameter just list them
    alias bench = benchmark!(fun, fun2);
    BenchmarkResult result = bench.execute();
}

/**
Each benchmark is executed with some properties, this properties can be
modified by passing an instance of $(D BenchmarkOptions) to the execute method
as shown below.
*/
unittest
{
    import core.time : dur;

	auto options = BenchmarkOptions(
		"customName", // A custom name for the benchmark
		100, // The maximal rounds the function to benchmark should be run
		dur!"seconds"(4), // The maximal time the function to benchmark should run
		43523, // A seed to the random source that generates test data
	);

    alias bench = benchmark!(isPrime);
    BenchmarkResult result = bench.execute(options);
}

/**
Testing with random data can be done as shown in following example.
In this example we create a function that tests std.algorithm.searching.find.
*/
unittest
{
	void forward(string randomString, char randomChar) {
		import std.algorithm.searching : find;
		import std.array : empty, front;

		auto idx = find(randomString, randomChar);
		doNotOptimizeAway(idx);

		debug
		{
			if (!idx.empty) 
			{
				assert(idx.front == randomChar);
			}
		}
	}

    alias bench = benchmark!(forward);
    BenchmarkResult result = bench.execute();
}

/* Sometimes it is required to restrict the passed test data.
The following example uses the $(D Gen) construct to create
a random string with a length between 10 and 20 characters.
*/
unittest
{
	void forward(Gen!(string, 10, 20) randomString, char randomChar) 
	{
		import std.algorithm.searching : find;
		import std.array : empty, front;

		auto idx = find(randomString, randomChar);
		doNotOptimizeAway(idx);

		debug
		{
			if (!idx.empty) 
			{
				assert(idx.front == randomChar);
			}
		}
	}

    alias bench = benchmark!(forward);
    BenchmarkResult result = bench.execute();
}

/** $(D Gen) exists for all primitive types, but sometimes it is required to
generate test data for custom data types. The following example demonstrates
how to create a custom $(D FooGen) element.
*/
unittest 
{
	/* We have the type $(D Foo) which is just an aggregate of a $(D string)
	   and a $(D c).
	*/
	struct Foo 
	{
		string str;
		char c;
	}

	/* $(D FooGen) is our $(D Foo) generator. In order to make a generator a
	   type must have three properties.  If must have a alias member called
	   Type that is the type of the generated value.  Additionally, it must
	   have a method called $(gen) that takes a $(D std.random.Random) as $(D
	   ref).  Usually, this method is used to generate the $(I random) value.
	   The last required property is that the generator must be implicitly be
	   convertible to type Type.  This is usually achieved by an $(alias this).
	*/
	static struct FooGen
	{
		import std.random : Random;
	
		alias Type = Foo;

		Foo value;
	
		void gen(ref Random gen)
		{
			Gen!(string) str;
			Gen!(char) c;
	
			str.gen(gen);
			c.gen(gen);
	
			this.value = Foo(str, c);
		}
	
		alias value this;
	}

	// $(D isGen) is used to test if $(D FooGen) is a valid generator
	static assert(isGen!(FooGen));

	// Finally, $(D FooGen) can be used as expected
	void customGenFunction(FooGen foo) 
	{
		import std.string : indexOf;
		auto idx = indexOf(foo.str, foo.c);
		doNotOptimizeAway(idx);
	}

    alias bench = benchmark!(customGenFunction);
    BenchmarkResult result = bench.execute();
}
