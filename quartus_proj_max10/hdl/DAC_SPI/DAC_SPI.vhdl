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

    --Bit 3 and 2: which DAC (00 -> DAC0); Bit 1 and 0: Mode of Operation: 01 -> Write to reg and update output )
    constant preamble : std_logic_vector(3 downto 0) := "0001";  
    -- SPI clock domain
    signal shift_reg : std_logic_vector(15 downto 0);
    signal data_buffer : std_logic_vector(15 downto 0);
    signal bit_cnt   : unsigned(4 downto 0);
    signal s_reset : std_logic := '0';

    signal spi_transmission_done : std_logic := '0';
    signal transmission_in_progress_ff : std_logic_vector(1 downto 0) := (others => '0');
    signal transmission_in_progress : std_logic := '0';
    signal spi_busy : std_logic := '0';
    signal spi_transmission_start : std_logic := '0';

begin
    s_reset <= rst;


    p_asi_data_capture: process(all) is
    begin
        if s_reset = '1' then
            data_buffer <= (others => '0');
            asi_ready <= '1';
            transmission_in_progress <= '0';
        elsif rising_edge(clk) then
            if asi_valid = '1' and asi_ready = '1' then
                data_buffer <= asi_data;
                asi_ready <= '0';  -- not ready to accept new data until current is sent
                transmission_in_progress <= '1';
            elsif transmission_in_progress = '1' and spi_transmission_done = '1' then
                asi_ready <= '1';  -- ready for next data after transmission is done
                transmission_in_progress <= '0';
            end if;
        end if;
    end process;

    -- clock_crossing 200MHz --> 40 MHz
    p_clk_crossing: process(all) is
    begin
        if s_reset = '1' then
            transmission_in_progress_ff <= (others => '0');
        elsif rising_edge(clk_spi) then
            transmission_in_progress_ff <= transmission_in_progress_ff(0) & transmission_in_progress;
        end if;
    end process;
    spi_transmission_start <= not transmission_in_progress_ff(1) and transmission_in_progress_ff(0);  -- detect rising edge of transmission_in_progress

    spi_clk <= clk_spi when spi_cs_n = '0' else '0';
    p_dac_spi_output: process(clk_spi, s_reset) is
    begin
        if s_reset = '1' then
            spi_cs_n <= '1';
            spi_data <= '0';
            bit_cnt <= (others => '0');
            spi_transmission_done <= '0';
            spi_busy <= '0';

        elsif rising_edge(clk_spi) then
            spi_data <= '0';
            spi_transmission_done <= '0';
            spi_cs_n <= '1';
            if spi_transmission_start = '1' then
                bit_cnt <= (others => '0');
                shift_reg <= preamble & data_buffer(11 downto 0);
                spi_data <= '0';
                spi_busy <= '1';
                
            elsif spi_transmission_done = '0' and spi_busy='1' then
                spi_data <= shift_reg(15);  -- MSB first
                shift_reg <= shift_reg(14 downto 0) & '0';  -- shift left
                bit_cnt <= bit_cnt + 1;
                spi_cs_n <= '0';  -- active
                
                if bit_cnt = 16 then
                    spi_transmission_done <= '1';
                    bit_cnt <= (others => '0');
                    spi_busy <= '0';
                end if;
            end if;

        end if;
    end process;
end architecture rtl;