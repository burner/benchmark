/** This module combines randomized unittests with benchmarking capabilites.

To gain appropriate test coverage and to test unexpected inputs, randomized
unittest are a possible approach.
Additionally, they lend itself for reproducible benchmarking and performance
monitoring.
*/
module std.experimental.randomized_unittest_benchmark;

debug import std.experimental.logger;

private template AliasSeq(TList...) // TODO remove on next result
{
    alias AliasSeq = TList;
}

private template aliasSeqOf(alias range) // TODO remove on next result
{
    import std.range : isInputRange;
    import std.traits : isArray, isNarrowString;

    alias ArrT = typeof(range);
    static if (isArray!ArrT && !isNarrowString!ArrT)
    {
        static if (range.length == 0)
        {
            alias aliasSeqOf = AliasSeq!();
        }
        else static if (range.length == 1)
        {
            alias aliasSeqOf = AliasSeq!(range[0]);
        }
        else
        {
            alias aliasSeqOf = AliasSeq!(aliasSeqOf!(range[0 .. $/2]), aliasSeqOf!(range[$/2 .. $]));
        }
    }
    else static if (isInputRange!ArrT)
    {
        import std.array : array;
        alias aliasSeqOf = aliasSeqOf!(array(range));
    }
    else
    {
        import std.string : format;
        static assert(false, format("Cannot transform %s of type %s into a AliasSeq.", range, ArrT.stringof));
    }
}

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

/// Ditto Manuel benchmarking
unittest
{
    auto rnd = Random(1337); // we need a random generator
 	// a benchmark object that stores the
    auto ben = Benchmark("aGoodName", 20, "filename");
    // benchmark values

    ben.dontWrite = true; // yes will prohibit the Benchmark
    // instance from writing the benchmark
    // results to a file

    /* This instance of $(D RndValueGen) named $(D generator) will be used 
    later as the random parameter value source in the following call to the 
    function to benchmark. The $(D RndValueGen) takes one construction 
    parameter, the source of randomness. 
    */
    auto generator = RndValueGen!(int, // a random $(D int) between $(D int.min)
    // and $(D int.max)
    Gen!(float, 0.0, 10.0), // a random $(D float) between -10 and 10
    Gen!(string, 0, 9)) // a random $(D string) with a length
    (&rnd); // between 0 and 9

    /* a, b and c will have random values created inside $(D generator) that
    uses $(D rnd) as source of randomness
    */
    static void fun(int a, float b, string c)
    {
        auto rslt = cast(int) b + c.length;

        assert(true); // some useful assertions.

    }

    /* This loops combines the three elements and executes the benchmark.
    */
    size_t rounds = 0;
    while (ben.timeSpend <= 1.seconds && rounds < 1000)
    {
        generator.genValues(); // generate random values for a, b, and c

        ben.start(); // start the benchmark timer
        fun(generator.values); // run the function
        ben.stop(); // stop the benchmark timer
        ++rounds;
    }

    /* When a $(D Benchmark) object goes out of scope the destructor writes
    the benchmark stats to a file, unless the $(D donWrite) member is set to
    $(D true). The name of the output file is $(D __FILE__ ~  "_benchmark.csv).
    The $(D Benchmark) instance will write a line of comma seperated values to
    the file containing. The line contains the following information: the given
    name, the date of execution, the measuring unit, the measurment, if the
    execution was abnormaliy interrupted. */
}

struct BenchmarkOptions {
	string funcName; // the name of the function to benchmark
	string filename; 
	Duration duration = 1.seconds;
	size_t maxRounds = 10000;
	int seed = 1337;

	static BenchmarkOptions opCall(string filename = __FILE__) {
		BenchmarkOptions ret;
		ret.filename = filename;
		return ret;
	}
}

import core.time : MonoTimeImpl, Duration, ClockType, dur, seconds;
import std.array : appender, Appender, array;
import std.datetime : StopWatch, DateTime, Clock;
import std.meta : staticMap;
import std.conv : to;
import std.random : Random, uniform, randomSample;
import std.stdio : writeln;
import std.traits : fullyQualifiedName, isFloatingPoint, isIntegral, isNumeric,
    isSomeString, Parameters;
