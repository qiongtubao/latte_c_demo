



test_%: 
	@echo "start"
	gcc $@.c -o $@  -I../deps/rocksdb/include ../deps/rocksdb/librocksdb.a -lm  -lstdc++ -pthread  -lz -ldl #-lrt  -lsnappy

clean:
	rm -rf *.o 
	rm -rf test_write test_score_range