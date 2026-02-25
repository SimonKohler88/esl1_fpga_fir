--============================================================================= 
--
-- Shift Register Sequence
--
--============================================================================= 

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;

entity shift_reg_seq is
  generic ( 
    cnt_max : integer := 1_000_000
  );
  
  port (		
    clk		  : in 	std_logic;						-- 12 MHz
    sel	    : in 	std_logic;
    led_out	: out	std_logic_vector(7 downto 0)
  );
end entity;

architecture behavioural of shift_reg_seq is
	
  signal cnt			  : integer range 0 to cnt_max;
  signal shift_reg	: std_logic_vector(7 downto 0) := X"00";
  signal dummy		  : std_logic := '1';
	
begin
-------------------------------------------------------------------------------
-- shift register
-------------------------------------------------------------------------------
  process(clk, sel)
  begin
    if sel = '0' then
      cnt <= 0;
      shift_reg <= "00000000";
    elsif rising_edge(clk) then
      if cnt = (cnt_max - 1) then  
        cnt <= 0;
        shift_reg(7 downto 0) <= dummy & shift_reg(7 downto 1);
      else
        cnt <= cnt + 1;					
      end if; 
    end if;
  end process;
  
  dummy <= '0' when shift_reg = "11111111" else 
          '1' when shift_reg = "00000000";

-------------------------------------------------------------------------------
-- LED output
-------------------------------------------------------------------------------
  led_out <= shift_reg;

end architecture;