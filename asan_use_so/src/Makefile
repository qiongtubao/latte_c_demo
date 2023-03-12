ifdef SANITIZER
ifeq ($(SANITIZER),address)
   MALLOC=libc
   CFLAGS+=-fsanitize=address -fno-sanitize-recover=all -fno-omit-frame-pointer
   LDFLAGS+=-fsanitize=address
else
ifeq ($(SANITIZER),undefined)
   MALLOC=libc
   CFLAGS+=-fsanitize=undefined -fno-sanitize-recover=all -fno-omit-frame-pointer
   LDFLAGS+=-fsanitize=undefined
else
ifeq ($(SANITIZER),thread)
   CFLAGS+=-fsanitize=thread -fno-sanitize-recover=all -fno-omit-frame-pointer
   LDFLAGS+=-fsanitize=thread
else
    $(error "unknown sanitizer=${SANITIZER}")
endif
endif
endif
endif
RUN := LD_LIBRARY_PATH=. ASAN_OPTIONS=symbolize=1 ASAN_SYMBOLIZER_PATH=$(shell which llvm-symbolizer)
PRELOAD := LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libasan.so.5
build:
	$(CC) $(CFLAGS) -c latte.c -fno-common -std=c99  -W -Wall -fPIC -o latte.o -O2 -lasan
	$(CC) $(CFLAGS) -o latte.so latte.o -shared -std=c99  -O2 -Wl,-Bsymbolic -lasan
	$(CC) $(CFLAGS) -g test.c -Wl,-E -o test -std=c99 -ldl -O2  -rdynamic -lasan

test: build 
	@echo "===== test start ====="
	./test
	@echo "===== test end ====="

clean:
	rm -rf *.o test latte.so

ascan_test:
	SANITIZER=address make test