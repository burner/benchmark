all:
	dmd -dip25 -dip1000 -debug -cov -unittest -main source/randomizedtestbenchmark/benchmark.d \
			source/randomizedtestbenchmark/execution.d \
			source/randomizedtestbenchmark/package.d \
			source/randomizedtestbenchmark/printer.d \
			source/randomizedtestbenchmark/valuegenerators.d
	./benchmark
