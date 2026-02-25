library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DAC_SPI_tb is
end entity DAC_SPI_tb;

architecture sim of DAC_SPI_tb is

    -- Clock periods
    constant CLK_PERIOD     : time := 5 ns;      -- 200 MHz
    constant SPI_CLK_PERIOD : time := 25 ns;   -- 40 MHz

    signal clk     : std_logic := '0';
    signal clk_spi : std_logic := '0';
    signal rst     : std_logic := '1';

    signal spi_clk  : std_logic;
    signal spi_cs_n : std_logic;
    signal spi_data : std_logic;

    signal asi_data  : std_logic_vector(15 downto 0) := (others => '0');
    signal asi_valid : std_logic := '0';
    signal asi_ready : std_logic;

    -- 2 MHz Avalon data rate -> 500 ns period
    constant AVL_PERIOD : time := 500 ns;

    signal spi_capure_data : std_logic_vector(11 downto 0);
    signal spi_capture_mode : std_logic_vector(3 downto 0);

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

    -- Main stimulus: send 10 values at 2 MHz (500 ns period)
    p_stim : process
        variable t_start : time;
        variable dac_val : std_logic_vector(15 downto 0);
    begin
        rst <= '1';
        asi_valid <= '0';
        asi_data  <= (others => '0');
        wait for 100 ns;
        rst <= '0';
        wait for 100 ns;

        for i in 0 to 9 loop
            t_start := now;
            dac_val := std_logic_vector(to_unsigned((i + 1) * 100, 16));

            -- Wait until DUT is ready, then send value
            wait until rising_edge(clk) and asi_ready = '1';
            asi_data  <= dac_val;
            asi_valid <= '1';
            wait until rising_edge(clk);
            asi_valid <= '0';

            -- Maintain 2 MHz rate: wait remainder of 500 ns period
            if (now - t_start) < AVL_PERIOD then
                wait for AVL_PERIOD - (now - t_start);
            end if;
        end loop;

        -- Wait for last SPI transfer to complete
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
            wait until falling_edge(spi_clk);
            captured(bit_idx) := spi_data;
        end loop;
        wait until spi_cs_n = '1';
        spi_capure_data <= captured(11 downto 0);
        spi_capture_mode <= captured(15 downto 12);
        -- report "DAC received: 0x" & to_hstring(captured) severity note;
    end process;

end architecture sim;
