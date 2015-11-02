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

/// Ditto Manuel benchmarking
unittest
{
    auto rnd = Random(1337); // we need a random generator
    auto ben = Benchmark("aGoodName", 20); // a benchmark object that stores the
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

import core.time : Duration, seconds;
import core.time : TickDuration, to, MonoTime, dur;
import std.array : appender, Appender, array;
import std.datetime : StopWatch, DateTime, Clock;
import std.meta : staticMap;
import std.random : Random, uniform, randomSample;
import std.stdio : writeln;
import std.traits : fullyQualifiedName, isFloatingPoint, isIntegral, isNumeric,
    isSomeString, Parameters;
import std.typetuple : TypeTuple;
import std.utf : byDchar, count;

private auto avgStopWatchTime()
{
    import core.time;

    MonoTime sw = MonoTime.currTime;

    enum numRounds = 500;
    MonoTime dummy;
    for (size_t i = 0; i < numRounds; ++i)
    {
        dummy = MonoTime.currTime;
        dummy = MonoTime.currTime;
    }

    auto diff = MonoTime.currTime - sw;

    return to!("nsecs", real)(cast(TickDuration) diff) / numRounds;
}

private TickDuration getQuantilTick(double q)(Duration[] ticks) pure @safe
{
    size_t idx = cast(size_t)(ticks.length * q);

    if (ticks.length % 2 == 1)
    {
        return cast(TickDuration) ticks[idx];
    }
    else
    {
        return cast(TickDuration)((ticks[idx] + ticks[idx - 1]) / 2);
    }
}

unittest
{
    static import std.conv;
    import std.algorithm.iteration : map;

    auto ticks = [1, 2, 3, 4, 5].map!(a => dur!"seconds"(a)).array;

    TickDuration q25 = getQuantilTick!0.25(ticks);
    assert(q25 == TickDuration.from!"seconds"(2));

    TickDuration q50 = getQuantilTick!0.50(ticks);
    assert(q50 == TickDuration.from!"seconds"(3));

    TickDuration q75 = getQuantilTick!0.75(ticks);
    assert(q75 == TickDuration.from!"seconds"(4));

    q25 = getQuantilTick!0.25(ticks[0 .. 4]);
    long q25l = q25.to!("seconds", long)();
    assert(q25l == 1);

    q50 = getQuantilTick!0.50(ticks[0 .. 4]);
    long q50l = q50.to!("seconds", long)();
    assert(q50l == 2, std.conv.to!string(q50l));

    q75 = getQuantilTick!0.75(ticks[0 .. 4]);
    long q75l = q75.to!("seconds", long)();
    assert(q75l == 3, std.conv.to!string(q75l));
}

/** This $(D struct) takes care of the time taking and outputting of the
statistics.
*/
struct Benchmark
{
    string filename; // where to write the benchmark result to
    string funcname; // the name of the benchmark
    string timeScale; // the unit the benchmark is measuring in
    real avgStopWatch; // the avg time it takes to get the clocktime twice
    bool dontWrite; // if set, no data is written to the the file name "filename"
    // true if, RndValueGen opApply was interrupt unexpectitally
    Appender!(Duration[]) ticks; // the stopped times, there will be rounds ticks
    size_t ticksIndex = 0; // the index into ticks
    MonoTime startTime;
    Duration timeSpend; // overall time spend running the benchmark function

    /** The constructor for the $(D Benchmark).
    Params:
        funcname = The name of the $(D benchmark) instance. The $(D funcname)
            will be used to associate the results with the function
        filename = The $(D filename) will be used as a filename to store the
            results.
    */
    static auto opCall(in string funcname, in string filename = __FILE__)
    {
        Benchmark ret;
        ret.filename = filename;
        ret.funcname = funcname;
        ret.timeScale = "nsecs";
        ret.ticks = appender!(Duration[])();
        ret.avgStopWatch = avgStopWatchTime();
        ret.timeSpend = dur!"seconds"(0);
        return ret;
    }

    /** A call to this method will start the time taking process */
    void start()
    {
        this.startTime = MonoTime.currTime;
    }

    /** A call to this method will stop the time taking process, and
    appends the execution time to the $(D ticks) member.
    */
    void stop()
    {
        MonoTime end = MonoTime.currTime;
        Duration dur = end - this.startTime;
        this.timeSpend += dur;

        this.ticks.put(dur);
    }

    ~this()
    {
        import std.stdio : File;

        if (!this.dontWrite)
        {
            import std.algorithm : sort;

            auto sortedTicks = this.ticks.data;
            sortedTicks.sort();

            auto f = File(filename ~ "_bechmark.csv", "a");
            scope (exit)
                f.close();

            auto q0 = (cast(TickDuration) sortedTicks[0]).to!("nsecs", real)() / this.rounds;
            auto q25 = getQuantilTick!0.25(sortedTicks).to!("nsecs", real)() / this.rounds;
            auto q50 = getQuantilTick!0.50(sortedTicks).to!("nsecs", real)() / this.rounds;
            auto q75 = getQuantilTick!0.75(sortedTicks).to!("nsecs", real)() / this.rounds;
            auto q100 = (cast(TickDuration) sortedTicks[$ - 1]).to!("nsecs", real)() / this.rounds;

            // funcName, the data when the benchmark was created, unit of time,
            // rounds, avgStopWatch, low, 0.25 quantil, median,
            // 0.75 quantil, high
            f.writefln(
                "\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"," ~ "\"%s\",\"%s\"",
                this.funcname, Clock.currTime.toISOExtString(), this.timeScale,
                this.rounds, this.avgStopWatch,
                q0 > this.avgStopWatch ? q0 - this.avgStopWatch : 0,
                q25 > this.avgStopWatch ? q25 - this.avgStopWatch : 0,
                q50 > this.avgStopWatch ? q50 - this.avgStopWatch : 0,
                q75 > this.avgStopWatch ? q75 - this.avgStopWatch : 0,
                q100 > this.avgStopWatch ? q100 - this.avgStopWatch : 0);
        }
    }
}

/** A $(D Gen) type that generates numeric values between the values of the
template parameter $(D low) and $(D high).
*/
struct Gen(T, T low, T high) if (isNumeric!T)
{
    alias Value = T;

    T value;

    void gen(ref Random gen)
    {
        static assert(low <= high);
        this.value = uniform!("[]")(low, high, gen);
    }

    ref T opCall()
    {
        return this.value;
    }

    alias opCall this;
}

/** A $(D Gen) type that generates unicode strings with a number of
charatacters that is between template parameter $(D low) and $(D high).
*/
struct Gen(T, size_t low, size_t high) if (isSomeString!T)
{
    static T charSet;
    static immutable size_t numCharsInCharSet;

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

    T value;
    alias opCall this;
}

unittest
{
    import std.utf : validate;
    import std.array : empty;
    import std.exception : assertNotThrown;

    auto rnd = Random(1337);

    foreach (S; TypeTuple!(string, wstring, dstring))
    {
        Gen!(S, 5, 5) gen;
        gen.gen(rnd);
        S str = gen();

        assert(!str.empty);
        assertNotThrown(validate(str));
    }
}

// Return $(D true) is the passed $(D T) is a $(D Gen) struct.
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
    else
        static assert(false);
}