import std.typetuple : TypeTuple;
import std.utf : byDchar, count;

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

    MonoTimeImpl!(ClockType.precise) dummy;
    for (size_t i = 0; i < numRounds; ++i)
    {
    	auto sw = MonoTimeImpl!(ClockType.precise).currTime;
        dummy = MonoTimeImpl!(ClockType.precise).currTime;
        dummy = MonoTimeImpl!(ClockType.precise).currTime;
		doNotOptimizeAway(dummy);
    	times[i] = MonoTimeImpl!(ClockType.precise).currTime - sw;
    }

	sort(times[]);

    return times[$ / 2].total!"hnsecs";
}

private Duration getQuantilTick(double q)(Duration[] ticks) pure @safe
{
    size_t idx = cast(size_t)(ticks.length * q);

    if (ticks.length % 2 == 1)
    {
        return ticks[idx];
    }
    else
    {
        return (ticks[idx] + ticks[idx - 1]) / 2;
    }
}

unittest
{
    static import std.conv;
    import std.algorithm.iteration : map;

    auto ticks = [1, 2, 3, 4, 5].map!(a => dur!"seconds"(a)).array;

    Duration q25 = getQuantilTick!0.25(ticks);
    assert(q25 == dur!"seconds"(2), q25.toString());

    Duration q50 = getQuantilTick!0.50(ticks);
    assert(q50 == dur!"seconds"(3), q25.toString());

    Duration q75 = getQuantilTick!0.75(ticks);
    assert(q75 == dur!"seconds"(4), q25.toString());

    q25 = getQuantilTick!0.25(ticks[0 .. 4]);
    assert(q25 == dur!"seconds"(1) + dur!"msecs"(500), q25.toString());

    q50 = getQuantilTick!0.50(ticks[0 .. 4]);
    assert(q50 == dur!"seconds"(2) + dur!"msecs"(500), q25.toString());

    q75 = getQuantilTick!0.75(ticks[0 .. 4]);
    assert(q75 == dur!"seconds"(3) + dur!"msecs"(500), q25.toString());
}

/** This $(D struct) takes care of the time taking and outputting of the
statistics.
*/
struct Benchmark
{
    string filename; // where to write the benchmark result to
    string funcname; // the name of the benchmark
    size_t rounds;  // the number of times the functions is supposed to be
                    //executed
    string timeScale; // the unit the benchmark is measuring in
    real medianStopWatch; // the median time it takes to get the clocktime twice
    bool dontWrite; // if set, no data is written to the the file name "filename"
    // true if, RndValueGen opApply was interrupt unexpectitally
    Appender!(Duration[]) ticks; // the stopped times, there will be rounds ticks
    size_t ticksIndex = 0; // the index into ticks
    size_t curRound = 0; // the number of rounds run
    MonoTimeImpl!(ClockType.precise) startTime;
    Duration timeSpend; // overall time spend running the benchmark function

    /** The constructor for the $(D Benchmark).
    Params:
        funcname = The name of the $(D benchmark) instance. The $(D funcname)
            will be used to associate the results with the function
        filename = The $(D filename) will be used as a filename to store the
            results.
    */
    static auto opCall(in string funcname, in size_t rounds, in string filename)
    {
        Benchmark ret;
        ret.filename = filename;
        ret.funcname = funcname;
        ret.rounds = rounds;
        ret.timeScale = "hnsecs";
        ret.ticks = appender!(Duration[])();
        ret.medianStopWatch = medianStopWatchTime();
        return ret;
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
        this.ticks.put(dur);
        ++this.curRound;
    }

