
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.FIR_types.all;

entity FIR_Filter_tb is
end;

architecture bench of FIR_Filter_tb is
  -- Clock period
  constant clk_period : time := 20 ns;
  -- Generics
  -- Ports
  signal clk : std_logic;
  signal rst : std_logic;
  signal Av_S_AUDIO_IN : std_logic_vector(15 downto 0);
  signal Av_S_AUDIO_IN_valid : std_logic;
  signal Av_S_AUDIO_IN_ready : std_logic;
  signal Av_S_AUDIO_OUT : std_logic_vector(15 downto 0);
  signal Av_S_AUDIO_OUT_valid : std_logic;
  signal Av_S_AUDIO_OUT_ready : std_logic;
  signal FIR_Coeffs : FIR_type_coeffs;

  signal enabled :boolean:=true;
begin

  FIR_Filter_inst : entity work.FIR_Filter
  port map (
    clk => clk,
    rst => rst,
    Av_S_AUDIO_IN => Av_S_AUDIO_IN,
    Av_S_AUDIO_IN_valid => Av_S_AUDIO_IN_valid,
    Av_S_AUDIO_IN_ready => Av_S_AUDIO_IN_ready,
    Av_S_AUDIO_OUT => Av_S_AUDIO_OUT,
    Av_S_AUDIO_OUT_valid => Av_S_AUDIO_OUT_valid,
    Av_S_AUDIO_OUT_ready => Av_S_AUDIO_OUT_ready,
    FIR_Coeffs => FIR_Coeffs
  );
-- clk <= not clk after clk_period/2;

rst <= transport '0', '1' after 10 ns;

p_sys_clock : process
begin
    while enabled loop
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end loop;
    wait;  -- don't do it again
end process;

p_tests: process
begin
    wait for 1 us;
    enabled <= false;
    wait;
end process;
end;