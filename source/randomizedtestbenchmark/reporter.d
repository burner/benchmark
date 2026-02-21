module randomizedtestbenchmark.reporter;

import randomizedtestbenchmark.database;
import randomizedtestbenchmark.benchmark;
import randomizedtestbenchmark.statistics;

import std.stdio : File, writeln;
import std.string : format;
import std.array : appender;
import std.range : enumerate;

string generateCsvHeader()
{
    return "benchmark,run_id,timestamp,machine_id,cpu_model,cpu_cores,memory_gb," ~
           "seed,max_rounds,max_time_seconds," ~
           "min_hnsecs,max_hnsecs,mean_hnsecs,mode_hnsecs," ~
           "quantil_01_hnsecs,quantil_25_hnsecs,quantil_50_hnsecs," ~
           "quantil_75_hnsecs,quantil_99_hnsecs," ~
           "sample_size,total_time_hnsecs," ~
           "load_before_1,load_before_5,load_before_15,memory_before_kb," ~
           "load_after_1,load_after_5,load_after_15,memory_after_kb,memory_delta_kb";
}

string resultToCsvRow(BenchmarkRun run, BenchmarkDataPoint data)
{
    return format("%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s",
        data.benchmarkName,
        run.id,
        run.timestamp,
        run.machineId,
        run.cpuModel,
        run.cpuCores,
        run.memoryGb,
        run.seed,
        run.maxRounds,
        run.maxTimeSeconds,
        data.minHnsecs,
        data.maxHnsecs,
        data.meanHnsecs,
        data.modeHnsecs,
        data.quantil01,
        data.quantil25,
        data.quantil50,
        data.quantil75,
        data.quantil99,
        data.sampleSize,
        data.totalTimeHnsecs,
        run.loadBefore1,
        run.loadBefore5,
        run.loadBefore15,
        run.memoryBeforeKB,
        run.loadAfter1,
        run.loadAfter5,
        run.loadAfter15,
        run.memoryAfterKB,
        run.memoryDeltaKB
    );
}

void exportRunsToCsv(Database db, string filename)
{
    auto file = File(filename, "w");
    file.writeln(generateCsvHeader());

    auto runs = db.getAllRuns();
    foreach (run; runs)
    {
        auto results = db.getResultsForRun(run.id);
        foreach (data; results)
        {
            file.writeln(resultToCsvRow(run, data));
        }
    }
}

void exportRunToCsv(Database db, long runId, string filename)
{
    auto file = File(filename, "w");
    file.writeln(generateCsvHeader());

    auto run = db.getAllRuns()[0];
    foreach (r; db.getAllRuns())
    {
        if (r.id == runId)
        {
            run = r;
            break;
        }
    }

    auto results = db.getResultsForRun(runId);
    foreach (data; results)
    {
        file.writeln(resultToCsvRow(run, data));
    }
}

void exportBenchmarkToCsv(Database db, string benchmarkName, string filename)
{
    auto file = File(filename, "w");
    file.writeln(generateCsvHeader());

    auto results = db.getResultsForBenchmark(benchmarkName);
    auto runs = db.getAllRuns();

    BenchmarkRun[long] runsMap;
    foreach (r; runs)
        runsMap[r.id] = r;

    foreach (data; results)
    {
        if (data.runId in runsMap)
            file.writeln(resultToCsvRow(runsMap[data.runId], data));
    }
}

string generateMarkdownReport(BenchmarkRun[] runs, BenchmarkDataPoint[] results)
{
    auto app = appender!string();

    app.put("# Benchmark Results\n\n");

    app.put("## Machine Information\n\n");
    if (runs.length > 0)
    {
        auto run = runs[0];
        app.put(format("- **Machine ID**: %s\n", run.machineId));
        app.put(format("- **CPU**: %s\n", run.cpuModel));
        app.put(format("- **Cores**: %d\n", run.cpuCores));
        app.put(format("- **Memory**: %.1f GB\n", run.memoryGb));
        app.put(format("- **OS**: %s\n", run.os));
    }
    app.put("\n");

    app.put("## Benchmark Results\n\n");
    app.put("| Benchmark | Mean (hnsecs) | Min | Max | Sample Size |\n");
    app.put("|-----------|---------------|-----|-----|-------------|\n");

    foreach (data; results)
    {
        app.put(format("| %s | %.2f | %d | %d | %d |\n",
            data.benchmarkName,
            data.meanHnsecs,
            data.minHnsecs,
            data.maxHnsecs,
            data.sampleSize));
    }
    app.put("\n");

    if (runs.length > 0)
    {
        auto run = runs[0];
        app.put("## System Metrics\n\n");
        app.put("| Metric | Before | After | Delta |\n");
        app.put("|--------|--------|-------|-------|\n");
        app.put(format("| Load (1min) | %.2f | %.2f | %.2f |\n",
            run.loadBefore1, run.loadAfter1, run.loadAfter1 - run.loadBefore1));
        app.put(format("| Memory RSS (KB) | %d | %d | %d |\n",
            run.memoryBeforeKB, run.memoryAfterKB, run.memoryDeltaKB));
    }

    return app.data;
}

void generateMarkdownReport(Database db, string filename)
{
    import std.file : write;

    auto runs = db.getAllRuns();
    BenchmarkDataPoint[] allResults;

    foreach (run; runs)
    {
        auto results = db.getResultsForRun(run.id);
        allResults ~= results;
    }

    auto report = generateMarkdownReport(runs, allResults);
    write(filename, report);
}

string generateComparisonMarkdown(ComparisonResult[] comparisons)
{
    auto app = appender!string();

    app.put("# Benchmark Comparison\n\n");

    app.put("| Benchmark | Old Mean | New Mean | Change % | Memory Delta |\n");
    app.put("|-----------|-----------|-----------|----------|--------------|\n");

    foreach (comp; comparisons)
    {
        string changeStr;
        if (comp.percentChange > 0)
            changeStr = format("+%.1f%% (slower)", comp.percentChange);
        else if (comp.percentChange < 0)
            changeStr = format("%.1f%% faster", -comp.percentChange);
        else
            changeStr = "0%";

        app.put(format("| %s | %.2f | %.2f | %s | %d KB |\n",
            comp.benchmarkName,
            comp.oldMean,
            comp.newMean,
            changeStr,
            comp.newMemoryDelta - comp.oldMemoryDelta));
    }

    return app.data;
}

void generateComparisonReport(Database db, string benchmarkName, long newRunId, string filename, bool global = false)
{
    import std.file : write;

    auto comparisons = global 
        ? db.compareWithGlobalBaseline(benchmarkName, newRunId)
        : db.compareWithBaseline(benchmarkName, newRunId);

    auto report = generateComparisonMarkdown(comparisons);
    write(filename, report);
}
