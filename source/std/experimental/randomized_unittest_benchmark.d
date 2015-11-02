/** This module combines randomized unittests with benchmarking capabilites.

To gain appropriate test coverage and to test unexpected inputs, randomized
unittest are a possible approach.
Additionally, they lend itself for reproducible benchmarking and performance
monitoring.
*/
module std.experimental.randomized_unittest_benchmark;

import core.time : Duration, seconds;
import std.meta : staticMap;
import std.utf : byDchar, count;
import std.stdio : writeln;
import std.array : array;

/// The following example shows a overview of the given functionalities.
/+unittest
{
    int theFunctionToTest(int a, float b, string c)
    {
        import std.conv : to;
        int ret = a + cast(int)b;

        foreach(it; c)
            ret += cast(int)it;

        return ret;
    }

    auto rnd = Random(1337);              // we need a random generator
    auto ben = Benchmark("aGoodName", 20);// a benchmark object that stores the
                                          // benchmark values

    ben.dontWrite = true;                 // yes will prohibit the Benchmark
                                          // instance from writing the benchmark
                                          // results to a file


    /* This RndValueGen instance will have a opApply member function that
    excepts delegate of type $(D int delegate(ref int, ref float, ref string)).
    The parameter of the delegate match the parameter of the function
    $(D theFunctionToTest). The instance of this $(D RndValueGen) named
    $(D generator) will be used later as the random parameter value source in
    the following $(D foreach) loop. The $(D RndValueGen) takes three
    construction parameter. The first is the random source, in our case
    $(D rnd). The second is the $(D Benchmark) instance $(D ben) which stores
    the benchmark values. The third is the number of times the $(D foreach)
    loop should be run.
    */
    auto generator = RndValueGen!(
            Gen!(int, -10, 10),     // a random $(D int) between -10 and 10
            Gen!(float, 0.0, 10.0), // a random $(D float) between -10 and 10
            Gen!(string, 0, 9))  // a random $(D string) with a length
        (rnd, ben);                    // between 0 and 9

    /+ a, b and c will have random created inside $(D generator) that uses
    $(D rnd) as source of randomness
    foreach(int a, float b, string c; generator)     {
        int rslt = theFunctionToTest(a, b, c);

        /* The execution of the assertions must not be measured as runtime of
        the $(D theFunctionToTest). The member function $(D stop) of
        $(D Benchmark) stops the stopwatch. The stopwatch is automatically
        resumed when the loop is continued. */
        ben.stop();

        assert(rslt > 0); // some useful assertions.
    }
    +/

    /* When a $(D Benchmark) object goes out of scope the destructor writes
    the benchmark stats to a file, unless the $(D donWrite) member is set to
    $(D true). The name of the output file is $(D __FILE__ ~  "_benchmark.csv).
    The $(D Benchmark) instance will write a line of comma seperated values to
    the file containing. The line contains the following information: the given
    name, the date of execution, the measuring unit, the measurment, if the
    execution was abnormaliy interrupted. */
}+/

import core.time : TickDuration, to, MonoTime, dur;
import std.array : appender, Appender;
import std.datetime : StopWatch, DateTime, Clock;
import std.random : Random, uniform, randomSample;
import std.typetuple : TypeTuple;
import std.traits;

private auto avgStopWatchTime() {
    import core.time;

	MonoTime sw = MonoTime.currTime;

    enum numRounds = 500;
    MonoTime dummy;
    for(size_t i = 0; i < numRounds; ++i) {
        dummy = MonoTime.currTime;
        dummy = MonoTime.currTime;
    }

	auto diff = MonoTime.currTime - sw;

    return to!("nsecs",real)(cast(TickDuration)diff) / numRounds;
}

private TickDuration getQuantilTick(double q)(Duration[] ticks)
    pure @safe
{
    size_t idx = cast(size_t)(ticks.length * q);

    if (ticks.length % 2 == 1)
    {
        return cast(TickDuration)ticks[idx];
    }
    else
    {
        return cast(TickDuration)((ticks[idx] + ticks[idx-1]) / 2);
    }
}

