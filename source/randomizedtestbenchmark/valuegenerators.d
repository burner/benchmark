module randomizedtestbenchmark.valuegenerators;

import std.algorithm : count, map, joiner;
import std.array : array, appender, empty;
import std.conv : to;
import std.meta : AliasSeq, aliasSeqOf, staticMap;
import std.random : Random, uniform;
import std.range : chain, drop, iota;
import std.traits : Parameters, ParameterStorageClassTuple, ParameterStorageClass
     , isImplicitlyConvertible, isArray, isSomeChar, isFloatingPoint, isNumeric
     , isSomeString, isIntegral;
import std.utf : byDchar;

/* Return $(D true) if the passed $(D T) is a $(D Gen) struct.

A $(D Gen!T) is something that implicitly converts to $(D T), has a method
called $(D gen) that is accepting a $(D ref Random).

This module already brings Gens for numeric types, strings and ascii strings.

If a function needs to be benchmarked that has a parameter of custom type a
custom $(D Gen) is required.
*/
template isGen(T)
{
    static if (__traits(hasMember, T, "Type") && __traits(hasMember, T, "gen")
            && Parameters!(__traits(getMember, T, "gen")).length == 1 
			&& is(Parameters!(__traits(getMember, T, "gen"))[0] == Random) 
			&& ParameterStorageClassTuple!(__traits(getMember, T, "gen")).length == 1
            && ParameterStorageClassTuple!(
				__traits(getMember, T, "gen"))[0] == ParameterStorageClass.ref_
            && isImplicitlyConvertible!(T, __traits(getMember, T, "Type")))
    {
        enum isGen = true;
    }
    else
    {
        enum isGen = false;
    }
}

///
@safe pure unittest
{
    static assert(!isGen!int);
    static assert(isGen!(Gen!(int, 0, 10)));
    static assert(isGen!(Gen!(float, 0, 10)));
    static assert(isGen!(Gen!(string)));
    static assert(isGen!(Gen!(string, 0, 10)));
    static assert(isGen!(Gen!(string, 0, 10, false)));
    static assert(isGen!(Gen!(string, 0, 10, true)));
}

/** A $(D Gen) type that generates character values. */
struct Gen(T, T low = 0, T high = T.max) if (isSomeChar!T)
{
    alias Type = T;
    T value;

    void gen(ref Random gen)
    {
        this.value = uniform!("[]", T)(low, high);
    }

    alias value this;
}

/** A $(D Gen) type that generates numeric values between the values of the
template parameter $(D low) and $(D high) for a numeric type $(D T).
*/
struct Gen(T, T low = 0, T high = T.max) if (isNumeric!T)
{
    alias Type = T;
    T value;

    void gen(ref Random gen)
    {
        static assert(low <= high);
        this.value = uniform!("[]")(low, high, gen);
    }

    alias value this;
}

/** A $(D Gen) type that generates a fixed-size array of numeric values
and provides slices with controlled sizes for benchmarking.

The first four calls to $(D gen) return predictable slices:
- 1st call: empty slice
- 2nd call: 1 element
- 3rd call: 2 elements  
- 4th call: all elements
- 5th+: random slice within bounds

Template parameters:
- $(D T): element type - numeric (integral/floating point), string, or bool
- $(D N): array size (default 16384)
- $(D lowVal): minimum element value for numeric types (default 0)
- $(D highVal): maximum element value for numeric types (default T.max)
- $(D strLenLow): minimum string length for string arrays (default 0)
- $(D strLenHigh): maximum string length for string arrays (default 30)
- $(D unicode): generate unicode strings for string arrays (default false)
*/
struct GenArray(T, size_t N = 16384, T lowVal = 0, T highVal = T.max) 
    if (isIntegral!T || isFloatingPoint!T || is(T == bool))
{
    alias Type = T[];
    T[N] data;
    T[] slice;
    size_t iteration;

    void gen(ref Random rnd)
    {
        static assert(lowVal <= highVal);
        
        static if (is(T == bool))
        {
            foreach (ref elem; data)
                elem = cast(bool) uniform!"[]"(0, 1, rnd);
        }
        else
        {
            foreach (ref elem; data)
                elem = uniform!("[]")(lowVal, highVal, rnd);
        }

        setSlice(rnd);
    }

    private void setSlice(ref Random rnd)
    {
        iteration++;
        if (iteration == 1)
            slice = data[0 .. 0];
        else if (iteration == 2)
            slice = data[0 .. 1];
        else if (iteration == 3)
            slice = data[0 .. 2];
        else if (iteration == 4)
            slice = data[0 .. N];
        else
        {
            size_t start = uniform!("[)")(0, N, rnd);
            size_t end = uniform!("[]")(start, N - 1, rnd);
            slice = data[start .. end + 1];
        }
    }

    alias slice this;
}

