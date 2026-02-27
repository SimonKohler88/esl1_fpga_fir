
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.FIR_types.all;

entity spi_reg_bank is
    port (
        clk       : in  std_logic;  -- system clock
        rst       : in  std_logic;  -- synchronous reset, active high

        -- bus interface to command interface
        reg_cmd    : in std_logic_vector(6 downto 0);
        reg_byte_nr : in std_logic_vector(8 downto 0);
        reg_wdata  : in std_logic_vector(7 downto 0);
        reg_wr_en  : in std_logic;
        reg_rdata  : out  std_logic_vector(7 downto 0);

        -- Mux Ctrl 1 x 16 Bit
        mux_ctrl : out std_logic_vector(15 downto 0);

         -- Filter Koeffs (64 x 16bit)
        fir_coeffs : out FIR_type_coeffs;

        -- Status reg
        status_reg : in std_logic_vector(7 downto 0)
    );
end entity spi_reg_bank;

architecture rtl of spi_reg_bank is

    signal coeff_array  : FIR_type_coeffs := (others => (others => '0'));
    signal mux_ctrl_reg : std_logic_vector(15 downto 0) := (others => '0');
    signal status_reg_int : std_logic_vector(7 downto 0) := (others => '0');

    signal cmd_int      : integer range 0 to 127;
    signal byte_nr_int  : integer range 0 to 511;

begin

    cmd_int     <= to_integer(unsigned(reg_cmd));
    byte_nr_int <= to_integer(unsigned(reg_byte_nr));

    -- output assignments
    mux_ctrl   <= mux_ctrl_reg;
    fir_coeffs <= coeff_array;

    ---------------------------------------------------------------
    -- WRITE mux: reg_cmd selects target, reg_byte_nr selects byte
    ---------------------------------------------------------------
    p_write : process(clk)
        variable coeff_idx : integer range 0 to 128;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                mux_ctrl_reg <= (others => '0');
                coeff_array  <= (others => (others => '0'));
            elsif reg_wr_en = '1' then
                case cmd_int is

                    when 0 =>  -- mux_ctrl: 2 bytes
                        case byte_nr_int is
                            when 0 => mux_ctrl_reg(15 downto 8)  <= reg_wdata;
                            when 1 => mux_ctrl_reg(7 downto 0) <= reg_wdata;
                            when others => null;
                        end case;

                    when 1 =>  -- FIR coefficients: 128 bytes (64 x 16-bit, big-endian)
                        coeff_idx := to_integer(unsigned(reg_byte_nr(7 downto 1))); --byte_nr_int / 2;
                        if(coeff_idx < 64) then
                            if byte_nr_int < 128 then
                                if reg_byte_nr(0) = '0' then
                                    coeff_array(coeff_idx)(15 downto 8)  <= reg_wdata;
                                else
                                    coeff_array(coeff_idx)(7 downto 0) <= reg_wdata;
                                end if;
                            end if;
                        end if;

                    when others => null;
                end case;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------
    -- READ mux: combinational, always drives reg_rdata
    ---------------------------------------------------------------
    p_read : process(all)
        variable coeff_idx : integer range 0 to 128;
    begin
        reg_rdata <= (others => '0');  -- default

        case cmd_int is

            when 0 =>  -- mux_ctrl
                case byte_nr_int is
                    when 0 => reg_rdata <= mux_ctrl_reg(15 downto 8);
                    when 1 => reg_rdata <= mux_ctrl_reg(7 downto 0);
                    when others => null;
                end case;

            when 1 =>  -- FIR coefficients
                coeff_idx := to_integer(unsigned(reg_byte_nr(7 downto 1))); --byte_nr_int / 2;
                if(coeff_idx < 64) then
                    if byte_nr_int < 128 then
                        if reg_byte_nr(0) = '0' then
                            reg_rdata <= coeff_array(coeff_idx)(15 downto 8);
                        else
                            reg_rdata <= coeff_array(coeff_idx)(7 downto 0);
                        end if;
                    end if;
                end if;
            
            when 2 =>  -- Status reg
                if byte_nr_int = 0 then
                    reg_rdata <= status_reg;
                end if;

            when others => null;
        end case;
    end process;

end architecture;