    ~this()
    {
        import std.stdio : File;

        if (!this.dontWrite && this.ticks.data.length)
        {
            import std.algorithm : sort;

            auto sortedTicks = this.ticks.data;
            sortedTicks.sort();

            auto f = File(filename ~ "_bechmark.csv", "a");
            scope (exit)
                f.close();

            auto q0 = sortedTicks[0].total!("hnsecs")() / 
				cast(double)this.rounds;
            auto q25 = getQuantilTick!0.25(sortedTicks).total!("hnsecs")() / 
				cast(double)this.rounds;
            auto q50 = getQuantilTick!0.50(sortedTicks).total!("hnsecs")() / 
				cast(double)this.rounds;
            auto q75 = getQuantilTick!0.75(sortedTicks).total!("hnsecs")() / 
				cast(double)this.rounds;
            auto q100 = sortedTicks[$ - 1].total!("hnsecs")() / 
				cast(double)this.rounds;

            // funcName, the data when the benchmark was created, unit of time,
            // rounds, medianStopWatch, low, 0.25 quantil, median,
            // 0.75 quantil, high
            f.writefln(
                "\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\""
                   ~ ",\"%s\"",
                this.funcname, Clock.currTime.toISOExtString(), this.timeScale,
                this.curRound, this.medianStopWatch,
                q0 > this.medianStopWatch ? q0 - this.medianStopWatch : 0,
                q25 > this.medianStopWatch ? q25 - this.medianStopWatch : 0,
                q50 > this.medianStopWatch ? q50 - this.medianStopWatch : 0,
                q75 > this.medianStopWatch ? q75 - this.medianStopWatch : 0,
                q100 > this.medianStopWatch ? q100 - this.medianStopWatch : 0);
        }
    }
}

/* Return $(D true) is the passed $(D T) is a $(D Gen) struct.

A $(D Gen!T) is something that implicitly converts to $(D T), has a methods
called $(D gen) accepting a $(D ref Random) and has an $(D bisect) method
returning a $(D Bisect!T) instance.

This module already brings Gens for numeric types, strings and ascii strings.

If a function needs to be benchmarked that has a parameter of custom type a
custom $(D Gen) is required.
*/
template isGen(T)
{
    static if (is(T : Gen!(S), S...))
        enum isGen = true;
    else
        enum isGen = false;
}

///
unittest
{
    static assert(!isGen!int);
    static assert(isGen!(Gen!(int, 0, 10)));
}

struct Bisect(T) {
	T low;
	T high;
}

/** A $(D Gen) type that generates numeric values between the values of the
template parameter $(D low) and $(D high).
*/
struct Gen(T, T low, T high) if (isNumeric!T)
{
    alias Value = T;

    T value;
	T realLow = to!T(low);
	T realHigh = to!T(high);

    void gen(ref Random gen)
    {
        static assert(low <= high);
        this.value = uniform!("[]")(this.realLow, this.realHigh, gen);
    }

    ref T opCall()
    {
        return this.value;
    }

	Bisect!(typeof(this)) bisect() {
		import std.conv : to;

		typeof(return) ret;

		ret.low.realLow = this.realLow;
		if(this.value - 1 > this.realLow) {
			ret.low.realHigh = to!T(this.value - 1);
		} else {
			ret.low.realHigh = this.value;
		}
		ret.low.value = to!T(
			ret.low.realLow + ((ret.low.realHigh - ret.low.realLow) / 2)
		);

		ret.high.realLow = this.value;
		ret.high.realHigh = this.realHigh;
		ret.high.value = to!T(
			ret.high.realLow + ((ret.high.realHigh - ret.high.realLow) / 2)
		);
		
		return ret;
	}

    alias opCall this;
}

unittest
{
	import std.format : format;

	Gen!(int, -4, 4) a;
	a.value = 0;
	assert(a.realLow == -4);
	assert(a.realHigh == 4);

	auto b = a.bisect();
	assert(b.low.realLow == -4);
	assert(b.low.realHigh == -1, format("%d", b.low.realHigh));
	assert(b.low.value == -3, format("%d", b.low.value));

	assert(b.high.realLow == 0);
	assert(b.high.realHigh == 4);
	assert(b.high.value == 2, format("%d", b.high.value));

	a.value = -4;
	assert(a.realLow == -4);
	assert(a.realHigh == 4);

	b = a.bisect();
	assert(b.low.realLow == -4);
	assert(b.low.realHigh == -4, format("%d", b.low.realHigh));
	assert(b.low.value == -4, format("%d", b.low.value));

	assert(b.high.realLow == -4);
	assert(b.high.realHigh == 4);
	assert(b.high.value == 0, format("%d", b.high.value));

	auto c = b.low.bisect();
	assert(b.low == c.low);
	assert(b.low == c.high);
	assert(b.low.value == c.low.value);
	assert(b.low.value == c.high.value);
}

