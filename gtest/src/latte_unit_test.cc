
extern "C" {
    #include "latte.h"
}

#include "gtest/gtest.h"


namespace {
    TEST(LATTE, ADD) {
        EXPECT_EQ(3, add(1, 2));
    }
}