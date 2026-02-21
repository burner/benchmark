module randomizedtestbenchmark.database;

import randomizedtestbenchmark.benchmark;
import randomizedtestbenchmark.systeminfo;
import randomizedtestbenchmark.machine;

import std.string : toStringz, fromStringz;
import std.conv : to;
import std.array : array;

import etc.c.sqlite3;

struct BenchmarkRun
{
    long id;
    string timestamp;
    string machineId;
    string dmdVersion;
    string os;
    string cpuModel;
    int cpuCores;
    double memoryGb;
    uint seed;
    size_t maxRounds;
    long maxTimeSeconds;
    double loadBefore1;
    double loadBefore5;
    double loadBefore15;
    long memoryBeforeKB;
    double loadAfter1;
    double loadAfter5;
    double loadAfter15;
    long memoryAfterKB;
    long memoryDeltaKB;
    string notes;
}

struct BenchmarkDataPoint
{
    long runId;
    string benchmarkName;
    long minHnsecs;
    long maxHnsecs;
    double meanHnsecs;
    long modeHnsecs;
    long quantil01;
    long quantil25;
    long quantil50;
    long quantil75;
    long quantil99;
    size_t sampleSize;
    long totalTimeHnsecs;
    long[] rawTicks;
}

struct ComparisonResult
{
    string benchmarkName;
    double oldMean;
    double newMean;
    double percentChange;
    long oldMemoryDelta;
    long newMemoryDelta;
    double memoryPercentChange;
}

class Database
{
    private sqlite3* db;

    this(string filename = "benchmark_results.db")
    {
        sqlite3_open(filename.toStringz(), &db);
    }

    ~this()
    {
        sqlite3_close(db);
    }

