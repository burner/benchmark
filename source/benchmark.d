module benchmarkmodule;

/* This function used $(D MonoTimeImpl!(ClockType.precise).currTime) to time
how long $(D MonoTimeImpl!(ClockType.precise).currTime) takes to return
the current time.
*/
private auto medianStopWatchTime()
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

unittest {
    import std.stdio : writefln;
	auto mst = medianStopWatchTime();
	writefln("mst %s", mst);
}

/** A function that makes sure that the passed parameters are not optimized
away by the compiler. This function is required as optimizing compilers are
able to figure out that a variable is not actually used, and therefore the
computation of the value of the variable can be removed from code. As
benchmarking functions sometimes include computing values that are not
actually used, this function allows use to force the compiler not to remove
the code that is benchmarked.
*/
void doNotOptimizeAway(T...)(ref T t)
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

struct Benchmark {
	import std.container.array : Array;
	import core.time : ClockType, Duration, MonoTimeImpl;

	/* the times it took to execute the function */
    Array!(Duration) ticks; 
	/* the number of times the functions is supposed to be
   	executed */
    const(size_t) maxRounds; 
	/* the number of rounds run */
    size_t curRound = 0; 
	/* overall time spend running the benchmark function */
    Duration timeSpend;
	/* the maximum time the benchmark should take*/
    const(Duration) maxTime;
	/* the time the benchmark started */
    MonoTimeImpl!(ClockType.precise) startTime;

	this(size_t maxRounds, Duration maxTime) {
		this.maxRounds = maxRounds;
		this.maxTime = maxTime;
		this.ticks.reserve(this.maxRounds);
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

	bool finished() const {
		if(this.maxTime == Duration.zero()) {
			return this.curRound >= this.maxRounds;
		} else {
			return this.curRound >= this.maxRounds 
				|| this.timeSpend >= this.maxTime;
		}
	}
}
