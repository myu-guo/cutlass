# Copyright (c) 2017-2019, NVIDIA CORPORATION.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are permitted
# provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright notice, this list of
#       conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright notice, this list of
#       conditions and the following disclaimer in the documentation and/or other materials
#       provided with the distribution.
#     * Neither the name of the NVIDIA CORPORATION nor the names of its contributors may be used
#       to endorse or promote products derived from this software without specific prior written
#       permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL NVIDIA CORPORATION BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TOR (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

if(CUDA_COMPILER MATCHES "[Cc]lang")
  set(CUTLASS_NATIVE_CUDA_INIT ON)
elseif(CMAKE_VERSION VERSION_LESS 3.12.4)
  set(CUTLASS_NATIVE_CUDA_INIT OFF)
else()
  set(CUTLASS_NATIVE_CUDA_INIT ON)
endif()

set(CUTLASS_NATIVE_CUDA ${CUTLASS_NATIVE_CUDA_INIT} CACHE BOOL "Utilize the CMake native CUDA flow")

if(NOT DEFINED ENV{CUDACXX} AND NOT DEFINED ENV{CUDA_BIN_PATH} AND DEFINED ENV{CUDA_PATH})
  # For backward compatibility, allow use of CUDA_PATH.
  set(ENV{CUDACXX} $ENV{CUDA_PATH}/bin/nvcc)
endif()

if(CUTLASS_NATIVE_CUDA)

  enable_language(CUDA)

else()

  find_package(CUDA REQUIRED)

endif()

if(NOT CUDA_VERSION)
  set(CUDA_VERSION ${CMAKE_CUDA_COMPILER_VERSION})
endif()
if(NOT CUDA_TOOLKIT_ROOT_DIR)
  get_filename_component(CUDA_TOOLKIT_ROOT_DIR "${CMAKE_CUDA_COMPILER}/../.." ABSOLUTE)
endif()

if (CUDA_VERSION VERSION_LESS 9.2)
  message(FATAL_ERROR "CUDA 9.2+ Required, Found ${CUDA_VERSION}.")
endif()

if(NOT CUTLASS_NATIVE_CUDA OR CUDA_COMPILER MATCHES "[Cc]lang")
  set(CMAKE_CUDA_COMPILER ${CUDA_TOOLKIT_ROOT_DIR}/bin/nvcc)
  message(STATUS "CUDA Compiler: ${CMAKE_CUDA_COMPILER}")
endif()

find_library(
  CUDART_LIBRARY cudart
  PATHS
  ${CUDA_TOOLKIT_ROOT_DIR}
  PATH_SUFFIXES
  lib/x64
  lib64
  lib
  NO_DEFAULT_PATH
  # We aren't going to search any system paths. We want to find the runtime 
  # in the CUDA toolkit we're building against.
  )

if(CUDART_LIBRARY)

  message(STATUS "CUDART: ${CUDART_LIBRARY}")

  if(WIN32)
    add_library(cudart STATIC IMPORTED GLOBAL)
    # Even though we're linking against a .dll, in Windows you statically link against
    # the .lib file found under lib/x64. The .dll will be loaded at runtime automatically
    # from the PATH search.
  else()
    add_library(cudart SHARED IMPORTED GLOBAL)
  endif()  

  add_library(nvidia::cudart ALIAS cudart)
  
  set_property(
    TARGET cudart
    PROPERTY IMPORTED_LOCATION
    ${CUDART_LIBRARY}
    )

else()

  message(STATUS "CUDART: Not Found")

endif()

find_library(
  CUDA_DRIVER_LIBRARY cuda
  PATHS
  ${CUDA_TOOLKIT_ROOT_DIR}
  PATH_SUFFIXES
  lib/x64
  lib64
  lib
  lib64/stubs
  lib/stubs
  NO_DEFAULT_PATH
  # We aren't going to search any system paths. We want to find the runtime 
  # in the CUDA toolkit we're building against.
  )

