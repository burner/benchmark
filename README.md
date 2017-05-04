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

	stdoutPrinter(result);
}
```
