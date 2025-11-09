--! @title Codec Top-Level (Mono Interface, Avalon-ST Compliant)
--! @file codec_top.vhd
--! @author Benedikt Sele
--! @version 1.2
--! @date 03.11.2025
--! @brief Implements a mono I²S audio interface for the Wolfson WM8731 codec on the DE1-SoC board.
--!
--! This top-level entity generates all required clocks (via PLL), configures the codec 
--! through I²C, and bridges between the I²S audio signals and the internal Avalon-ST 
--! streaming interfaces for connection to the FIR filter.
--!
--! Only the left channel is used (mono). Each 48 kHz audio frame transfers one 16-bit sample.
--!
--! **Instantiation Credits:**  
--!  - PLL (`ime_vga_audio_pll`),  
--!  - Codec configuration (`codec_i2c_top`), and  
--!  - I²S interface (`codec_if`)  
--!    were provided by **Prof. Michael Pichler (FHNW IME)**  
--!
--! **Avalon-ST Interface Behavior**
--! - *ADC → FIR (source)*:  
--!   - `Av_S_AUDIO_IN` carries the 16-bit sample captured from the ADC.  
--!   - `Av_S_AUDIO_IN_valid` asserts once per 48 kHz frame when new data is available.  
--!   - `Av_S_AUDIO_IN_ready` from the FIR acknowledges acceptance of the sample.  
--!   - If `ready='0'`, the current sample is skipped.
--!
--! - *FIR → DAC (sink)*:  
--!   - `Av_S_AUDIO_OUT` carries the filtered 16-bit sample to be played.  
--!   - `Av_S_AUDIO_OUT_valid` asserts when a new FIR output sample is available.  
--!   - `Av_S_AUDIO_OUT_ready` asserts once per 48 kHz frame to request a new sample.  
--!   - When both are high, the sample is latched and sent to the DAC.
--!
--! **Clocks**
--! - `SYS_CLCK`: 18 MHz system clock (PLL output)
--! - `clk_48k`: derived sample-rate clock for synchronous data transfers
--! - `BCLCK`: 1.536 MHz I²S bit clock
--! - `XCK`: 18 MHz master clock to codec
--!
--! **Direction Summary**
--! - `ADC → FIR`: Source (Avalon-ST producer)  
--! - `FIR → DAC`: Sink   (Avalon-ST consumer)
--!
--! This design preserves full Avalon-ST handshake semantics while maintaining
--! continuous 48 kHz streaming compatibility with unmodified professor-provided modules.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity codec_top is
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
end entity codec_top;

architecture rtl of codec_top is

  --------------------------------------------------------------------
  -- Internal Signals
  --------------------------------------------------------------------
  --! PLL output: 18.432 MHz system clock derived from 50 MHz reference.
  signal SYS_CLCK : std_logic;

  --! 48 kHz frame clock for audio sample synchronization.
  signal clk_48k : std_logic;

  --! PLL lock indicator (unused but available for monitoring).
  signal locked : std_logic;

  --! 16-bit sample captured from ADC (codec_if output).
  signal adc_sample_reg : std_logic_vector(15 downto 0);

  --! 16-bit sample to be sent to DAC (codec_if input).
  signal dac_sample_reg : std_logic_vector(15 downto 0);

begin
  --------------------------------------------------------------------
  -- PLL: generate 18 MHz system clock from 50 MHz input
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
  -- I²C configuration for WM8731
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
  -- I²S codec interface (mono: left channel only)
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
      left_data_in            => dac_sample_reg,
      right_data_in => (others => '0'),
      left_data_out_neg_edge  => adc_sample_reg,
      right_data_out_neg_edge => open
    );

  --------------------------------------------------------------------
  -- Avalon-ST Source: ADC → FIR
  --------------------------------------------------------------------
  --! Process generating Avalon-ST source stream from ADC samples.
  adc_to_fir_proc : process (clk_48k, rst_n)
  begin
    if rst_n = '0' then
      Av_S_AUDIO_IN_valid <= '0';
      Av_S_AUDIO_IN       <= (others => '0');
    elsif rising_edge(clk_48k) then
      if Av_S_AUDIO_IN_ready = '1' then
        Av_S_AUDIO_IN       <= adc_sample_reg; -- present new sample
        Av_S_AUDIO_IN_valid <= '1';
      else
        Av_S_AUDIO_IN_valid <= '0'; -- FIR not ready, sample skipped
      end if;
    end if;
  end process adc_to_fir_proc;

  --------------------------------------------------------------------
  -- Avalon-ST Sink: FIR → DAC
  --------------------------------------------------------------------
  --! Process consuming Avalon-ST sink stream and driving DAC data.
  fir_to_dac_proc : process (clk_48k, rst_n)
  begin
    if rst_n = '0' then
      Av_S_AUDIO_OUT_ready <= '0';
      dac_sample_reg       <= (others => '0');
    elsif rising_edge(clk_48k) then
      Av_S_AUDIO_OUT_ready <= '1'; -- request next sample each frame
      if Av_S_AUDIO_OUT_valid = '1' then
        dac_sample_reg <= Av_S_AUDIO_OUT; -- latch FIR output to DAC
      end if;
    end if;
  end process fir_to_dac_proc;

end architecture rtl;
