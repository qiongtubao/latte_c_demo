#include "my.h" 

int sayHi(int n) {
    int array_at_libmy[100];
    array_at_libmy[1] = 0;
    return array_at_libmy[n]; // Buggy access.
}