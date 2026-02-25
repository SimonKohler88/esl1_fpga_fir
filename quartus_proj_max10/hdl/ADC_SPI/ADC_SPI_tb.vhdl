library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ADC_SPI_tb is
end entity ADC_SPI_tb;

architecture sim of ADC_SPI_tb is

    -- Clock periods
    constant CLK_PERIOD     : time := 5 ns;      -- 200 MHz
    constant SPI_CLK_PERIOD : time := 25 ns;  -- 40 MHz
    constant TRIG_PERIOD    : time := 500 ns;     -- 2 MHz

    signal clk         : std_logic := '0';
    signal clk_spi     : std_logic := '0';
    signal clk_trigger : std_logic := '0';
    signal rst         : std_logic := '1';

    signal spi_clk  : std_logic;
    signal spi_cs_n : std_logic;
    signal spi_data : std_logic := '0';

    signal aso_data  : std_logic_vector(15 downto 0);
    signal aso_valid : std_logic;
    signal aso_ready : std_logic := '1';

    -- Test data the simulated ADC will shift out (12-bit value with 2 leading zeros)
    signal ADC_VALUE : unsigned(15 downto 0) := "00" & x"AAA" & "00";

    signal sim_done : boolean := false;

begin

    -- Clock generators
    clk         <= not clk         after CLK_PERIOD / 2     when not sim_done else '0';
    clk_spi     <= not clk_spi     after SPI_CLK_PERIOD / 2 when not sim_done else '0';
    clk_trigger <= not clk_trigger after TRIG_PERIOD / 2    when not sim_done else '0';

    -- DUT
    dut : entity work.ADC_SPI
        port map (
            clk         => clk,
            clk_spi     => clk_spi,
            clk_trigger => clk_trigger,
            rst         => rst,
            spi_clk     => spi_clk,
            spi_cs_n    => spi_cs_n,
            spi_data    => spi_data,
            aso_data    => aso_data,
            aso_valid   => aso_valid,
            aso_ready   => aso_ready
        );

    -- Simulated ADC slave: shift out ADC_VALUE on falling edge of spi_clk when CS is low
    p_adc_slave : process
    begin
        spi_data <= '0';
        wait until spi_cs_n = '0';
        -- Shift out MSB first on each falling edge of spi_clk
        for bit_idx in 15 downto 0 loop
            wait until rising_edge(spi_clk);
            spi_data <= ADC_VALUE(bit_idx);
        end loop;
        ADC_VALUE <= ADC_VALUE + "100";  -- increment value for next conversion
    end process;

    -- Main stimulus
    p_stim : process
    begin
        rst <= '1';
        wait for 100 ns;
        rst <= '0';

        wait for 2 us;
        aso_ready <= '0';  -- simulate Avalon-ST sink not ready for a while
        wait for 1 us;
        aso_ready <= '1';  -- then ready again
        -- Let a few conversion cycles run
        wait for 10 us;

        sim_done <= true;
        report "Simulation finished." severity note;
        wait;
    end process;

end architecture sim;