unittest
{
    static import std.conv;
	import std.algorithm.iteration : map;

    auto ticks = [1,2,3,4,5].map!(a => dur!"seconds"(a)).array;

    TickDuration q25 = getQuantilTick!0.25(ticks);
    assert(q25 == TickDuration.from!"seconds"(2));

    TickDuration q50 = getQuantilTick!0.50(ticks);
    assert(q50 == TickDuration.from!"seconds"(3));

    TickDuration q75 = getQuantilTick!0.75(ticks);
    assert(q75 == TickDuration.from!"seconds"(4));

    q25 = getQuantilTick!0.25(ticks[0 .. 4]);
    long q25l = q25.to!("seconds",long)();
    assert(q25l == 1);

    q50 = getQuantilTick!0.50(ticks[0 .. 4]);
    long q50l = q50.to!("seconds",long)();
    assert(q50l == 2, std.conv.to!string(q50l));

    q75 = getQuantilTick!0.75(ticks[0 .. 4]);
    long q75l = q75.to!("seconds",long)();
    assert(q75l == 3, std.conv.to!string(q75l));
}

struct Benchmark
{
    string filename; // where to write the benchmark result to
    string funcname; // the name of the benchmark
    string timeScale; // the unit the benchmark is measuring in
    real avgStopWatch; // the avg time it takes to get the clocktime twice
    size_t rounds; // how many round the benchmark is run
    bool dontWrite; // if set, no data is written to the the file name "filename"
 	// true if, RndValueGen opApply was interrupt unexpectitally
    bool wasInterrupted;
    Duration[] ticks; // the stopped times, there will be rounds ticks
    size_t ticksIndex = 0; // the index into ticks
	MonoTime startTime;
	Duration timeSpend; // overall time spend running the benchmark function

    static auto opCall(in string funcname, in size_t rounds,
            in string filename = __FILE__)
    {
        Benchmark ret;
        ret.filename = filename;
        ret.funcname = funcname;
        ret.timeScale = "nsecs";
        ret.rounds = rounds;
        ret.ticks = new Duration[ret.rounds];
        ret.avgStopWatch = avgStopWatchTime();
		ret.timeSpend = dur!"seconds"(0);
        return ret;
    }

    void start()
    {
		this.startTime = MonoTime.currTime;
    }

    void stop()
    {
		MonoTime end = MonoTime.currTime;
		Duration dur = end - this.startTime;
		this.timeSpend += dur;

        if (this.ticksIndex < ticks.length)
        {
            this.ticks[this.ticksIndex] = dur;
			
            ++this.ticksIndex;
        }
    }

	Duration peek() {
		return this.ticks[this.ticksIndex - 1];
	}

    ~this()
    {
        import std.stdio : File;
        if (!this.dontWrite)
        {
            import std.algorithm : sort;
            this.ticks.sort();

            auto f = File(filename ~ "_bechmark.csv", "a");
            scope(exit) f.close();

            auto q0 = (cast(TickDuration)ticks[0]).to!("nsecs",real)() / this.rounds;
            auto q25 = getQuantilTick!0.25(ticks).to!("nsecs",real)() / this.rounds;
            auto q50 = getQuantilTick!0.50(ticks).to!("nsecs",real)() / this.rounds;
            auto q75 = getQuantilTick!0.75(ticks).to!("nsecs",real)() / this.rounds;
            auto q100 = (cast(TickDuration)this.ticks[$-1]).to!("nsecs",real)() / this.rounds;

            // funcName, the data when the benchmark was created, unit of time,
            // rounds, wasInterrupted, avgStopWatch, low, 0.25 quantil, median,
            // 0.75 quantil, high
            f.writefln(
                "\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\",\"%s\","
				~ "\"%s\",\"%s\"",
                this.funcname, Clock.currTime.toISOExtString(), this.timeScale,
                   this.rounds, this.wasInterrupted, this.avgStopWatch,
                q0 > this.avgStopWatch ? q0 - this.avgStopWatch : 0,
                q25 > this.avgStopWatch ? q25 - this.avgStopWatch : 0,
                q50 > this.avgStopWatch ? q50 - this.avgStopWatch : 0,
                q75 > this.avgStopWatch ? q75 - this.avgStopWatch : 0,
                q100 > this.avgStopWatch ? q100 - this.avgStopWatch : 0
            );
        }
    }
}

