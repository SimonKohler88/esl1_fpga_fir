# Copyright (C) 2023  Intel Corporation. All rights reserved.
# Your use of Intel Corporation's design tools, logic functions 
# and other software and tools, and any partner logic 
# functions, and any output files from any of the foregoing 
# (including device programming or simulation files), and any 
# associated documentation or information are expressly subject 
# to the terms and conditions of the Intel Program License 
# Subscription Agreement, the Intel Quartus Prime License Agreement,
# the Intel FPGA IP License Agreement, or other applicable license
# agreement, including, without limitation, that your use is for
# the sole purpose of programming logic devices manufactured by
# Intel and sold by Intel or its authorized distributors.  Please
# refer to the applicable agreement for further details, at
# https://fpgasoftware.intel.com/eula.

# Quartus Prime: Generate Tcl File for Project
# File: test_board.tcl
# Generated on: Fri Feb  2 13:55:54 2024

# Load Quartus Prime Tcl Project package
package require ::quartus::project

set need_to_close_project 0
set make_assignments 1

# Check that the right project is open
if {[is_project_open]} {
	if {[string compare $quartus(project) "test_board"]} {
		puts "Project test_board is not open"
		set make_assignments 0
	}
} else {
	# Only open if not already open
	if {[project_exists test_board]} {
		project_open -revision test_board test_board
	} else {
		project_new -revision test_board test_board
	}
	set need_to_close_project 1
}

