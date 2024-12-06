# Set the project root directory
set( PROJECT_ROOT_DIR "${CMAKE_CURRENT_LIST_DIR}/../" )

# Is this not clang? NOTE: Do a architecture check as well for the arches
# from LLVM-MINGW as a safety check
if(NOT CMAKE_CXX_COMPILER_ID MATCHES "Clang")
	message( FATAL_ERROR "Clang is required to build this project." )
else()
        # Build flags for the final shellcode
        set( CMAKE_SHELLCODE_C_FLAGS -Os -fno-asynchronous-unwind-tables -fuse-ld=bfd -fno-exceptions -fno-unwind-tables )
	set( CMAKE_SHELLCODE_C_FLAGS "${CMAKE_SHELLCODE_C_FLAGS}" -fPIC -fno-ident -fpack-struct=8 -falign-functions=1 )
        set( CMAKE_SHELLCODE_C_FLAGS "${CMAKE_SHELLCODE_C_FLAGS}" -s -ffunction-sections -falign-jumps=1 -w )
        set( CMAKE_SHELLCODE_C_FLAGS "${CMAKE_SHELLCODE_C_FLAGS}" -falign-labels=1 -fdata-sections -mno-sse )
        set( CMAKE_SHELLCODE_C_FLAGS "${CMAKE_SHELLCODE_C_FLAGS}" -fms-extensions -fno-jump-tables -mno-stack-arg-probe )

        # Add the compile flags
        add_compile_options( ${CMAKE_SHELLCODE_C_FLAGS} )
endif()

# Builds an object file using the 
function(add_bof_executable tgt)
	# Create an object we can use to merge them together
	add_library(${tgt} ${ARGN})

	# Disable install of the library
	set_target_properties(${tgt} PROPERTIES INSTALL_EXCLUDE_FROM_ALL TRUE)

	# Changes the name of the library
	set_target_properties(${tgt} PROPERTIES PREFIX "")
	set_target_properties(${tgt} PROPERTIES SUFFIX ".lib")

	# Create the target name
	set(TARGET_BASE_NAME "$<TARGET_FILE_DIR:${tgt}>/$<TARGET_FILE_BASE_NAME:${tgt}>")

	# Create a custom object file target that merges all the objects together
	if ( "${CMAKE_SIZEOF_VOID_P}" STREQUAL "8" )
		# x86_64 download and extract
		add_custom_command(TARGET ${tgt}
			POST_BUILD
			USES_TERMINAL
			COMMENT "Downloading the GNU LD linker from musl.cc"
			COMMAND ${CMAKE_COMMAND} -E env bash -c "wget -q -O - https://musl.cc/x86_64-w64-mingw32-cross.tgz | tar -zxf - x86_64-w64-mingw32-cross/bin/x86_64-w64-mingw32-ld.bfd --strip-components=2" 
			VERBATIM
		)

		# x86_64 linker
		add_custom_target( ${tgt}.obj ALL
			USES_TERMINAL
			BYPRODUCTS ${tgt}.obj
			COMMAND "$<TARGET_FILE_DIR:${tgt}>/x86_64-w64-mingw32-ld.bfd" -r "$<TARGET_OBJECTS:${tgt}>" -o "${TARGET_BASE_NAME}.obj"
			DEPENDS ${tgt}
			COMMAND_EXPAND_LISTS
			VERBATIM
		)
	else()
		# x86 download and extract
		add_custom_command(TARGET ${tgt}
			POST_BUILD
			USES_TERMINAL
			COMMENT "Downloading the GNU LD linker from musl.cc"
			COMMAND ${CMAKE_COMMAND} -E env bash -c "wget -q -O - https://musl.cc/i686-w64-mingw32-cross.tgz | tar -zxf - i686-w64-mingw32-cross/i686-w64-mingw32-ld.bfd --strip-components=2"
			VERBATIM
		)

		# x86 linker
		add_custom_target( ${tgt}.obj ALL
			USES_TERMINAL
			BYPRODUCTS ${tgt}.obj
			COMMAND "$<TARGET_FILE_DIR:${tgt}>/i686-w64-mingw32-ld.bfd" -r "$<TARGET_OBJECTS:${tgt}>" -o "${TARGET_BASE_NAME}.obj"
			DEPENDS ${tgt}
			COMMAND_EXPAND_LISTS
			VERBATIM
		)
	endif()

	# Install into the appropriate directories
	if ( "${CMAKE_SIZEOF_VOID_P}" STREQUAL "8" ) 
		install( FILES ${TARGET_BASE_NAME}.obj DESTINATION "${CMAKE_INSTALL_PREFIX}" RENAME "$<TARGET_FILE_BASE_NAME:${tgt}>.x64.obj" )
	else()
		install( FILES ${TARGET_BASE_NAME}.obj DESTINATION "${CMAKE_INSTALL_PREFIX}" RENAME "$<TARGET_FILE_BASE_NAME:${tgt}>.x86.obj" )
	endif()
endfunction()
