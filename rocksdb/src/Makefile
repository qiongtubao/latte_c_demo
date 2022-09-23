



test_%: 
	@echo "start"
	gcc $@.c -o $@  -I../deps/rocksdb/include ../deps/rocksdb/librocksdb.a -lm -lrt -lstdc++ -pthread -lsnappy -lz -ldl

clean:
	rm -rf *.o 
	rm -rf test_write test_score_range