# Make assignments
if {$make_assignments} {
# #TE_MOD# 	set_global_assignment -name FAMILY "MAX 10" 
# #TE_MOD# 	set_global_assignment -name DEVICE 10M08SAU169C8G 
	set_global_assignment -name ORIGINAL_QUARTUS_VERSION 18.1.0
	set_global_assignment -name PROJECT_CREATION_TIME_DATE "11:47:22  MARCH 18, 2019"
	set_global_assignment -name LAST_QUARTUS_VERSION "22.1std.2 Lite Edition"
	set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
	set_global_assignment -name DEVICE_FILTER_PACKAGE UFBGA
	set_global_assignment -name ERROR_CHECK_FREQUENCY_DIVISOR 256
	set_global_assignment -name ENABLE_OCT_DONE OFF
	set_global_assignment -name USE_CONFIGURATION_DEVICE OFF
	set_global_assignment -name CRC_ERROR_OPEN_DRAIN OFF
	set_global_assignment -name STRATIX_DEVICE_IO_STANDARD "3.3-V LVTTL"
	set_global_assignment -name PROJECT_IP_REGENERATION_POLICY ALWAYS_REGENERATE_IP
	set_global_assignment -name POWER_PRESET_COOLING_SOLUTION "23 MM HEAT SINK WITH 200 LFPM AIRFLOW"
	set_global_assignment -name POWER_BOARD_THERMAL_MODEL "NONE (CONSERVATIVE)"
	set_global_assignment -name FLOW_ENABLE_POWER_ANALYZER ON
	set_global_assignment -name POWER_DEFAULT_INPUT_IO_TOGGLE_RATE "12.5 %"
	set_global_assignment -name EXTERNAL_FLASH_FALLBACK_ADDRESS 00000000
	set_global_assignment -name INTERNAL_FLASH_UPDATE_MODE "SINGLE IMAGE WITH ERAM"
	set_global_assignment -name ENABLE_DEVICE_WIDE_RESET OFF
	set_global_assignment -name ENABLE_CONFIGURATION_PINS OFF
	set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id Top
	set_global_assignment -name PARTITION_FITTER_PRESERVATION_LEVEL PLACEMENT_AND_ROUTING -section_id Top
	set_global_assignment -name PARTITION_COLOR 16764057 -section_id Top
	set_global_assignment -name VHDL_FILE hdl/shift_reg_seq.vhd
	set_global_assignment -name VHDL_FILE hdl/pwm_seq.vhd
	set_global_assignment -name VHDL_FILE hdl/knightrider.vhd
	set_global_assignment -name VHDL_FILE hdl/control_mux.vhd
	set_global_assignment -name VHDL_FILE hdl/case_state_seq.vhd
	set_global_assignment -name QIP_FILE ddrclk.qip
	set_global_assignment -name SDC_FILE test_board.out.sdc
	set_global_assignment -name QSYS_FILE NIOS_test_board.qsys
	set_global_assignment -name BDF_FILE test_board.bdf
	set_global_assignment -name OUTPUT_IO_TIMING_NEAR_END_VMEAS "HALF VCCIO" -rise
	set_global_assignment -name OUTPUT_IO_TIMING_NEAR_END_VMEAS "HALF VCCIO" -fall
	set_global_assignment -name OUTPUT_IO_TIMING_FAR_END_VMEAS "HALF SIGNAL SWING" -rise
	set_global_assignment -name OUTPUT_IO_TIMING_FAR_END_VMEAS "HALF SIGNAL SWING" -fall
	set_location_assignment PIN_A12 -to DQ[15]
	set_location_assignment PIN_B13 -to DQ[14]
	set_location_assignment PIN_B12 -to DQ[13]
	set_location_assignment PIN_C12 -to DQ[12]
	set_location_assignment PIN_D12 -to DQ[11]
	set_location_assignment PIN_E13 -to DQ[10]
	set_location_assignment PIN_E12 -to DQ[9]
	set_location_assignment PIN_F13 -to DQ[8]
	set_location_assignment PIN_F8 -to DQ[7]
	set_location_assignment PIN_G9 -to DQ[6]
	set_location_assignment PIN_D9 -to DQ[5]
	set_location_assignment PIN_E10 -to DQ[4]
	set_location_assignment PIN_F9 -to DQ[3]
	set_location_assignment PIN_F10 -to DQ[2]
	set_location_assignment PIN_G10 -to DQ[1]
	set_location_assignment PIN_D11 -to DQ[0]
	set_location_assignment PIN_M10 -to A[11]
	set_location_assignment PIN_N4 -to A[10]
	set_location_assignment PIN_N8 -to A[9]
	set_location_assignment PIN_M13 -to A[8]
	set_location_assignment PIN_L10 -to A[7]
	set_location_assignment PIN_N9 -to A[6]
	set_location_assignment PIN_M11 -to A[5]
	set_location_assignment PIN_N10 -to A[4]
	set_location_assignment PIN_J8 -to A[3]
	set_location_assignment PIN_N5 -to A[2]
	set_location_assignment PIN_M5 -to A[1]
	set_location_assignment PIN_K6 -to A[0]
	set_location_assignment PIN_H6 -to CLK12M
	set_location_assignment PIN_F12 -to DQM[1]
	set_location_assignment PIN_E9 -to DQM[0]
	set_location_assignment PIN_K8 -to BA[1]
	set_location_assignment PIN_N6 -to BA[0]
	set_location_assignment PIN_M7 -to RAS
	set_location_assignment PIN_E7 -to RESET
	set_location_assignment PIN_M9 -to CLK
	set_location_assignment PIN_M8 -to CKE
	set_location_assignment PIN_N7 -to CAS
	set_location_assignment PIN_K7 -to WE
	set_location_assignment PIN_M4 -to CS
	set_location_assignment PIN_E6 -to USER_BTN
	set_location_assignment PIN_J6 -to SEN_SPC
	set_location_assignment PIN_K5 -to SEN_SDO
	set_location_assignment PIN_J7 -to SEN_SDI
	set_location_assignment PIN_L5 -to SEN_CS
	set_location_assignment PIN_B2 -to F_DO
	set_location_assignment PIN_A2 -to F_DI
	set_location_assignment PIN_B3 -to F_CS
	set_location_assignment PIN_A3 -to F_CLK
	set_location_assignment PIN_A4 -to BDBUS0
	set_location_assignment PIN_B4 -to BDBUS1
	set_location_assignment PIN_A8 -to LED0
	set_location_assignment PIN_A9 -to LED1
	set_location_assignment PIN_A11 -to LED2
	set_location_assignment PIN_A10 -to LED3
	set_location_assignment PIN_B10 -to LED4
	set_location_assignment PIN_C9 -to LED5
	set_location_assignment PIN_C10 -to LED6
	set_location_assignment PIN_D8 -to LED7
	set_location_assignment PIN_C4 -to NSTATUS
	set_location_assignment PIN_B9 -to DEVCLRn
	set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top

	# Commit assignments
	export_assignments

	# Close project
	if {$need_to_close_project} {
		project_close
	}
}

