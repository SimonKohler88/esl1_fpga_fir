--! @title Codec Top-Level (Mono Interface, Avalon-ST Compliant)
--! @file codec_top.vhd
--! @author Benedikt Sele
--! @version 1.3
--! @date 10.11.2025
--! @brief Mono I²S codec interface for Wolfson WM8731 with Avalon-ST bridging.
--!
--! Generates all required clocks (via PLL), configures the WM8731 codec via I²C,
--! and bridges between I²S audio and Avalon-ST streaming interfaces for FIR connection.
--! Only the left channel is used (mono). Each 48 kHz audio frame transfers one 16-bit sample.
--!
--! **Instantiation Credits**
--! - PLL (`ime_vga_audio_pll`)
--! - Codec configuration (`codec_i2c_top`)
--! - I²S interface (`codec_if`)
--!   provided by **Prof. Michael Pichler (FHNW IME)**
--!
--! **Avalon-ST Interface Behavior**
--! - *ADC → FIR (Source)*  
--!   - `Av_S_AUDIO_IN`: 16-bit sample captured from ADC  
--!   - `Av_S_AUDIO_IN_valid`: asserted once per 48 kHz frame when new data available  
--!   - `Av_S_AUDIO_IN_ready`: from FIR; acknowledges acceptance  
--!   - if `ready='0'`, the current sample is skipped
--!
--! - *FIR → DAC (Sink)*  
--!   - `Av_S_AUDIO_OUT`: 16-bit filtered sample  
--!   - `Av_S_AUDIO_OUT_valid`: high when new FIR output available  
--!   - `Av_S_AUDIO_OUT_ready`: asserted once per 48 kHz frame to request new sample  
--!   - when both high → sample latched and sent to DAC
--!
--! **Clocks**
--! - `clk_50`      : 50 MHz system clock
--! - `SYS_CLCK`    : 18.432 MHz system clock (PLL output)  
--! - `clk_48k`     : derived sample-rate clock  
--! - `BCLCK`       : 1.536 MHz I²S bit clock  
--! - `XCK`         : 18 MHz master clock to codec
--!
--! **Direction Summary**
--! - `ADC → FIR`  : Source (Avalon-ST producer)  
--! - `FIR → DAC`  : Sink   (Avalon-ST consumer)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity codec_top is
  port (
    --------------------------------------------------------------------
    -- System
    --------------------------------------------------------------------
    clk_50 : in std_logic; --! 50 MHz reference clock
    rst_n  : in std_logic; --! Global active-low reset

    --------------------------------------------------------------------
    -- I²C control (codec configuration)
    --------------------------------------------------------------------
    I2C_CLCK : out std_logic; --! I²C serial clock to WM8731
    I2C_DATA : inout std_logic; --! I²C bidirectional data line

    --------------------------------------------------------------------
    -- Codec interface (I²S audio signals)
    --------------------------------------------------------------------
    ADC_DAT    : in std_logic; --! Serial audio data in (ADC)
    DAC_DAT    : out std_logic; --! Serial audio data out (DAC)
    ADC_LR_SEL : out std_logic; --! ADC L/R select (48 kHz frame sync)
    DAC_LR_SEL : out std_logic; --! DAC L/R select (48 kHz frame sync)
    BCLCK      : out std_logic; --! I²S bit clock (1.536 MHz)
    XCK        : out std_logic; --! Master clock (18 MHz)

    --------------------------------------------------------------------
    -- FIR stream interface (mono, Avalon-ST @ 50 MHz)
    --------------------------------------------------------------------
    Av_S_AUDIO_OUT       : in std_logic_vector(15 downto 0); --! FIR → DAC sample
    Av_S_AUDIO_OUT_valid : in std_logic; --! FIR sample valid
    Av_S_AUDIO_OUT_ready : out std_logic; --! Request next sample

    Av_S_AUDIO_IN       : out std_logic_vector(15 downto 0); --! ADC → FIR sample
    Av_S_AUDIO_IN_valid : out std_logic; --! ADC sample valid
    Av_S_AUDIO_IN_ready : in std_logic --! FIR ready flag
  );
end entity codec_top;

architecture rtl of codec_top is

  --------------------------------------------------------------------
  -- Internal Signals
  --------------------------------------------------------------------
  signal SYS_CLCK       : std_logic; -- 18.432 MHz PLL output
  signal clk_48k        : std_logic; -- 48 kHz frame clock
  signal locked         : std_logic; -- PLL lock indicator
  signal adc_sample_reg : std_logic_vector(15 downto 0); -- ADC parallel sample
  signal dac_sample_48k : std_logic_vector(15 downto 0) := (others => '0');
  signal dac_sample_50m : std_logic_vector(15 downto 0) := (others => '0');
  signal clk48k_ff1     : std_logic                     := '0';
  signal clk48k_ff2     : std_logic                     := '0';
  signal frame_stb_50m  : std_logic                     := '0'; -- 1-cycle @ 50 MHz

