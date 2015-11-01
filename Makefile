all:
	dmd -cov -main -unittest -run randomized_unittest_benchmark.d
