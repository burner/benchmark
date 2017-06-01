```D
/** This module combines randomized unittests with benchmarking capabilites.

To gain appropriate test coverage and to test unexpected inputs, randomized
unittest are a possible approach.
Additionally, they lend itself for reproducible benchmarking and performance
monitoring.

$(D randomizedtestbenchmark) is a test data generation and benchmark
package. The below example shows a simple example of how to test a function
with this package.
*/

import randomizedtestbenchmark;

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
}
```
