cmake_minimum_required(VERSION 3.22)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/third_party/cmake_toolbox")
include(CMakeToolboxInitialize)

CMakeToolboxInitialize()

SetCAndCXXStandard(11 20)

EnableCCache()

project(jfml)

# Project
add_subdirectory(src)