    void initialize()
    {
        run("
            CREATE TABLE IF NOT EXISTS runs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                machine_id TEXT NOT NULL,
                dmd_version TEXT,
                os TEXT NOT NULL,
                cpu_model TEXT,
                cpu_cores INTEGER,
                memory_gb REAL,
                seed INTEGER NOT NULL,
                max_rounds INTEGER NOT NULL,
                max_time_seconds INTEGER NOT NULL,
                load_before_1 REAL,
                load_before_5 REAL,
                load_before_15 REAL,
                memory_before_kb INTEGER,
                load_after_1 REAL,
                load_after_5 REAL,
                load_after_15 REAL,
                memory_after_kb INTEGER,
                memory_delta_kb INTEGER,
                notes TEXT
            )
        ");

        run("
            CREATE TABLE IF NOT EXISTS benchmarks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE,
                module_path TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
        ");

        run("
            CREATE TABLE IF NOT EXISTS results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                run_id INTEGER NOT NULL,
                benchmark_id INTEGER NOT NULL,
                min_hnsecs INTEGER NOT NULL,
                max_hnsecs INTEGER NOT NULL,
                mean_hnsecs REAL NOT NULL,
                mode_hnsecs INTEGER NOT NULL,
                quantil_01_hnsecs INTEGER,
                quantil_25_hnsecs INTEGER,
                quantil_50_hnsecs INTEGER,
                quantil_75_hnsecs INTEGER,
                quantil_99_hnsecs INTEGER,
                sample_size INTEGER NOT NULL,
                total_time_hnsecs INTEGER NOT NULL
            )
        ");

        run("
            CREATE TABLE IF NOT EXISTS raw_ticks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                result_id INTEGER NOT NULL,
                tick_hnsecs INTEGER NOT NULL
            )
        ");

        run("
            CREATE TABLE IF NOT EXISTS baselines (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                benchmark_id INTEGER NOT NULL,
                machine_id TEXT NOT NULL,
                run_id INTEGER NOT NULL,
                is_global INTEGER DEFAULT 0
            )
        ");

        run("CREATE INDEX IF NOT EXISTS idx_results_run ON results(run_id)");
        run("CREATE INDEX IF NOT EXISTS idx_results_benchmark ON results(benchmark_id)");
    }

    private void run(string sql)
    {
        char* errMsg;
        sqlite3_exec(db, sql.toStringz(), null, null, &errMsg);
        if (errMsg)
        {
            sqlite3_free(errMsg);
        }
    }

    long insertRun(BenchmarkRun run)
    {
        sqlite3_stmt* stmt;
        const char* sql = "
            INSERT INTO runs (
                timestamp, machine_id, dmd_version, os, cpu_model, cpu_cores,
                memory_gb, seed, max_rounds, max_time_seconds,
                load_before_1, load_before_5, load_before_15, memory_before_kb,
                load_after_1, load_after_5, load_after_15, memory_after_kb,
                memory_delta_kb, notes
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ".toStringz();

        sqlite3_prepare_v2(db, sql, -1, &stmt, null);

        sqlite3_bind_text(stmt, 1, run.timestamp.toStringz(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 2, run.machineId.toStringz(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 3, run.dmdVersion.toStringz(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 4, run.os.toStringz(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 5, run.cpuModel.toStringz(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_int(stmt, 6, run.cpuCores);
        sqlite3_bind_double(stmt, 7, run.memoryGb);
        sqlite3_bind_int(stmt, 8, run.seed);
        sqlite3_bind_int64(stmt, 9, run.maxRounds);
        sqlite3_bind_int64(stmt, 10, run.maxTimeSeconds);
        sqlite3_bind_double(stmt, 11, run.loadBefore1);
        sqlite3_bind_double(stmt, 12, run.loadBefore5);
        sqlite3_bind_double(stmt, 13, run.loadBefore15);
        sqlite3_bind_int64(stmt, 14, run.memoryBeforeKB);
        sqlite3_bind_double(stmt, 15, run.loadAfter1);
        sqlite3_bind_double(stmt, 16, run.loadAfter5);
        sqlite3_bind_double(stmt, 17, run.loadAfter15);
        sqlite3_bind_int64(stmt, 18, run.memoryAfterKB);
        sqlite3_bind_int64(stmt, 19, run.memoryDeltaKB);
        sqlite3_bind_text(stmt, 20, run.notes.toStringz(), -1, SQLITE_TRANSIENT);

        sqlite3_step(stmt);
        sqlite3_finalize(stmt);

        return sqlite3_last_insert_rowid(db);
    }

    long insertBenchmark(string name, string modulePath)
    {
        import std.datetime : Clock;
        auto now = Clock.currTime.toISOExtString();

        sqlite3_stmt* stmt;
        const char* sql = "INSERT INTO benchmarks (name, module_path, created_at) VALUES (?, ?, ?)".toStringz();
        sqlite3_prepare_v2(db, sql, -1, &stmt, null);
        sqlite3_bind_text(stmt, 1, name.toStringz(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 2, modulePath.toStringz(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(stmt, 3, now.toStringz(), -1, SQLITE_TRANSIENT);

        int result = sqlite3_step(stmt);
        sqlite3_finalize(stmt);

        if (result != SQLITE_DONE)
        {
            const char* selSql = "SELECT id FROM benchmarks WHERE name = ?".toStringz();
            sqlite3_prepare_v2(db, selSql, -1, &stmt, null);
            sqlite3_bind_text(stmt, 1, name.toStringz(), -1, SQLITE_TRANSIENT);
            long id = -1;
            if (sqlite3_step(stmt) == SQLITE_ROW)
            {
                id = sqlite3_column_int64(stmt, 0);
            }
            sqlite3_finalize(stmt);
            return id;
        }

        return sqlite3_last_insert_rowid(db);
    }

    long getBenchmarkId(string name)
    {
        sqlite3_stmt* stmt;
        const char* sql = "SELECT id FROM benchmarks WHERE name = ?".toStringz();
        sqlite3_prepare_v2(db, sql, -1, &stmt, null);
        sqlite3_bind_text(stmt, 1, name.toStringz(), -1, SQLITE_TRANSIENT);

        long id = -1;
        if (sqlite3_step(stmt) == SQLITE_ROW)
        {
            id = sqlite3_column_int64(stmt, 0);
        }
        sqlite3_finalize(stmt);
        return id;
    }

    void insertResult(BenchmarkDataPoint data)
    {
        long benchmarkId = getBenchmarkId(data.benchmarkName);
        if (benchmarkId == -1) return;

        sqlite3_stmt* stmt;
        const char* sql = "
            INSERT INTO results (
                run_id, benchmark_id, min_hnsecs, max_hnsecs, mean_hnsecs,
                mode_hnsecs, quantil_01_hnsecs, quantil_25_hnsecs,
                quantil_50_hnsecs, quantil_75_hnsecs, quantil_99_hnsecs,
                sample_size, total_time_hnsecs
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ".toStringz();

        sqlite3_prepare_v2(db, sql, -1, &stmt, null);

        sqlite3_bind_int64(stmt, 1, data.runId);
        sqlite3_bind_int64(stmt, 2, benchmarkId);
        sqlite3_bind_int64(stmt, 3, data.minHnsecs);
        sqlite3_bind_int64(stmt, 4, data.maxHnsecs);
        sqlite3_bind_double(stmt, 5, data.meanHnsecs);
        sqlite3_bind_int64(stmt, 6, data.modeHnsecs);
        sqlite3_bind_int64(stmt, 7, data.quantil01);
        sqlite3_bind_int64(stmt, 8, data.quantil25);
        sqlite3_bind_int64(stmt, 9, data.quantil50);
        sqlite3_bind_int64(stmt, 10, data.quantil75);
        sqlite3_bind_int64(stmt, 11, data.quantil99);
        sqlite3_bind_int64(stmt, 12, data.sampleSize);
        sqlite3_bind_int64(stmt, 13, data.totalTimeHnsecs);

        sqlite3_step(stmt);
        sqlite3_finalize(stmt);

        long resultId = sqlite3_last_insert_rowid(db);

        if (data.rawTicks.length > 0)
        {
            const char* tickSql = "INSERT INTO raw_ticks (result_id, tick_hnsecs) VALUES (?, ?)".toStringz();
            sqlite3_prepare_v2(db, tickSql, -1, &stmt, null);

            foreach (tick; data.rawTicks)
            {
                sqlite3_bind_int64(stmt, 1, resultId);
                sqlite3_bind_int64(stmt, 2, tick);
                sqlite3_step(stmt);
                sqlite3_reset(stmt);
            }
            sqlite3_finalize(stmt);
        }
    }

    BenchmarkRun[] getAllRuns()
    {
        BenchmarkRun[] runs;
        sqlite3_stmt* stmt;
        const char* sql = "
            SELECT id, timestamp, machine_id, dmd_version, os, cpu_model, 
                   cpu_cores, memory_gb, seed, max_rounds, max_time_seconds, 
                   load_before_1, load_before_5, load_before_15, memory_before_kb, 
                   load_after_1, load_after_5, load_after_15, memory_after_kb, 
                   memory_delta_kb, notes 
            FROM runs ORDER BY timestamp DESC
        ".toStringz();

        sqlite3_prepare_v2(db, sql, -1, &stmt, null);

        while (sqlite3_step(stmt) == SQLITE_ROW)
        {
            BenchmarkRun run;
            run.id = sqlite3_column_int64(stmt, 0);
            run.timestamp = to!string(sqlite3_column_text(stmt, 1));
            run.machineId = to!string(sqlite3_column_text(stmt, 2));
            run.dmdVersion = to!string(sqlite3_column_text(stmt, 3));
            run.os = to!string(sqlite3_column_text(stmt, 4));
            run.cpuModel = to!string(sqlite3_column_text(stmt, 5));
            run.cpuCores = sqlite3_column_int(stmt, 6);
            run.memoryGb = sqlite3_column_double(stmt, 7);
            run.seed = sqlite3_column_int(stmt, 8);
            run.maxRounds = sqlite3_column_int64(stmt, 9);
            run.maxTimeSeconds = sqlite3_column_int64(stmt, 10);
            run.loadBefore1 = sqlite3_column_double(stmt, 11);
            run.loadBefore5 = sqlite3_column_double(stmt, 12);
            run.loadBefore15 = sqlite3_column_double(stmt, 13);
            run.memoryBeforeKB = sqlite3_column_int64(stmt, 14);
            run.loadAfter1 = sqlite3_column_double(stmt, 15);
            run.loadAfter5 = sqlite3_column_double(stmt, 16);
            run.loadAfter15 = sqlite3_column_double(stmt, 17);
            run.memoryAfterKB = sqlite3_column_int64(stmt, 18);
            run.memoryDeltaKB = sqlite3_column_int64(stmt, 19);
            run.notes = to!string(sqlite3_column_text(stmt, 20));
            runs ~= run;
        }
        sqlite3_finalize(stmt);
        return runs;
    }

    BenchmarkRun[] getRunsForMachine(string machineId)
    {
        BenchmarkRun[] runs;
        sqlite3_stmt* stmt;
        const char* sql = "
            SELECT id, timestamp, machine_id, dmd_version, os, cpu_model, 
                   cpu_cores, memory_gb, seed, max_rounds, max_time_seconds, 
                   load_before_1, load_before_5, load_before_15, memory_before_kb, 
                   load_after_1, load_after_5, load_after_15, memory_after_kb, 
                   memory_delta_kb, notes 
            FROM runs WHERE machine_id = ? ORDER BY timestamp DESC
        ".toStringz();

        sqlite3_prepare_v2(db, sql, -1, &stmt, null);
        sqlite3_bind_text(stmt, 1, machineId.toStringz(), -1, SQLITE_TRANSIENT);

        while (sqlite3_step(stmt) == SQLITE_ROW)
        {
            BenchmarkRun run;
            run.id = sqlite3_column_int64(stmt, 0);
            run.timestamp = to!string(sqlite3_column_text(stmt, 1));
            run.machineId = to!string(sqlite3_column_text(stmt, 2));
            run.dmdVersion = to!string(sqlite3_column_text(stmt, 3));
            run.os = to!string(sqlite3_column_text(stmt, 4));
            run.cpuModel = to!string(sqlite3_column_text(stmt, 5));
            run.cpuCores = sqlite3_column_int(stmt, 6);
            run.memoryGb = sqlite3_column_double(stmt, 7);
            run.seed = sqlite3_column_int(stmt, 8);
            run.maxRounds = sqlite3_column_int64(stmt, 9);
            run.maxTimeSeconds = sqlite3_column_int64(stmt, 10);
            run.loadBefore1 = sqlite3_column_double(stmt, 11);
            run.loadBefore5 = sqlite3_column_double(stmt, 12);
            run.loadBefore15 = sqlite3_column_double(stmt, 13);
            run.memoryBeforeKB = sqlite3_column_int64(stmt, 14);
            run.loadAfter1 = sqlite3_column_double(stmt, 15);
            run.loadAfter5 = sqlite3_column_double(stmt, 16);
            run.loadAfter15 = sqlite3_column_double(stmt, 17);
            run.memoryAfterKB = sqlite3_column_int64(stmt, 18);
            run.memoryDeltaKB = sqlite3_column_int64(stmt, 19);
            run.notes = to!string(sqlite3_column_text(stmt, 20));
            runs ~= run;
        }
        sqlite3_finalize(stmt);
        return runs;
    }

    BenchmarkDataPoint[] getResultsForRun(long runId)
    {
        BenchmarkDataPoint[] results;
        sqlite3_stmt* stmt;
        const char* sql = "
            SELECT r.id, b.name, r.min_hnsecs, r.max_hnsecs, r.mean_hnsecs,
                   r.mode_hnsecs, r.quantil_01_hnsecs, r.quantil_25_hnsecs,
                   r.quantil_50_hnsecs, r.quantil_75_hnsecs, r.quantil_99_hnsecs,
                   r.sample_size, r.total_time_hnsecs
            FROM results r
            JOIN benchmarks b ON r.benchmark_id = b.id
            WHERE r.run_id = ?
        ".toStringz();

        sqlite3_prepare_v2(db, sql, -1, &stmt, null);
        sqlite3_bind_int64(stmt, 1, runId);

        while (sqlite3_step(stmt) == SQLITE_ROW)
        {
            BenchmarkDataPoint data;
            data.runId = runId;
            data.benchmarkName = to!string(sqlite3_column_text(stmt, 1));
            data.minHnsecs = sqlite3_column_int64(stmt, 2);
            data.maxHnsecs = sqlite3_column_int64(stmt, 3);
            data.meanHnsecs = sqlite3_column_double(stmt, 4);
            data.modeHnsecs = sqlite3_column_int64(stmt, 5);
            data.quantil01 = sqlite3_column_int64(stmt, 6);
            data.quantil25 = sqlite3_column_int64(stmt, 7);
            data.quantil50 = sqlite3_column_int64(stmt, 8);
            data.quantil75 = sqlite3_column_int64(stmt, 9);
            data.quantil99 = sqlite3_column_int64(stmt, 10);
            data.sampleSize = sqlite3_column_int64(stmt, 11);
            data.totalTimeHnsecs = sqlite3_column_int64(stmt, 12);
            results ~= data;
        }
        sqlite3_finalize(stmt);
        return results;
    }

    BenchmarkDataPoint[] getResultsForBenchmark(string name)
    {
        BenchmarkDataPoint[] results;
        sqlite3_stmt* stmt;
        const char* sql = "
            SELECT r.run_id, b.name, r.min_hnsecs, r.max_hnsecs, r.mean_hnsecs,
                   r.mode_hnsecs, r.quantil_01_hnsecs, r.quantil_25_hnsecs,
                   r.quantil_50_hnsecs, r.quantil_75_hnsecs, r.quantil_99_hnsecs,
                   r.sample_size, r.total_time_hnsecs
            FROM results r
            JOIN benchmarks b ON r.benchmark_id = b.id
            WHERE b.name = ?
            ORDER BY r.run_id
        ".toStringz();

        sqlite3_prepare_v2(db, sql, -1, &stmt, null);
        sqlite3_bind_text(stmt, 1, name.toStringz(), -1, SQLITE_TRANSIENT);

        while (sqlite3_step(stmt) == SQLITE_ROW)
        {
            BenchmarkDataPoint data;
            data.runId = sqlite3_column_int64(stmt, 0);
            data.benchmarkName = to!string(sqlite3_column_text(stmt, 1));
            data.minHnsecs = sqlite3_column_int64(stmt, 2);
            data.maxHnsecs = sqlite3_column_int64(stmt, 3);
            data.meanHnsecs = sqlite3_column_double(stmt, 4);
            data.modeHnsecs = sqlite3_column_int64(stmt, 5);
            data.quantil01 = sqlite3_column_int64(stmt, 6);
            data.quantil25 = sqlite3_column_int64(stmt, 7);
            data.quantil50 = sqlite3_column_int64(stmt, 8);
            data.quantil75 = sqlite3_column_int64(stmt, 9);
            data.quantil99 = sqlite3_column_int64(stmt, 10);
            data.sampleSize = sqlite3_column_int64(stmt, 11);
            data.totalTimeHnsecs = sqlite3_column_int64(stmt, 12);
            results ~= data;
        }
        sqlite3_finalize(stmt);
        return results;
    }

    BenchmarkRun getBaselineRun(string benchmarkName)
    {
        BenchmarkRun run;
        sqlite3_stmt* stmt;
        const char* sql = "
            SELECT r.id, r.timestamp, r.machine_id, r.dmd_version, r.os, r.cpu_model,
                   r.cpu_cores, r.memory_gb, r.seed, r.max_rounds, r.max_time_seconds,
                   r.load_before_1, r.load_before_5, r.load_before_15, r.memory_before_kb,
                   r.load_after_1, r.load_after_5, r.load_after_15, r.memory_after_kb,
                   r.memory_delta_kb, r.notes
            FROM baselines b
            JOIN runs r ON b.run_id = r.id
            JOIN benchmarks bm ON b.benchmark_id = bm.id
            WHERE bm.name = ? AND b.is_global = 0
            ORDER BY r.timestamp DESC
            LIMIT 1
        ".toStringz();

        sqlite3_prepare_v2(db, sql, -1, &stmt, null);
        sqlite3_bind_text(stmt, 1, benchmarkName.toStringz(), -1, SQLITE_TRANSIENT);

        if (sqlite3_step(stmt) == SQLITE_ROW)
        {
            run.id = sqlite3_column_int64(stmt, 0);
            run.timestamp = to!string(sqlite3_column_text(stmt, 1));
            run.machineId = to!string(sqlite3_column_text(stmt, 2));
            run.dmdVersion = to!string(sqlite3_column_text(stmt, 3));
            run.os = to!string(sqlite3_column_text(stmt, 4));
            run.cpuModel = to!string(sqlite3_column_text(stmt, 5));
            run.cpuCores = sqlite3_column_int(stmt, 6);
            run.memoryGb = sqlite3_column_double(stmt, 7);
            run.seed = sqlite3_column_int(stmt, 8);
            run.maxRounds = sqlite3_column_int64(stmt, 9);
            run.maxTimeSeconds = sqlite3_column_int64(stmt, 10);
            run.loadBefore1 = sqlite3_column_double(stmt, 11);
            run.loadBefore5 = sqlite3_column_double(stmt, 12);
            run.loadBefore15 = sqlite3_column_double(stmt, 13);
            run.memoryBeforeKB = sqlite3_column_int64(stmt, 14);
            run.loadAfter1 = sqlite3_column_double(stmt, 15);
            run.loadAfter5 = sqlite3_column_double(stmt, 16);
            run.loadAfter15 = sqlite3_column_double(stmt, 17);
            run.memoryAfterKB = sqlite3_column_int64(stmt, 18);
            run.memoryDeltaKB = sqlite3_column_int64(stmt, 19);
            run.notes = to!string(sqlite3_column_text(stmt, 20));
        }
        sqlite3_finalize(stmt);
        return run;
    }

    BenchmarkRun getGlobalBaselineRun(string benchmarkName)
    {
        BenchmarkRun run;
        sqlite3_stmt* stmt;
        const char* sql = "
            SELECT r.id, r.timestamp, r.machine_id, r.dmd_version, r.os, r.cpu_model,
                   r.cpu_cores, r.memory_gb, r.seed, r.max_rounds, r.max_time_seconds,
                   r.load_before_1, r.load_before_5, r.load_before_15, r.memory_before_kb,
                   r.load_after_1, r.load_after_5, r.load_after_15, r.memory_after_kb,
                   r.memory_delta_kb, r.notes
            FROM baselines b
            JOIN runs r ON b.run_id = r.id
            JOIN benchmarks bm ON b.benchmark_id = bm.id
            WHERE bm.name = ? AND b.is_global = 1
            ORDER BY r.timestamp DESC
            LIMIT 1
        ".toStringz();

        sqlite3_prepare_v2(db, sql, -1, &stmt, null);
        sqlite3_bind_text(stmt, 1, benchmarkName.toStringz(), -1, SQLITE_TRANSIENT);

        if (sqlite3_step(stmt) == SQLITE_ROW)
        {
            run.id = sqlite3_column_int64(stmt, 0);
            run.timestamp = to!string(sqlite3_column_text(stmt, 1));
            run.machineId = to!string(sqlite3_column_text(stmt, 2));
            run.dmdVersion = to!string(sqlite3_column_text(stmt, 3));
            run.os = to!string(sqlite3_column_text(stmt, 4));
            run.cpuModel = to!string(sqlite3_column_text(stmt, 5));
            run.cpuCores = sqlite3_column_int(stmt, 6);
            run.memoryGb = sqlite3_column_double(stmt, 7);
            run.seed = sqlite3_column_int(stmt, 8);
            run.maxRounds = sqlite3_column_int64(stmt, 9);
            run.maxTimeSeconds = sqlite3_column_int64(stmt, 10);
            run.loadBefore1 = sqlite3_column_double(stmt, 11);
            run.loadBefore5 = sqlite3_column_double(stmt, 12);
            run.loadBefore15 = sqlite3_column_double(stmt, 13);
            run.memoryBeforeKB = sqlite3_column_int64(stmt, 14);
            run.loadAfter1 = sqlite3_column_double(stmt, 15);
            run.loadAfter5 = sqlite3_column_double(stmt, 16);
            run.loadAfter15 = sqlite3_column_double(stmt, 17);
            run.memoryAfterKB = sqlite3_column_int64(stmt, 18);
            run.memoryDeltaKB = sqlite3_column_int64(stmt, 19);
            run.notes = to!string(sqlite3_column_text(stmt, 20));
        }
        sqlite3_finalize(stmt);
        return run;
    }

    void setBaselineRun(string benchmarkName, long runId)
    {
        long benchmarkId = getBenchmarkId(benchmarkName);
        if (benchmarkId == -1) return;

        string machineId;
        sqlite3_stmt* stmt;
        const char* selSql = "SELECT machine_id FROM runs WHERE id = ?".toStringz();
        sqlite3_prepare_v2(db, selSql, -1, &stmt, null);
        sqlite3_bind_int64(stmt, 1, runId);
        if (sqlite3_step(stmt) == SQLITE_ROW)
        {
            machineId = to!string(sqlite3_column_text(stmt, 0));
        }
        sqlite3_finalize(stmt);

        run("DELETE FROM baselines WHERE benchmark_id = " ~ to!string(benchmarkId) ~ 
            " AND machine_id = '" ~ machineId ~ "' AND is_global = 0");

        const char* insSql = "INSERT INTO baselines (benchmark_id, machine_id, run_id, is_global) VALUES (?, ?, ?, 0)".toStringz();
        sqlite3_prepare_v2(db, insSql, -1, &stmt, null);
        sqlite3_bind_int64(stmt, 1, benchmarkId);
        sqlite3_bind_text(stmt, 2, machineId.toStringz(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(stmt, 3, runId);
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);
    }

    void setGlobalBaselineRun(string benchmarkName, long runId)
    {
        long benchmarkId = getBenchmarkId(benchmarkName);
        if (benchmarkId == -1) return;

        run("DELETE FROM baselines WHERE benchmark_id = " ~ to!string(benchmarkId) ~ " AND is_global = 1");

        sqlite3_stmt* stmt;
        const char* insSql = "INSERT INTO baselines (benchmark_id, machine_id, run_id, is_global) VALUES (?, 'global', ?, 1)".toStringz();
        sqlite3_prepare_v2(db, insSql, -1, &stmt, null);
        sqlite3_bind_int64(stmt, 1, benchmarkId);
        sqlite3_bind_int64(stmt, 2, runId);
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);
    }

    void updateRunNotes(long runId, string notes)
    {
        sqlite3_stmt* stmt;
        const char* sql = "UPDATE runs SET notes = ? WHERE id = ?".toStringz();
        sqlite3_prepare_v2(db, sql, -1, &stmt, null);
        sqlite3_bind_text(stmt, 1, notes.toStringz(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(stmt, 2, runId);
        sqlite3_step(stmt);
        sqlite3_finalize(stmt);
    }

    ComparisonResult[] compareWithBaseline(string benchmarkName, long newRunId)
    {
        return compareImpl(benchmarkName, newRunId, false);
    }

    ComparisonResult[] compareWithGlobalBaseline(string benchmarkName, long newRunId)
    {
        return compareImpl(benchmarkName, newRunId, true);
    }

    private ComparisonResult[] compareImpl(string benchmarkName, long newRunId, bool global)
    {
        ComparisonResult[] results;

        BenchmarkRun baseline = global ? getGlobalBaselineRun(benchmarkName) 
                                      : getBaselineRun(benchmarkName);
        if (baseline.id == 0) return results;

        BenchmarkDataPoint[] oldResults = getResultsForRun(baseline.id);
        BenchmarkDataPoint[] newResults = getResultsForRun(newRunId);
        
        BenchmarkRun newRunInfo;
        foreach (r; getAllRuns())
        {
            if (r.id == newRunId)
                newRunInfo = r;
        }

        foreach (old; oldResults)
        {
            foreach (newR; newResults)
            {
                if (old.benchmarkName == newR.benchmarkName)
                {
                    ComparisonResult cr;
                    cr.benchmarkName = old.benchmarkName;
                    cr.oldMean = old.meanHnsecs;
                    cr.newMean = newR.meanHnsecs;
                    cr.percentChange = ((newR.meanHnsecs - old.meanHnsecs) / old.meanHnsecs) * 100.0;
                    cr.oldMemoryDelta = baseline.memoryDeltaKB;
                    cr.newMemoryDelta = newRunInfo.memoryDeltaKB;
                    if (baseline.memoryDeltaKB != 0)
                        cr.memoryPercentChange = ((newRunInfo.memoryDeltaKB - baseline.memoryDeltaKB) 
                                                  / cast(double)baseline.memoryDeltaKB) * 100.0;
                    else
                        cr.memoryPercentChange = 0;
                    results ~= cr;
                }
            }
        }
        return results;
    }
}

Database openDatabase(string filename = "benchmark_results.db")
{
    auto db = new Database(filename);
    db.initialize();
    return db;
}
