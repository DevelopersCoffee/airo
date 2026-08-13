# Cargokit builds airo_core as part of the CMake configure/build, so the
# desktop targets need no separate step (#1677).
cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "core_native")
project(${PROJECT_NAME} LANGUAGES CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/../cargokit/cmake/cargokit.cmake")
# The crate is in the cargo workspace at <repo>/rust, not in this package.
apply_cargokit(${PROJECT_NAME} ../../../rust/airo_core airo_core "")

set(core_native_bundled_libraries
  "${core_native_cargokit_lib}"
  PARENT_SCOPE
)
