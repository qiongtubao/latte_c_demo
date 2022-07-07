



build:
	gcc -fprofile-arcs -ftest-coverage -std=c11 -O0 -o latte.o -c latte.c
	g++ -fprofile-arcs -ftest-coverage -I../googletest/googletest/include -std=c++11 -O0 -o latte_unit_test.o -c latte_unit_test.cc
	g++ -fprofile-arcs -ftest-coverage -I../googletest/googletest/include -std=c++11 -o latte_gtest_main  latte_unit_test.o latte.o ../googletest/lib/libgmock.a ../googletest/lib/libgmock_main.a ../googletest/lib/libgtest.a ../googletest/lib/libgtest_main.a


test: build 
	./latte_gtest_main
	lcov --capture --directory . \
		--output-file latte_gtest.info \
		--test-name latte_gtest \
		--no-external 
	genhtml latte_gtest.info \
		--output-directory output \
		--title "latte_gtest GoogleTest/LCOV Demo" \
		--show-details \
		--legend

clean:
	@rm -rf *.o *.gcda *.gcno 
	@rm -rf latte_gtest_main latte_gtest.info output
