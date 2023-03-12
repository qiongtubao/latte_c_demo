
path=$(dirname $($CXX --print-file-name libclang_rt.asan-x86_64.so))
build:
	clang++ -std=c++11 -O0 -g -ggdb -Wl,-rpath=/usr/lib/clang/15.0.7/lib/linux:./ -Wl,-undefined -Wl,dynamic_lookup -fsanitize=address -fsanitize-recover=address -fno-omit-frame-pointer -fsanitize-address-use-after-scope -DTESTLIB -shared -fPIC -o libtestLib.so testLib.cpp -ldl -shared-libasan 
	clang++ -std=c++11 -O0 -g -ggdb -Wl,-rpath=/usr/lib/clang/15.0.7/lib/linux:./ -Wl,-undefined -Wl,dynamic_lookup -fsanitize=address -fsanitize-recover=address -fno-omit-frame-pointer -fsanitize-address-use-after-scope -DTESTLIBRUNTIME -shared -fPIC -o libtestLibRuntime.so testLibRuntime.cpp -ldl -shared-libasan 
	clang++ -std=c++11 -O0 -g -ggdb -Wl,-rpath=/usr/lib/clang/15.0.7/lib/linux:./ -Wl,-undefined -Wl,dynamic_lookup -fsanitize=address -fsanitize-recover=address -fno-omit-frame-pointer -fsanitize-address-use-after-scope -o leak main.cpp -ldl -L./ -ltestLib -shared-libasan 

clean:
	rm -rf leak libtestLib.so libtestLibRuntime.so

test: build
	export LD_LIBRARY_PATH=/usr/lib/clang/15.0.7/lib/linux/:./
	./leak