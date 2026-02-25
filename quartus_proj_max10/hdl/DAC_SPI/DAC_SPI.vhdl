library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


-- interfacing DAC chip via SPI, receiving data from Avalon-ST sink interface
entity DAC_SPI is
    port (
        clk     : in  std_logic;
        clk_spi : in  std_logic;
        rst     : in  std_logic;

        -- SPI output to DAC
        spi_clk  : out std_logic;
        spi_cs_n : out std_logic := '1';  -- active low chip select
        spi_data : out std_logic;

        -- Avalon-ST sink (16-bit)
        asi_data  : in  std_logic_vector(15 downto 0);
        asi_valid : in  std_logic;
        asi_ready : out std_logic
    );
end entity DAC_SPI;

architecture rtl of DAC_SPI is

   
   signal shift_reg : std_logic_vector(15 downto 0);
   signal bit_cnt   : unsigned(3 downto 0);
   signal s_reset : std_logic := '0';


begin
end architecture rtl;