begin

  --------------------------------------------------------------------
  -- PLL: Generate 18.432 MHz from 50 MHz reference
  --------------------------------------------------------------------
  i_pll : entity work.ime_vga_audio_pll
    port map
    (
      refclk   => clk_50,
      rst      => not rst_n,
      outclk_0 => SYS_CLCK,
      locked   => locked
    );

  --------------------------------------------------------------------
  -- I²C Configuration for WM8731 (50 MHz domain)
  --------------------------------------------------------------------
  i_i2c_cfg : entity work.codec_i2c_top
    port map
    (
      clk      => clk_50,
      rst_n    => rst_n,
      i2c_sclk => I2C_CLCK,
      i2c_sdat => I2C_DATA
    );

  --------------------------------------------------------------------
  -- I²S Codec Interface (Mono – Left Channel Only)
  --------------------------------------------------------------------
  i_codec_if : entity work.codec_if
    port map
    (
      clk_18m                 => SYS_CLCK,
      rst_n                   => rst_n,
      adc_data                => ADC_DAT,
      dac_data                => DAC_DAT,
      dac_lrclk_48k           => DAC_LR_SEL,
      adc_lrclk_48k           => ADC_LR_SEL,
      bitclk_1536k            => BCLCK,
      xclk_18m                => XCK,
      clk_48k                 => clk_48k,
      clk_1536k               => open,
      left_data_in            => dac_sample_48k,
      right_data_in => (others => '0'),
      left_data_out_neg_edge  => adc_sample_reg,
      right_data_out_neg_edge => open
    );

  --------------------------------------------------------------------
  -- Sync 48 kHz Clock into 50 MHz Domain (double-flop + edge detect)
  -- Generates 1-cycle strobe (frame_stb_50m) for new frame events.
  --------------------------------------------------------------------
  sync_48k_to_50m : process (clk_50, rst_n)
  begin
    if rst_n = '0' then
      clk48k_ff1    <= '0';
      clk48k_ff2    <= '0';
      frame_stb_50m <= '0';
    elsif rising_edge(clk_50) then
      clk48k_ff1    <= clk_48k;
      clk48k_ff2    <= clk48k_ff1;
      frame_stb_50m <= clk48k_ff1 and not clk48k_ff2;
    end if;
  end process sync_48k_to_50m;

  --------------------------------------------------------------------
  -- Avalon-ST Source: ADC → FIR
  -- Pulses valid once per frame when FIR ready = '1'.
  --------------------------------------------------------------------
  adc_to_fir_proc : process (clk_50, rst_n)
  begin
    if rst_n = '0' then
      Av_S_AUDIO_IN       <= (others => '0');
      Av_S_AUDIO_IN_valid <= '0';
    elsif rising_edge(clk_50) then
      Av_S_AUDIO_IN_valid <= '0';
      if frame_stb_50m = '1' and Av_S_AUDIO_IN_ready = '1' then
        Av_S_AUDIO_IN       <= adc_sample_reg;
        Av_S_AUDIO_IN_valid <= '1';
      end if;
    end if;
  end process adc_to_fir_proc;

  --------------------------------------------------------------------
  -- Avalon-ST Sink: FIR → DAC
  -- Requests one sample per frame; deasserts ready after valid seen.
  --------------------------------------------------------------------
  fir_to_dac_proc_50m : process (clk_50, rst_n)
  begin
    if rst_n = '0' then
      Av_S_AUDIO_OUT_ready <= '0';
      dac_sample_50m       <= (others => '0');
    elsif rising_edge(clk_50) then
      if frame_stb_50m = '1' then
        Av_S_AUDIO_OUT_ready <= '1';
      elsif Av_S_AUDIO_OUT_valid = '1' and Av_S_AUDIO_OUT_ready = '1' then
        dac_sample_50m       <= Av_S_AUDIO_OUT;
        Av_S_AUDIO_OUT_ready <= '0';
      end if;
    end if;
  end process fir_to_dac_proc_50m;

  --------------------------------------------------------------------
  -- 48 kHz Domain: Forward Latched FIR Sample to Codec
  --------------------------------------------------------------------
  fir_to_dac_proc_48k : process (clk_48k, rst_n)
  begin
    if rst_n = '0' then
      dac_sample_48k <= (others => '0');
    elsif rising_edge(clk_48k) then
      dac_sample_48k <= dac_sample_50m;
    end if;
  end process fir_to_dac_proc_48k;
end architecture rtl;
