# The following lines of boilerplate have to be in your project's
# CMakeLists in this exact order for cmake to work correctly
cmake_minimum_required(VERSION 3.11)

if(NOT DEFINED ENV{IDF_PATH})
    set(ENV{IDF_PATH} "C:/esp/v5.5.3/esp-idf")
endif()

if(NOT DEFINED ENV{PYTHON})
    set(ENV{PYTHON} "C:/Espressif/tools/python/v5.5.3/venv/Scripts/python.exe")
endif()

# Set the target explicitly
set(IDF_TARGET "esp32s3")

# Set CMAKE_TOOLCHAIN_FILE to the one provided by ESP-IDF
set(CMAKE_TOOLCHAIN_FILE "$ENV{IDF_PATH}/tools/cmake/toolchain-esp32s3.cmake")

set(ENV{PATH} "C:/Espressif/tools/xtensa-esp-elf/esp-14.2.0_20251107/xtensa-esp-elf/bin;$ENV{PATH}")

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(app-template)
