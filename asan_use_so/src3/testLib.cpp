// ----------------------------------------------------------------------------
// testLib.cpp
#include "testLib.hpp"

namespace TestLib {

void LeakerTestLib::leak() {
    volatile char* myLeak = new char[10];
    (void)myLeak;
}

}