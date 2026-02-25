--============================================================================= 
--
-- Mode Controller
--
-- Toggles through choosing 1 out of 5 possible LED sequence modes
--
--============================================================================= 

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;

entity control_mux is
  port (		
    clk       : in 	std_logic;
    user_btn  : in	std_logic;
    led_in    : in	std_logic_vector(39 downto 0);
    led_out   : out	std_logic_vector(7 downto 0);
    sel       : out	std_logic_vector(4 downto 0)
  );
end entity;

architecture behavioural of control_mux is

  signal sel_reg  : std_logic_vector(4 downto 0) := "00001";
  signal reset	  : std_logic :='1';
  signal keyout	  : std_logic;
  signal key_db	  : std_logic := '0';
  signal dbcnt 	  : integer range 0 to 63 := 0;
	
begin
-------------------------------------------------------------------------------
-- debounce key
-------------------------------------------------------------------------------
  process 
  begin
    wait until rising_edge(clk);
    if (user_btn=key_db) then 
      dbcnt <= 0;
    else                   
      dbcnt <= dbcnt+1;
    end if;
    if (dbcnt=63) then 
      key_db <= user_btn; 
    end if;
  end process;
	
  keyout <= key_db;

-------------------------------------------------------------------------------
-- toggle through states
-------------------------------------------------------------------------------
  
  process(keyout, reset)
  begin
    if reset = '0' then
      sel_reg(4 downto 0) <= "00001";
    elsif falling_edge(keyout) then
      sel_reg(4 downto 0) <= sel_reg(3 downto 0)&sel_reg(4);
    end if;
  end process;
	
-------------------------------------------------------------------------------
-- Pass LED sequence to LEDs depending on mode
-------------------------------------------------------------------------------
  process(sel_reg, led_in)
  begin		
    case sel_reg is	
      when "00001"  => led_out <= led_in (39 downto 32);
      when "00010" 	=> led_out <= led_in (31 downto 24);
      when "00100" 	=> led_out <= led_in (23 downto 16);
      when "01000" 	=> led_out <= led_in (15 downto 8);
      when "10000" 	=> led_out <= led_in (7 downto 0);
      when others => led_out <="00000000";
    end case;
  end process;
	
  reset <= '0' when led_in (39 downto 32) = "11111111" else
          '1';
          
  sel <= sel_reg;

end architecture;