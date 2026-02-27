@echo off
REM Build script for a vhdl module using ghdl
REM set MODULE with your module name
Set MODULE=MCU_SPI
REM Don't touch following:
REM Set FILES=spi_cmd_package.vhdl spi_phy.vhdl spi_protocol.vhdl spi_reg_bank.vhdl ../FIR/fir_types.vhdl %MODULE%.vhdl %MODULE%_tb.vhdl

ghdl -a  --std=08 ../FIR/fir_types.vhdl
ghdl -a  --std=08 spi_cmd_package.vhdl
ghdl -a  --std=08 spi_phy.vhdl
ghdl -a  --std=08 spi_protocol.vhdl
ghdl -a  --std=08 spi_reg_bank.vhdl
ghdl -a  --std=08 MCU_SPI.vhdl          
ghdl -a  --std=08 MCU_SPI_tb.vhdl          

REM ghdl -a  --std=08 %FILES% 

if %ERRORLEVEL%==1 (
	PAUSE
	goto end
)

ghdl -r --std=08 --time-resolution=ns %MODULE%_tb --vcd=func.vcd --stop-time=1500us

if %ERRORLEVEL%==1 (
	PAUSE
) else (
	gtkwave func.vcd wave_save.gtkw
)

:end


