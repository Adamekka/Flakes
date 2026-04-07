cmake_minimum_required(VERSION 3.15)

project(my_executable_name) # TODO: CHANGE BINARY NAME

set(CMAKE_C_STANDARD 26)

set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED True)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Debug CACHE STRING "Choose the type of build." FORCE)
    message(STATUS "Setting build type to 'Debug' as none was specified.")
endif()

set(CXX_FLAGS
    -Wall
    -Wcast-align
    -Wextra
    -Wformat
    -Wformat-security
    -Wno-shadow
    -Wno-unused-result
    -Wnull-dereference
    -Wredundant-decls
    -Wreturn-type
    -Wstrict-overflow
    -Wuninitialized
    -Wvla
    -fstack-protector-strong
    -fsanitize=address
    -fsanitize=undefined
)

file(GLOB SOURCES src/*.cpp)
add_executable(my_executable_name ${SOURCES}) # TODO: CHANGE BINARY NAME

target_compile_options(my_executable_name PRIVATE ${CXX_FLAGS}) # TODO: CHANGE BINARY NAME
target_link_options(my_executable_name PRIVATE -fsanitize=address -fsanitize=undefined) # TODO: CHANGE BINARY NAME