/** A $(D Gen) type that generates numeric values between the values of the
template parameter $(D low) and $(D high).
*/
struct Gen(T,T low, T high)
	if(isNumeric!T)
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
struct Gen(T, size_t low, size_t high)
        if(isSomeString!T)
{
    static T charSet;
	static immutable size_t numCharsInCharSet;

	static this() {
    	import std.uni : unicode;
    	import std.conv : to;
    	import std.format : format;
    	import std.range : chain, iota;
    	import std.algorithm : map, joiner;

    	Gen!(T,low,high).charSet = to!T(chain(
    	    iota(0x21, 0x7E).map!(a => to!T(cast(dchar)a)),
    	    iota(0xA1, 0x1EF).map!(a => to!T(cast(dchar)a))).joiner.array);

		Gen!(T,low,high).numCharsInCharSet = count(charSet);
	}

    void gen(ref Random gen)
    {
		static assert(low <= high);
		import std.range : drop;
		import std.array : front;

        auto app = appender!T();
        app.reserve(high);
        size_t numElems = uniform!("[]")(low, high, gen);

		for(size_t i = 0; i < numElems; ++i) 
		{
			size_t toSelect = uniform!("[]")(0, numCharsInCharSet, gen);
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
	static assert( isGen!(Gen!(int, 0, 10)));
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
	void genValues() {
		foreach(ref it; this.values) {
			it.gen(*this.rnd);
		}
	}
}

///
unittest
{
    auto rnd = Random(1337);
    auto generator = RndValueGen!(Gen!(int, 0, 10), Gen!(float, 0.0, 10.0))
        (&rnd);
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
    auto generator = RndValueGen!(Gen!(int, 0, 10), Gen!(float, 0.0, 10.0))
        (&rnd);

	generator.genValues();
	foreach(i; 0 .. 1000) {
		fun(generator.values);
	}
}

/** A template that turns a $(D T) into a $(D Gen!T) unless $(D T) is
already a $(D Gen) or no $(D Gen) for given $(D T) is avaiable.
*/
template ParameterToGen(T) {
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

	static fun(int i) {

	}

	GenInt a;
	fun(a);
}

unittest
{
	foreach(T; TypeTuple!(byte,ubyte,ushort,short,uint,int,ulong,long,float,
				double,real,string,wstring,dstring))
	{
		alias TP = staticMap!(ParameterToGen, T);
		static assert(isGen!TP);
	}
}

private void funToBenchmark(int a, float b, Gen!(int, -5, 5) c, string d) {
	import core.thread;
	Thread.sleep(1.seconds/4);
	writeln(a, " ", b, " ", c, " ", d);
}

unittest
{
	benchmark!funToBenchmark();
	benchmark!funToBenchmark("Another Name");
	benchmark!funToBenchmark("Another Name", 2.seconds);
	benchmark!funToBenchmark(2.seconds);
}

/** This function runs the passes $(D T) for the duration of $(D maxRuntime).
It will count how often $(D T) is run in the duration and how long each run
took to complete.
*/
void benchmark(alias T)(string name, Duration maxRuntime, int rndSeed) {
	auto bench = Benchmark(name, 1000);
    auto rnd = Random(rndSeed);
	auto valueGenerator = RndValueGen!(Parameters!T)(&rnd);

	size_t roundCnt = 0;
	while(bench.timeSpend <= maxRuntime)
	{
		writeln(bench.timeSpend);
		valueGenerator.genValues();

		bench.start();
		T(valueGenerator.values);
		bench.stop();

		++roundCnt;
	}
}

void benchmark(alias T)() {
	benchmark!(T)(fullyQualifiedName!T, 1.seconds, 1337);
}

void benchmark(alias T)(Duration maxRuntime) {
	benchmark!(T)(fullyQualifiedName!T, maxRuntime, 1337);
}

void benchmark(alias T)(string name) {
	benchmark!(T)(name, 1.seconds, 1337);
}

void benchmark(alias T)(string name, Duration maxRuntime) {
	benchmark!(T)(name, maxRuntime, 1337);
}

unittest
{
	immutable(ubyte)[] s = cast(immutable(ubyte)[])"Hello";
	string str = cast(string)s;
	assert(str == "Hello");
}

unittest
{
	import core.thread;

	struct Foo {
		void superSlowMethod(int a, Gen!(int,-10,10) b) {
			Thread.sleep(1.seconds/4);
			doNotOptimizeAway(cast(void*)&a);
		}
	}

	Foo a;

	auto del = delegate(int ai, Gen!(int,-10,10) b) { a.superSlowMethod(ai, b);
	};

	benchmark!(del)();
}

extern(C) void doNotOptimizeAway(void* p);

void main() {

}