if(CUDA_DRIVER_LIBRARY)

  message(STATUS "CUDA Driver: ${CUDA_DRIVER_LIBRARY}")

  if(WIN32)
    add_library(cuda_driver STATIC IMPORTED GLOBAL)
    # Even though we're linking against a .dll, in Windows you statically link against
    # the .lib file found under lib/x64. The .dll will be loaded at runtime automatically
    # from the PATH search.
  else()
    add_library(cuda_driver SHARED IMPORTED GLOBAL)
  endif()  

  add_library(nvidia::cuda_driver ALIAS cuda_driver)
  
  set_property(
    TARGET cuda_driver
    PROPERTY IMPORTED_LOCATION
    ${CUDA_DRIVER_LIBRARY}
    )

else()

  message(STATUS "CUDA Driver: Not Found")

endif()

find_library(
  NVRTC_LIBRARY nvrtc
  PATHS
  ${CUDA_TOOLKIT_ROOT_DIR}
  PATH_SUFFIXES
  lib/x64
  lib64
  lib
  NO_DEFAULT_PATH
  # We aren't going to search any system paths. We want to find the runtime 
  # in the CUDA toolkit we're building against.
  )

if(NVRTC_LIBRARY)

  message(STATUS "NVRTC: ${NVRTC_LIBRARY}")

  if(WIN32)
    add_library(nvrtc STATIC IMPORTED GLOBAL)
    # Even though we're linking against a .dll, in Windows you statically link against
    # the .lib file found under lib/x64. The .dll will be loaded at runtime automatically
    # from the PATH search.
  else()
    add_library(nvrtc SHARED IMPORTED GLOBAL)
  endif()  
  
  add_library(nvidia::nvrtc ALIAS nvrtc)
  
  set_property(
    TARGET nvrtc
    PROPERTY IMPORTED_LOCATION
    ${NVRTC_LIBRARY}
    )

else()

  message(STATUS "NVRTC: Not Found")

endif()

include_directories(SYSTEM ${CUDA_INCLUDE_DIRS})
# Some platforms (e.g. Visual Studio) don't add the CUDA include directories to the system include
# paths by default, so we add it explicitly here.

function(cutlass_correct_source_file_language_property)
  if(CUDA_COMPILER MATCHES "clang")
    foreach(File ${ARGN})
      if(${File} MATCHES ".*\.cu$")
        set_source_files_properties(${File} PROPERTIES LANGUAGE CXX)
      endif()
    endforeach()
  endif()
endfunction()

function(cutlass_add_library)

  set(options INTERFACE STATIC SHARED OBJECT)
  set(oneValueArgs)
  set(multiValueArgs)
  cmake_parse_arguments(_ "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(CUTLASS_NATIVE_CUDA OR CUDA_COMPILER MATCHES "clang" OR __INTERFACE)
    cutlass_correct_source_file_language_property(${ARGN})
    add_library(${ARGN})
  else()
    set(CUDA_LINK_LIBRARIES_KEYWORD PRIVATE)
    cuda_add_library(${ARGN})
  endif()

endfunction()

function(cutlass_add_executable)

  set(options)
  set(oneValueArgs)
  set(multiValueArgs)
  cmake_parse_arguments(_ "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(CUTLASS_NATIVE_CUDA OR CUDA_COMPILER MATCHES "clang")
    cutlass_correct_source_file_language_property(${ARGN})
    add_executable(${ARGN})
  else()
    set(CUDA_LINK_LIBRARIES_KEYWORD PRIVATE)
    cuda_add_executable(${ARGN})
  endif()

endfunction()

function(cutlass_target_sources)

  set(options)
  set(oneValueArgs)
  set(multiValueArgs)
  cmake_parse_arguments(_ "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  cutlass_correct_source_file_language_property(${ARGN})
  target_sources(${ARGN})

endfunction()
