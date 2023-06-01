 gcc -fsanitize=address -shared -o libtest.so testlib.c
 
 gcc -fsanitize=address -o testprog testprog.c -ldl


./testprog
=================================================================
==62400==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x60200000005a at pc 0x56135619e360 bp 0x7ffed44762d0 sp 0x7ffed44762c0
WRITE of size 1 at 0x60200000005a thread T0
    #0 0x56135619e35f in main (/home/dong/Documents/latte/latte_c_demo/asan_test/src/testprog+0x135f)
    #1 0x7f3029ce4d8f  (/lib/x86_64-linux-gnu/libc.so.6+0x29d8f)
    #2 0x7f3029ce4e3f in __libc_start_main (/lib/x86_64-linux-gnu/libc.so.6+0x29e3f)
    #3 0x56135619e134 in _start (/home/dong/Documents/latte/latte_c_demo/asan_test/src/testprog+0x1134)

0x60200000005a is located 0 bytes to the right of 10-byte region [0x602000000050,0x60200000005a)
allocated by thread T0 here:
    #0 0x7f3029fc2950 in __interceptor_malloc (/lib/x86_64-linux-gnu/libasan.so.4+0xdf950)
    #1 0x7f302777c161 in test_malloc (libtest.so+0x1161)
    #2 0x56135619e31f in main (/home/dong/Documents/latte/latte_c_demo/asan_test/src/testprog+0x131f)
    #3 0x7f3029ce4d8f  (/lib/x86_64-linux-gnu/libc.so.6+0x29d8f)

SUMMARY: AddressSanitizer: heap-buffer-overflow (/home/dong/Documents/latte/latte_c_demo/asan_test/src/testprog+0x135f) in main
Shadow bytes around the buggy address:
  0x0c047fff7fb0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0x0c047fff7fc0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0x0c047fff7fd0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0x0c047fff7fe0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0x0c047fff7ff0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
=>0x0c047fff8000: fa fa 00 05 fa fa fd fa fa fa 00[02]fa fa fa fa
  0x0c047fff8010: fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa
  0x0c047fff8020: fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa
  0x0c047fff8030: fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa
  0x0c047fff8040: fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa
  0x0c047fff8050: fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa fa
Shadow byte legend (one shadow byte represents 8 application bytes):
  Addressable:           00
  Partially addressable: 01 02 03 04 05 06 07 
  Heap left redzone:       fa
  Freed heap region:       fd
  Stack left redzone:      f1
  Stack mid redzone:       f2
  Stack right redzone:     f3
  Stack after return:      f5
  Stack use after scope:   f8
  Global redzone:          f9
  Global init order:       f6
  Poisoned by user:        f7
  Container overflow:      fc
  Array cookie:            ac
  Intra object redzone:    bb
  ASan internal:           fe
  Left alloca redzone:     ca
  Right alloca redzone:    cb
==62400==ABORTING