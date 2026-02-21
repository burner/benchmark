module randomizedtestbenchmark.machine;

import std.file : readText;
import std.string : strip, split, lineSplitter;
import std.conv : to;
import std.algorithm : startsWith;
import std.process : execute;

struct MachineInfo
{
    string os;
    string cpuModel;
    int cpuCores;
    double memoryGb;
    string hostname;
    string kernelVersion;

    static MachineInfo collect()
    {
        MachineInfo info;
        info.os = "unknown";
        info.cpuModel = "unknown";
        info.cpuCores = 1;
        info.memoryGb = 0;
        info.hostname = "unknown";
        info.kernelVersion = "unknown";

        version(linux)
        {
            info.os = "linux";
            collectLinux(info);
        }
        else version(darwin)
        {
            info.os = "darwin";
            collectDarwin(info);
        }
        else version(Windows)
        {
            info.os = "windows";
            collectWindows(info);
        }

        return info;
    }

    private static void collectLinux(ref MachineInfo info)
    {
        try
        {
            auto cpuinfo = readText("/proc/cpuinfo");
            string modelName;
            int cores;
            foreach (line; lineSplitter(cpuinfo))
            {
                if (line.startsWith("model name"))
                {
                    auto parts = line.split(":");
                    if (parts.length >= 2)
                        modelName = strip(parts[1]);
                }
                if (line.startsWith("processor"))
                {
                    cores++;
                }
            }
            if (modelName.length > 0)
                info.cpuModel = modelName;
            if (cores > 0)
                info.cpuCores = cores;
        }
        catch (Exception) {}

        try
        {
            auto meminfo = readText("/proc/meminfo");
            foreach (line; lineSplitter(meminfo))
            {
                if (line.startsWith("MemTotal:"))
                {
                    auto parts = line.split();
                    if (parts.length >= 2)
                    {
                        long kb = to!long(parts[1]);
                        info.memoryGb = kb / 1024.0 / 1024.0;
                    }
                }
            }
        }
        catch (Exception) {}

        try
        {
            auto utsname = readText("/proc/sys/kernel/hostname");
            info.hostname = strip(utsname);
        }
        catch (Exception) {}

        try
        {
            auto kernelVer = readText("/proc/sys/kernel/osrelease");
            info.kernelVersion = strip(kernelVer);
        }
        catch (Exception) {}
    }

    private static void collectDarwin(ref MachineInfo info)
    {
        auto sysctl = (string cmd) {
            auto result = execute(["sh", "-c", cmd]);
            return result.output.strip;
        };

        info.cpuModel = sysctl("sysctl -n machdep.cpu.brand_string");
        info.cpuCores = to!int(sysctl("sysctl -n hw.ncpu"));
        info.hostname = sysctl("hostname");
        
        auto memBytes = to!long(sysctl("sysctl -n hw.memsize"));
        info.memoryGb = memBytes / 1024.0 / 1024.0 / 1024.0;
    }

    private static void collectWindows(ref MachineInfo info)
    {
        auto wmic = (string cmd) {
            auto result = execute(["cmd", "/c", cmd]);
            return result.output.strip;
        };

        info.cpuModel = wmic("cpu get Name");
        info.cpuCores = to!int(wmic("cpu get NumberOfCores"));
        auto memKB = to!long(wmic("computerSystem get TotalPhysicalMemory"));
        info.memoryGb = memKB / 1024.0 / 1024.0;
    }

    string fingerprint() const
    {
        import std.string : representation;
        import std.digest.sha : SHA256;
        import std.digest : digest, toHexString;
        import std.array : array;
        
        string data = cpuModel ~ to!string(cpuCores) ~ hostname;
        auto hash = digest!SHA256(data.representation);
        auto hex = toHexString(hash);
        return hex[0 .. 16].idup;
    }
}

unittest
{
    auto machine = MachineInfo.collect();
    assert(machine.os.length > 0);
    assert(machine.fingerprint().length == 16);
}
