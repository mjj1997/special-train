include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(special_train_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(special_train_setup_options)
  option(special_train_ENABLE_HARDENING "Enable hardening" ON)
  option(special_train_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    special_train_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    special_train_ENABLE_HARDENING
    OFF)

  special_train_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR special_train_PACKAGING_MAINTAINER_MODE)
    option(special_train_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(special_train_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(special_train_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(special_train_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(special_train_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(special_train_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(special_train_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(special_train_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(special_train_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(special_train_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(special_train_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(special_train_ENABLE_PCH "Enable precompiled headers" OFF)
    option(special_train_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(special_train_ENABLE_IPO "Enable IPO/LTO" ON)
    option(special_train_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(special_train_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(special_train_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(special_train_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(special_train_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(special_train_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(special_train_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(special_train_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(special_train_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(special_train_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(special_train_ENABLE_PCH "Enable precompiled headers" OFF)
    option(special_train_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      special_train_ENABLE_IPO
      special_train_WARNINGS_AS_ERRORS
      special_train_ENABLE_USER_LINKER
      special_train_ENABLE_SANITIZER_ADDRESS
      special_train_ENABLE_SANITIZER_LEAK
      special_train_ENABLE_SANITIZER_UNDEFINED
      special_train_ENABLE_SANITIZER_THREAD
      special_train_ENABLE_SANITIZER_MEMORY
      special_train_ENABLE_UNITY_BUILD
      special_train_ENABLE_CLANG_TIDY
      special_train_ENABLE_CPPCHECK
      special_train_ENABLE_COVERAGE
      special_train_ENABLE_PCH
      special_train_ENABLE_CACHE)
  endif()

  special_train_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (special_train_ENABLE_SANITIZER_ADDRESS OR special_train_ENABLE_SANITIZER_THREAD OR special_train_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(special_train_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(special_train_global_options)
  if(special_train_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    special_train_enable_ipo()
  endif()

  special_train_supports_sanitizers()

  if(special_train_ENABLE_HARDENING AND special_train_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR special_train_ENABLE_SANITIZER_UNDEFINED
       OR special_train_ENABLE_SANITIZER_ADDRESS
       OR special_train_ENABLE_SANITIZER_THREAD
       OR special_train_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${special_train_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${special_train_ENABLE_SANITIZER_UNDEFINED}")
    special_train_enable_hardening(special_train_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(special_train_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(special_train_warnings INTERFACE)
  add_library(special_train_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  special_train_set_project_warnings(
    special_train_warnings
    ${special_train_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(special_train_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    special_train_configure_linker(special_train_options)
  endif()

  include(cmake/Sanitizers.cmake)
  special_train_enable_sanitizers(
    special_train_options
    ${special_train_ENABLE_SANITIZER_ADDRESS}
    ${special_train_ENABLE_SANITIZER_LEAK}
    ${special_train_ENABLE_SANITIZER_UNDEFINED}
    ${special_train_ENABLE_SANITIZER_THREAD}
    ${special_train_ENABLE_SANITIZER_MEMORY})

  set_target_properties(special_train_options PROPERTIES UNITY_BUILD ${special_train_ENABLE_UNITY_BUILD})

  if(special_train_ENABLE_PCH)
    target_precompile_headers(
      special_train_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(special_train_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    special_train_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(special_train_ENABLE_CLANG_TIDY)
    special_train_enable_clang_tidy(special_train_options ${special_train_WARNINGS_AS_ERRORS})
  endif()

  if(special_train_ENABLE_CPPCHECK)
    special_train_enable_cppcheck(${special_train_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(special_train_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    special_train_enable_coverage(special_train_options)
  endif()

  if(special_train_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(special_train_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(special_train_ENABLE_HARDENING AND NOT special_train_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR special_train_ENABLE_SANITIZER_UNDEFINED
       OR special_train_ENABLE_SANITIZER_ADDRESS
       OR special_train_ENABLE_SANITIZER_THREAD
       OR special_train_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    special_train_enable_hardening(special_train_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
