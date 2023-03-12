#ifdef DYNAMIC

#include <dlfcn.h>

#elif STATIC

#include "my.h"

#endif

#include <iostream>

int main(int argc, char **argv) {

#ifdef DYNAMIC

    std::cout << "DYNAMIC option\n";
    void* handle = dlopen("./libmy.so", RTLD_LAZY);    
    if (!handle) {
        std::cerr << "Can not open library: " << dlerror() << '\n';
        return 1;
    }
    
    std::cout << "Loading symbol 'sayHi'...\n";
    typedef int (*say_hi_t)(int);
    say_hi_t sayHi = (say_hi_t) dlsym(handle, "sayHi");
    if (!sayHi) {
        std::cerr << "Can not load symbol 'sayHi': " << dlerror() << '\n';
        dlclose(handle);
        return 1;
    }

#elif STATIC

    std::cout << "STATIC option\n";

#endif
    
    int argument = argc + 100;
    int res = sayHi(argument); // Boom.
    std::cout << "sayHi(" << argument << ") = " << res << '\n';           

    return 0;
}