library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


-- interfacing ADC chip ADS7049 via SPI, and outputting data to Avalon-ST source interface
--The device output is in straight binary format. 
entity ADC_SPI is
    port (
        clk     : in  std_logic;
        clk_spi     : in  std_logic;
        clk_trigger : in  std_logic;
        rst     : in  std_logic;

        -- SPI input from ADC
        spi_clk  : out  std_logic;
        spi_cs_n : out  std_logic := '1';  -- active low chip select
        spi_data : in  std_logic;

        -- Avalon-ST source (16-bit)
        aso_data  : out std_logic_vector(15 downto 0);
        aso_valid : out std_logic;
        aso_ready : in  std_logic
    );
end entity ADC_SPI;

architecture rtl of ADC_SPI is

    -- SPI clock domain
    signal shift_reg : std_logic_vector(15 downto 0);
    signal bit_cnt   : unsigned(3 downto 0);
    signal s_reset : std_logic := '0';

    signal start_conversion : std_logic := '0';
    signal conversion_in_progress : std_logic := '0';
    signal start_conversion_ff : std_logic_vector(1 downto 0) := (others => '0');
    signal conversion_done_ff : std_logic_vector(1 downto 0) := (others => '0');
    signal conversion_done_sync : std_logic := '0';
    signal conv_stage : unsigned(2 downto 0) := (others => '0');  -- track which stage of conversion we're in (0-7)

    signal aso_data_reg : std_logic_vector(15 downto 0);

    signal av_st_data_sent : std_logic := '0';  -- flag to indicate data has been sent to Avalon-ST

begin
    s_reset <= rst;

    -- clk domain crossing for trigger signal
    p_trigger: process(all) is
    begin
        if s_reset = '1' then
            start_conversion_ff <= (others => '0');
        elsif rising_edge(clk_spi) then
            start_conversion_ff <= start_conversion_ff(0) & clk_trigger;
        end if;
    end process;
    start_conversion <= not start_conversion_ff(1) and start_conversion_ff(0);  -- detect rising edge of trigger

    spi_clk <= clk_spi when spi_cs_n = '0' else '0';
    p_spi_read: process(all) is
    begin
        if s_reset = '1' then
            spi_cs_n <= '1';  -- inactive
            bit_cnt <= (others => '0');
            shift_reg <= (others => '0');
            conversion_in_progress <= '0';
            conv_stage <= (others => '0');

        elsif falling_edge(clk_spi) then
            conversion_in_progress <= '0';

            if start_conversion = '1' then
                spi_cs_n <= '0';  -- active
                bit_cnt <= (others => '0');
                shift_reg <= (others => '0');
                conversion_in_progress <= '1';
                conv_stage <= conv_stage + 1;

            elsif ( conv_stage = 1) then
                shift_reg <= shift_reg(14 downto 0) & spi_data;  -- shift in new bit
                spi_cs_n <= '0';  -- active
                bit_cnt <= bit_cnt + 1;
                conversion_in_progress <= '1';
                if bit_cnt = 15 then
                    conv_stage <= conv_stage + 1;  -- move to next stage after 16 bits
                end if;

            elsif (conv_stage = 2) then
                spi_cs_n <= '1';
                conv_stage <= (others=>'0');
                
            end if;
        end if;
    end process;

    -- clock domain crossing from spi to main clk
    p_conversion_done_sync: process(all) is
    begin
        if s_reset = '1' then
            conversion_done_ff <= (others => '0');
        elsif rising_edge(clk) then
            conversion_done_ff <= conversion_done_ff(0) & conversion_in_progress;
        end if;
    end process;
    conversion_done_sync <= conversion_done_ff(1) and not conversion_done_ff(0);

    -- data takeover from spi
    p_data_transfer: process(all) is
    begin
        if s_reset = '1' then
            aso_data_reg <= (others => '0');
        elsif rising_edge(clk) then
            if conversion_done_sync = '1' then
                aso_data_reg <= "00" & shift_reg(15 downto 2);  -- zero-extend to 16 bits
            end if;
        end if;
    end process;
    aso_data <= aso_data_reg;

    -- Avalon-ST output logic
    p_avalon_st: process(all) is
    begin
        if s_reset = '1' then
            aso_valid <= '0';
        elsif rising_edge(clk) then
            aso_valid <= '0';
            if conversion_done_sync = '1' then
                av_st_data_sent <= '0';  -- reset flag at start of new conversion
            elsif  av_st_data_sent = '0' and aso_ready = '1' then
                aso_valid <= '1';  -- set valid when ready is high and data has not been sent
                av_st_data_sent <= '1';  -- set flag to indicate data has been sent
            end if;
        end if;
    end process;

end architecture rtl;
