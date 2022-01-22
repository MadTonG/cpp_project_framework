# @file     cpp_project_framework_callables.cmake
# @author   Curtis Lo

# detect build type and build folder
macro(cpf_detect_build_type)
    message("CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
    message("CMAKE_CURRENT_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}")
    message("CMAKE_CURRENT_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}")
    if(NOT CMAKE_CONFIGURATION_TYPES)
        set(CMAKE_CONFIGURATION_TYPES Debug Release MinSizeRel RelWithDebInfo)
    endif()
    message("CMAKE_CONFIGURATION_TYPES=${CMAKE_CONFIGURATION_TYPES}")
    list(JOIN CMAKE_CONFIGURATION_TYPES "|" SUPPORTED_BUILD_TYPES)
    message("SUPPORTED_BUILD_TYPES=${SUPPORTED_BUILD_TYPES}")
    string(REGEX MATCH "(${SUPPORTED_BUILD_TYPES})$" DETECTED_BUILD_FOLDER ${CMAKE_CURRENT_BINARY_DIR})
    message("DETECTED_BUILD_FOLDER=${DETECTED_BUILD_FOLDER}")
    if(NOT DETECTED_BUILD_FOLDER IN_LIST CMAKE_CONFIGURATION_TYPES)
        message(FATAL_ERROR "DETECTED_BUILD_FOLDER (${DETECTED_BUILD_FOLDER}) must be in one of the CMAKE_CONFIGURATION_TYPES (${CMAKE_CONFIGURATION_TYPES})")
    endif()
    if(CMAKE_BUILD_TYPE)
        if(NOT DETECTED_BUILD_FOLDER STREQUAL CMAKE_BUILD_TYPE)
            message(FATAL_ERROR "DETECTED_BUILD_FOLDER (${DETECTED_BUILD_FOLDER}) must be same as CMAKE_BUILD_TYPE (${CMAKE_BUILD_TYPE})")
        endif()
        set(DETECTED_BUILD_TYPE ${CMAKE_BUILD_TYPE})
        message("CMAKE_BUILD_TYPE found, DETECTED_BUILD_TYPE=CMAKE_BUILD_TYPE=${DETECTED_BUILD_TYPE}")
    else()
        set(DETECTED_BUILD_TYPE ${DETECTED_BUILD_FOLDER})
        message("CMAKE_BUILD_TYPE not found, DETECTED_BUILD_TYPE=DETECTED_BUILD_FOLDER=${DETECTED_BUILD_TYPE}")
    endif()
    string(TOUPPER ${DETECTED_BUILD_TYPE} DETECTED_BUILD_TYPE_UPPER)
endmacro()

# check if python virtual environment exists
macro(cpf_detect_virtual_environment)
    set(VENV_PATH ${CMAKE_CURRENT_SOURCE_DIR}/.venv)
    if(IS_DIRECTORY ${VENV_PATH})
        message("python virtual environment found, VENV_PATH=${VENV_PATH}")
    else()
        message(FATAL_ERROR "python virtual environment not found, VENV_PATH=${VENV_PATH}")
    endif()
    if(WIN32)
        set(VENV_ACTIVATE_CMD ".venv\\Scripts\\activate")
    else()
        set(VENV_ACTIVATE_CMD "source .venv/bin/activate")
    endif()
endmacro()

# install conan dependencies
macro(cpf_install_conan_dependencies)
    set(CONAN_INSTALL_CMD "conan install conanfile.txt -b missing -s build_type=${DETECTED_BUILD_TYPE} -if ${DETECTED_BUILD_FOLDER}")
    if(WIN32)
        execute_process(COMMAND CMD /c "${VENV_ACTIVATE_CMD} && ${CONAN_INSTALL_CMD}" WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
    else()
        execute_process(COMMAND bash -c "${VENV_ACTIVATE_CMD} && ${CONAN_INSTALL_CMD}" WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})
    endif()  
endmacro()

# inject conan information
macro(cpf_inject_conan_info)
    if(EXISTS ${CMAKE_BINARY_DIR}/conanbuildinfo_multi.cmake)
    message("cmake_multi generator conan information detected")
    include(${CMAKE_BINARY_DIR}/conanbuildinfo_multi.cmake)
    conan_basic_setup()
    elseif(EXISTS ${CMAKE_BINARY_DIR}/conanbuildinfo.cmake)
    message("cmake generator conan information detected")
    include(${CMAKE_BINARY_DIR}/conanbuildinfo.cmake)
    conan_basic_setup()
    else()
    message("no cmake generator conan information detected")
    endif()
endmacro()

# get variable by build type
function(cpf_get_variable_by_build_type VARIABLE_NAME)
    if (DEFINED ${VARIABLE_NAME}_${DETECTED_BUILD_TYPE_UPPER})
        set(CPF_GET_VARIABLE ${${VARIABLE_NAME}_${DETECTED_BUILD_TYPE_UPPER}} PARENT_SCOPE)
    else()
        set(CPF_GET_VARIABLE ${${VARIABLE_NAME}} PARENT_SCOPE)
    endif()
endfunction()

# set project type
macro(cpf_set_project_type)
    if(NOT IS_EXE)
        if (PROJECT_TYPE EQUAL "LIB")
            set(IS_LIB TRUE)
        endif()
    endif()
    if(NOT IS_LIB)
        if(PROJECT_TYPE EQUAL "EXE")
            set(IS_EXE TRUE)
        endif()
    endif()
    if(NOT IS_EXE AND NOT IS_LIB)
        set(PROJECT_TYPE "HEADER_ONLY")
        set(IS_HEADER_ONLY TRUE)
    endif()
endmacro()

# find all header files
macro(cpf_find_all_header_files)
    if(NOT HEADER_FILES)
        file(GLOB HEADER_FILES *.h *.hpp)
    endif()
endmacro()

# add binary target
macro(cpf_add_binary_target)
    # build the static and shared libraries (make)
    if(IS_LIB)
        add_library(static_lib STATIC ${SRC_FILES})
        add_library(shared_lib SHARED ${SRC_FILES})
    endif()

    # build the executable (make)
    if(IS_EXE)
        add_executable(exe ${SRC_FILES})
    endif()
endmacro()

# link binary target with depending library files
macro(cpf_binary_target_link_libraries)
    # specify depending library files
    set(STATIC_LIBS ${USER_STATIC_LIBS} ${BOOST_STATIC_LIBS})
    set(DYNAMIC_LIBS ${USER_DYNAMIC_LIBS} ${BOOST_DYNAMIC_LIBS})
    set(LIB_FILES ${STATIC_LIBS} ${DYNAMIC_LIBS})

    # link with depending library files
    if(IS_LIB)
        target_link_libraries(static_lib ${LIB_FILES})
        target_link_libraries(shared_lib ${LIB_FILES})
    endif()
    if(IS_EXE)
        target_link_libraries(exe ${LIB_FILES})
    endif()

    # link with depending library files using conan
    if(IS_LIB)
        conan_target_link_libraries(static_lib)
        conan_target_link_libraries(shared_lib)
    endif()
    if(IS_EXE)
        conan_target_link_libraries(exe)
    endif()
endmacro()

# rename binary target
macro(cpf_rename_binary_target)
    # rename the generated static and shared libraries
    if(IS_LIB)
        set(LIBRARY_NAME "${PROJECT_NAME}")
        set_target_properties(static_lib PROPERTIES OUTPUT_NAME ${LIBRARY_NAME})
        set_target_properties(shared_lib PROPERTIES OUTPUT_NAME ${LIBRARY_NAME})
    endif()

    # rename the generated executable
    if(IS_EXE)
        set(EXE_NAME "${PROJECT_NAME}")
        set_target_properties(exe PROPERTIES OUTPUT_NAME ${EXE_NAME})
    endif()
endmacro()

# install targets and files
macro(cpf_install)
    # install the static and shared libraries and header files (make install)
    if(IS_LIB)
        install(TARGETS static_lib shared_lib DESTINATION lib)
        install(FILES ${HEADER_FILES} DESTINATION include/${LIBRARY_NAME})
    endif()

    # install the executable (make install)
    if(IS_EXE)
        install(TARGETS exe DESTINATION bin)
    endif()

    # install the header files (make install)
    if(IS_HEADER_ONLY)
        set(LIBRARY_NAME "${PROJECT_NAME}")
        install(FILES ${HEADER_FILES} DESTINATION include/${LIBRARY_NAME})
    endif()
endmacro()