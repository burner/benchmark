module randomizedtestbenchmark;

public import randomizedtestbenchmark.printer;
public import randomizedtestbenchmark.benchmark;
public import randomizedtestbenchmark.execution;
public import randomizedtestbenchmark.valuegenerators;

/** $(D randomizedtestbenchmark) is a test data generation and benchmark
package. The below example shows a simple example of how to test a function
with this package.
*/
uint sumOfDivisors(uint a) 
{
	uint ret;
	for (uint i = 1; i < a/2; ++i)
	{
		if (ret % i == 0) {
			ret += i;
		}
	}
	return ret;
}

/// Ditto
unittest
{
    alias bench = benchmark!(sumOfDivisors);
    BenchmarkResult result = bench.execute();

	/* $(D stdoutPrinter(result);)
	this prints the results of the benchmark, by default the 0.01, 0.25, 0.50,
	0.75, and 0.99 runtime quantils are printed in hnsecs.
	Additionally, the number number of executions of the functions are
	printed.
	*/
}

/** Ditto
$(D delegate)s can be tested as well as shown here.
*/
unittest {
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
	stdoutPrinter(result);
}

/** Ditto
Each benchmark is executed with some properties, this properties can be
modifed by passing an instance of $(D BenchmarkOptions) to the execute method
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

    alias bench = benchmark!(sumOfDivisors);
    BenchmarkResult result = bench.execute(options);
}

/** Ditto
Testing with random data can be done as shown in following example.
In this example we create a function that tests std.string.indexOf.
std.string.indexOf returns the index of the searched character in the passed
string.
*/
unittest
{
	void forward(string randomString, char randomChar) {
		import std.string : indexOf;
		import std.format : format;

		auto idx = indexOf(randomString, randomChar);
		doNotOptimizeAway(idx);

		debug
		{
			if (idx != -1) 
			{
				/*assert(randomString[idx] == randomChar,
					format("%d randomString[idx](%x) != randomChar(%x)\n%s",
						idx, randomString[idx], randomChar, randomString
					)
				);*/
			}
		}
	}

    alias bench = benchmark!(forward);
    BenchmarkResult result = bench.execute();
}

/** Ditto
Sometimes it is required to restrict the passed test data.
The following example uses the $(D Gen) construct to create
a random string with a length between 10 and 20 characters.
*/
unittest
{
	void forward(Gen!(string, 10, 20) randomString, char randomChar) {
		import std.string : indexOf;
		import std.format : format;

		auto idx = indexOf(randomString, randomChar);
		doNotOptimizeAway(idx);

		debug
		{
			if (idx != -1) 
			{
				/*assert(randomString[idx] == randomChar,
					format("%d randomString[idx](%x) != randomChar(%x)\n%s",
						idx, randomString[idx], randomChar, randomString
					)
				);*/
			}
		}
	}

    alias bench = benchmark!(forward);
    BenchmarkResult result = bench.execute();
}

/** Ditto
$(D Gen) exists for all primitive types, but sometimes it is required to
generate test data for custom data types. The following example demonstrates
how to create a custom $(D Gen) element.
*/
unittest {
	struct Foo {
		string str;
		char c;
	}

	struct Gen(T) if (is(T == Foo))
	{
		import std.random : Random;

    	Foo value;

    	void gen(ref Random gen)
    	{
			Gen!(string) str;
			Gen!(char) c;

			str.gen(gen);
			c.gen(gen);

			this.value = Foo(str(), c());
		}

    	ref Foo opCall()
    	{
    	    return this.value;
    	}

    	alias opCall this;
	}

	void customGenFunction(Gen!Foo foo) {
		import std.string : indexOf;
		auto idx = indexOf(foo.str, foo.c);
		doNotOptimizeAway(idx);
	}

    alias bench = benchmark!(customGenFunction);
    BenchmarkResult result = bench.execute();
}
