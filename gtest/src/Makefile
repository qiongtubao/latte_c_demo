



build:
	gcc -std=c11 -O0 -o latte.o -c latte.c
	g++ -I../googletest/googletest/include -std=c++11 -O0 -o latte_unit_test.o -c latte_unit_test.cc
	g++ -I../googletest/googletest/include -std=c++11 -O0 -o latte_gtest_main.o -c latte_gtest_main.cc
	g++ -I../googletest/googletest/include -std=c++11 -o latte_gtest_main latte_gtest_main.o latte_unit_test.o latte.o ../googletest/lib/libgmock.a ../googletest/lib/libgmock_main.a ../googletest/lib/libgtest.a ../googletest/lib/libgtest_main.a


test: build 
	./latte_gtest_main

clean:
	rm -rf *.o