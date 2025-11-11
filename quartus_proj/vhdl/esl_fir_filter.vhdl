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
        AUD_BCLK   : out  std_logic;                         -- audio bit clock
        AUD_DACLRCK: out  std_logic;                          -- audio DAC LR clock
        AUD_ADCLRCK: out  std_logic;                          -- audio ADC LR clock
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
    signal nios_pio_data : std_logic_vector(7 downto 0);

component uart is
    Port (
        clk     : in  STD_LOGIC;
        reset_n   : in  STD_LOGIC;
        pio_data_out: out STD_LOGIC_VECTOR (7 downto 0);
        FIR_Coeffs : out FIR_type_coeffs         -- 64 x 16bit 
    );
end component;

component FIR_Filter is
port (
    clk : in std_logic;     -- 50 MHz
    rst :in std_logic;

    -- Avalon Stream AUDIO in und out von Benedikt.
    Av_S_AUDIO_IN: in std_logic_vector(15 downto 0);
    Av_S_AUDIO_IN_valid: in std_logic;
    Av_S_AUDIO_IN_ready: out std_logic;

    Av_S_AUDIO_OUT: out  std_logic_vector(15 downto 0);
    Av_S_AUDIO_OUT_valid: out std_logic;
    Av_S_AUDIO_OUT_ready: in std_logic;

    -- Filter Koeffs von Simon via UART
    FIR_Coeffs : in FIR_type_coeffs         -- 64 x 16bit 
);
end component;
    signal FIR_Coeffs : FIR_type_coeffs;
    signal sig_AVS_audio_in : std_logic_vector(15 downto 0);
    signal sig_AVS_audio_in_valid : std_logic;
    signal sig_AVS_audio_in_ready : std_logic;
    signal sig_AVS_audio_out : std_logic_vector(15 downto 0);
    signal sig_AVS_audio_out_valid : std_logic;
    signal sig_AVS_audio_out_ready : std_logic;

component  codec_top is
port (
    --------------------------------------------------------------------
    -- System
    --------------------------------------------------------------------
    --! 50 MHz reference system clock.
    clk_50 : in std_logic;

    --! Global active-low reset.
    rst_n : in std_logic;

    --------------------------------------------------------------------
    -- I²C control (codec configuration)
    --------------------------------------------------------------------
    --! I²C serial clock to WM8731 codec.
    I2C_CLCK : out std_logic;

    --! I²C bidirectional serial data line to WM8731 codec.
    I2C_DATA : inout std_logic;

    --------------------------------------------------------------------
    -- Codec interface (I²S audio signals)
    --------------------------------------------------------------------
    --! Serial audio data input from ADC (I²S SDIN).
    ADC_DAT : in std_logic;

    --! Serial audio data output to DAC (I²S SDOUT).
    DAC_DAT : out std_logic;

    --! Left/right channel select for ADC (48 kHz frame sync).
    ADC_LR_SEL : out std_logic;

    --! Left/right channel select for DAC (48 kHz frame sync).
    DAC_LR_SEL : out std_logic;

    --! I²S bit clock (1.536 MHz, 32 bits per channel at 48 kHz).
    BCLCK : out std_logic;

    --! Master clock to WM8731 (18.432 MHz).
    XCK : out std_logic;

    --------------------------------------------------------------------
    -- FIR stream interface (mono, Avalon-ST)
    --------------------------------------------------------------------
    --! FIR output sample toward DAC (16-bit).
    Av_S_AUDIO_OUT : in std_logic_vector(15 downto 0);

    --! FIR output sample valid flag.
    Av_S_AUDIO_OUT_valid : in std_logic;

    --! FIR output ready signal (requests next sample each 48 kHz frame).
    Av_S_AUDIO_OUT_ready : out std_logic;

    --! ADC input sample toward FIR (16-bit).
    Av_S_AUDIO_IN : out std_logic_vector(15 downto 0);

    --! ADC input sample valid flag.
    Av_S_AUDIO_IN_valid : out std_logic;

    --! FIR ready signal for new ADC sample.
    Av_S_AUDIO_IN_ready : in std_logic
);
end component;

begin
    reset_n <= KEY(0);

    u0: uart
        port map (
        clk => CLOCK_50,
        reset_n => reset_n,
        pio_data_out => nios_pio_data,
        FIR_Coeffs => FIR_Coeffs
    );

    f0 : FIR_Filter
        port map (
        clk => CLOCK_50,
        rst => not reset_n,
        Av_S_AUDIO_IN => sig_AVS_audio_in,
        Av_S_AUDIO_IN_valid => sig_AVS_audio_in_valid,
        Av_S_AUDIO_IN_ready => sig_AVS_audio_in_ready,
        Av_S_AUDIO_OUT => sig_AVS_audio_out,
        Av_S_AUDIO_OUT_valid => sig_AVS_audio_out_valid,
        Av_S_AUDIO_OUT_ready => sig_AVS_audio_out_ready,
        FIR_Coeffs => FIR_Coeffs
    );

    codec0 : codec_top
        port map (
        clk_50 => CLOCK_50,
        rst_n => reset_n,
        I2C_CLCK => FPGA_I2C_SCLK,
        I2C_DATA => FPGA_I2C_SDAT,
        ADC_DAT => AUD_ADCDAT,
        DAC_DAT => AUD_DACDAT,
        ADC_LR_SEL => AUD_ADCLRCK,
        DAC_LR_SEL => AUD_DACLRCK,
        BCLCK => AUD_BCLK,
        XCK => AUD_XCK,
        Av_S_AUDIO_OUT => sig_AVS_audio_out,
        Av_S_AUDIO_OUT_valid => sig_AVS_audio_out_valid,
        Av_S_AUDIO_OUT_ready => sig_AVS_audio_out_ready,
        Av_S_AUDIO_IN => sig_AVS_audio_in,
        Av_S_AUDIO_IN_valid => sig_AVS_audio_in_valid,
        Av_S_AUDIO_IN_ready => sig_AVS_audio_in_ready
    );
    

    -- Blank HEX (all segments off = '1' on common-anode wiring used on DE1-SoC)
    HEX0 <= (others => '1');
    HEX1 <= (others => '1');
    HEX2 <= (others => '1');
    HEX3 <= (others => '1');
    HEX4 <= (others => '1');
    HEX5 <= (others => '1');

    
    -- Im alive blinky
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