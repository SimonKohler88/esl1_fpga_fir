library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MCU_SPI_tb is
end entity MCU_SPI_tb;

architecture sim of MCU_SPI_tb is

    constant CLK_PERIOD : time := 5 ns;      -- 200 MHz system clock
    constant SPI_HALF   : time := 125 ns;    -- 4 MHz SPI clock (250 ns period)

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '1';

    -- SPI bus
    signal spi_clk  : std_logic := '0';
    signal spi_cs_n : std_logic := '1';
    signal spi_mosi : std_logic := '0';
    signal spi_miso : std_logic;
    signal s_num_bytes : integer range 0 to 255;
    signal stat_reg : std_logic_vector(7 downto 0) := (others => '0');

    signal sim_done : boolean := false;

    -- Procedure: send/receive one byte over SPI (CPOL=0, CPHA=0, MSB first)
    -- CS is NOT toggled – caller controls CS framing.
    procedure spi_xfer_byte(
        constant tx   : in  std_logic_vector(7 downto 0);
        signal   mosi : out std_logic;
        signal   sclk : out std_logic;
        signal   miso : in  std_logic;
        variable rx   : out std_logic_vector(7 downto 0)
    ) is
    begin
        for i in 7 downto 0 loop
            mosi <= tx(i);
            sclk <= '0';
            wait for SPI_HALF;
            sclk <= '1';       -- DUT samples on rising edge
            rx(i) := miso;     -- capture MISO on rising edge
            wait for SPI_HALF;
        end loop;
        sclk <= '0';
        report "SPI byte TX=0x" & to_hstring(tx) & " RX=0x" & to_hstring(rx);
    end procedure;

    -- Write a register: command byte 0x00|addr, then data byte
    procedure spi_write_reg(
        constant addr : in  std_logic_vector(6 downto 0);
        signal num_bytes : in integer range 0 to 255;
        signal   mosi : out std_logic;
        signal   sclk : out std_logic;
        signal   cs_n : out std_logic;
        signal   miso : in  std_logic
    ) is
        variable rx_byte : std_logic_vector(7 downto 0);
    begin
        cs_n <= '0';
        wait for SPI_HALF;
        spi_xfer_byte('0' & addr, mosi, sclk, miso, rx_byte);   -- cmd: write
        wait for SPI_HALF;
        for i in 0 to num_bytes - 1 loop
            spi_xfer_byte( std_logic_vector(to_unsigned(i + 1, 8)), mosi, sclk, miso, rx_byte);     -- data byte
            wait for SPI_HALF;
        end loop;
        cs_n <= '1';
    end procedure;

    -- Read a register: command byte 0x80|addr, then dummy byte (read MISO)
    procedure spi_read_reg(
        constant addr : in  std_logic_vector(6 downto 0);
        signal num_bytes : in integer range 0 to 255;
        signal   mosi : out std_logic;
        signal   sclk : out std_logic;
        signal   cs_n : out std_logic;
        signal   miso : in  std_logic
    ) is
        variable rx_byte : std_logic_vector(7 downto 0);
    begin
        cs_n <= '0';
        wait for SPI_HALF;
        spi_xfer_byte('1' & addr, mosi, sclk, miso, rx_byte);   -- cmd: read
        wait for SPI_HALF;
        for i in 0 to num_bytes - 1 loop
            spi_xfer_byte(x"00", mosi, sclk, miso, rx_byte);     -- dummy byte; MISO has response
            wait for SPI_HALF;
        end loop;
        cs_n <= '1';
    end procedure;

begin

    -- System clock
    clk <= not clk after CLK_PERIOD / 2 when not sim_done else '0';

    -- DUT
    dut : entity work.MCU_SPI
        port map (
            clk      => clk,
            rst      => rst,
            spi_clk  => spi_clk,
            spi_cs_n => spi_cs_n,
            spi_mosi => spi_mosi,
            spi_miso => spi_miso,
            status_reg => stat_reg
        );

    -- Stimulus
    p_stim : process
    begin
        rst <= '1';
        wait for 100 ns;
        rst <= '0';
        wait for 100 ns;


        report "------------Writing to register 0-------------------";
        s_num_bytes <= 2;
        spi_write_reg("0000000", s_num_bytes, spi_mosi, spi_clk, spi_cs_n, spi_miso);
        wait for 500 ns;

        -- -- Write 0x42 to register address 0x10
        -- report "Writing 0x42 to register 0x10";
        -- s_num_bytes <= 128;
        -- spi_write_reg("0000001", s_num_bytes, spi_mosi, spi_clk, spi_cs_n, spi_miso);
        -- wait for 500 ns;

        -- Read back register 0x03
        report "------------------Reading register 0--------------";
        s_num_bytes <= 2;
        spi_read_reg("0000000", s_num_bytes, spi_mosi, spi_clk, spi_cs_n, spi_miso);
        wait for 500 ns;

        -- Read back register 0x10
        report "----------------Reading coeffs------------------------";
        s_num_bytes <= 128;
        spi_read_reg("0000001", s_num_bytes, spi_mosi, spi_clk, spi_cs_n, spi_miso);
        wait for 500 ns;

        report "----------------Reading Status I ------------------------";
        stat_reg <= x"08";
        wait for 500 ns;
        s_num_bytes <= 1;
        spi_read_reg("0000010", s_num_bytes, spi_mosi, spi_clk, spi_cs_n, spi_miso);
        report "----------------";
        wait for 500 ns;
        spi_read_reg("0000010", s_num_bytes, spi_mosi, spi_clk, spi_cs_n, spi_miso);
        wait for 500 ns;
        
        report "----------------Reading Status II ------------------------";
        stat_reg <= x"00";
        wait for 1500 ns;
        s_num_bytes <= 1;
        spi_read_reg("0000010", s_num_bytes, spi_mosi, spi_clk, spi_cs_n, spi_miso);
        report "----------------";
        wait for 500 ns;
        spi_read_reg("0000010", s_num_bytes, spi_mosi, spi_clk, spi_cs_n, spi_miso);
        wait for 500 ns;
        
        wait for 1500 ns;
        sim_done <= true;
        report "Simulation finished." severity note;
        wait;
    end process;

end architecture sim;
