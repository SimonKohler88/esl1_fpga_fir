library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.FIR_types.all;

entity FIR_Filter is
port (
    clk : in std_logic;     -- 50 MHz
    rst :in std_logic;

    -- Avalon Stream AUDIO in und out von Benedikt.
    Av_S_AUDIO_IN: in std_logic_vector(15 downto 0);
    Av_S_AUDIO_IN_valid: in std_logic;
    Av_S_AUDIO_IN_ready: out std_logic;

    Av_S_AUDIO_OUT: out  std_logic_vector(15 downto 0);
    Av_S_AUDIO_OUT_valid: out std_logic;
    Av_S_AUDIO_OUT_ready: in std_logic;

    -- Filter Koeffs von Simon via UART
    FIR_Coeffs : in FIR_type_coeffs         -- 64 x 16bit 
);
end entity;

architecture FIR_Filter_Arch of FIR_Filter is
    -- Standard Setup
    constant INPUT_WIDTH : integer range 8 to 32 := 16;
    constant COEFF_WIDTH : integer range 8 to 32 := 16;
    constant OUTPUT_WIDTH : integer range 8 to 32 := 16;

    -- Capture signal history
    type input_registers is array(0 to FILTER_TAPS-1) of signed(INPUT_WIDTH-1 downto 0);
    signal delay_line_s  : input_registers := (others=>(others=>'0'));

    -- Wait for rising edge on Av_S_AUDIO_IN_valid
    signal fsclk_q : std_logic := '0';
    signal fsclk : std_logic := '0';

    type state_machine is (idle_st, active_st);
    signal state : state_machine := idle_st;

    signal counter : integer range 0 to FILTER_TAPS-1 := FILTER_TAPS-1;

    signal output       : signed(INPUT_WIDTH+COEFF_WIDTH-1 downto 0) := (others=>'0');
    signal accumulator  : signed(INPUT_WIDTH+COEFF_WIDTH-1 downto 0) := (others=>'0');

    signal data_o : std_logic_vector(15 downto 0);
    signal data_i : std_logic_vector(15 downto 0);

    signal valid_out: std_logic;

begin
    fsclk <= Av_S_AUDIO_IN_valid;
    data_i <= Av_S_AUDIO_IN;

    Av_S_AUDIO_OUT_valid <= valid_out;

    process(clk)
    variable sum_v : signed(INPUT_WIDTH+COEFF_WIDTH-1 downto 0) := (others=>'0');
    begin

    if rising_edge(clk) then
        fsclk_q <= fsclk;

        case state is
        when idle_st =>
            if fsclk = '1' and fsclk_q = '0' then
                state <= active_st;
            end if;

        when active_st =>
            -- Counter
            if counter > 0 then
                counter <= counter - 1;
            else
                counter <= FILTER_TAPS-1;
                state <= idle_st;
            end if;

            -- Delay line shifting
            if counter > 0 then
                delay_line_s(counter) <= delay_line_s(counter-1);
            else
                delay_line_s(counter) <= signed(data_i);
            end if;

            -- MAC operations
            if counter > 0 then
                sum_v := delay_line_s(counter) * signed( FIR_Coeffs(counter) );
                accumulator <= accumulator + sum_v;
            else
                accumulator <= (others=>'0');
                sum_v := delay_line_s(counter) * signed( FIR_Coeffs(counter) );
                output <= accumulator + sum_v;
            end if;


        end case;
        if counter=0 and state=active_st then
            valid_out <= '1';
            data_o <= std_logic_vector(signed(output(INPUT_WIDTH+COEFF_WIDTH-2 downto INPUT_WIDTH+COEFF_WIDTH-OUTPUT_WIDTH-1)));
        else
            valid_out <= '0';
            data_o <= (others=>'0');
        end if;
    end if;

    end process;
end architecture FIR_Filter_Arch;