--============================================================================= 
--
-- KnightRider
--
--============================================================================= 

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;

entity knightrider is
  generic ( 
    cnt_clk_max     : integer := 1_000_000;
    cnt_pwm_max     : integer := 100_000;
    duty_cycle_pwm1 : integer := 70_000;
    duty_cycle_pwm2 : integer := 95_000
	);
	
  port (		
    clk     : in  std_logic;
    sel     : in  std_logic;
    led_out : out std_logic_vector(7 downto 0)
  );
end entity;

architecture behavioural of knightrider is

  signal cnt_led  : std_logic_vector(4 downto 0);
  signal cnt_clk  : integer range 0 to cnt_clk_max;
  signal cnt_pwm  : integer range 0 to cnt_pwm_max;
  signal pwm1     : std_logic;
  signal pwm2     : std_logic;

begin
-------------------------------------------------------------------------------
-- counter pwm
-------------------------------------------------------------------------------
  process (clk, sel, pwm1, pwm2)
  begin
    if sel = '0' then
      cnt_pwm <= 0;
      pwm1 <= '0';
      pwm2 <= '0';
    elsif rising_edge(clk) then
      cnt_pwm <= cnt_pwm + 1;
      if cnt_pwm = duty_cycle_pwm1 then
        pwm1 <= '1';
      end if;
      
      if cnt_pwm = duty_cycle_pwm2 then
        pwm2 <= '1';
      end if;
      
      if cnt_pwm = cnt_pwm_max then
        cnt_pwm <= 0;
        pwm1 <= '0';
        pwm2 <= '0';
      end if;		
    end if;	
  end process;
	
-------------------------------------------------------------------------------
-- counter clock and led
-------------------------------------------------------------------------------
  process (clk, sel)
  begin
    if sel = '0' then
			cnt_clk <= 0;
			cnt_led <= (others => '0');
    elsif rising_edge(clk) then
      if cnt_clk = (cnt_clk_max - 1) then
        cnt_clk <= 0;
        if cnt_led = "10010" then
          cnt_led <= "00000";
        else
          cnt_led <= cnt_led + '1';
        end if;
      else
        cnt_clk <= cnt_clk + 1;
      end if;
    end if;
  end process;

-------------------------------------------------------------------------------
-- LED output
-------------------------------------------------------------------------------
  process(cnt_led, sel, pwm1, pwm2)
  begin
    if sel = '1' then
      case cnt_led is
        when "00000" => led_out <= "0000000" & '1';
        when "00001" => led_out <= "000000" & '1' & pwm1;
        when "00010" => led_out <= "00000" & '1' & pwm1 & pwm2;
        when "00011" => led_out <= "0000" & '1' & pwm1 & pwm2 & '0';
        when "00100" => led_out <= "000" & '1' & pwm1 & pwm2 & "00";
        when "00101" => led_out <= "00" & '1' & pwm1 & pwm2 & "000";
        when "00110" => led_out <= '0' & '1' & pwm1 & pwm2 & "0000";
        when "00111" => led_out <= '1' & pwm1 & pwm2 & "00000";
        when "01000" => led_out <= '1' & pwm1 & "000000";
        when "01001" => led_out <= '1' &  "0000000";
        when "01010" => led_out <= pwm1 & '1' & "000000";
        when "01011" => led_out <= pwm2 & pwm1 & '1' & "00000";
        when "01100" => led_out <= '0' & pwm2 & pwm1 & '1' & "0000";
        when "01101" => led_out <= "00" & pwm2 & pwm1 & '1' & "000";
        when "01110" => led_out <= "000" & pwm2 & pwm1 & '1' & "00";
        when "01111" => led_out <= "0000" & pwm2 & pwm1 & '1' & '0';
        when "10000" => led_out <= "00000" & pwm2 & pwm1 & '1';
        when "10001" => led_out <= "000000" & pwm1 & '1';
        when "10010" => led_out <= "0000000" & '1';
        when others => led_out <=  "00000000";
      end case;
    else 
      led_out <=  "001000" & pwm2 & pwm1;
    end if;
  end process;
	
end architecture;