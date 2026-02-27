library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity BUS_BYPASS_MUX is
    port (
        clk   : in std_logic;  -- system clock
        rst   : in std_logic;  -- synchronous reset, active high
        sel : in std_logic;

        av_in1_data : in std_logic_vector(15 downto 0);
        av_in1_valid : in std_logic;
        av_in1_ready : out std_logic;

        av_in2_data : in std_logic_vector(15 downto 0);
        av_in2_valid : in std_logic;
        av_in2_ready : out std_logic;

        av_out1_data : out std_logic_vector(15 downto 0);
        av_out1_valid : out std_logic;
        av_out1_ready : in std_logic;

        av_out2_data : out std_logic_vector(15 downto 0);
        av_out2_valid : out std_logic;
        av_out2_ready : in std_logic
    );
end entity BUS_BYPASS_MUX;

architecture rtl of BUS_BYPASS_MUX is
begin


    -- Normal Operation sel:0
    -- data mux
    with sel select
        av_out1_data <= av_in1_data when '0' , av_in2_data when others;
    
    with sel select
        av_out2_data <= av_in1_data when '1' , av_in2_data when others;
    
    -- valid mux
    with sel select
        av_out1_valid <= av_in1_valid when '0' , av_in2_valid when others;
    
    with sel select
        av_out2_valid <= av_in1_valid when '1' , av_in2_valid when others;
   
    -- ready mux
    with sel select
        av_in1_ready <= av_out1_ready when '0' , av_out2_ready when others;
    
    with sel select
        av_in2_ready <= av_out1_ready when '1' , av_out2_ready when others;
    
end architecture;