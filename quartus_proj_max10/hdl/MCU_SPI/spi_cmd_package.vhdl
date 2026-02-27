library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


package SPI_CMD_PACKAGE is
    constant NUM_OF_CMD: integer := 3;

    -- t_spi_cmd structure: num of payload-bytes, permission (0=rw, 1=r, 2=w)
    type t_spi_cmd is array(0 to 1) of unsigned(7 downto 0);
    type t_spi_cmd_list is array(0 to NUM_OF_CMD - 1) of t_spi_cmd;

    constant command_list: t_spi_cmd_list:= (
        -- cmd 0: Input Output Mux and Offset Control
        -- 2byte, wr
        -- bit 0-2: Input Range R: 
        --          0: 6V, 1: 10V, 2: 5V, 3: 12V, 4: 24V, 5: 3V,
        -- bit 3:   0: adc offset off (Range from 0 to R)
        --          1: adc offset on (=>Range goes from -R/2 to R/2)
        -- bit 4-6: reserved
        -- bit 7-9: Output Range R: 
        --          0: 6V, 1: 10V, 2: 5V, 3: 12V, 4: 24V, 5: 3V,
        -- bit 10:   0: dac offset off (Range from 0 to R)
        --          1: dac offset on (=>Range goes from -R/2 to R/2)
        -- bit 11-14: reserved
        -- bit 15: Filter Bypass: 0=normal, 1=bypass (output = input) 
        (x"02", x"00"),

        -- cmd 1: FIR Coefficients
        -- 128byte, wr
        -- 64 coefficients, 16bit each, signed fixed-point with 15 fractional bits  
        (x"80", x"00"),

        -- cmd 2: Status read
        -- 1byte, r
        -- bit 0 : 1=ADC overrange high, 0=no overrange
        -- bit 1 : 1=ADC overrange low,  0=no overrange
        (x"01", x"01")  
    );
end package;