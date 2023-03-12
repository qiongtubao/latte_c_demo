// ----------------------------------------------------------------------------
// testLibRuntime.cpp
#include "testLibRuntime.hpp"

namespace TestLibRuntime {

void LeakerTestLib::leak() {
    volatile char* myLeak = new char[10];
    (void)myLeak;
}

extern "C" {

    LeakerTestLib* createInstance() {
        return new LeakerTestLib();
    }

    void freeInstance(LeakerTestLib* instance) {
        delete instance;
    }

    void performLeak(LeakerTestLib* instance) {
        if(instance) {
            instance->leak();
        }
    }

}

}