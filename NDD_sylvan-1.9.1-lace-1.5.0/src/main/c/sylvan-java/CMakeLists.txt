cmake_minimum_required(VERSION 3.1)

project(sylvan-java)

enable_language(C)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

include(CMakeDependentOption)

set(LIBRARY_OUTPUT_PATH lib)
set(SYLVAN_SOVERSION 1)

# Sylvan header layout differs between versions:
# - older: ${SYLVAN_SRC_ROOT}/src/sylvan/include/sylvan.h
# - current: ${SYLVAN_SRC_ROOT}/src/sylvan/sylvan.h
if (EXISTS "${SYLVAN_SRC_ROOT}/src/sylvan/include/sylvan.h")
    include_directories(${SYLVAN_SRC_ROOT}/src/sylvan/include)
elseif (EXISTS "${SYLVAN_SRC_ROOT}/src/sylvan/sylvan.h")
    include_directories(${SYLVAN_SRC_ROOT}/src/sylvan)
else()
    include_directories(${SYLVAN_SRC_ROOT}/src)
endif()

# Lace headers are required by Sylvan public headers (sylvan.h includes lace.h).
# In newer Sylvan builds Lace is usually fetched as a CMake dependency.
if (DEFINED FETCHCONTENT_SOURCE_DIR_LACE AND EXISTS "${FETCHCONTENT_SOURCE_DIR_LACE}/src/lace.h")
    include_directories(${FETCHCONTENT_SOURCE_DIR_LACE}/src)
elseif (DEFINED LACE_SRC_ROOT AND EXISTS "${LACE_SRC_ROOT}/src/lace.h")
    include_directories(${LACE_SRC_ROOT}/src)
elseif (EXISTS "${SYLVAN_BUILD_ROOT}/_deps/lace-src/src/lace.h")
    include_directories(${SYLVAN_BUILD_ROOT}/_deps/lace-src/src)
elseif (EXISTS "${SYLVAN_SRC_ROOT}/build/_deps/lace-src/src/lace.h")
    include_directories(${SYLVAN_SRC_ROOT}/build/_deps/lace-src/src)
endif()

if (EXISTS "${SYLVAN_BUILD_ROOT}/_deps/lace-build/lace_config.h")
    include_directories(${SYLVAN_BUILD_ROOT}/_deps/lace-build)
elseif (EXISTS "${SYLVAN_SRC_ROOT}/build/_deps/lace-build/lace_config.h")
    include_directories(${SYLVAN_SRC_ROOT}/build/_deps/lace-build)
endif()

if(USE_NATIVE_JNI)
    find_package(JNI REQUIRED)
    include_directories(${JNI_INCLUDE_DIRS})
else()
    include_directories(/java/include)
    include_directories(/java/include/linux)
    include_directories(/java/include/darwin)
endif()

set(JNI_SOURCE_FILES
    ${PROJECT_SOURCE_DIR}/src/jsylvan.c
    ${PROJECT_SOURCE_DIR}/src/mc_help.c)

add_library(sylvan-java SHARED ${JNI_SOURCE_FILES})
set(SYLVAN_JAVA_LIBS "")
if (EXISTS "${SYLVAN_BUILD_ROOT}/src/lib/libsylvan${CMAKE_STATIC_LIBRARY_SUFFIX}")
    list(APPEND SYLVAN_JAVA_LIBS "${SYLVAN_BUILD_ROOT}/src/lib/libsylvan${CMAKE_STATIC_LIBRARY_SUFFIX}")
elseif (EXISTS "${SYLVAN_BUILD_ROOT}/src/sylvan/lib/libsylvan${CMAKE_STATIC_LIBRARY_SUFFIX}")
    list(APPEND SYLVAN_JAVA_LIBS "${SYLVAN_BUILD_ROOT}/src/sylvan/lib/libsylvan${CMAKE_STATIC_LIBRARY_SUFFIX}")
elseif (EXISTS "${SYLVAN_BUILD_ROOT}/src/sylvan/libsylvan${CMAKE_STATIC_LIBRARY_SUFFIX}")
    list(APPEND SYLVAN_JAVA_LIBS "${SYLVAN_BUILD_ROOT}/src/sylvan/libsylvan${CMAKE_STATIC_LIBRARY_SUFFIX}")
else()
    list(APPEND SYLVAN_JAVA_LIBS "${SYLVAN_BUILD_ROOT}/src/libsylvan${CMAKE_STATIC_LIBRARY_SUFFIX}")
endif()
if (EXISTS "${SYLVAN_BUILD_ROOT}/_deps/lace-build/lib/liblace${CMAKE_STATIC_LIBRARY_SUFFIX}")
    list(APPEND SYLVAN_JAVA_LIBS "${SYLVAN_BUILD_ROOT}/_deps/lace-build/lib/liblace${CMAKE_STATIC_LIBRARY_SUFFIX}")
endif()
target_link_libraries(sylvan-java ${SYLVAN_JAVA_LIBS})
