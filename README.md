```D
/** This module combines randomized unittests with benchmarking capabilites.

To gain appropriate test coverage and to test unexpected inputs, randomized
unittest are a possible approach.
Additionally, they lend itself for reproducible benchmarking and performance
monitoring.
*/
module std.experimental.randomized_unittest_benchmark;

import std.experimental.logger;

/// The following examples show an overview of the given functionalities.
unittest
{
    void theFunctionToTest(int a, float b, string c)
    {
        // super expensive operation
        auto rslt = (a + b) * c.length;

        /* Pass the result to doNotOptimizeAway so the compiler
        can not remove the expensive operation, and thereby falsify the
        benchmark.
        */
        doNotOptimizeAway(rslt);

        debug
        {
            /* As the paramters to the function assume random values, 
            $(D benchmark) allows to quickly test function with various input
            values. As the verification of computed value or state will at to
            the runtime of the function to benchmark, it makes sense to only
            execute these verifications in debug mode.
            */
            assert(c.length ? true : true);
        }
    }

    /* $(D benchmark) will run the function $(D theFunctionToTest) as often as
    possible in 1 second. The function will be called with randomly selected
    values for its parameters.
    */
    benchmark!theFunctionToTest();
}

/// Ditto
unittest
{
    /* This function takes to $(D Gen) types as parameter. These $(D Gen)
     types are implicitly convertiable to the type given as the first template
    type parameter. The second and thrid template parameter give the upper and
    lower bound of the randomly selected value given to the parameter. This
    allows to test functions which only work for a specific range of values.
    */
    void theFunctionToTest(Gen!(int, 1, 5) a, Gen!(float, 0.0, 10.0) b)
    {
        // This will always be true
        assert(a >= 1 && a <= 5);
        assert(a >= 0.0 && a <= 10.0);

        // super expensive operation
        auto rslt = (a + b);
        doNotOptimizeAway(rslt);

        debug
        {
            assert(rslt > 1.0);
        }
    }

    benchmark!theFunctionToTest();
}
```
