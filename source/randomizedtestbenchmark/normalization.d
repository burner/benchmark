module randomizedtestbenchmark.normalization;

import randomizedtestbenchmark.database;
import randomizedtestbenchmark.machine;

import std.math : sqrt;
import std.algorithm : min;

struct NormalizedResult
{
    string benchmarkName;
    string machineId;
    double rawMeanHnsecs;
    double normalizedScore;
    double cpuBenchmarkRatio;
    string timestamp;
}

struct CrossMachineResult
{
    string benchmarkName;
    string machineId;
    double meanHnsecs;
    double normalizedScore;
    double relativeToBest;
}

struct MachineBenchmark
{
    string machineId;
    string cpuModel;
    double score;
}

double getCpuBenchmarkRatio()
{
    import core.time : MonoTime;
    import randomizedtestbenchmark.benchmark : doNotOptimizeAway;

    enum iterations = 10_000_000;

    auto start = MonoTime.currTime;
    long dummy;
    for (int i = 0; i < iterations; i++)
    {
        dummy += i * 17 % 31;
    }
    auto end = MonoTime.currTime;
    doNotOptimizeAway(dummy);

    auto elapsed = (end - start).total!"hnsecs";
    double referenceRatio = 3_600_000_000.0 / elapsed;

    return referenceRatio;
}

double normalizeToReferenceCPU(double hnsecs, double cpuRatio)
{
    return hnsecs / cpuRatio;
}

NormalizedResult normalizeResult(BenchmarkRun run, BenchmarkDataPoint data, double cpuRatio)
{
    NormalizedResult result;
    result.benchmarkName = data.benchmarkName;
    result.machineId = run.machineId;
    result.rawMeanHnsecs = data.meanHnsecs;
    result.normalizedScore = normalizeToReferenceCPU(data.meanHnsecs, cpuRatio);
    result.cpuBenchmarkRatio = cpuRatio;
    result.timestamp = run.timestamp;
    return result;
}

NormalizedResult[] normalizeRun(Database db, long runId)
{
    import randomizedtestbenchmark.benchmark : BenchmarkResult;
    import randomizedtestbenchmark.statistics : Mean;

    NormalizedResult[] results;

    auto runs = db.getAllRuns();
    BenchmarkRun run;
    foreach (r; runs)
    {
        if (r.id == runId)
        {
            run = r;
            break;
        }
    }

    auto dataPoints = db.getResultsForRun(runId);
    double cpuRatio = getCpuBenchmarkRatio();

    foreach (data; dataPoints)
    {
        results ~= normalizeResult(run, data, cpuRatio);
    }

    return results;
}

CrossMachineResult[] compareAcrossMachines(Database db, string benchmarkName)
{
    CrossMachineResult[] results;

    auto allRuns = db.getAllRuns();
    double[string] machineRatios;

    foreach (run; allRuns)
    {
        if (run.machineId !in machineRatios)
        {
            machineRatios[run.machineId] = getCpuBenchmarkRatio();
        }
    }

    auto dataPoints = db.getResultsForBenchmark(benchmarkName);

    BenchmarkRun[long] runsMap;
    foreach (r; allRuns)
        runsMap[r.id] = r;

    foreach (data; dataPoints)
    {
        if (data.runId in runsMap)
        {
            auto run = runsMap[data.runId];
            auto ratio = machineRatios.get(run.machineId, 1.0);
            auto normalized = normalizeToReferenceCPU(data.meanHnsecs, ratio);

            CrossMachineResult cr;
            cr.benchmarkName = benchmarkName;
            cr.machineId = run.machineId;
            cr.meanHnsecs = data.meanHnsecs;
            cr.normalizedScore = normalized;
            cr.relativeToBest = 0;
            results ~= cr;
        }
    }

    if (results.length > 0)
    {
        double best = double.infinity;
        foreach (ref r; results)
        {
            if (r.normalizedScore < best)
                best = r.normalizedScore;
        }
        foreach (ref r; results)
        {
            r.relativeToBest = (r.normalizedScore / best - 1.0) * 100.0;
        }
    }

    return results;
}

double calculateStandardDeviation(double[] values)
{
    if (values.length == 0) return 0;

    double sum = 0;
    foreach (v; values)
        sum += v;
    double mean = sum / values.length;

    double varianceSum = 0;
    foreach (v; values)
        varianceSum += (v - mean) * (v - mean);

    return sqrt(varianceSum / values.length);
}

BenchmarkTrend analyzeTrend(Database db, string benchmarkName)
{
    BenchmarkTrend trend;
    trend.benchmarkName = benchmarkName;

    auto dataPoints = db.getResultsForBenchmark(benchmarkName);

    double[] means;
    long[] timestamps;

    foreach (data; dataPoints)
    {
        means ~= data.meanHnsecs;
    }

    if (means.length >= 2)
    {
        trend.mean = means[means.length - 1];
        trend.previousMean = means[means.length - 2];
        trend.changePercent = ((trend.mean - trend.previousMean) / trend.previousMean) * 100.0;
    }

    if (means.length >= 3)
    {
        double[] recentMeans = means[$ - min(3, means.length) .. $];
        trend.stdDeviation = calculateStandardDeviation(recentMeans);
    }

    return trend;
}

struct BenchmarkTrend
{
    string benchmarkName;
    double mean;
    double previousMean;
    double changePercent;
    double stdDeviation;
}
