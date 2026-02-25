--============================================================================= 
--
-- Simple PWM sequence
--
--============================================================================= 

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;

entity pwm_seq is
  generic(
    cnt_clk_max   : integer := 20000;
    cnt_pulse_max : integer := 1250
  );
  port(		
    clk     : in  std_logic;
    sel     : in  std_logic;
    led_out : out std_logic_vector(7 downto 0)
  );
end entity;

architecture behaviour of pwm_seq is
  signal pwm_out      : std_logic;
  signal polarity     : std_logic;
  signal duty_cycle   : integer range 0 to cnt_pulse_max;
  signal cnt_pulse    : integer range 0 to cnt_pulse_max;
  signal cnt_clk      : integer range 0 to cnt_clk_max;
  signal clk_intern_s : std_logic;

begin
-------------------------------------------------------------------------------
-- Duty Cycle
-------------------------------------------------------------------------------
  process(clk_intern_s, sel) 
  begin
    if sel = '0' then
			--
    elsif rising_edge(clk_intern_s) then
      if (polarity = '0') then
        if duty_cycle < (cnt_pulse_max - 1) then
          duty_cycle <= duty_cycle + 1;
          polarity <= '0';
        else
          polarity <= '1';
        end if;
      elsif (polarity = '1') then 
        if (duty_cycle > 1) then
          duty_cycle <= duty_cycle - 1;
          polarity <= '1';
        else
          polarity <= '0';
        end if;
      end if;
    end if;
  end process;
		
-------------------------------------------------------------------------------
-- Counting
-------------------------------------------------------------------------------
  process(clk, sel) 
  begin
    if sel = '0' then
      cnt_clk <= 0;
    elsif rising_edge(clk) then
      if cnt_clk = (cnt_clk_max - 1) then  
        cnt_clk <= 0;
      else
        cnt_clk <= cnt_clk + 1;					
      end if; 

      if cnt_pulse < (cnt_pulse_max - 1) then
        cnt_pulse <= cnt_pulse + 1;
      else
        cnt_pulse <= 0;
      end if;
    end if;
  end process;
		
  clk_intern_s <= '0' when cnt_clk < cnt_clk_max else '1';

-------------------------------------------------------------------------------
-- Pulsing
-------------------------------------------------------------------------------
  process(clk) 
  begin
    if rising_edge(clk) then
      if (duty_cycle > cnt_pulse) then
        pwm_out <= '1';
      else
        pwm_out <= '0';
      end if;
    end if;
  end process;

-------------------------------------------------------------------------------
-- LED output
-------------------------------------------------------------------------------
  led_out(7 downto 4) <= (others => pwm_out)		when sel = '1' else (others => '0');
  led_out(3 downto 0) <= (others => not pwm_out) 	when sel = '1' else (others => '0');

end architecture;
