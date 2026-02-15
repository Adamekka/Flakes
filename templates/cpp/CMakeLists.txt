cmake_minimum_required(VERSION 3.15)

project(CPP VERSION 1.0 LANGUAGES CXX)

set(CMAKE_C_STANDARD 23)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED True)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Debug CACHE STRING "Choose the type of build." FORCE)
    message(STATUS "Setting build type to 'Debug' as none was specified.")
endif()

set(CMAKE_CXX_FLAGS
    "-fsanitize=address -fsanitize=undefined -fstack-protector-strong -Wno-unused-result -Wall -Wextra -Werror=uninitialized -Werror=vla -Werror=return-type -Wshadow -Wnull-dereference -Wformat -Wformat-security -Wstrict-overflow -Wstrict-prototypes -Wcast-align -Wredundant-decls -Wpedantic -Werror -Wno-shadow"
)

add_executable(my_executable_name src/main.cpp) # <-- CHANGE THIS TOO

target_compile_options(my_executable_name PRIVATE -Wall -Wextra -Wpedantic)
