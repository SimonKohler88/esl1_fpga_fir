cmake_minimum_required(VERSION 3.20)
project(MyVHDLProject NONE)

# Ordner mit VHDL-Dateien
set(VHDL_DIR "${CMAKE_SOURCE_DIR}/quartus_proj/vhdl")

set(GHDL_FLAGS -fsynopsys --std=08)

# WICHTIG: GHDL schlägt fehl, wenn eine Datei analysiert wird in der Entities verwendet werden,
# die noch nicht eingelesen wurden.
# Benutzerdefinierte Reihenfolge (Dateinamen ohne Pfad)
set(SORT_ORDER
        "ime_vga_audio_pll.vhd",
        "fir_types.vhdl"
)


# Alle VHDL-Dateien im src-Ordner finden
file(GLOB ALL_VHDL_FILES
        "${VHDL_DIR}/*.vhdl"
        "${VHDL_DIR}/*.vhd"
)

# Listen für sortierte Dateien
set(VHDL_SOURCES_ORDERED "")
set(VHDL_REMAINING_FILES "")

# Dateien nach der Reihenfolge in SORT_ORDER einfügen
foreach(name ${SORT_ORDER})
    foreach(file ${ALL_VHDL_FILES})
        get_filename_component(fname ${file} NAME)
        if(fname STREQUAL ${name})
            list(APPEND VHDL_SOURCES_ORDERED ${file})
        endif()
    endforeach()
endforeach()

# Alle übrigen Dateien hinten anhängen
foreach(file ${ALL_VHDL_FILES})
    list(FIND VHDL_SOURCES_ORDERED ${file} index)
    if(index EQUAL -1)
        list(APPEND VHDL_SOURCES_ORDERED ${file})
    endif()
endforeach()

# Listen für normale VHDL-Dateien und Testbenches
set(VHDL_SOURCES "")
set(VHDL_TESTBENCHES "")

foreach(file ${VHDL_SOURCES_ORDERED})
    get_filename_component(fname ${file} NAME)
    if(fname MATCHES ".*tb\\.(vhdl|vhd)$")
        list(APPEND VHDL_TESTBENCHES ${file})
    else()
        list(APPEND VHDL_SOURCES ${file})
    endif()
endforeach()

message(STATUS "VHDL Sources: ${VHDL_SOURCES}")
message(STATUS "VHDL Testbenches: ${VHDL_TESTBENCHES}")

# Allgemeines Target für Analyse aller Dateien
add_custom_target(ghdl_analyze_all
        COMMAND ghdl -a ${GHDL_FLAGS} ${VHDL_SOURCES} ${VHDL_TESTBENCHES}
        WORKING_DIRECTORY ${VHDL_DIR}
        COMMENT "Analysiere alle VHDL-Dateien"
)


# Für jede Testbench ein eigenes Target
foreach(tb ${VHDL_TESTBENCHES})
    get_filename_component(tb_name ${tb} NAME_WE)  # Name ohne Extension

    # Elaborieren
    add_custom_target(ghdl_elab_${tb_name}
            COMMAND ghdl -e ${GHDL_FLAGS} ${tb_name}
            DEPENDS ghdl_analyze_all
            WORKING_DIRECTORY ${VHDL_DIR}
            COMMENT "Elaboriere Testbench ${tb_name}"
    )

    # Simulation
    add_custom_target(ghdl_run_${tb_name}
            COMMAND ghdl -r ${GHDL_FLAGS} ${tb_name} --vcd=${tb_name}.vcd
            DEPENDS ghdl_elab_${tb_name}
            WORKING_DIRECTORY ${VHDL_DIR}
            COMMENT "Simuliere Testbench ${tb_name} und erzeuge ${tb_name}.vcd"
    )
endforeach()