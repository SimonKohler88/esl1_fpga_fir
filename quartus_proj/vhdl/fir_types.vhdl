library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


package FIR_types is
    constant FILTER_TAPS : integer := 64;
    type FIR_type_coeffs is array(0 to FILTER_TAPS - 1) of std_logic_vector(15 downto 0);
end package;