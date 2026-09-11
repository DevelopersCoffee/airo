# Cargokit builds m3u_parser as part of the CMake configure/build, so the
# desktop targets need no separate step. Mirrors packages/core_native's
# pattern (#1677).
cmake_minimum_required(VERSION 3.14)

set(PROJECT_NAME "m3u_parser")
project(${PROJECT_NAME} LANGUAGES CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/../cargokit/cmake/cargokit.cmake")
apply_cargokit(${PROJECT_NAME} ../rust m3u_parser "")

set(m3u_parser_bundled_libraries
  "${m3u_parser_cargokit_lib}"
  PARENT_SCOPE
)
