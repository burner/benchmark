all:
	dmd -D -dip25 -dip1000 -debug -cov -unittest -main source/randomizedtestbenchmark/benchmark.d \
			source/randomizedtestbenchmark/execution.d \
			source/randomizedtestbenchmark/package.d \
			source/randomizedtestbenchmark/printer.d \
			source/randomizedtestbenchmark/valuegenerators.d \
			source/randomizedtestbenchmark/statistics.d \
			source/randomizedtestbenchmark/gnuplot.d
	./benchmark
