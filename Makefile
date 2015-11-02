main: main.d libstd_benchmark.a
	#dmd main.d libstd_benchmark.a -ofmain -Isource libdonotoptimizeaway.a
	dmd main.d libstd_benchmark.a -ofmain -Isource
	./main

all:
	dmd -cov -unittest -c randomized_unittest_benchmark.d
	dmd donotoptimizeaway.o randomized_unittest_benchmark.o -ofrandomized_unittest_benchmark
	./randomized_unittest_benchmark