///
unittest
{
    alias GenInt = ParameterToGen!int;

    static fun(int i)
    {

    }

    GenInt a;
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

private void funToBenchmark(int a, float b, Gen!(int, -5, 5) c, string d)
{
    import core.thread;

    Thread.sleep(1.seconds / 100000);
    writeln(a, " ", b, " ", c, " ", d);
}

unittest
{
    benchmark!funToBenchmark();
    benchmark!funToBenchmark("Another Name");
    benchmark!funToBenchmark("Another Name", 2.seconds);
    benchmark!funToBenchmark(2.seconds);
}

/** This function runs the passed callable $(D T) for the duration of 
$(D maxRuntime). It will count how often $(D T) is run in the duration and
how long each run took to complete.

Unless compiled in release mode, statictis will be printed to $(D stderr).
If compiled in release mode the statictis are appended to a file called 
$(D name).

Params:
    name = The name of the benchmark. The name is also used as filename to
        save the benchmark results.
    maxRuntime = The maximul time the benchmark is executed. The last run will
        not be interrupted
    rndSeed = The seed to the random number generator used to populate the
        parameter passed to the function to benchmark.
*/
void benchmark(alias T)(string name, Duration maxRuntime, int rndSeed)
{
    auto bench = Benchmark(name, 1000);
    auto rnd = Random(rndSeed);
    auto valueGenerator = RndValueGen!(Parameters!T)(&rnd);

    size_t rounds = 0;
    while (bench.timeSpend <= maxRuntime, rounds < 10000)
    {
        valueGenerator.genValues();

        bench.start();
        T(valueGenerator.values);
        bench.stop();
        ++rounds;
    }
}

/// Ditto
void benchmark(alias T)()
{
    benchmark!(T)(fullyQualifiedName!T, 1.seconds, 1337);
}

/// Ditto
void benchmark(alias T)(Duration maxRuntime)
{
    benchmark!(T)(fullyQualifiedName!T, maxRuntime, 1337);
}

/// Ditto
void benchmark(alias T)(string name)
{
    benchmark!(T)(name, 1.seconds, 1337);
}

/// Ditto
void benchmark(alias T)(string name, Duration maxRuntime)
{
    benchmark!(T)(name, maxRuntime, 1337);
}

unittest
{
    immutable(ubyte)[] s = cast(immutable(ubyte)[]) "Hello";
    string str = cast(string) s;
    assert(str == "Hello");
}

unittest
{
    import core.thread;

    struct Foo
    {
        void superSlowMethod(int a, Gen!(int, -10, 10) b)
        {
            Thread.sleep(1.seconds / 400000);
            doNotOptimizeAway(a);
        }
    }

    Foo a;

    auto del = delegate(int ai, Gen!(int, -10, 10) b) {
        a.superSlowMethod(ai, b);
    };

    benchmark!(del)();
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
