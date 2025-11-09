-- File: esl_fir_filter.vhdl
-- Top-level entity for Intel DE1-SoC (minimal I/O used by typical projects)
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.FIR_types.all;

entity esl_fir_filter is
    port (
        -- Clock and buttons/switches
        CLOCK_50 : in  std_logic;                         -- 50 MHz system clock
        KEY      : in  std_logic_vector(3 downto 0);     -- push buttons (active low)
        SW       : in  std_logic_vector(9 downto 0);     -- DIP switches

        -- LEDs and HEX displays
        LEDR     : out std_logic_vector(9 downto 0);     -- red LEDs
        HEX0     : out std_logic_vector(6 downto 0);     -- 7-seg (a..g)
        HEX1     : out std_logic_vector(6 downto 0);
        HEX2     : out std_logic_vector(6 downto 0);
        HEX3     : out std_logic_vector(6 downto 0);
        HEX4     : out std_logic_vector(6 downto 0);
        HEX5     : out std_logic_vector(6 downto 0);

        AUD_ADCDAT : in  std_logic;                         -- audio ADC data
        AUD_DACDAT : out std_logic;                         -- audio DAC data
        AUD_BCLK   : in  std_logic;                         -- audio bit clock
        AUD_DACLRCK: in  std_logic;                          -- audio DAC LR clock
        AUD_ADCLRCK: in  std_logic;                          -- audio ADC LR clock
        AUD_XCK    : out std_logic;                          -- audio master clock

        FPGA_I2C_SDAT : inout std_logic;                     -- I2C data line
        FPGA_I2C_SCLK : out   std_logic                      -- I2C clock
    );
end entity esl_fir_filter;

architecture rtl of esl_fir_filter is
    -- Active-low reset from KEY(0)
    signal reset_n : std_logic;

     -- Simple alive/blink LED (1 Hz) driven from CLOCK_50
    signal blink_counter : unsigned(24 downto 0) := (others => '0'); -- 25 bits -> covers 25,000,000
    signal alive         : std_logic := '0';
    constant HALF_PERIOD : integer := 25000000; -- CLOCK_50 / 2 for 1 Hz toggle

component uart is
    Port (
        clk     : in  STD_LOGIC;
        reset_n   : in  STD_LOGIC;
        pio_data_out: out STD_LOGIC_VECTOR (7 downto 0);
        FIR_Coeffs : out FIR_type_coeffs         -- 64 x 16bit 
    );
end component;

    signal nios_pio_data : std_logic_vector(7 downto 0);
begin
    reset_n <= KEY(0);

    u0: uart
        port map (
            clk => CLOCK_50,
            reset_n => reset_n,
            pio_data_out => nios_pio_data
        );

    ----------------------------------------------------------------
    -- Placeholder top-level connections:
    -- - Connect switches directly to LEDs for basic board sanity.
    -- - Blank HEX displays; replace these with your FIR filter
    --   result visualization and control logic.
    ----------------------------------------------------------------
    

    -- Blank HEX (all segments off = '1' on common-anode wiring used on DE1-SoC)
    HEX0 <= (others => '1');
    HEX1 <= (others => '1');
    HEX2 <= (others => '1');
    HEX3 <= (others => '1');
    HEX4 <= (others => '1');
    HEX5 <= (others => '1');

    

    blink_proc : process(all)
    begin
        if rising_edge(CLOCK_50) then
            if reset_n = '0' then
                blink_counter <= (others => '0');
                alive <= '0';
            else
                if blink_counter = to_unsigned(HALF_PERIOD - 1, blink_counter'length) then
                    blink_counter <= (others => '0');
                    alive <= not alive;
                else
                    blink_counter <= blink_counter + 1;
                end if;
            end if;
        end if;
    end process blink_proc;

    -- Map alive indicator to one LED while preserving the other switch-driven LEDs.
    -- LEDR(9) shows the alive blink
    LEDR <= SW(9) & nios_pio_data(7 downto 0) & alive;

    ----------------------------------------------------------------
    -- Instantiate your FIR filter core and surrounding control logic here.
    -- Example placeholder (commented):
    --
    -- fir_core_inst : entity work.fir_core
    --   port map (
    --     clk       => CLOCK_50,
    --     reset_n   => reset_n,
    --     sample_in => adc_sample,
    --     sample_out=> filtered_sample,
    --     control   => SW,
    --     status    => LEDR
    --   );
    ----------------------------------------------------------------
end architecture rtl;