cmake_minimum_required(VERSION 3.14)
project(airo_haptics LANGUAGES CXX)

set(PLUGIN_NAME "airo_haptics_plugin")

add_library(${PLUGIN_NAME} SHARED
  "airo_haptics_plugin.cpp"
  "airo_haptics_plugin_c_api.cpp"
)

apply_standard_cpp_compiler_flags(${PLUGIN_NAME})

set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden
)

target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include"
)

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)