/** A $(D Gen) type that generates unicode strings with a number of
charatacters that is between template parameter $(D low) and $(D high).
*/
struct Gen(T, size_t low, size_t high) if (isSomeString!T)
{
    static T charSet;
    static immutable size_t numCharsInCharSet;

    T value;

    static this()
    {
        import std.uni : unicode;
        import std.conv : to;
        import std.format : format;
        import std.range : chain, iota;
        import std.algorithm : map, joiner;

        Gen!(T, low, high).charSet = to!T(chain(iota(0x21,
            0x7E).map!(a => to!T(cast(dchar) a)), iota(0xA1,
            0x1EF).map!(a => to!T(cast(dchar) a))).joiner.array);

        Gen!(T, low, high).numCharsInCharSet = count(charSet);
    }

    void gen(ref Random gen)
    {
        static assert(low <= high);
        import std.range : drop;
        import std.array : front;

        auto app = appender!T();
        app.reserve(high);
        size_t numElems = uniform!("[]")(low, high, gen);

        for (size_t i = 0; i < numElems; ++i)
        {
            size_t toSelect = uniform!("[)")(0, numCharsInCharSet, gen);
            app.put(charSet.byDchar().drop(toSelect).front);
        }

        this.value = app.data;
    }

    ref T opCall()
    {
        return this.value;
    }

	Bisect!(typeof(this)) bisect() {
		import std.utf : byDchar;
		import std.range : drop, take;
		typeof(return) ret;

		auto l = this.value.count();
		ret.low.value = this.value.byDchar().take(l / 2).array.to!T;
		ret.high.value = this.value.byDchar().drop(l / 2).array.to!T;
		
		return ret;
	}

    alias opCall this;
}

unittest
{
	assert(null == null);

	Gen!(string, 1, 4) a;
	a.value = "aßcd";

	auto b = a.bisect();
	assert(b.low.value == "aß");
	assert(b.high.value == "cd");

	b = b.low.bisect();
	assert(b.low.value == "a");
	assert(b.high.value == "ß");

	b = b.low.bisect();
	assert(b.low.value == "");
	assert(b.high.value == "a");

	auto c = b.low.bisect();
	assert(b.low == c.low);
	assert(b.low == c.high);
}

unittest
{
	import std.typetuple : TypeTuple;
	//import std.meta : aliasSeqOf; TODO uncomment with next release
    import std.range : iota;
	import std.array : empty;

	auto r = Random(1337);
	foreach(T; TypeTuple!(string,wstring,dstring))
	{
		foreach(L; aliasSeqOf!(iota(0, 2)))
		{
			foreach(H; aliasSeqOf!(iota(L, 2)))
			{
				Gen!(T, L, H) a;
				a.gen(r);
				if(L) 
				{
					assert(!a.value.empty);
				}
				auto b = a.bisect();
			}
		}
	}
}

/// DITTO This random $(D string)s only consisting of ASCII character
struct GenASCIIString(size_t low, size_t high)
{
    static string charSet;
    static immutable size_t numCharsInCharSet;

    string value;

    static this()
    {
        import std.uni : unicode;
        import std.conv : to;
        import std.format : format;
        import std.range : chain, iota;
        import std.algorithm : map, joiner;

        GenASCIIString!(low, high).charSet = to!string(
			chain(iota(0x21, 0x7E).map!(a => to!char(cast(dchar) a)).array)
		);

        GenASCIIString!(low, high).numCharsInCharSet = count(charSet);
    }

    void gen(ref Random gen)
    {
        auto app = appender!string();
        app.reserve(high);
        size_t numElems = uniform!("[]")(low, high, gen);

        for (size_t i = 0; i < numElems; ++i)
        {
            size_t toSelect = uniform!("[)")(0, numCharsInCharSet, gen);
            app.put(charSet[toSelect]);
		}

        this.value = app.data;
	}

