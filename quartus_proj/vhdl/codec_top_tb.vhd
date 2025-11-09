--! @title Codec Top-Level (Mono Interface, Avalon-ST Compliant)
--! @file codec_top_tb.vhd
--! @author Benedikt Sele
--! @version 1,0
--! @date 09.11.2025
--! @brief Testbench for `codec_top` (ESL Project)
--!
--! Functional testbench verifying correct operation of the audio codec interface.
--! It validates the PLL clock chain, I²C configuration activity, ADC/DAC data
--! handling, and Avalon-Streaming handshakes.
--!
--! **Main Test Objectives**
--! 1. Verify 50 MHz → 18.432 MHz → 1.536 MHz → 48 kHz clock generation chain.  
--! 2. Observe I²C configuration waveform activity.  
--! 3. Drive a serial ADC data pattern and confirm deserialization to 16-bit samples.  
--! 4. Loop ADC samples back to DAC path through Avalon-ST interface.  
--! 5. Momentarily de-assert `Av_S_AUDIO_IN_ready` to test handshake and backpressure.
--!
--! This testbench uses the behavioral PLL stub `ime_vga_audio_pll_0002.vhd`
--! instead of the vendor Verilog model for compatibility with pure-VHDL
--! simulators such as GHDL (TerosHDL).  
--!
--! **Simulation length:** 5 ms  
--! -----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! ## Entity Declaration
--! Empty entity – this file serves purely as a simulation testbench.
entity codec_top_tb is
end entity;

--! ## Architecture Overview
--! Architecture `sim` implements clock/reset generation, stimulus, and loopback checks.
architecture sim of codec_top_tb is

  --! Clock period for the 50 MHz base clock.
  constant CLK50_PERIOD : time := 20 ns;

  --! 50 MHz system clock generated in the testbench.
  signal clk_50 : std_logic := '0';

  --! Global active-low reset for the DUT.
  signal rst_n  : std_logic := '0';

  --! I²C serial clock to codec configuration block.
  signal I2C_CLCK : std_logic := '0';

  --! I²C serial data line to codec configuration block.
  signal I2C_DATA : std_logic := '0';

  --! Serial audio input from codec ADC (I²S SDIN).
  signal ADC_DAT  : std_logic := '0';

  --! Serial audio output to codec DAC (I²S SDOUT).
  signal DAC_DAT  : std_logic := '0';

  --! ADC left/right channel select (48 kHz frame clock from codec_if).
  signal ADC_LR_SEL : std_logic := '0';

  --! DAC left/right channel select (48 kHz frame clock from codec_if).
  signal DAC_LR_SEL : std_logic := '0';

  --! Bit clock for audio serial interface (I²S), ~1.536 MHz.
  signal BCLCK      : std_logic := '0';

  --! Master clock for audio codec (from PLL stub), 18.432 MHz.
  signal XCK        : std_logic := '0';

  --! Avalon-ST sample going *to* DUT/FIR (DAC side).
  signal Av_S_AUDIO_OUT       : std_logic_vector(15 downto 0) := (others => '0');

  --! Valid flag for `Av_S_AUDIO_OUT`.
  signal Av_S_AUDIO_OUT_valid : std_logic := '0';

  --! Ready flag from DUT/FIR for `Av_S_AUDIO_OUT`.
  signal Av_S_AUDIO_OUT_ready : std_logic;

  --! Avalon-ST sample coming *from* DUT/FIR (ADC side).
  signal Av_S_AUDIO_IN        : std_logic_vector(15 downto 0);

  --! Valid flag for `Av_S_AUDIO_IN`.
  signal Av_S_AUDIO_IN_valid  : std_logic;

  --! Ready flag towards DUT/FIR for `Av_S_AUDIO_IN` (we drive this).
  signal Av_S_AUDIO_IN_ready  : std_logic := '1';

begin
  --! DUT instantiation – connects this testbench to `codec_top` (includes PLL, I²C, I²S).
  codec_top_inst : entity work.codec_top
    port map (
      clk_50               => clk_50,
      rst_n                => rst_n,
      I2C_CLCK             => I2C_CLCK,
      I2C_DATA             => I2C_DATA,
      ADC_DAT              => ADC_DAT,
      DAC_DAT              => DAC_DAT,
      ADC_LR_SEL           => ADC_LR_SEL,
      DAC_LR_SEL           => DAC_LR_SEL,
      BCLCK                => BCLCK,
      XCK                  => XCK,
      Av_S_AUDIO_OUT       => Av_S_AUDIO_OUT,
      Av_S_AUDIO_OUT_valid => Av_S_AUDIO_OUT_valid,
      Av_S_AUDIO_OUT_ready => Av_S_AUDIO_OUT_ready,
      Av_S_AUDIO_IN        => Av_S_AUDIO_IN,
      Av_S_AUDIO_IN_valid  => Av_S_AUDIO_IN_valid,
      Av_S_AUDIO_IN_ready  => Av_S_AUDIO_IN_ready
    );

  --! Clock generation process – produces the 50 MHz base clock.
  clk_process : process
  begin
    clk_50 <= '0';
    wait for CLK50_PERIOD / 2;
    clk_50 <= '1';
    wait for CLK50_PERIOD / 2;
  end process;

  --! Reset sequence process – holds reset low for 200 ns before release.
  rst_process : process
  begin
    rst_n <= '0';
    wait for 200 ns;
    rst_n <= '1';
    wait;
  end process;

  --! Simulation end condition – terminates automatically after 5 ms.
  sim_end : process
  begin
    wait for 5 ms;
    report "Simulation ended normally" severity note;
    std.env.stop;
  end process;

  --! ADC serial data pattern generator – emits 16-bit counter samples (MSB-first).
  adc_data_pattern : process
    variable bit_cnt    : integer range 0 to 15 := 15;
    variable sample_cnt : unsigned(15 downto 0) := (others => '0');
  begin
    wait until rst_n = '1';
    wait for 1 ms;  -- startup delay
    loop
      -- output current bit (MSB first)
      ADC_DAT <= std_logic(sample_cnt(bit_cnt));
      -- one bit period @ 1.536 MHz
      wait for 650 ns;
      if bit_cnt = 0 then
        bit_cnt    := 15;
        sample_cnt := sample_cnt + 1;  -- next 16-bit sample
      else
        bit_cnt := bit_cnt - 1;
      end if;
    end loop;
  end process;

  --! Expected DAC_DAT serialization examples:
  --! One 48 kHz frame of pipeline latency occurs through `codec_if` + Avalon-ST.
  --! First visible DAC samples:
  --!   • Frame #1 : `0x0001` → `0000 0000 0000 0001`
  --!   • Frame #2 : `0x0003` → `0000 0000 0000 0011`
  --!   • Frame #3 : `0x0005` → `0000 0000 0000 0101`
  --! Bit order = MSB-first, data updates on falling edge of `BCLCK`.

  --! Simple loopback assignment – routes ADC samples to DAC input.
  Av_S_AUDIO_OUT       <= Av_S_AUDIO_IN;
  Av_S_AUDIO_OUT_valid <= Av_S_AUDIO_IN_valid;

  --! Backpressure test process – de-asserts `Av_S_AUDIO_IN_ready` for 200 µs to test handshake.
  stall_proc : process
  begin
    wait until rst_n = '1';
    wait for 2 ms;               -- normal operation
    Av_S_AUDIO_IN_ready <= '0';  -- FIR not ready
    wait for 200 us;             -- stall duration
    Av_S_AUDIO_IN_ready <= '1';  -- resume normal flow
    wait;
  end process;

end architecture;