// ----------------------------------------------------------------------------
// dllHelper.hpp
#pragma once

#include <string>
#include <sstream>
#include <iostream>

#include <errno.h>
#include <dlfcn.h>

// Generic helper definitions for shared library support
#if defined WIN32
#define MY_DLL_EXPORT __declspec(dllexport)
#define MY_DLL_IMPORT __declspec(dllimport)
#define MY_DLL_LOCAL
#define MY_DLL_INTERNAL
#else
#if __GNUC__ >= 4
#define MY_DLL_EXPORT __attribute__ ((visibility ("default")))
#define MY_DLL_IMPORT __attribute__ ((visibility ("default")))
#define MY_DLL_LOCAL  __attribute__ ((visibility ("hidden")))
#define MY_DLL_INTERNAL __attribute__ ((visibility ("internal")))
#else
#define MY_DLL_IMPORT
#define MY_DLL_EXPORT
#define MY_DLL_LOCAL
#define MY_DLL_INTERNAL
#endif
#endif

void* loadLibrary(const std::string& filename) {
    void* module = dlopen(filename.c_str(), RTLD_NOW | RTLD_GLOBAL);

    if(module == nullptr) {
        char* error = dlerror();
        std::stringstream stream;
        stream << "Error trying to load the library. Filename: " << filename << " Error: " << error;
        std::cout << stream.str() << std::endl;
    }

    return module;
}

void unloadLibrary(void* module) {
    dlerror(); //clear all errors
    int result = dlclose(module);
    if(result != 0) {
        char* error = dlerror();
        std::stringstream stream;
        stream << "Error trying to free the library. Error code: " << error;
        std::cout << stream.str() << std::endl;
    }
}

void* loadFunction(void* module, const std::string& functionName) {
    if(!module) {
        std::cerr << "Invalid module" << std::endl;
        return nullptr;
    }

    dlerror(); //clear all errors
    #ifdef __GNUC__
    __extension__
    #endif
    void* result = dlsym(module, functionName.c_str());
    char* error;
    if((error = dlerror()) != nullptr) {
        std::stringstream stream;
        stream << "Error trying to get address of function \"" << functionName << "\" from the library. Error code: " << error;
        std::cout << stream.str() << std::endl;
    }

    return result;
}







