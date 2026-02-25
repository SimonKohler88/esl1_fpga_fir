library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DAC_SPI_tb is
end entity DAC_SPI_tb;

architecture sim of DAC_SPI_tb is

    -- Clock periods
    constant CLK_PERIOD     : time := 5 ns;      -- 200 MHz
    constant SPI_CLK_PERIOD : time := 29.4 ns;   -- 34 MHz

    signal clk     : std_logic := '0';
    signal clk_spi : std_logic := '0';
    signal rst     : std_logic := '1';

    signal spi_clk  : std_logic;
    signal spi_cs_n : std_logic;
    signal spi_data : std_logic;

    signal asi_data  : std_logic_vector(15 downto 0) := (others => '0');
    signal asi_valid : std_logic := '0';
    signal asi_ready : std_logic;

    -- Test data to send to the DAC
    constant DAC_VALUE_1 : std_logic_vector(15 downto 0) := x"1234";
    constant DAC_VALUE_2 : std_logic_vector(15 downto 0) := x"ABCD";

    signal sim_done : boolean := false;

begin

    -- Clock generators
    clk     <= not clk     after CLK_PERIOD / 2     when not sim_done else '0';
    clk_spi <= not clk_spi after SPI_CLK_PERIOD / 2 when not sim_done else '0';

    -- DUT
    dut : entity work.DAC_SPI
        port map (
            clk      => clk,
            clk_spi  => clk_spi,
            rst      => rst,
            spi_clk  => spi_clk,
            spi_cs_n => spi_cs_n,
            spi_data => spi_data,
            asi_data  => asi_data,
            asi_valid => asi_valid,
            asi_ready => asi_ready
        );

    -- Main stimulus: feed data via Avalon-ST sink
    p_stim : process
    begin
        rst <= '1';
        asi_valid <= '0';
        asi_data  <= (others => '0');
        wait for 100 ns;
        rst <= '0';
        wait for 100 ns;

        -- Wait until DUT is ready, then send first value
        wait until rising_edge(clk) and asi_ready = '1';
        asi_data  <= DAC_VALUE_1;
        asi_valid <= '1';
        wait until rising_edge(clk);
        asi_valid <= '0';

        -- Wait for SPI transfer to complete
        wait for 2 us;

        -- Send second value
        wait until rising_edge(clk) and asi_ready = '1';
        asi_data  <= DAC_VALUE_2;
        asi_valid <= '1';
        wait until rising_edge(clk);
        asi_valid <= '0';

        -- Wait for SPI transfer to complete
        wait for 2 us;

        sim_done <= true;
        report "Simulation finished." severity note;
        wait;
    end process;

    -- Simulated DAC slave: capture spi_data on rising edge of spi_clk when CS is low
    p_dac_slave : process
        variable captured : std_logic_vector(15 downto 0);
    begin
        wait until spi_cs_n = '0';
        for bit_idx in 15 downto 0 loop
            wait until rising_edge(spi_clk);
            captured(bit_idx) := spi_data;
        end loop;
        wait until spi_cs_n = '1';
        report "DAC received: 0x" & to_hstring(captured) severity note;
    end process;

end architecture sim;