    ref string opCall()
    {
        return this.value;
    }

	Bisect!(typeof(this)) bisect() {
		typeof(return) ret;
		ret.low.value = this.value[0 .. $/2];
		ret.high.value = this.value[$/2 .. $];
		
		return ret;
	}

    alias opCall this;
}

unittest
{
	assert(null == null);

	GenASCIIString!(1, 4) a;
	a.value = "abcd";

	auto b = a.bisect();
	assert(b.low.value == "ab");
	assert(b.high.value == "cd");

	b = b.low.bisect();
	assert(b.low.value == "a");
	assert(b.high.value == "b");

	b = b.low.bisect();
	assert(b.low.value == "");
	assert(b.high.value == "a");

	auto c = b.low.bisect();
	assert(b.low == c.low);
	assert(b.low == c.high);
}

unittest
{
    import std.utf : validate;
    import std.array : empty;
    import std.exception : assertNotThrown;

    auto rnd = Random(1337);

    GenASCIIString!(5, 5) gen;
    gen.gen(rnd);
    auto str = gen();

    assert(!str.empty);
    assertNotThrown(validate(str));
}

/** This type will generate a $(D Gen!T) for all passed $(D T...).
Every call to $(D genValues) will call $(D gen) of all $(D Gen) structs
present in $(D values). The member $(D values) can be passed to every
functions accepting $(D T...).
*/
struct RndValueGen(T...)
{
    /* $(D Values) is a collection of $(D Gen) types created through 
    $(D ParameterToGen) of passed $(T ...).
    */
    alias Values = staticMap!(ParameterToGen, T);
    /// Ditto
    Values values;

    /* The constructor accepting the required random number generator.
    Params:
        rnd = The required random number generator.
    */
    this(Random* rnd)
    {
        this.rnd = rnd;
    }

    /* The random number generator used to generate new value for all
    $(D values).
    */
    Random* rnd;

    /** A call to this member function will call $(D gen) on all items in
    $(D values) passing $(D the provided) random number generator
    */
    void genValues()
    {
        foreach (ref it; this.values)
        {
            it.gen(*this.rnd);
        }
    }
}

///
unittest
{
    auto rnd = Random(1337);
    auto generator = RndValueGen!(Gen!(int, 0, 10), Gen!(float, 0.0, 10.0))(&rnd);
    generator.genValues();

    static fun(int i, float f)
    {
        assert(i >= 0 && i <= 10);
        assert(f >= 0.0 && i <= 10.0);
    }

    fun(generator.values);
}

unittest
{
    static fun(int i, float f)
    {
        assert(i >= 0 && i <= 10);
        assert(f >= 0.0 && i <= 10.0);
    }

    auto rnd = Random(1337);
    auto generator = RndValueGen!(Gen!(int, 0, 10), Gen!(float, 0.0, 10.0))(&rnd);

    generator.genValues();
    foreach (i; 0 .. 1000)
    {
        fun(generator.values);
    }
}

/** A template that turns a $(D T) into a $(D Gen!T) unless $(D T) is
already a $(D Gen) or no $(D Gen) for given $(D T) is avaiable.
*/
template ParameterToGen(T)
{
    static if (isGen!T)
        alias ParameterToGen = T;
    else static if (isIntegral!T)
        alias ParameterToGen = Gen!(T, T.min, T.max);
    else static if (isFloatingPoint!T)
        alias ParameterToGen = Gen!(T, T.min_normal, T.max);
    else static if (isSomeString!T)
        alias ParameterToGen = Gen!(T, 0, 32);
    else static if (is(T : GenASCIIString!(S), S...))
        alias ParameterToGen = T;
    else
        static assert(false);
}

///
unittest
{
    alias GenInt = ParameterToGen!int;

    static fun(int i)
    {
		assert(i == 1337);
    }

    GenInt a;
	a.value = 1337;
    fun(a);
}

unittest
{
    foreach (T; TypeTuple!(byte, ubyte, ushort, short, uint, int, ulong, long,
            float, double, real, string, wstring, dstring))
    {
        alias TP = staticMap!(ParameterToGen, T);
        static assert(isGen!TP);
    }
}

