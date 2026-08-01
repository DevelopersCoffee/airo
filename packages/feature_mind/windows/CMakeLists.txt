# Cargokit builds airo_mind_runtime as part of the CMake configure/build so the
# desktop targets need no separate step either.
cmake_minimum_required(VERSION 3.10)

set(PROJECT_NAME "feature_mind")
project(${PROJECT_NAME} LANGUAGES CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/../cargokit/cmake/cargokit.cmake")
# The runtime is in the cargo workspace at <repo>/rust, not in this package.
apply_cargokit(${PROJECT_NAME} ../../../rust/airo_mind_runtime airo_mind_runtime "")

set(feature_mind_bundled_libraries
  "${airo_mind_runtime_cargokit_lib}"
  PARENT_SCOPE
)
