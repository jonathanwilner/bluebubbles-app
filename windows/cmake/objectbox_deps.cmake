# Copyright 2024
#
# Helper utilities for preparing the native ObjectBox dependencies that are
# required when building the Windows desktop client.  The ObjectBox Flutter
# plugin uses CMake's FetchContent module to download a pre-built copy of the
# native database library.  That works fine when building inside Flutter, but
# when the BlueBubbles Windows project is built directly with CMake (for
# example when packaging in CI) the download step may fail if the
# `objectbox-download` FetchContent entry has not been configured yet.  This
# helper ensures the dependency is available ahead of time and seeds the cache
# variables expected by the plugin so that it can reuse the already downloaded
# artefacts without hitting the network again.

include_guard(GLOBAL)

function(prepare_objectbox_native_libs)
  if(NOT WIN32)
    return()
  endif()

  # ObjectBox Flutter 4.0.x uses the objectbox-c 4.0.0 binaries for Windows.
  if(NOT DEFINED OBJECTBOX_NATIVE_VERSION)
    set(OBJECTBOX_NATIVE_VERSION "4.0.0")
  endif()
  set(_objectbox_version "${OBJECTBOX_NATIVE_VERSION}")

  set(_processor_source "${CMAKE_SYSTEM_PROCESSOR}")
  if(NOT _processor_source)
    set(_processor_source "${CMAKE_HOST_SYSTEM_PROCESSOR}")
  endif()

  string(TOLOWER "${_processor_source}" _processor)
  if(NOT _processor)
    set(_processor "amd64")
  endif()
  set(_archive_arch "")
  set(_expected_hash "")

  if(_processor STREQUAL "amd64" OR _processor STREQUAL "x86_64")
    # The upstream release artefact is published as "objectbox-windows-x64".
    set(_archive_arch "x64")
    if(NOT DEFINED OBJECTBOX_NATIVE_SHA256_X64)
      set(OBJECTBOX_NATIVE_SHA256_X64
          "625245962c238bfab5cf61bf5db954d989974c6738ebf203a7a71c96c9644db0")
    endif()
    set(_expected_hash "${OBJECTBOX_NATIVE_SHA256_X64}")
  else()
    message(WARNING
      "ObjectBox native libraries are only published for 64-bit x86 on Windows. "
      "Skipping automatic download for processor '${CMAKE_SYSTEM_PROCESSOR}'.")
    return()
  endif()

  set(_download_base "${CMAKE_BINARY_DIR}/objectbox")
  set(_archive_path "${_download_base}/objectbox-${_archive_arch}.zip")
  set(_extract_dir "${_download_base}/${_objectbox_version}-${_archive_arch}")
  set(_extract_marker "${_extract_dir}/lib/objectbox.dll")

  if(NOT EXISTS "${_extract_marker}")
    file(MAKE_DIRECTORY "${_extract_dir}")

    set(_download_url
      "https://github.com/objectbox/objectbox-c/releases/download/v${_objectbox_version}/objectbox-windows-${_archive_arch}.zip")

    message(STATUS "Downloading ObjectBox native library from ${_download_url}")
    file(DOWNLOAD "${_download_url}" "${_archive_path}"
         EXPECTED_HASH SHA256=${_expected_hash}
         SHOW_PROGRESS
         STATUS _status)

    list(LENGTH _status _status_len)
    if(_status_len GREATER 0)
      list(GET _status 0 _status_code)
    else()
      set(_status_code -1)
    endif()

    if(NOT _status_code EQUAL 0)
      if(_status_len GREATER 1)
        list(GET _status 1 _status_msg)
      else()
        set(_status_msg "Unknown error")
      endif()
      message(FATAL_ERROR
        "Failed to download ObjectBox native library (${_status_code}): ${_status_msg}")
    endif()

    execute_process(
      COMMAND "${CMAKE_COMMAND}" -E tar xzf "${_archive_path}"
      WORKING_DIRECTORY "${_extract_dir}"
      RESULT_VARIABLE _extract_result
    )
    if(NOT _extract_result EQUAL 0)
      message(FATAL_ERROR "Failed to extract ObjectBox archive: ${_archive_path}")
    endif()
  endif()

  # Pre-populate the FetchContent cache variables that the ObjectBox Flutter
  # plugin relies on.  This prevents a redundant download inside the plugin's
  # own CMake logic and provides the path to the native binaries.
  set(objectbox-download_SOURCE_DIR "${_extract_dir}" CACHE PATH
      "Directory containing the prebuilt ObjectBox native libraries" FORCE)
  set(objectbox-download_POPULATED TRUE CACHE BOOL
      "Marks the ObjectBox native libraries as downloaded" FORCE)

  set(OBJECTBOX_NATIVE_DLL "${_extract_dir}/lib/objectbox.dll" CACHE FILEPATH
      "Path to the ObjectBox runtime library" FORCE)
  set(OBJECTBOX_NATIVE_IMPORT_LIB "${_extract_dir}/lib/objectbox.lib" CACHE FILEPATH
      "Path to the ObjectBox import library" FORCE)
endfunction()

