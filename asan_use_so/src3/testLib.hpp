// ----------------------------------------------------------------------------
// testLib.hpp
#pragma once

#include "dllHelper.hpp"

#ifdef TESTLIB
#define TESTLIB_EXPORT MY_DLL_EXPORT
#else
#define TESTLIB_EXPORT MY_DLL_IMPORT
#endif

namespace TestLib {

// will be linked at compile time
class TESTLIB_EXPORT LeakerTestLib {
    public:
        void leak();
};

}


