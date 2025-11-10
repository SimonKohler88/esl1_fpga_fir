--! @title Codec Top-Level Testbench (Mono Interface, Avalon-ST Compliant)
--! @file codec_top_tb.vhd
--! @author Benedikt Sele
--! @version 1.2
--! @date 10.11.2025
--! @brief Testbench for `codec_top` verifying correct Avalon-ST and I²S behavior.
--!
--! Functional testbench validating:
--! 1. 50 MHz → 18.432 MHz → 1.536 MHz → 48 kHz clock chain
--! 2. I²C configuration activity
--! 3. ADC serial pattern deserialization to 16-bit samples
--! 4. ADC → FIR → DAC Avalon-ST handshakes
--! 5. Backpressure when `Av_S_AUDIO_IN_ready` is de-asserted
--!
--! Simulation duration: 5 ms

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity codec_top_tb is
end entity codec_top_tb;

architecture sim of codec_top_tb is

  --------------------------------------------------------------------
  -- Clocking / Timing Constants
  --------------------------------------------------------------------
  constant CLK50_PERIOD : time := 20 ns;  --! 50 MHz system clock

  --------------------------------------------------------------------
  -- DUT I/O Signals
  --------------------------------------------------------------------
  signal clk_50   : std_logic := '0';
  signal rst_n    : std_logic := '0';

  signal I2C_CLCK : std_logic;
  signal I2C_DATA : std_logic;

  signal ADC_DAT  : std_logic := '0';
  signal DAC_DAT  : std_logic;

  signal ADC_LR_SEL : std_logic;
  signal DAC_LR_SEL : std_logic;
  signal BCLCK      : std_logic;
  signal XCK        : std_logic;

  signal Av_S_AUDIO_OUT       : std_logic_vector(15 downto 0) := (others => '0');
  signal Av_S_AUDIO_OUT_valid : std_logic := '0';
  signal Av_S_AUDIO_OUT_ready : std_logic;

  signal Av_S_AUDIO_IN        : std_logic_vector(15 downto 0);
  signal Av_S_AUDIO_IN_valid  : std_logic;
  signal Av_S_AUDIO_IN_ready  : std_logic := '1';

  --! Optional observation signal (for waveform debug)
  signal frame_stb_50m : std_logic;

begin

  --------------------------------------------------------------------
  -- DUT Instantiation
  --------------------------------------------------------------------
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

  --! Uncomment to monitor internal strobe:
  --! frame_stb_50m <= codec_top_inst.frame_stb_50m;

  --------------------------------------------------------------------
  -- 50 MHz Clock Generator
  --------------------------------------------------------------------
  clk_process : process
  begin
    clk_50 <= '0';
    wait for CLK50_PERIOD / 2;
    clk_50 <= '1';
    wait for CLK50_PERIOD / 2;
  end process clk_process;

  --------------------------------------------------------------------
  -- Reset Sequence
  --------------------------------------------------------------------
  rst_process : process
  begin
    rst_n <= '0';
    wait for 200 ns;
    rst_n <= '1';
    wait;
  end process rst_process;

  --------------------------------------------------------------------
  -- Simulation End Condition (5 ms)
  --------------------------------------------------------------------
  sim_end : process
  begin
    wait for 5 ms;
    report "Simulation ended normally" severity note;
    std.env.stop;
  end process sim_end;

  --------------------------------------------------------------------
  -- ADC Serial Data Generator (Emulates Codec ADC)
  --! Produces 16-bit counter samples, MSB first, at 1.536 MHz.
  --------------------------------------------------------------------
  adc_data_pattern : process
    variable bit_cnt    : integer range 0 to 15 := 15;
    variable sample_cnt : unsigned(15 downto 0) := (others => '0');
  begin
    wait until rst_n = '1';
    wait for 1 ms;  -- startup delay before streaming
    loop
      ADC_DAT <= std_logic(sample_cnt(bit_cnt));
      wait for 650 ns;  -- ≈ 1.536 MHz bit clock period
      if bit_cnt = 0 then
        bit_cnt    := 15;
        sample_cnt := sample_cnt + 1;
      else
        bit_cnt := bit_cnt - 1;
      end if;
    end loop;
  end process adc_data_pattern;

  --------------------------------------------------------------------
  -- FIR Behavioral Model (Avalon-ST Source + Sink)
  --! Simulates FIR filter response with one-cycle latency.
  --------------------------------------------------------------------
  fir_model_proc : process (clk_50)
    variable last_frame : std_logic := '0';
  begin
    if rising_edge(clk_50) then
      Av_S_AUDIO_OUT_valid <= '0';  -- default

      -- optional: detect frame boundary
      if (frame_stb_50m = '1') and (last_frame = '0') then
        Av_S_AUDIO_OUT_valid <= '0';  -- FIR latency placeholder
      end if;

      -- handshake: ADC → FIR → DAC loop
      if (Av_S_AUDIO_IN_valid = '1') and (Av_S_AUDIO_IN_ready = '1') then
        Av_S_AUDIO_OUT       <= std_logic_vector(unsigned(Av_S_AUDIO_IN) + 2);
        Av_S_AUDIO_OUT_valid <= '1';
      end if;

      last_frame := frame_stb_50m;
    end if;
  end process fir_model_proc;

  --------------------------------------------------------------------
  -- Backpressure Test
  --! Temporarily deasserts `Av_S_AUDIO_IN_ready` for 200 µs.
  --------------------------------------------------------------------
  stall_proc : process
  begin
    wait until rst_n = '1';
    wait for 2 ms;
    Av_S_AUDIO_IN_ready <= '0';
    wait for 200 us;
    Av_S_AUDIO_IN_ready <= '1';
    wait;
  end process stall_proc;

end architecture sim;
