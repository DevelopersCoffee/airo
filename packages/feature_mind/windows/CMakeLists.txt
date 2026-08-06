# Cargokit builds the Airo Mind engines as part of the CMake configure/build, so
# the desktop targets need no separate step.
#
# Two libraries, not one: whisper.cpp and llama.cpp each statically vendor their
# own copy of ggml, with the same symbol names and 348 files of difference
# between the trees. One library holding both is a one-definition-rule conflict
# between two upstream projects (#1546), so each engine is its own cdylib and
# Dart loads them separately.
cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "feature_mind")
project(${PROJECT_NAME} LANGUAGES CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/../cargokit/cmake/cargokit.cmake")
# The engines are in the cargo workspace at <repo>/rust, not in this package.
apply_cargokit(${PROJECT_NAME} ../../../rust/airo_mind_whisper airo_mind_whisper "")
apply_cargokit(${PROJECT_NAME} ../../../rust/airo_mind_llama airo_mind_llama "")

set(feature_mind_bundled_libraries
  "${airo_mind_whisper_cargokit_lib}"
  "${airo_mind_llama_cargokit_lib}"
  PARENT_SCOPE
)
