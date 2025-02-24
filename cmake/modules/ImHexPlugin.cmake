macro(add_imhex_plugin)
    # Parse arguments
    set(options LIBRARY_PLUGIN)
    set(oneValueArgs NAME)
    set(multiValueArgs SOURCES INCLUDES LIBRARIES FEATURES)
    cmake_parse_arguments(IMHEX_PLUGIN "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (IMHEX_STATIC_LINK_PLUGINS)
        set(IMHEX_PLUGIN_LIBRARY_TYPE STATIC)

        target_link_libraries(libimhex PUBLIC ${IMHEX_PLUGIN_NAME})

        configure_file(${CMAKE_SOURCE_DIR}/dist/web/plugin-bundle.cpp.in ${CMAKE_CURRENT_BINARY_DIR}/plugin-bundle.cpp @ONLY)
        target_sources(main PUBLIC ${CMAKE_CURRENT_BINARY_DIR}/plugin-bundle.cpp)
        set(IMHEX_PLUGIN_SUFFIX ".hexplug")
    else()
        if (IMHEX_PLUGIN_LIBRARY_PLUGIN)
            set(IMHEX_PLUGIN_LIBRARY_TYPE SHARED)
            set(IMHEX_PLUGIN_SUFFIX ".hexpluglib")
        else()
            set(IMHEX_PLUGIN_LIBRARY_TYPE MODULE)
            set(IMHEX_PLUGIN_SUFFIX ".hexplug")
        endif()
    endif()

    # Define new project for plugin
    project(${IMHEX_PLUGIN_NAME})

    # Create a new shared library for the plugin source code
    add_library(${IMHEX_PLUGIN_NAME} ${IMHEX_PLUGIN_LIBRARY_TYPE} ${IMHEX_PLUGIN_SOURCES})

    # Add include directories and link libraries
    target_include_directories(${IMHEX_PLUGIN_NAME} PUBLIC ${IMHEX_PLUGIN_INCLUDES})
    target_link_libraries(${IMHEX_PLUGIN_NAME} PRIVATE libimhex ${IMHEX_PLUGIN_LIBRARIES} ${FMT_LIBRARIES} imgui_all_includes libwolv)
    addIncludesFromLibrary(${IMHEX_PLUGIN_NAME} libpl)

    # Add IMHEX_PROJECT_NAME and IMHEX_VERSION define
    target_compile_definitions(${IMHEX_PLUGIN_NAME} PRIVATE IMHEX_PROJECT_NAME="${IMHEX_PLUGIN_NAME}")
    target_compile_definitions(${IMHEX_PLUGIN_NAME} PRIVATE IMHEX_VERSION="${IMHEX_VERSION_STRING}")
    target_compile_definitions(${IMHEX_PLUGIN_NAME} PRIVATE IMHEX_PLUGIN_NAME=${IMHEX_PLUGIN_NAME})

    # Enable required compiler flags
    set_target_properties(${IMHEX_PLUGIN_NAME} PROPERTIES POSITION_INDEPENDENT_CODE ON)
    enableUnityBuild(${IMHEX_PLUGIN_NAME})
    setupCompilerFlags(${IMHEX_PLUGIN_NAME})

    # Configure build properties
    set_target_properties(${IMHEX_PLUGIN_NAME}
            PROPERTIES
            RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/plugins
            CXX_STANDARD 23
            PREFIX ""
            SUFFIX ${IMHEX_PLUGIN_SUFFIX}
    )

    # Setup a romfs for the plugin
    list(APPEND LIBROMFS_RESOURCE_LOCATION ${CMAKE_CURRENT_SOURCE_DIR}/romfs)
    set(LIBROMFS_PROJECT_NAME ${IMHEX_PLUGIN_NAME})
    add_subdirectory(${IMHEX_BASE_FOLDER}/lib/external/libromfs ${CMAKE_CURRENT_BINARY_DIR}/libromfs)
    set_target_properties(${LIBROMFS_LIBRARY} PROPERTIES POSITION_INDEPENDENT_CODE ON)
    target_link_libraries(${IMHEX_PLUGIN_NAME} PRIVATE ${LIBROMFS_LIBRARY})

    foreach(feature ${IMHEX_PLUGIN_FEATURES})
        string(TOUPPER ${feature} feature)
        add_definitions(-DIMHEX_PLUGIN_${IMHEX_PLUGIN_NAME}_FEATURE_${feature}=0)
    endforeach()

    # Add the new plugin to the main dependency list so it gets built by default
    if (TARGET imhex_all)
        add_dependencies(imhex_all ${IMHEX_PLUGIN_NAME})
    endif()
endmacro()

macro(add_romfs_resource input output)
    configure_file(${input} ${CMAKE_CURRENT_BINARY_DIR}/romfs/${output} COPYONLY)

    list(APPEND LIBROMFS_RESOURCE_LOCATION ${CMAKE_CURRENT_BINARY_DIR}/romfs)
endmacro()

macro (enable_plugin_feature feature)
    string(TOUPPER ${feature} feature)
    if (NOT (feature IN_LIST IMHEX_PLUGIN_FEATURES))
        message(FATAL_ERROR "Feature ${feature} is not enabled for plugin ${IMHEX_PLUGIN_NAME}")
    endif()

    remove_definitions(-DIMHEX_PLUGIN_${IMHEX_PLUGIN_NAME}_FEATURE_${feature}=0)
    add_definitions(-DIMHEX_PLUGIN_${IMHEX_PLUGIN_NAME}_FEATURE_${feature}=1)
endmacro()