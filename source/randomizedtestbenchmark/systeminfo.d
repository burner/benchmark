module randomizedtestbenchmark.systeminfo;

import std.file : readText;
import std.string : strip, split, lineSplitter;
import std.conv : to;

version(linux)
{
    struct SystemSnapshot
    {
        double load1;
        double load5;
        double load15;
        long rssKB;
        long virtualMemKB;
        long systemTotalRamKB;
        long systemFreeRamKB;

        static SystemSnapshot capture()
        {
            SystemSnapshot snap;
            snap.load1 = 0;
            snap.load5 = 0;
            snap.load15 = 0;
            snap.rssKB = 0;
            snap.virtualMemKB = 0;
            snap.systemTotalRamKB = 0;
            snap.systemFreeRamKB = 0;

            try
            {
                auto loadavg = readText("/proc/loadavg").split();
                if (loadavg.length >= 3)
                {
                    snap.load1 = to!double(loadavg[0]);
                    snap.load5 = to!double(loadavg[1]);
                    snap.load15 = to!double(loadavg[2]);
                }
            }
            catch (Exception) {}

            try
            {
                auto status = readText("/proc/self/status");
                foreach (line; lineSplitter(status))
                {
                    auto parts = line.split();
                    if (parts.length >= 2)
                    {
                        if (parts[0] == "VmRSS:")
                            snap.rssKB = to!long(parts[1]);
                        else if (parts[0] == "VmSize:")
                            snap.virtualMemKB = to!long(parts[1]);
                    }
                }
            }
            catch (Exception) {}

            try
            {
                auto meminfo = readText("/proc/meminfo");
                foreach (line; lineSplitter(meminfo))
                {
                    auto parts = line.split();
                    if (parts.length >= 2)
                    {
                        if (parts[0] == "MemTotal:")
                            snap.systemTotalRamKB = to!long(parts[1]);
                        else if (parts[0] == "MemFree:")
                            snap.systemFreeRamKB = to!long(parts[1]);
                    }
                }
            }
            catch (Exception) {}

            return snap;
        }

        long memoryDeltaKB(ref const SystemSnapshot other) const
        {
            return other.rssKB - rssKB;
        }

        double loadDelta1min(ref const SystemSnapshot other) const
        {
            return other.load1 - load1;
        }
    }

    struct BenchmarkSystemMetrics
    {
        SystemSnapshot before;
        SystemSnapshot after;

        long memoryDeltaKB() const
        {
            return after.rssKB - before.rssKB;
        }

        double loadDelta1min() const
        {
            return after.load1 - before.load1;
        }

        double loadDelta5min() const
        {
            return after.load5 - before.load5;
        }

        double loadDelta15min() const
        {
            return after.load15 - before.load15;
        }
    }
}
else
{
    struct SystemSnapshot
    {
        double load1;
        double load5;
        double load15;
        long rssKB;
        long virtualMemKB;
        long systemTotalRamKB;
        long systemFreeRamKB;

        static SystemSnapshot capture()
        {
            SystemSnapshot snap;
            snap.load1 = 0;
            snap.load5 = 0;
            snap.load15 = 0;
            snap.rssKB = 0;
            snap.virtualMemKB = 0;
            snap.systemTotalRamKB = 0;
            snap.systemFreeRamKB = 0;
            return snap;
        }

        long memoryDeltaKB(ref const SystemSnapshot other) const
        {
            return 0;
        }

        double loadDelta1min(ref const SystemSnapshot other) const
        {
            return 0;
        }
    }

    struct BenchmarkSystemMetrics
    {
        SystemSnapshot before;
        SystemSnapshot after;

        long memoryDeltaKB() const { return 0; }
        double loadDelta1min() const { return 0; }
        double loadDelta5min() const { return 0; }
        double loadDelta15min() const { return 0; }
    }
}
