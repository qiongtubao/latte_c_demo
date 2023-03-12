
#include <stdlib.h>
#define UNUSED(x) (void)(x)
void test(long long size) {
    void* a = malloc(size);
    UNUSED(a);
}
void* latte_zmalloc(long long size) {
    test(size);
    return NULL;
}