#g++-4.9
G++ := g++ -print-file-name=/usr/lib/x86_64-linux-gnu/libasan.so.5
# clang++-3.8
GLANG++ := clang++

SAN_CMP := -fno-omit-frame-pointer -fsanitize=address 
SAN_STAT := -static-libstdc++ -static-libasan

BIN_CMP := -std=c++11 -c -I. main.cpp -O -g3 -o main.o -shared-libasan
LIB_CMP := -std=c++11 my.cpp -o libmy.so -shared -fPIC -g3	-shared-libasan

RUN := LD_LIBRARY_PATH=. ASAN_OPTIONS=symbolize=1 ASAN_SYMBOLIZER_PATH=$(shell which llvm-symbolizer)
PRELOAD := LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libasan.so.5

lib-gcc: 
	$(G++) $(LIB_CMP)

lib-gcc-asan:
	$(G++) $(SAN_CMP) $(LIB_CMP)

lib-clang-asan: 
	 $(SAN_CMP) $(LIB_CMP)

bin-gcc-ldynamic:
	$(G++) $(SAN_CMP) $(BIN_CMP) -DDYNAMIC
	$(G++) -o main-gcc-ldynamic main.o -ldl -lasan
	$(RUN)  ./main-gcc-ldynamic 

bin-gcc-lstatic: 
	$(G++) $(SAN_CMP) $(BIN_CMP) -DSTATIC
	$(G++) -o main-gcc-lstatic main.o -L. -lmy -lasan
	$(RUN) ./main-gcc-lstatic

bin-gcc-stat-lstatic: 
	$(G++) $(SAN_CMP) $(BIN_CMP) -DSTATIC
	$(G++) $(SAN_CMP) $(SAN_STAT) -o main-gcc-stat-lstatic main.o -L. -lmy 
	$(RUN) ./main-gcc-stat-lstatic

bin-gcc-preload:	
	$(G++) $(BIN_CMP) -DDYNAMIC
	$(G++) -o main-gcc-preload main.o -L. -ldl -lmy 
	$(RUN) $(PRELOAD) ./main-gcc-preload

bin-clang-ldynamic: 
	$(GLANG++) $(SAN_CMP) $(BIN_CMP) -DDYNAMIC
	$(GLANG++) $(SAN_CMP) -o main-clang-ldynamic main.o -L. -lmy
	$(RUN) ./main-clang-ldynamic

bin-clang-lstatic: 
	$(GLANG++) $(SAN_CMP) $(BIN_CMP) -DSTATIC
	$(GLANG++) $(SAN_CMP) -o main-clang-lstatic main.o -L. -lmy
	$(RUN) ./main-clang-lstatic

clean:
	rm -f libmy.so
	rm -f main-*
	rm -f *.o