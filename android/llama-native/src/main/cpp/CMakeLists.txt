# geny_llama_jni — lib nativa do LLM local (docs §6, TODO core-05).
#
# PT: módulo SEPARADO do app de propósito. O llama.cpp v0.4.0 traz o próprio
# ggml v0.4.0, incompatível com o ggml vendored pelo whisper.cpp v1.7.4
# (ambos usam a guarda `if (NOT TARGET ggml)` — num único configure o
# primeiro alvo colidiria com o segundo). Módulos distintos = dois
# configurates isolados, cada um com o seu ggml. O LLAMA_DIR vem do
# build.gradle.kts via argumento do CMake.
# EN: a module SEPARATED from :app on purpose. llama.cpp v0.4.0 vendors its
# own ggml v0.4.0, incompatible with the ggml vendored by whisper.cpp
# v1.7.4 (both guard with `if (NOT TARGET ggml)` — a single configure would
# collide the first target with the second). Distinct modules = isolated
# configures, each with its own ggml. LLAMA_DIR comes from build.gradle.kts
# as a CMake argument.

cmake_minimum_required(VERSION 3.22)
project(geny_llama_jni CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT EXISTS "${LLAMA_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "LLAMA_DIR inválido: rode scripts/setup-submodules.sh (${LLAMA_DIR})")
endif()

# Opções do llama.cpp/ggml para Android: CPU puro, sem extras de rede —
# build determinístico e leve. Estático: tudo entra no geny_llama_jni.so.
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_APP OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_UI OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_COMMON OFF CACHE BOOL "" FORCE)
set(LLAMA_USE_PREBUILT_UI OFF CACHE BOOL "" FORCE)
set(LLAMA_CURL OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
set(GGML_LLAMAFILE OFF CACHE BOOL "" FORCE)
set(GGML_BACKEND_DL OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP_FETCH OFF CACHE BOOL "" FORCE)

add_subdirectory(${LLAMA_DIR} llama-build EXCLUDE_FROM_ALL)

add_library(geny_llama_jni SHARED geny_llama_jni.cpp)

target_include_directories(geny_llama_jni PRIVATE
    ${LLAMA_DIR}/include
    ${LLAMA_DIR}/ggml/include
)
target_link_libraries(geny_llama_jni PRIVATE llama log)
