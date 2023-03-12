#include <dlfcn.h>
#include <stdio.h>


int main() {
    //use module.so
    void* (*latte_zmalloc)(long long);
    void *handle;
    char* path = "./latte.so";
    handle = dlopen(path,RTLD_NOW|RTLD_LOCAL);
    if (handle == NULL) {
        printf("latte.so %s failed to load: %s\n", path, dlerror());
        return 0;
    }
    latte_zmalloc = (void* (*)(long long))(unsigned long) dlsym(handle,"latte_zmalloc");

    void* result = latte_zmalloc(1000);
    return 0;
}