library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.FIR_types.all;

-- SPI slave interface for MCU communication (CPOL=0, CPHA=0, MSB first)
-- Shifts in 16-bit words from MOSI, presents them on rx_data/rx_valid.
-- Directly clocked by the external SPI_CLK from the master.
entity MCU_SPI is
    port (
        clk   : in std_logic;  -- system clock
        rst   : in std_logic;  -- synchronous reset, active high

        -- SPI pins (directly from MCU master)
        spi_clk  : in  std_logic;
        spi_cs_n : in  std_logic;  -- active low chip select
        spi_mosi : in  std_logic;
        spi_miso : out std_logic;

        mux_ctrl : out std_logic_vector(15 downto 0);
        fir_coeffs : out FIR_type_coeffs;   
        status_reg : in std_logic_vector(7 downto 0)
      
    );
end entity MCU_SPI;

architecture rtl of MCU_SPI is

    
component spi_phy is
    port (
        clk       : in  std_logic;  -- system clock
        rst       : in  std_logic;  -- synchronous reset, active high

        -- SPI bus pins
        spi_clk   : in  std_logic;
        spi_cs_n  : in  std_logic;  -- active-low chip select
        spi_mosi  : in  std_logic;
        spi_miso  : out std_logic;

        -- parallel interface (system clock domain)
        tx_data   : in  std_logic_vector(7 downto 0);  -- byte to send on MISO
        tx_load   : in  std_logic;                      -- load tx_data into shift reg
        rx_data   : out std_logic_vector(7 downto 0);   -- received byte
        byte_valid: out std_logic   
    );
end component spi_phy;

component spi_protocol is
    port (
        clk           : in  std_logic;
        rst           : in  std_logic;
        phy_rx_data   : in  std_logic_vector(7 downto 0);
        phy_byte_valid: in  std_logic;
        phy_tx_data   : out std_logic_vector(7 downto 0);
        phy_tx_load   : out std_logic;
        spi_cs_n      : in  std_logic;
        reg_cmd      : out std_logic_vector(6 downto 0);
        reg_byte_nr : out std_logic_vector(8 downto 0);
        reg_wdata     : out std_logic_vector(7 downto 0);
        reg_wr_en     : out std_logic;
        reg_rdata     : in  std_logic_vector(7 downto 0)
    );
end component spi_protocol;

component spi_reg_bank is
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
end component spi_reg_bank;

    -- spi_phy signals
    signal phy_tx_data   : std_logic_vector(7 downto 0) := (others => '0');
    signal phy_tx_load   : std_logic := '0';
    signal phy_rx_data   : std_logic_vector(7 downto 0);
    signal phy_byte_valid: std_logic;

    -- spi_protocol -> register bus
    signal reg_cmd  : std_logic_vector(6 downto 0);
    signal reg_byte_nr : std_logic_vector(8 downto 0);
    signal reg_wdata : std_logic_vector(7 downto 0);
    signal reg_wr_en : std_logic;
    signal reg_rdata : std_logic_vector(7 downto 0) := (others => '0');

begin

    u_spi_phy : spi_phy
        port map (
            clk        => clk,
            rst        => rst,
            spi_clk    => spi_clk,
            spi_cs_n   => spi_cs_n,
            spi_mosi   => spi_mosi,
            spi_miso   => spi_miso,
            tx_data    => phy_tx_data,
            tx_load    => phy_tx_load,
            rx_data    => phy_rx_data,
            byte_valid => phy_byte_valid
        );

    u_spi_protocol : spi_protocol
        port map (
            clk           => clk,
            rst           => rst,
            phy_rx_data   => phy_rx_data,
            phy_byte_valid=> phy_byte_valid,
            phy_tx_data   => phy_tx_data,
            phy_tx_load   => phy_tx_load,
            spi_cs_n      => spi_cs_n,
            reg_cmd      => reg_cmd,
            reg_byte_nr => reg_byte_nr,
            reg_wdata     => reg_wdata,
            reg_wr_en     => reg_wr_en,
            reg_rdata     => reg_rdata
        );

    u_spi_reg_bank : spi_reg_bank
        port map (
            clk       => clk,
            rst       => rst,
            reg_cmd    => reg_cmd,
            reg_byte_nr => reg_byte_nr,
            reg_wdata  => reg_wdata,
            reg_wr_en  => reg_wr_en,
            reg_rdata  => reg_rdata,
            mux_ctrl   => mux_ctrl,
            fir_coeffs => fir_coeffs,
            status_reg => status_reg
        );
end architecture rtl;
