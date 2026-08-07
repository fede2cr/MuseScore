# SPDX-License-Identifier: GPL-3.0-only
# MuseScore-Studio-CLA-applies

function(fdk-aac_Populate remote_url local_path os arch build_type)
    include(FetchContent)

    set(BUILD_PROGRAMS OFF CACHE BOOL "" FORCE)
    set(FDK_AAC_INSTALL_CMAKE_CONFIG_MODULE OFF CACHE BOOL "" FORCE)
    set(FDK_AAC_INSTALL_PKGCONFIG_MODULE OFF CACHE BOOL "" FORCE)

    # fdk-aac requires CMake 3.5.1, so CMP0077 is OLD there and its
    # option(BUILD_SHARED_LIBS ... ON) would ignore the normal variable set by
    # SetupBuildEnvironment. Force the cache entry so the codec stays static and
    # no dylib has to be deployed into the bundle, then restore the old value.
    get_property(prev_shared_set CACHE BUILD_SHARED_LIBS PROPERTY VALUE SET)
    get_property(prev_shared CACHE BUILD_SHARED_LIBS PROPERTY VALUE)
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

    FetchContent_Declare(fdk-aac
        URL https://github.com/mstorsjo/fdk-aac/archive/refs/tags/v2.0.3.tar.gz
        URL_HASH SHA256=e25671cd96b10bad896aa42ab91a695a9e573395262baed4e4a2ff178d6a3a78
        DOWNLOAD_EXTRACT_TIMESTAMP TRUE
        EXCLUDE_FROM_ALL
    )
    FetchContent_MakeAvailable(fdk-aac)

    if (prev_shared_set)
        set(BUILD_SHARED_LIBS "${prev_shared}" CACHE BOOL "" FORCE)
    else()
        unset(BUILD_SHARED_LIBS CACHE)
    endif()

    FetchContent_GetProperties(fdk-aac SOURCE_DIR fdk_aac_source_dir)
    set_property(GLOBAL PROPERTY fdk-aac_SOURCE_DIR "${fdk_aac_source_dir}")
endfunction()