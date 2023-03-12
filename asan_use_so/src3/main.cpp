

// ----------------------------------------------------------------------------
// main.cpp
#include "testLib.hpp"
#include "testLibRuntime.hpp"

#define LEAK_TESTLIB
#define LEAK_TESTLIBRUNTIME

int main(int argc, char** argv) {
    #ifdef LEAK_TESTLIBRUNTIME
    void* testLibRuntimeModule = loadLibrary("./libtestLibRuntime.so");

    if(!testLibRuntimeModule) {
        return -1;
    }

    TestLibRuntime::LeakerTestLib* testLibRuntime = nullptr;

    auto createInstance = (TestLibRuntime::LeakerTestLib * (*)())loadFunction(testLibRuntimeModule, "createInstance");
    if(!createInstance) {
        return -1;
    }
    auto freeInstance = (void(*)(TestLibRuntime::LeakerTestLib*))loadFunction(testLibRuntimeModule, "freeInstance");
    if(!freeInstance) {
        return -1;
    }
    auto performLeak = (void(*)(TestLibRuntime::LeakerTestLib*))loadFunction(testLibRuntimeModule, "performLeak");
    if(!performLeak) {
        return -1;
    }

    testLibRuntime = createInstance();
    performLeak(testLibRuntime);
    freeInstance(testLibRuntime);
    #endif

    #ifdef LEAK_TESTLIB
    TestLib::LeakerTestLib testLib;
    testLib.leak();
    #endif

    #ifdef LEAK_TESTLIBRUNTIME
    unloadLibrary(testLibRuntimeModule);
    #endif

    return 0;
}