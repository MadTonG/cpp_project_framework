# @file     cpp_project_framework_callables.cmake
# @author   Curtis Lo

# detect build type and build folder
macro(cpf_detect_build_type)
    message("CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
    message("CMAKE_SOURCE_DIR=${CMAKE_SOURCE_DIR}")
    message("CMAKE_BINARY_DIR=${CMAKE_BINARY_DIR}")
    message("CMAKE_CURRENT_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}")
    message("CMAKE_CURRENT_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}")
    if(NOT CMAKE_CONFIGURATION_TYPES)
        set(CMAKE_CONFIGURATION_TYPES Debug Release MinSizeRel RelWithDebInfo)
    endif()
    message("CMAKE_CONFIGURATION_TYPES=${CMAKE_CONFIGURATION_TYPES}")
    list(JOIN CMAKE_CONFIGURATION_TYPES "|" SUPPORTED_BUILD_TYPES)
    message("SUPPORTED_BUILD_TYPES=${SUPPORTED_BUILD_TYPES}")
    string(REGEX MATCH "(${SUPPORTED_BUILD_TYPES})$" DETECTED_BUILD_FOLDER ${CMAKE_BINARY_DIR})
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
    set(VENV_PATH ${CMAKE_SOURCE_DIR}/.venv)
    if(IS_DIRECTORY ${VENV_PATH})
        message("python virtual environment found, VENV_PATH=${VENV_PATH}")
    else()
        find_program(PYTHON_PROGRAM NAMES python3 python HINTS "$ENV{LOCALAPPDATA}\\Continuum\\anaconda3" REQUIRED)
        message("PYTHON_PROGRAM=${PYTHON_PROGRAM}")
        execute_process(COMMAND "${PYTHON_PROGRAM}" -m venv .venv WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
        if(IS_DIRECTORY ${VENV_PATH})
            message("python virtual environment created, VENV_PATH=${VENV_PATH}")
        else()
            message(FATAL_ERROR "python virtual environment not found, VENV_PATH=${VENV_PATH}")
        endif()
    endif()
    if(WIN32)
        set(VENV_ACTIVATE_CMD "${VENV_PATH}/Scripts/activate")
    else()
        set(VENV_ACTIVATE_CMD "source ${VENV_PATH}/bin/activate")
    endif()
endmacro()

# run shell command
macro(cpf_run_shell_command SHELL_CMD SHELL_WORKING_DIRECTORY)
    message("SHELL_CMD=${SHELL_CMD}")
    message("SHELL_WORKING_DIRECTORY=${SHELL_WORKING_DIRECTORY}")
    if(WIN32)
        execute_process(COMMAND CMD /c "${SHELL_CMD}" WORKING_DIRECTORY ${SHELL_WORKING_DIRECTORY})
    else()
        execute_process(COMMAND bash -c "${SHELL_CMD}" WORKING_DIRECTORY ${SHELL_WORKING_DIRECTORY})
    endif()
endmacro()

# run command in virtual environment
macro(cpf_run_venv_command VENV_CMD SHELL_WORKING_DIRECTORY)
    cpf_run_shell_command("${VENV_ACTIVATE_CMD} && ${VENV_CMD}" "${SHELL_WORKING_DIRECTORY}")
endmacro()

# install conan dependencies
macro(cpf_install_conan_dependencies)
    cpf_run_venv_command("pip install -U conan && conan install conanfile.txt -b missing -s build_type=${DETECTED_BUILD_TYPE} -if ${DETECTED_BUILD_FOLDER}" ${CMAKE_CURRENT_SOURCE_DIR})
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

# install c++ project framework files
macro(cpf_install_cpp_project_framework_files)
    cpf_get_variable_by_build_type(CONAN_RES_DIRS_CPP_PROJECT_FRAMEWORK)
    set(CONAN_RES_DIRS_CPP_PROJECT_FRAMEWORK ${CPF_GET_VARIABLE})
    message("CONAN_RES_DIRS_CPP_PROJECT_FRAMEWORK=${CONAN_RES_DIRS_CPP_PROJECT_FRAMEWORK}")
    if(CONAN_RES_DIRS_CPP_PROJECT_FRAMEWORK)
        file(INSTALL
            ${CONAN_RES_DIRS_CPP_PROJECT_FRAMEWORK}/cpp_project_framework_callables.cmake
            ${CONAN_RES_DIRS_CPP_PROJECT_FRAMEWORK}/cpp_project_framework.cmake
            ${CONAN_RES_DIRS_CPP_PROJECT_FRAMEWORK}/make.bat
            ${CONAN_RES_DIRS_CPP_PROJECT_FRAMEWORK}/Makefile
            DESTINATION ${CMAKE_SOURCE_DIR}
            )
    else()
        message("CONAN_RES_DIRS_CPP_PROJECT_FRAMEWORK not found")
    endif()
endmacro()

# set project type
macro(cpf_set_project_type PROJECT_TYPE_ARG)
    message("PROJECT_TYPE_ARG=${PROJECT_TYPE_ARG}")
    set(PROJECT_TYPE ${PROJECT_TYPE_ARG})

    if(PROJECT_TYPE STREQUAL "LIB")
        set(IS_LIB TRUE)
    elseif(PROJECT_TYPE STREQUAL "EXE")
        set(IS_EXE TRUE)
    elseif(PROJECT_TYPE STREQUAL "HEADER_ONLY")
        set(IS_HEADER_ONLY TRUE)
    endif()

    set(SUPPORTED_PROJECT_TYPES "LIB" "EXE" "HEADER_ONLY")
    if(PROJECT_TYPE)
        if(NOT PROJECT_TYPE IN_LIST SUPPORTED_PROJECT_TYPES)
            message(WARNING "PROJECT_TYPE (${PROJECT_TYPE}) should be in one of the SUPPORTED_PROJECT_TYPES (${SUPPORTED_PROJECT_TYPES})")
            set(PROJECT_TYPE "")
        endif()
    endif()

    if(NOT PROJECT_TYPE)
        if(IS_LIB)
            set(PROJECT_TYPE "LIB")
        elseif(IS_EXE)
            set(PROJECT_TYPE "EXE")
        else()
            set(PROJECT_TYPE "HEADER_ONLY")
            set(IS_HEADER_ONLY TRUE)
        endif()
    endif()

    message("PROJECT_TYPE=${PROJECT_TYPE}")
    message("IS_LIB=${IS_LIB}")
    message("IS_EXE=${IS_EXE}")
    message("IS_HEADER_ONLY=${IS_HEADER_ONLY}")
endmacro()

# find all header files
macro(cpf_find_all_header_files)
    if(NOT HEADER_FILES)
        file(GLOB HEADER_FILES *.h *.hpp *.hxx)
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

# add gcov compiler flags
macro(cpf_add_gcov_compiler_flags)
    if(UNIX)
        set(GCOV_COMPILER_FLAGS "--coverage")
        set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} ${GCOV_COMPILER_FLAGS}")
    endif()
endmacro()

# build and execute unit test (make test)
macro(cpf_add_unit_tests LINK_TYPES)
    enable_testing()

    set(SUPPORTED_LINK_TYPES static shared)
    message("LINK_TYPES=${LINK_TYPES}")
    message("SUPPORTED_LINK_TYPES=${SUPPORTED_LINK_TYPES}")

    if(NOT TEST_UNITS)
        file(GLOB_RECURSE TEST_UNIT_FILES RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" *.test.cpp)
        foreach(TEST_UNIT_FILE ${TEST_UNIT_FILES})
            if(TEST_UNIT_FILE MATCHES "^(.+)\.test\.cpp$")
                list(APPEND TEST_UNITS ${CMAKE_MATCH_1})
            endif()
        endforeach()
    endif()
    message("TEST_UNITS=${TEST_UNITS}")

    foreach(TEST_UNIT ${TEST_UNITS})
        string(REPLACE "/" "." UNIT_TEST_NAME "${TEST_UNIT}")
        set(TEST_SRC_FILES ${TEST_UNIT}.test.cpp)
        if(IS_EXE)
            list(APPEND TEST_SRC_FILES ${SRC_FILES})
            list(REMOVE_ITEM TEST_SRC_FILES ${PROJECT_NAME}.cpp)
        endif()
        message("    TEST_SRC_FILES=${TEST_SRC_FILES}")

        set(UNIT_TEST_EXE )
        foreach(LINK_TYPE ${LINK_TYPES})
            if(TARGET ${LINK_TYPE}_lib)
                set(UNIT_TEST_EXE ${UNIT_TEST_NAME}.${LINK_TYPE}.test)
                message("        UNIT_TEST_EXE=${UNIT_TEST_EXE}")
                add_executable(${UNIT_TEST_EXE} ${TEST_SRC_FILES})
                if(WIN32)
                    if(LINK_TYPE STREQUAL "shared")
                        add_dependencies(${UNIT_TEST_EXE} static_lib)
                    endif()
                endif()
                target_include_directories(${UNIT_TEST_EXE} PRIVATE "${CMAKE_SOURCE_DIR}")
                target_link_libraries(${UNIT_TEST_EXE} ${LINK_TYPE}_lib)
                conan_target_link_libraries(${UNIT_TEST_EXE})
                add_test(NAME ${UNIT_TEST_EXE} COMMAND ${UNIT_TEST_EXE})
                list(APPEND UNIT_TEST_EXE_LIST ${UNIT_TEST_EXE})
            endif()
        endforeach()
        if(NOT UNIT_TEST_EXE)
            set(UNIT_TEST_EXE ${UNIT_TEST_NAME}.test)
            message("        UNIT_TEST_EXE=${UNIT_TEST_EXE}")
            add_executable(${UNIT_TEST_EXE} ${TEST_SRC_FILES})
            target_include_directories(${UNIT_TEST_EXE} PRIVATE "${CMAKE_SOURCE_DIR}")
            conan_target_link_libraries(${UNIT_TEST_EXE})
            add_test(NAME ${UNIT_TEST_EXE} COMMAND ${UNIT_TEST_EXE})
            list(APPEND UNIT_TEST_EXE_LIST ${UNIT_TEST_EXE})
        endif()
    endforeach()
    message("UNIT_TEST_EXE_LIST=${UNIT_TEST_EXE_LIST}")

    cpf_add_unit_test_coverage_target()
endmacro()

# add unit test code coverage target
macro(cpf_add_unit_test_coverage_target)
    set(COVERAGE_TARGET coverage)
    set(COVERAGE_TARGET_DIR ${CMAKE_CURRENT_BINARY_DIR}/${COVERAGE_TARGET})
    message("COVERAGE_TARGET=${COVERAGE_TARGET}")
    message("COVERAGE_TARGET_DIR=${COVERAGE_TARGET_DIR}")
    if(GCOV_COMPILER_FLAGS)
        add_custom_target(${COVERAGE_TARGET} COMMAND mkdir -p ${COVERAGE_TARGET} COMMAND ${CMAKE_MAKE_PROGRAM} test WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})

        set(GCOVR_REPORT_NAME "CoverageReport")
        set(GCOVR_ACTIVATE_CMD "${VENV_ACTIVATE_CMD} && pip install -U gcovr")
        set(GCOVR_GENERATE_CMD "gcovr -r ${CMAKE_CURRENT_SOURCE_DIR} --object-directory ${CMAKE_CURRENT_BINARY_DIR}")
        set(GCOVR_GENERATE_TEXT_CMD "${GCOVR_GENERATE_CMD} -o ${GCOVR_REPORT_NAME}.txt")
        set(GCOVR_GENERATE_HTML_CMD "${GCOVR_GENERATE_CMD} --html-details ${GCOVR_REPORT_NAME}.html")
        set(GCOVR_GENERATE_TEXT_AND_HTML_CMD "${GCOVR_GENERATE_TEXT_CMD} && ${GCOVR_GENERATE_HTML_CMD}")

        if(WIN32)
            set(GET_GCOVR_REPORT_DIR_CMD "python -c \"from datetime import datetime; print(datetime.now().strftime(\\\"${GCOVR_REPORT_NAME}-%%Y-%%m-%%d-%%Hh%%Mm%%Ss\\\"))\"")
            set(GCOVR_GENERATED_MSG_CMD "ECHO Coverage generated in Folder %%I && echo Coverage Text Report: %%I\\CoverageReport.txt && echo Coverage HTML Report: %%I\\CoverageReport.html")
            set(GCOVR_GENERATE_REPORT_CMD "${GCOVR_ACTIVATE_CMD} && FOR /F \"tokens=*\" %%I IN ('${GET_GCOVR_REPORT_DIR_CMD}') DO (MKDIR \"%%I\" && CD \"%%I\" && ${GCOVR_GENERATE_TEXT_AND_HTML_CMD} && ${GCOVR_GENERATED_MSG_CMD})")
            add_custom_command(TARGET ${COVERAGE_TARGET} COMMAND CMD /c "${GCOVR_GENERATE_REPORT_CMD}" WORKING_DIRECTORY ${COVERAGE_TARGET_DIR})
        else()
            set(GET_GCOVR_REPORT_DIR_CMD "python -c \"from datetime import datetime; print(datetime.now().strftime(\\\"${GCOVR_REPORT_NAME}-%Y-%m-%d-%Hh%Mm%Ss\\\"))\"")
            set(GCOVR_GENERATED_MSG_CMD "echo Coverage generated in Folder `pwd` && echo Coverage Text Report: `pwd`/CoverageReport.txt && echo Coverage HTML Report: `pwd`/CoverageReport.html")
            set(GCOVR_GENERATE_REPORT_CMD "${GCOVR_ACTIVATE_CMD} && mkdir -p `${GET_GCOVR_REPORT_DIR_CMD}` && cd $_ && ${GCOVR_GENERATE_TEXT_AND_HTML_CMD} && ${GCOVR_GENERATED_MSG_CMD}")
            add_custom_command(TARGET ${COVERAGE_TARGET} COMMAND bash -c "${GCOVR_GENERATE_REPORT_CMD}" WORKING_DIRECTORY ${COVERAGE_TARGET_DIR} VERBATIM)
        endif()

        message("GCOVR_REPORT_NAME=${GCOVR_REPORT_NAME}")
        message("GCOVR_GENERATE_CMD=${GCOVR_GENERATE_CMD}")
        message("GCOVR_GENERATE_TEXT_CMD=${GCOVR_GENERATE_TEXT_CMD}")
        message("GCOVR_GENERATE_HTML_CMD=${GCOVR_GENERATE_HTML_CMD}")
        message("GCOVR_GENERATE_TEXT_AND_HTML_CMD=${GCOVR_GENERATE_TEXT_AND_HTML_CMD}")
        message("GET_GCOVR_REPORT_DIR_CMD=${GET_GCOVR_REPORT_DIR_CMD}")
        message("GCOVR_GENERATED_MSG_CMD=${GCOVR_GENERATED_MSG_CMD}")
        message("GCOVR_GENERATE_REPORT_CMD=${GCOVR_GENERATE_REPORT_CMD}")

        add_dependencies(${COVERAGE_TARGET} ${UNIT_TEST_EXE})
    elseif(WIN32)
        find_program(OPEN_CPP_COVERAGE_PROGRAM NAMES OpenCppCoverage OpenCppCoverage.exe HINTS "$ENV{PROGRAMFILES}" "$ENV{PROGRAMFILES\(X86\)}")
        if(OPEN_CPP_COVERAGE_PROGRAM STREQUAL "OPEN_CPP_COVERAGE_PROGRAM-NOTFOUND")
            set(OPEN_CPP_COVERAGE_VERSION "0.9.9.0")
            if ("$ENV{PROGRAMFILES\(X86\)}" STREQUAL "")
                set(OPEN_CPP_COVERAGE_PLATFORM "x86")
            else()
                set(OPEN_CPP_COVERAGE_PLATFORM "x64")
            endif()
            set(OPEN_CPP_COVERAGE_INSTALLER_URL "https://github.com/OpenCppCoverage/OpenCppCoverage/releases/download/release-${OPEN_CPP_COVERAGE_VERSION}/OpenCppCoverageSetup-${OPEN_CPP_COVERAGE_PLATFORM}-${OPEN_CPP_COVERAGE_VERSION}.exe")
            set(OPEN_CPP_COVERAGE_INSTALLER "${CMAKE_CURRENT_BINARY_DIR}/OpenCppCoverageSetup.exe")

            message("ENV{PROGRAMFILES(X86)}=$ENV{PROGRAMFILES\(X86\)}")
            message("OPEN_CPP_COVERAGE_VERSION=${OPEN_CPP_COVERAGE_VERSION}")
            message("OPEN_CPP_COVERAGE_PLATFORM=${OPEN_CPP_COVERAGE_PLATFORM}")
            message("OPEN_CPP_COVERAGE_INSTALLER_URL=${OPEN_CPP_COVERAGE_INSTALLER_URL}")
            message("OPEN_CPP_COVERAGE_INSTALLER=${OPEN_CPP_COVERAGE_INSTALLER}")

            file(DOWNLOAD "${OPEN_CPP_COVERAGE_INSTALLER_URL}" "${OPEN_CPP_COVERAGE_INSTALLER}" SHOW_PROGRESS)
            execute_process(COMMAND ${OPEN_CPP_COVERAGE_INSTALLER})
            find_program(OPEN_CPP_COVERAGE_PROGRAM NAMES OpenCppCoverage OpenCppCoverage.exe HINTS "$ENV{PROGRAMFILES}\\OpenCppCoverage" "$ENV{PROGRAMFILES\(X86\)}\\OpenCppCoverage")
        endif()
        message("OPEN_CPP_COVERAGE_PROGRAM=${OPEN_CPP_COVERAGE_PROGRAM}")
        if(OPEN_CPP_COVERAGE_PROGRAM STREQUAL "OPEN_CPP_COVERAGE_PROGRAM-NOTFOUND")
            message("OPEN_CPP_COVERAGE_PROGRAM not found")
        else()
            file(TO_NATIVE_PATH "${CMAKE_CURRENT_SOURCE_DIR}" NATIVE_CURRENT_SOURCE_DIR)
            file(TO_NATIVE_PATH "${COVERAGE_TARGET_DIR}" NATIVE_COVERAGE_TARGET_DIR)
            message("NATIVE_CURRENT_SOURCE_DIR=${NATIVE_CURRENT_SOURCE_DIR}")
            message("NATIVE_COVERAGE_TARGET_DIR=${NATIVE_COVERAGE_TARGET_DIR}")
            add_custom_target(${COVERAGE_TARGET} COMMAND MKDIR ${COVERAGE_TARGET} || (EXIT 0) WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})

            set(UNIT_TEST_EXE_DIR "${CMAKE_CURRENT_BINARY_DIR}/${DETECTED_BUILD_TYPE}")
            foreach(UNIT_TEST_EXE ${UNIT_TEST_EXE_LIST})
                file(TO_NATIVE_PATH "${UNIT_TEST_EXE_DIR}" NATIVE_UNIT_TEST_EXE_DIR)
                file(TO_NATIVE_PATH "${UNIT_TEST_EXE_DIR}/${UNIT_TEST_EXE}" NATIVE_UNIT_TEST_EXE_PATH)
                message("UNIT_TEST_EXE=${UNIT_TEST_EXE}")
                message("UNIT_TEST_EXE_DIR=${UNIT_TEST_EXE_DIR}")
                message("NATIVE_UNIT_TEST_EXE_DIR=${NATIVE_UNIT_TEST_EXE_DIR}")
                message("NATIVE_UNIT_TEST_EXE_PATH=${NATIVE_UNIT_TEST_EXE_PATH}")
                add_custom_command(TARGET ${COVERAGE_TARGET}
                    COMMAND "${OPEN_CPP_COVERAGE_PROGRAM}" --sources "${NATIVE_CURRENT_SOURCE_DIR}" -- "${NATIVE_UNIT_TEST_EXE_PATH}" --working_dir "${NATIVE_UNIT_TEST_EXE_DIR}" --export_type html:"${NATIVE_COVERAGE_TARGET_DIR}"
                    COMMAND ECHO Coverage Results: ${NATIVE_COVERAGE_TARGET_DIR}\\LastCoverageResults.log
                    WORKING_DIRECTORY ${COVERAGE_TARGET_DIR} VERBATIM)
                add_custom_command(TARGET ${COVERAGE_TARGET} COMMAND CMD /c "FOR /F \"tokens=*\" %%I IN ('FINDSTR /C:\"Coverage generated in Folder\" \"${NATIVE_COVERAGE_TARGET_DIR}\\LastCoverageResults.log\"') DO @ECHO %%I\\index.html" WORKING_DIRECTORY ${COVERAGE_TARGET_DIR})
            endforeach()
        endif()
    endif()
