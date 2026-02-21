module randomizedtestbenchmark.benchmark;

/* This function used $(D MonoTimeImpl!(ClockType.precise).currTime) to time
how long $(D MonoTimeImpl!(ClockType.precise).currTime) takes to return
the current time.
*/
long medianStopWatchTime()
{
    import core.time;
    import std.algorithm : sort;

    enum numRounds = 51;
    Duration[numRounds] times;

    for (size_t i = 0; i < numRounds; ++i)
    {
        auto sw = MonoTimeImpl!(ClockType.precise).currTime;
        auto dummy = MonoTimeImpl!(ClockType.precise).currTime;
        auto dummy2 = MonoTimeImpl!(ClockType.precise).currTime;
        doNotOptimizeAway(dummy, dummy2);
        times[i] = MonoTimeImpl!(ClockType.precise).currTime - sw;
    }

    sort(times[]);

    return times[$ / 2].total!"hnsecs";
}

/// Ditto
unittest
{
    long mst = medianStopWatchTime();
    doNotOptimizeAway(mst);
}

/** A function that makes sure that the passed parameters are not optimized
away by the compiler. This function is required as optimizing compilers are
able to figure out that a variable is not actually used, and therefore the
computation of the value of the variable can be removed from code. As
benchmarking functions sometimes include computing values that are not
actually used, this function allows use to force the compiler not to remove
the code that is benchmarked.
*/
void doNotOptimizeAway(T...)(auto ref T t)
{
    foreach (ref it; t)
    {
        doNotOptimizeAwayImpl(&it);
    }
}

private void doNotOptimizeAwayImpl(void* p)
{
    import core.thread : getpid;
    import std.stdio : writeln;

    if (getpid() == 0)
    {
        writeln(p);
    }
}

/** $(D Benchmark) is the result of a benchmark.
*/
struct Benchmark
{
    import std.container.array : Array;
    import core.time : ClockType, Duration, MonoTimeImpl;

    /* the name of the benchmark */
    string funcname;
    /* the times it took to execute the function */
    Array!(Duration) ticks;
    /* the number of rounds run */
    size_t curRound = 0;
    /* overall time spend running the benchmark function */
    Duration timeSpend;
    /* the time the benchmark started */
    MonoTimeImpl!(ClockType.precise) startTime;

    /** The constructor of $(D Benchmark).
	Params:
		maxRounds = The maximal times the benchmark should be executed
		funcname = The name of the function to benchmark
	*/
    this(size_t maxRounds, string funcname)
    {
        this.funcname = funcname;
        this.ticks.reserve(maxRounds);
    }

    /** A call to this method will start the time taking process */
    void start()
    {
        this.startTime = MonoTimeImpl!(ClockType.precise).currTime;
    }

    /** A call to this method will stop the time taking process, and
    appends the execution time to the $(D ticks) member.
    */
    void stop()
    {
        auto end = MonoTimeImpl!(ClockType.precise).currTime;
        Duration dur = end - this.startTime;
        this.timeSpend += dur;
        this.ticks.insertBack(dur);
        ++this.curRound;
    }
}

struct BenchmarkOptions
{
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

    this(string name, size_t maxRounds, Duration maxTime, uint seed)
    {
        this.name = name;
        this.maxRounds = maxRounds;
        this.maxTime = maxTime;
        this.seed = seed;
    }
}

struct BenchmarkResult
{
    import std.container.array : Array;
    import randomizedtestbenchmark.benchmark : Benchmark;

    BenchmarkOptions options;
    Array!Benchmark results;
}

struct BenchmarkWithMetrics
{
    BenchmarkResult result;
    import randomizedtestbenchmark.systeminfo : BenchmarkSystemMetrics;
    BenchmarkSystemMetrics systemMetrics;
}