/// Overload for string arrays
struct GenArray(T, size_t N = 16384, size_t strLenLow = 0, size_t strLenHigh = 30, bool unicode = false) 
    if (isSomeString!T)
{
    alias Type = T[];
    static if (unicode)
        static immutable T charSet = genCharSet!T();
    else
        static immutable T charSet = genCharSetASCII!T();
    static immutable size_t numCharsInCharSet = count(charSet);

    T[N] data;
    T[] slice;
    size_t iteration;

    void gen(ref Random rnd)
    {
        static assert(strLenLow <= strLenHigh);
        foreach (ref str; data)
        {
            auto app = appender!T();
            app.reserve(strLenHigh);
            size_t numElems = uniform!("[]")(strLenLow, strLenHigh, rnd);

            for (size_t i = 0; i < numElems; ++i)
            {
                size_t toSelect = uniform!("[)")(0, numCharsInCharSet, rnd);
                static if (unicode)
                {
                    app.put(charSet.byDchar().drop(toSelect).front);
                }
                else
                {
                    app.put(charSet[toSelect]);
                }
            }
            str = app.data;
        }

        iteration++;
        if (iteration == 1)
            slice = data[0 .. 0];
        else if (iteration == 2)
            slice = data[0 .. 1];
        else if (iteration == 3)
            slice = data[0 .. 2];
        else if (iteration == 4)
            slice = data[0 .. N];
        else
        {
            size_t start = uniform!("[)")(0, N, rnd);
            size_t end = uniform!("[]")(start, N - 1, rnd);
            slice = data[start .. end + 1];
        }
    }

    alias slice this;
}

unittest
{
    auto rnd = Random(1337);
    
    GenArray!(int, 100, 0, 10) gen;
    static assert(isGen!(typeof(gen)));
    
    gen.gen(rnd);
    assert(gen.slice.length == 0);
    
    gen.gen(rnd);
    assert(gen.slice.length == 1);
    
    gen.gen(rnd);
    assert(gen.slice.length == 2);
    
    gen.gen(rnd);
    assert(gen.slice.length == 100);
    
    foreach (i; 0 .. 100)
    {
        gen.gen(rnd);
        assert(gen.slice.length >= 1);
        assert(gen.slice.length <= 100);
    }
}

private pure @safe T genCharSet(T)()
{
    return to!T(chain(iota(0x21, 0x7E).map!(a => to!T(cast(dchar) a)),
            iota(0xA1, 0x1EF).map!(a => to!T(cast(dchar) a))).joiner.array);
}

private pure @safe T genCharSetASCII(T)()
{
    auto charSet = to!T(chain(iota(0x21, 0x7B)
            .map!(a => to!char(cast(dchar) a)).array)
        );
    return charSet;
}

/** A $(D Gen) type that generates strings with a number of characters between
template parameters $(D low) and $(D high).

Template parameters:
- $(D T): string type (string, wstring, dstring)
- $(D low): minimum string length (default 0)
- $(D high): maximum string length (default 30)
- $(D unicode): if true, generate unicode strings; if false, ASCII only (default false)
*/
struct Gen(T, size_t low = 0, size_t high = 30, bool unicode = false) if (isSomeString!T)
{
    alias Type = T;
    T value;

    static if (unicode)
    {
        static immutable T charSet = genCharSet!T();
    }
    else
    {
        static immutable T charSet = genCharSetASCII!T();
    }
    static immutable size_t numCharsInCharSet = count(charSet);

