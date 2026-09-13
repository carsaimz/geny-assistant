# geny_whisper_jni — lib nativa do STT (docs §7.2, TODO core-02).
#
# PT: compila o wrapper JNI + whisper.cpp do submodule pinado
# (native/whisper.cpp, tag fixa). O WHISPER_DIR é passado pelo
# build.gradle.kts via argumento do CMake — sem caminhos relativos frágeis.
# EN: builds the JNI wrapper + the pinned whisper.cpp submodule
# (native/whisper.cpp, fixed tag). WHISPER_DIR comes from build.gradle.kts
# as a CMake argument — no fragile relative paths.

cmake_minimum_required(VERSION 3.22)
project(geny_whisper_jni CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT EXISTS "${WHISPER_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "WHISPER_DIR inválido: rode scripts/setup-submodules.sh (${WHISPER_DIR})")
endif()

# Opções do whisper.cpp/ggml para Android (build determinístico, sem OpenMP).
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
set(GGML_LLAMAFILE OFF CACHE BOOL "" FORCE)
set(GGML_BACKEND_DL OFF CACHE BOOL "" FORCE)

add_subdirectory(${WHISPER_DIR} whisper-build EXCLUDE_FROM_ALL)

add_library(geny_whisper_jni SHARED geny_whisper_jni.cpp)

target_include_directories(geny_whisper_jni PRIVATE ${WHISPER_DIR}/include)
target_link_libraries(geny_whisper_jni PRIVATE whisper log)