endmacro()

# add doxygen target
macro(cpf_add_doxygen_target)
    cpf_get_variable_by_build_type(CONAN_BIN_DIRS_DOXYGEN)
    set(CONAN_BIN_DIRS_DOXYGEN ${CPF_GET_VARIABLE})
    message("CONAN_BIN_DIRS_DOXYGEN=${CONAN_BIN_DIRS_DOXYGEN}")

    find_program(DOXYGEN_PROGRAM NAMES doxygen doxygen.exe HINTS "${CONAN_BIN_DIRS_DOXYGEN}")
    if(DOXYGEN_PROGRAM STREQUAL "DOXYGEN_PROGRAM-NOTFOUND")
        message(WARNING "DOXYGEN_PROGRAM not found")
    else()
        message("DOXYGEN_PROGRAM=${DOXYGEN_PROGRAM}")

        file(RELATIVE_PATH RELATIVE_CURRENT_SOURCE_DIR "${CMAKE_SOURCE_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}")

        set(PARSE_DOXYFILE_SNIPPET "{k.strip(): v.strip() for k, v in (l.split('=', 1) for l in open('Doxyfile') if not l.startswith('#') and ' =' in l)}")
        set(PRINT_DOXYGEN_HTML_PATH_CMD "python -c \"from pathlib import Path; print('HTML Source Code Documentation: ' + Path(${PARSE_DOXYFILE_SNIPPET}.get('OUTPUT_DIRECTORY'), 'html/index.html').absolute().as_posix())\"")

        set(READ_DOXYFILE_LINES_SNIPPET "lines = [l.split('=', 1) if not l.startswith('#') and ' =' in l else l for l in open('Doxyfile')];")
        set(GET_DOXYFILE_KEY_VALUES_SNIPPET "kvs = {k.strip(): v.strip() for k, v in (l for l in lines if type(l) is list)};")
        set(SET_DOXYFILE_VALUES_SNIPPET "${SET_DOXYFILE_VALUES_SNIPPET} kvs['PROJECT_NAME'] = '\\\"${CMAKE_PROJECT_NAME}\\\"';")
        set(SET_DOXYFILE_VALUES_SNIPPET "${SET_DOXYFILE_VALUES_SNIPPET} kvs['PROJECT_NUMBER'] = '${CMAKE_PROJECT_VERSION}';")
        set(SET_DOXYFILE_VALUES_SNIPPET "${SET_DOXYFILE_VALUES_SNIPPET} kvs['PROJECT_BRIEF'] = '\\\"${CMAKE_PROJECT_DESCRIPTION}\\\"';")
        set(SET_DOXYFILE_VALUES_SNIPPET "${SET_DOXYFILE_VALUES_SNIPPET} kvs['OUTPUT_DIRECTORY'] = 'doxygen';")
        if(EXISTS "${CMAKE_SOURCE_DIR}/README.md")
            set(SET_DOXYFILE_VALUES_SNIPPET "${SET_DOXYFILE_VALUES_SNIPPET} kvs['INPUT'] = 'README.md ${RELATIVE_CURRENT_SOURCE_DIR}';")
            set(SET_DOXYFILE_VALUES_SNIPPET "${SET_DOXYFILE_VALUES_SNIPPET} kvs['USE_MDFILE_AS_MAINPAGE'] = 'README.md';")
        else()
            set(SET_DOXYFILE_VALUES_SNIPPET "${SET_DOXYFILE_VALUES_SNIPPET} kvs['INPUT'] = '${RELATIVE_CURRENT_SOURCE_DIR}';")
            set(SET_DOXYFILE_VALUES_SNIPPET "${SET_DOXYFILE_VALUES_SNIPPET} kvs['USE_MDFILE_AS_MAINPAGE'] = '';")
        endif()
        set(SET_DOXYFILE_VALUES_SNIPPET "${SET_DOXYFILE_VALUES_SNIPPET} kvs['GENERATE_TREEVIEW'] = 'YES';")
        set(SET_DOXYFILE_VALUES_SNIPPET "${SET_DOXYFILE_VALUES_SNIPPET} kvs['GENERATE_LATEX'] = 'NO';")
        set(SET_DOXYFILE_VALUES_SNIPPET "${SET_DOXYFILE_VALUES_SNIPPET} kvs['EXTRACT_ANON_NSPACES'] = 'YES';")
        set(WRITE_DOXYFILE_LINES_SNIPPET "f = open('Doxyfile', 'w'); r = [f.write(l[0] + '=' + (l[1] if kvs.get(l[0].strip()) is None else (' ' + kvs.get(l[0].strip()) if kvs.get(l[0].strip()).strip() else '') + '\\n') if type(l) is list else l) for l in lines]; f.close();")
        set(UPDATE_DOXYFILE_CMD "python -c \"${READ_DOXYFILE_LINES_SNIPPET} ${GET_DOXYFILE_KEY_VALUES_SNIPPET} ${SET_DOXYFILE_VALUES_SNIPPET} ${WRITE_DOXYFILE_LINES_SNIPPET}\"")

        add_custom_target(doxygen_create_config COMMAND "${DOXYGEN_PROGRAM}" -g WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
        add_custom_target(doxygen COMMAND "${DOXYGEN_PROGRAM}" WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
        if(WIN32)
            add_custom_command(TARGET doxygen_create_config COMMAND CMD /c "${VENV_ACTIVATE_CMD} ^&^& ${UPDATE_DOXYFILE_CMD}" WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
            add_custom_command(TARGET doxygen COMMAND CMD /c "${VENV_ACTIVATE_CMD} ^&^& ${PRINT_DOXYGEN_HTML_PATH_CMD}" WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
        else()
            add_custom_command(TARGET doxygen_create_config COMMAND bash -c "${VENV_ACTIVATE_CMD} && ${UPDATE_DOXYFILE_CMD}" WORKING_DIRECTORY ${CMAKE_SOURCE_DIR} VERBATIM)
            add_custom_command(TARGET doxygen COMMAND bash -c "${VENV_ACTIVATE_CMD} && ${PRINT_DOXYGEN_HTML_PATH_CMD}" WORKING_DIRECTORY ${CMAKE_SOURCE_DIR} VERBATIM)
        endif()
    endif()
endmacro()

# build and execute benchmark test (make benchmark)
macro(cpf_add_benchmarks LINK_TYPES)
    set(SUPPORTED_LINK_TYPES static shared)
    if(NOT BENCHMARKS_DIR)
        set(BENCHMARKS_DIR "${CMAKE_SOURCE_DIR}/tests/benchmarks")
    endif()
    message("LINK_TYPES=${LINK_TYPES}")
    message("SUPPORTED_LINK_TYPES=${SUPPORTED_LINK_TYPES}")
    message("BENCHMARKS_DIR=${BENCHMARKS_DIR}")

    if(NOT BENCHMARKS)
        file(GLOB_RECURSE BENCHMARK_FILES RELATIVE "${BENCHMARKS_DIR}" "${BENCHMARKS_DIR}/*.benchmark.cpp")
        message("    BENCHMARK_FILES=${BENCHMARK_FILES}")
        foreach(BENCHMARK_FILE ${BENCHMARK_FILES})
            if(BENCHMARK_FILE MATCHES "^(.+)\.benchmark\.cpp$")
                list(APPEND BENCHMARKS ${CMAKE_MATCH_1})
            endif()
        endforeach()
    endif()
    message("BENCHMARKS=${BENCHMARKS}")

    foreach(BENCHMARK ${BENCHMARKS})
        string(REPLACE "/" "." BENCHMARK_NAME "${BENCHMARK}")
        set(BENCHMARK_FILE "${BENCHMARKS_DIR}/${BENCHMARK}.benchmark.cpp")
        get_filename_component(BENCHMARK_SRC_DIR "${BENCHMARK_FILE}" DIRECTORY)
        file(GLOB BENCHMARK_SRC_FILES "${BENCHMARK_SRC_DIR}/*.cpp")
        message("    BENCHMARK_SRC_DIR=${BENCHMARK_SRC_DIR}")
        message("    BENCHMARK_SRC_FILES=${BENCHMARK_SRC_FILES}")

        set(BENCHMARK_EXE )
        foreach(LINK_TYPE ${LINK_TYPES})
            if(TARGET ${LINK_TYPE}_lib)
                set(BENCHMARK_EXE ${BENCHMARK_NAME}.${LINK_TYPE}.benchmark)
                message("        BENCHMARK_EXE=${BENCHMARK_EXE}")
                add_executable(${BENCHMARK_EXE} ${BENCHMARK_SRC_FILES})
                target_include_directories(${BENCHMARK_EXE} PRIVATE ${CMAKE_SOURCE_DIR})
                if(WIN32)
                    if(LINK_TYPE STREQUAL "shared")
                        add_dependencies(${BENCHMARK_EXE} static_lib)
                    endif()
                endif()
                target_link_libraries(${BENCHMARK_EXE} ${LINK_TYPE}_lib)
                conan_target_link_libraries(${BENCHMARK_EXE})
                list(APPEND BENCHMARK_EXE_LIST ${BENCHMARK_EXE})
            endif()
        endforeach()
        if(NOT BENCHMARK_EXE)
            set(BENCHMARK_EXE ${BENCHMARK_NAME}.benchmark)
            message("        BENCHMARK_EXE=${BENCHMARK_EXE}")
            add_executable(${BENCHMARK_EXE} ${BENCHMARK_SRC_FILES})
            target_include_directories(${BENCHMARK_EXE} PRIVATE ${CMAKE_SOURCE_DIR})
            conan_target_link_libraries(${BENCHMARK_EXE})
            list(APPEND BENCHMARK_EXE_LIST ${BENCHMARK_EXE})
        endif()
    endforeach()
    message("BENCHMARK_EXE_LIST=${BENCHMARK_EXE_LIST}")
endmacro()
