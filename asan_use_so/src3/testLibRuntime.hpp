// ----------------------------------------------------------------------------
// testLibRuntime.hpp
#pragma once

#include "dllHelper.hpp"

#ifdef TESTLIBRUNTIME
#define TESTLIBRUNTIME_EXPORT MY_DLL_EXPORT
#else
#define TESTLIBRUNTIME_EXPORT MY_DLL_IMPORT
#endif

namespace TestLibRuntime {

// will be loaded via dlopen at runtime
class TESTLIBRUNTIME_EXPORT LeakerTestLib {
    public:
        void leak();
};

}

extern "C" {
    TestLibRuntime::LeakerTestLib* TESTLIBRUNTIME_EXPORT createInstance();
    void TESTLIBRUNTIME_EXPORT freeInstance(TestLibRuntime::LeakerTestLib* instance);
    void TESTLIBRUNTIME_EXPORT performLeak(TestLibRuntime::LeakerTestLib* instance);
}