    void gen(ref Random gen)
    {
        static assert(low <= high);
        auto app = appender!T();
        app.reserve(high);
        size_t numElems = uniform!("[]")(low, high, gen);

        for (size_t i = 0; i < numElems; ++i)
        {
            size_t toSelect = uniform!("[)")(0, numCharsInCharSet, gen);
            static if (unicode)
            {
                app.put(charSet.byDchar().drop(toSelect).front);
            }
            else
            {
                app.put(charSet[toSelect]);
            }
        }

        this.value = app.data;
    }

    alias value this;
}

@safe pure unittest
{
    auto r = Random(1337);
    foreach (T; AliasSeq!(string, wstring, dstring))
    {
        foreach (L; aliasSeqOf!(iota(0, 2)))
        {
            foreach (H; aliasSeqOf!(iota(L, 2)))
            {
                Gen!(T, L, H, false) a;
                a.gen(r);
                if (L)
                {
                    assert(!a.value.empty);
                }
            }
        }
    }
}

/** This type will generate a $(D Gen!T) for all passed $(D T...).
Every call to $(D genValues) will call $(D gen) of all $(D Gen) structs
present in $(D values). The member $(D values) can be passed to every
function accepting $(D T...).
*/
struct RndValueGen(T...)
{
    static if (T.length > 0)
    {
        /* $(D Values) is a collection of $(D Gen) types created through
    	$(D ParameterToGen) of passed $(T ...).
    	*/
        alias Values = staticMap!(ParameterToGen, T[1 .. $]);
        /// Ditto
        Values values;
    }

    /* The constructor accepting the required random number generator.
    Params:
        rnd = The required random number generator.
    */
    this(Random rnd)
    {
        this.rnd = rnd;
    }

    /* The random number generator used to generate new value for all
    $(D values).
    */
    Random rnd;

    /** A call to this member function will call $(D gen) on all items in
    $(D values) passing $(D the provided) random number generator
    */
    void genValues()
    {
        static if (T.length > 0)
        {
            foreach (ref it; this.values)
            {
                it.gen(this.rnd);
            }
        }
    }
}

///
unittest
{
    auto rnd = Random(1337);
    auto generator = RndValueGen!(["i", "f"], Gen!(int, 0, 10),
		   	Gen!(float, 0.0, 10.0)
		)(rnd);
    generator.genValues();

    static fun(int i, float f)
    {
        assert(i >= 0 && i <= 10);
        assert(f >= 0.0 && i <= 10.0);
    }

    fun(generator.values);
}

@safe pure unittest
{
    auto rnd = Random(1337);
    auto generator = RndValueGen!()(rnd);
    generator.genValues();
}

unittest
{
    static fun(int i, float f)
    {
        assert(i >= 0 && i <= 10);
        assert(f >= 0.0 && i <= 10.0);
    }

    auto rnd = Random(1337);
    auto generator = RndValueGen!(["i", "f"], Gen!(int, 0, 10),
		   	Gen!(float, 0.0, 10.0)
		)(rnd);

    generator.genValues();
    foreach (i; 0 .. 1000)
    {
        fun(generator.values);
    }
}

/** A template that turns a $(D T) into a $(D Gen!T) unless $(D T) is
already a $(D Gen) or no $(D Gen) for given $(D T) is available.
*/
template ParameterToGen(T)
{
    static if (isGen!T)
        alias ParameterToGen = T;
    else static if (isSomeString!T)
        alias ParameterToGen = Gen!(T, 0, 32);
    else static if (is(T == U[], U))
    {
        static if (is(U == bool))
            alias ParameterToGen = GenArray!bool;
        else static if (isIntegral!U)
            alias ParameterToGen = GenArray!U;
        else static if (isFloatingPoint!U)
            alias ParameterToGen = GenArray!U;
        else static if (isSomeString!U)
            alias ParameterToGen = GenArray!U;
        else
            static assert(false, T.stringof);
    }
    else static if (isIntegral!T)
        alias ParameterToGen = Gen!(T, T.min, T.max);
    else static if (isSomeChar!T)
        alias ParameterToGen = Gen!(T);
    else static if (isFloatingPoint!T)
        alias ParameterToGen = Gen!(T, T.min_normal, T.max);
    else static if (is(T : GenASCIIString!(S), S...))
        alias ParameterToGen = T;
    else
        static assert(false, T.stringof);
}

