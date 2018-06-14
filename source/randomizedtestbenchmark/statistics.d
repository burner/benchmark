module randomizedtestbenchmark.statistics;

import std.container.array : Array;
import core.time : Duration;
import std.range : SortedRange;

immutable defaultQuantils = [0.01, 0.25, 0.5, 0.75, 0.99];

alias SortedDurationArray = SortedRange!(Array!(Duration).Range, "a < b");

/* The quantil measure.
Params:
	quantil = 0.0 <= qunatil <= 1.0
*/
struct Quantil(double quantil)
{
    import std.math : approxEqual;

    static if (approxEqual(quantil, 1.0))
    {
        static immutable name = "Quantil!1.00";
    }
    else
    {
        import std.format : format;

        static immutable name = format!"Quantil!0.%2d"(cast(int)(quantil * 100));
    }
    static Duration compute(SortedDurationArray ticks)
    {
        import std.exception : enforce;

        enforce(ticks.length > 0, "Can't take the quantil of an empty range");
        size_t idx = cast(size_t)(ticks.length * quantil);

        if (ticks.length % 2 == 1)
        {
            return ticks[idx];
        }
        else
        {
            if (idx == 0)
            {
                return ticks[idx];
            }
            else
            {
                return (ticks[idx] + ticks[idx - 1]) / 2;
            }
        }
    }
}

unittest
{
    import core.time : dur;
    import std.meta : aliasSeqOf;

    Array!(Duration) durs;
    durs.insertBack(dur!"seconds"(2));

    void test(double q)()
    {
        import std.range : assumeSorted;

        alias Quan = Quantil!q;
        Duration r = Quan.compute(assumeSorted(durs[]));
        assert(r == durs[0]);
    }

    foreach (q; aliasSeqOf!(defaultQuantils))
    {
        test!(q)();
    }
}

unittest
{
    import core.time : dur;
    import std.meta : aliasSeqOf;

    Array!(Duration) durs;
    durs.insertBack(dur!"seconds"(1));
    durs.insertBack(dur!"seconds"(2));

    void test(double q)()
    {
        import std.range : assumeSorted;

        alias Quan = Quantil!q;
        Duration r = Quan.compute(assumeSorted(durs[]));
        assert(r == durs[0] || r == durs[1] || r == (durs[0] + durs[1]) / 2);
    }

    foreach (q; aliasSeqOf!(defaultQuantils))
    {
        test!(q)();
    }
}

/** The Mean measure.
*/
struct Mean
{
    static immutable name = "Mean";
    static Duration compute(SortedDurationArray ticks)
    {
        Duration sum;
        foreach (ref it; ticks)
        {
            sum += it;
        }
        return sum / ticks.length;
    }
}

unittest
{
    import std.range : assumeSorted;
    import core.time : dur;

    Array!(Duration) durs;
    durs.insertBack(dur!"seconds"(1));
    durs.insertBack(dur!"seconds"(2));

    auto avg = Mean.compute(assumeSorted(durs[]));
    assert((durs[0] + durs[1]) / 2 == avg);
}

/** The Mode measure.
*/
struct Mode
{
    static immutable name = "Mode";
    static Duration compute(SortedDurationArray ticks)
    {
        Duration max;
        size_t maxCnt;
        Duration cur;
        size_t curCnt;

        size_t idx;
        foreach (ref it; ticks)
        {
            if (idx == 0)
            {
                cur = it;
                curCnt = 1;
            }
            else
            {
                if (it == cur)
                {
                    ++curCnt;
                }
                else if (curCnt > maxCnt)
                {
                    max = cur;
                    maxCnt = curCnt;
                    curCnt = 1;
                    cur = it;
                }
            }
            ++idx;
        }

        if (curCnt > maxCnt)
        {
            max = cur;
        }

        return max;
    }
}

unittest
{
    import std.range : assumeSorted;
    import core.time : dur;

    Array!(Duration) durs;
    durs.insertBack(dur!"seconds"(1));

    auto mode = Mode.compute(assumeSorted(durs[]));
    assert(mode == durs[0]);
}

unittest
{
    import std.range : assumeSorted;
    import core.time : dur;

    Array!(Duration) durs;
    durs.insertBack(dur!"seconds"(1));
    durs.insertBack(dur!"seconds"(2));

    auto mode = Mode.compute(assumeSorted(durs[]));
    assert(mode == durs[0]);
}

unittest
{
    import std.range : assumeSorted;
    import core.time : dur;
    import std.format : format;

    Array!(Duration) durs;
    durs.insertBack(dur!"seconds"(1));
    durs.insertBack(dur!"seconds"(1));
    durs.insertBack(dur!"seconds"(2));
    durs.insertBack(dur!"seconds"(2));
    durs.insertBack(dur!"seconds"(2));

    auto mode = Mode.compute(assumeSorted(durs[]));
    assert(mode == durs[2], format("%s %s", mode, durs[2]));
}

unittest
{
    import std.range : assumeSorted;
    import core.time : dur;
    import std.format : format;

    Array!(Duration) durs;
    durs.insertBack(dur!"seconds"(1));
    durs.insertBack(dur!"seconds"(1));
    durs.insertBack(dur!"seconds"(1));
    durs.insertBack(dur!"seconds"(2));
    durs.insertBack(dur!"seconds"(2));

    auto mode = Mode.compute(assumeSorted(durs[]));
    assert(mode == durs[0], format("%s %s", mode, durs[2]));
}

/** The Min measure.
*/
struct Min
{
    static immutable name = "Min";
    static Duration compute(SortedDurationArray ticks)
    {
        return ticks.front;
    }
}

/** The Max measure.
*/
struct Max
{
    static immutable name = "Max";
    static Duration compute(SortedDurationArray ticks)
    {
        return ticks.back;
    }
}

unittest
{
    import std.range : assumeSorted;
    import core.time : dur;

    Array!(Duration) durs;
    durs.insertBack(dur!"seconds"(1));
    durs.insertBack(dur!"seconds"(2));

    auto min = Min.compute(assumeSorted(durs[]));
    assert(min == durs[0]);
    auto max = Max.compute(assumeSorted(durs[]));
    assert(max == durs[1]);
}
