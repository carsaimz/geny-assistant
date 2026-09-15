# geny_whisper_jni — lib nativa do STT (docs §7.2, TODO core-02).
#
# PT: compila o wrapper JNI + whisper.cpp do submodule pinado
# (native/whisper.cpp, tag fixa). O WHISPER_DIR é passado pelo
# build.gradle.kts via argumento do CMake — sem caminhos relativos frágeis.
# O ggml do whisper fica ISOLADO neste módulo: o LLM local (:llama-native)
# tem o próprio ggml (v0.4.0) — as duas versões não são intercambiáveis
# (guardas `if (NOT TARGET ggml)` colidiriam num único configure).
# EN: builds the JNI wrapper + the pinned whisper.cpp submodule
# (native/whisper.cpp, fixed tag). WHISPER_DIR comes from build.gradle.kts
# as a CMake argument — no fragile relative paths. The whisper ggml stays
# ISOLATED in this module: the local LLM (:llama-native) has its own ggml
# (v0.4.0) — the two versions are not interchangeable (the
# `if (NOT TARGET ggml)` guards would collide in a single configure).

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
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

add_subdirectory(${WHISPER_DIR} whisper-build EXCLUDE_FROM_ALL)

add_library(geny_whisper_jni SHARED geny_whisper_jni.cpp)

target_include_directories(geny_whisper_jni PRIVATE ${WHISPER_DIR}/include)
target_link_libraries(geny_whisper_jni PRIVATE whisper log)

# --------------------------------------------------------------------------
# geny_espeak_jni — fonemização IPA do Piper (TODO core-03).
#
# PT: compila o wrapper JNI + o espeak-ng do submodule pinado
# (native/espeak-ng @ ed530aa — fork com CMake usado pelo sherpa-onnx).
# Biblioteca estática ligada dentro do geny_espeak_jni.so; sem async,
# mbrola, sonic, pcaudio, klatt e speechPlayer — build determinístico e
# leve. Os espeak-ng-data NÃO entram no APK: são baixados sob demanda
# (PiperVoiceCatalog.ESPEAK_DATA) e extraídos em filesDir.
# EN: builds the JNI wrapper + the pinned espeak-ng submodule
# (native/espeak-ng @ ed530aa — CMake fork used by sherpa-onnx). Static
# library linked into geny_espeak_jni.so; no async, mbrola, sonic, pcaudio,
# klatt or speechPlayer — deterministic light build. The espeak-ng-data is
# NOT bundled in the APK: it is downloaded on demand
# (PiperVoiceCatalog.ESPEAK_DATA) and extracted into filesDir.

if(NOT EXISTS "${ESPEAK_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "ESPEAK_DIR inválido: rode scripts/setup-submodules.sh (${ESPEAK_DIR})")
endif()

set(BUILD_ESPEAK_NG_TESTS OFF CACHE BOOL "" FORCE)
set(BUILD_ESPEAK_NG_EXE OFF CACHE BOOL "" FORCE)
set(USE_ASYNC OFF CACHE BOOL "" FORCE)
set(USE_MBROLA OFF CACHE BOOL "" FORCE)
set(USE_LIBSONIC OFF CACHE BOOL "" FORCE)
set(USE_LIBPCAUDIO OFF CACHE BOOL "" FORCE)
set(USE_KLATT OFF CACHE BOOL "" FORCE)
set(USE_SPEECHPLAYER OFF CACHE BOOL "" FORCE)

add_subdirectory(${ESPEAK_DIR} espeak-build EXCLUDE_FROM_ALL)

add_library(geny_espeak_jni SHARED geny_espeak_jni.cpp)

target_include_directories(geny_espeak_jni PRIVATE
    ${ESPEAK_DIR}/src/include
    ${ESPEAK_DIR}/src/libespeak-ng
    ${CMAKE_CURRENT_BINARY_DIR}/espeak-build)
target_link_libraries(geny_espeak_jni PRIVATE espeak-ng log)
