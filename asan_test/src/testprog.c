#include <stdio.h>
   #include <stdlib.h>
   #include <dlfcn.h>
   
   int main() {
       void *handle;
       void *(*test_malloc)(size_t);
       char *error;
   
       handle = dlopen("./libtest.so", RTLD_LAZY);
       if (!handle) {
           fprintf(stderr, "%s\n", dlerror());
           exit(EXIT_FAILURE);
       }
   
       dlerror();    /* Clear any existing error */
   
       test_malloc = dlsym(handle, "test_malloc");
       if ((error = dlerror()) != NULL)  {
           fprintf(stderr, "%s\n", error);
           exit(EXIT_FAILURE);
       }
   
       char *p = test_malloc(10);
       p[10] = 'a';  /* Access out of bounds */
   
       dlclose(handle);
       return 0;
   }