///
@safe pure unittest
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

@safe pure unittest
{
    foreach (T; AliasSeq!(byte, ubyte, ushort, char, wchar, dchar, short, uint,
            int, ulong, long, float, double, real, string, wstring, dstring))
    {
        alias TP = staticMap!(ParameterToGen, T);
        static assert(isGen!TP);
    }
}

@safe pure unittest
{
    foreach (T; AliasSeq!(int[], float[], double[], long[]))
    {
        alias GenArr = ParameterToGen!T;
        static assert(isGen!GenArr);
        static assert(is(GenArr.Type == T));
    }
}

@safe pure unittest
{
    auto rnd = Random(1337);

    GenArray!(string, 10, 3, 5, false) gen;
    static assert(isGen!(typeof(gen)));
    static assert(is(typeof(gen.slice) == string[]));

    gen.gen(rnd);
    assert(gen.slice.length == 0);

    gen.gen(rnd);
    assert(gen.slice.length == 1);
    assert(gen[0].length >= 3 && gen[0].length <= 5);

    gen.gen(rnd);
    assert(gen.slice.length == 2);

    gen.gen(rnd);
    assert(gen.slice.length == 10);

    foreach (i; 0 .. 10)
    {
        gen.gen(rnd);
        assert(gen.slice.length >= 1);
        assert(gen.slice.length <= 10);
    }
}

@safe pure unittest
{
    foreach (T; AliasSeq!(string[], wstring[], dstring[]))
    {
        alias GenArr = ParameterToGen!T;
        static assert(isGen!GenArr);
        static assert(is(GenArr.Type == T));
    }
}

@safe pure unittest
{
    auto rnd = Random(1337);

    GenArray!(int, 10, 0, 100) gen;
    static assert(isGen!(typeof(gen)));

    gen.gen(rnd);
    assert(gen.slice.length == 0);

    gen.gen(rnd);
    assert(gen.slice.length == 1);

    gen.gen(rnd);
    assert(gen.slice.length == 2);

    gen.gen(rnd);
    assert(gen.slice.length == 10);

    foreach (i; 0 .. 10)
    {
        gen.gen(rnd);
        assert(gen.slice.length >= 1);
        assert(gen.slice.length <= 10);
    }
}

@safe pure unittest
{
    auto rnd = Random(1337);

    GenArray!(float, 10, 0.0f, 1.0f) gen;
    static assert(isGen!(typeof(gen)));

    gen.gen(rnd);
    assert(gen.slice.length == 0);

    gen.gen(rnd);
    assert(gen.slice.length == 1);
    assert(gen[0] >= 0.0f && gen[0] <= 1.0f);

    gen.gen(rnd);
    assert(gen.slice.length == 2);

    gen.gen(rnd);
    assert(gen.slice.length == 10);
}

@safe pure unittest
{
    auto rnd = Random(1337);

    GenArray!(string, 10, 3, 5, false) gen;
    static assert(isGen!(typeof(gen)));

    gen.gen(rnd);
    assert(gen.slice.length == 0);

    gen.gen(rnd);
    assert(gen.slice.length == 1);
    assert(gen[0].length >= 3 && gen[0].length <= 5);

    gen.gen(rnd);
    assert(gen.slice.length == 2);

    gen.gen(rnd);
    assert(gen.slice.length == 10);

    foreach (i; 0 .. 10)
    {
        gen.gen(rnd);
        assert(gen.slice.length >= 1);
        assert(gen.slice.length <= 10);
    }
}

@safe pure unittest
{
    auto rnd = Random(1337);

    GenArray!bool gen;
    static assert(isGen!(typeof(gen)));

    gen.gen(rnd);
    assert(gen.slice.length == 0);

    gen.gen(rnd);
    assert(gen.slice.length == 1);

    gen.gen(rnd);
    assert(gen.slice.length == 2);

    gen.gen(rnd);
    assert(gen.slice.length == 16384);

    foreach (i; 0 .. 10)
    {
        gen.gen(rnd);
        assert(gen.slice.length >= 1);
        assert(gen.slice.length <= 16384);
    }
}