/*unittest
{
	static void funToBenchmark(int a, float b, Gen!(int, -5, 5) c, string d,
		GenASCIIString!(1, 10) e)
	{
	    import core.thread;
	
	    Thread.sleep(1.seconds / 100000);
	    doNotOptimizeAway(a, b, c, d, e);
	}

    benchmark!funToBenchmark();
    benchmark!funToBenchmark("Another Name");
    benchmark!funToBenchmark("Another Name", 2.seconds);
    benchmark!funToBenchmark(2.seconds);
}*/

/** This function runs the passed callable $(D T) for the duration of 
$(D maxRuntime). It will count how often $(D T) is run in the duration and
how long each run took to complete.

Unless compiled in release mode, statictis will be printed to $(D stderr).
If compiled in release mode the statictis are appended to a file called 
$(D name).

Params:
	opts = An $(D BenchmarkOptions) instance that encompasses all possible
		parameter of benchmark.
    name = The name of the benchmark. The name is also used as filename to
        save the benchmark results.
    maxRuntime = The maximul time the benchmark is executed. The last run will
        not be interrupted
    rndSeed = The seed to the random number generator used to populate the
        parameter passed to the function to benchmark.
    rounds = The maximum numbers of times the callable $(D T) is called.
*/
void benchmark(alias T)(const ref BenchmarkOptions opts)
{
    auto bench = Benchmark(opts.funcName, opts.maxRounds, opts.filename);
    auto rnd = Random(opts.seed);
    auto valueGenerator = RndValueGen!(Parameters!T)(&rnd);

    while (bench.timeSpend <= opts.duration 
			&& bench.curRound < opts.maxRounds)
    {
        valueGenerator.genValues();

        bench.start();
		try {
			T(valueGenerator.values);
		} catch(Throwable t) {
			logf("unittest with name %s failed when parameter %s where passed",
				opts.funcName, valueGenerator);
			break;
		} finally {
        	bench.stop();
        	++bench.curRound;
		}
    }
}

/// Ditto
void benchmark(alias T)(string filename = __FILE__)
{
	auto opt = BenchmarkOptions(filename);
	opt.funcName = fullyQualifiedName!T;
    benchmark!(T)(opt);
}

/// Ditto
void benchmark(alias T)(Duration maxRuntime, string filename = __FILE__)
{
	auto opt = BenchmarkOptions(filename);
	opt.funcName = fullyQualifiedName!T;
	opt.duration = maxRuntime;
    benchmark!(T)(opt);
}

/// Ditto
void benchmark(alias T)(string name, string filename = __FILE__)
{
	auto opt = BenchmarkOptions(filename);
	opt.funcName = name;
    benchmark!(T)(opt);
}

/// Ditto
void benchmark(alias T)(string name, Duration maxRuntime,
	 string filename = __FILE__)
{
	auto opt = BenchmarkOptions(filename);
	opt.funcName = name;
	opt.duration = maxRuntime;
    benchmark!(T)(opt);
}

/*unittest
{
    import core.thread : Thread;

    struct Foo
    {
        void superSlowMethod(int a, Gen!(int, -10, 10) b)
        {
            Thread.sleep(1.seconds / 250000);
            doNotOptimizeAway(a);
        }
    }

    Foo a;

    auto del = delegate(int ai, Gen!(int, -10, 10) b) {
        a.superSlowMethod(ai, b);
    };

    benchmark!(del)();
}*/

unittest {
	static int failingFun(int a, string b) {
		throw new Exception("Hello");
	}

	log();
	benchmark!failingFun();
}

/** A functions that makes sure that the passed parameter are not optimized
away by the compiler. This function is required as optimizing compiler are
able to figure out that a variable is not actually used, and therefore the
computation of the value of the variable can be removed from code. As
benchmarking functions sometimes include computing values that are not
actually used, this functions allows use to force the compiler not to remove
the code that is benchmarked.
*/
void doNotOptimizeAway(T...)(ref T t)
{
    foreach (ref it; t)
    {
        doNotOptimizeAwayImpl(&it);
    }
}

private extern (C) void doNotOptimizeAwayImpl(void* p);
