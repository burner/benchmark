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
    auto result = bench.execute();

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
    auto result = bench.execute();
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
    auto result = bench.execute(options);
}
