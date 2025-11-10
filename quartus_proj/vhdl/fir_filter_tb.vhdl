
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
    Av_S_AUDIO_IN_valid <= '0';
    Av_S_AUDIO_IN <= "0000000000000000";

    FIR_Coeffs <= (
        x"0013", x"0008", x"0005", x"000C",
        x"0016", x"0025", x"0037", x"004E",
        x"0069", x"008B", x"00B2", x"00E0",
        x"0114", x"014E", x"018E", x"01D3",
        x"021D", x"026A", x"02BA", x"030B",
        x"035B", x"03AA", x"03F5", x"043B",
        x"047B", x"04B2", x"04E0", x"0504",
        x"051C", x"0528", x"0528", x"051C",
        x"0504", x"04E0", x"04B2", x"047B",
        x"043B", x"03F5", x"03AA", x"035B",
        x"030B", x"02BA", x"026A", x"021D",
        x"01D3", x"018E", x"014E", x"0114",
        x"00E0", x"00B2", x"008B", x"0069",
        x"004E", x"0037", x"0025", x"0016",
        x"000C", x"0005", x"0001", x"0000",
        x"0000", x"0000", x"0000", x"0000"
    );

    wait until Av_S_AUDIO_IN_ready = '1' for 100 ns;

    Av_S_AUDIO_IN_valid <= '1';
    Av_S_AUDIO_IN <= "0111111111111111";
    wait for 50 ns;
    Av_S_AUDIO_IN_valid <= '0';
    wait for 700 ns;
    Av_S_AUDIO_OUT_ready <= '1';
    wait until Av_S_AUDIO_OUT_valid = '1' for 700 ns;

    Av_S_AUDIO_IN_valid <= '1';
    Av_S_AUDIO_IN <= "0000000000000000";
    wait for 50 ns;
    Av_S_AUDIO_IN_valid <= '0';
    wait for 700 ns;
    Av_S_AUDIO_OUT_ready <= '1';
    wait until Av_S_AUDIO_OUT_valid = '1' for 700 ns;

    Av_S_AUDIO_IN_valid <= '1';
    Av_S_AUDIO_IN <= "0000000000000000";
    wait for 50 ns;
    Av_S_AUDIO_IN_valid <= '0';
    wait for 700 ns;
    Av_S_AUDIO_OUT_ready <= '1';
    wait until Av_S_AUDIO_OUT_valid = '1' for 700 ns;

    Av_S_AUDIO_IN_valid <= '1';
    Av_S_AUDIO_IN <= "0000000000000000";
    wait for 50 ns;
    Av_S_AUDIO_IN_valid <= '0';
    wait for 700 ns;
    Av_S_AUDIO_OUT_ready <= '1';
    wait until Av_S_AUDIO_OUT_valid = '1' for 700 ns;

    Av_S_AUDIO_IN_valid <= '1';
    Av_S_AUDIO_IN <= "0000000000000000";
    wait for 50 ns;
    Av_S_AUDIO_IN_valid <= '0';
    wait for 700 ns;
    Av_S_AUDIO_OUT_ready <= '1';
    wait until Av_S_AUDIO_OUT_valid = '1' for 700 ns;

    Av_S_AUDIO_IN_valid <= '1';
    Av_S_AUDIO_IN <= "0000000000000000";
    wait for 50 ns;
    Av_S_AUDIO_IN_valid <= '0';
    wait for 700 ns;
    Av_S_AUDIO_OUT_ready <= '1';
    wait until Av_S_AUDIO_OUT_valid = '1' for 700 ns;

    Av_S_AUDIO_IN_valid <= '1';
    Av_S_AUDIO_IN <= "0000000000000000";
    wait for 50 ns;
    Av_S_AUDIO_IN_valid <= '0';
    wait for 700 ns;
    Av_S_AUDIO_OUT_ready <= '1';
    wait until Av_S_AUDIO_OUT_valid = '1' for 700 ns;

    wait for 300 ns;

    enabled <= false;
    wait;
end process;
end;