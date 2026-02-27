library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity BUS_BYPASS_MUX_tb is
end entity BUS_BYPASS_MUX_tb;

architecture sim of BUS_BYPASS_MUX_tb is

    constant CLK_PERIOD : time := 5 ns; -- 200 MHz

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '1';
    signal sel   : std_logic := '0';

    signal av_in1_data  : std_logic_vector(15 downto 0) := (others => '0');
    signal av_in1_valid : std_logic := '0';
    signal av_in1_ready : std_logic;

    signal av_in2_data  : std_logic_vector(15 downto 0) := (others => '0');
    signal av_in2_valid : std_logic := '0';
    signal av_in2_ready : std_logic;

    signal av_out1_data  : std_logic_vector(15 downto 0);
    signal av_out1_valid : std_logic;
    signal av_out1_ready : std_logic := '0';

    signal av_out2_data  : std_logic_vector(15 downto 0);
    signal av_out2_valid : std_logic;
    signal av_out2_ready : std_logic := '0';

    procedure pulse_out(signal out_signal: out std_logic; signal clk_p : in std_logic) is
    begin
        wait until rising_edge(clk_p);
        out_signal <= '1';
        wait until rising_edge(clk_p);
        out_signal <= '0';
    end procedure pulse_out;

begin

    -- Clock generation
    clk <= not clk after CLK_PERIOD / 2;

    -- DUT instantiation
    dut : entity work.BUS_BYPASS_MUX
        port map (
            clk            => clk,
            rst            => rst,
            sel            => sel,
            av_in1_data    => av_in1_data,
            av_in1_valid   => av_in1_valid,
            av_in1_ready   => av_in1_ready,
            av_in2_data    => av_in2_data,
            av_in2_valid   => av_in2_valid,
            av_in2_ready   => av_in2_ready,
            av_out1_data   => av_out1_data,
            av_out1_valid  => av_out1_valid,
            av_out1_ready  => av_out1_ready,
            av_out2_data   => av_out2_data,
            av_out2_valid  => av_out2_valid,
            av_out2_ready  => av_out2_ready
        );

    -- Stimulus process
    stim_proc : process
    begin
        -- Reset phase
        rst <= '1';
        wait for CLK_PERIOD * 3;
        rst <= '0';
        wait for CLK_PERIOD;

        -----------------------------------------------------------------------
        -- sel = '0' : Normal operation (in1 -> out1, in2 -> out2)
        -----------------------------------------------------------------------
        sel <= '0';

        -- Drive input data and valid signals
        av_in1_data  <= x"AAAA";
        av_in1_valid <= '1';
        av_in2_data  <= x"BBBB";
        av_in2_valid <= '1';
        av_out1_ready <= '1';
        av_out2_ready <= '1';
        wait for CLK_PERIOD;

        -- Check data routing
        assert av_out1_data = x"AAAA"
            report "sel=0: out1_data mismatch, expected AAAA" severity error;
        assert av_out2_data = x"BBBB"
            report "sel=0: out2_data mismatch, expected BBBB" severity error;

        -- Check valid routing
        assert av_out1_valid = '1'
            report "sel=0: out1_valid should be 1" severity error;
        assert av_out2_valid = '1'
            report "sel=0: out2_valid should be 1" severity error;

        -- Check ready routing
        assert av_in1_ready = '1'
            report "sel=0: in1_ready should follow out1_ready=1" severity error;
        assert av_in2_ready = '1'
            report "sel=0: in2_ready should follow out2_ready=1" severity error;

        -- Test with ready de-asserted
        av_out1_ready <= '0';
        av_out2_ready <= '0';
        wait for CLK_PERIOD;

        assert av_in1_ready = '0'
            report "sel=0: in1_ready should follow out1_ready=0" severity error;
        assert av_in2_ready = '0'
            report "sel=0: in2_ready should follow out2_ready=0" severity error;

            
        wait for CLK_PERIOD;
        --visualize paths with pulses
        av_in1_data <= (others=>'0');
        av_in2_data <= (others=>'0');
        av_in1_valid <= '0';
        av_in2_valid <= '0';
        wait for CLK_PERIOD;
        
        pulse_out(av_out1_ready, clk);
        pulse_out(av_in1_valid, clk);
        pulse_out(av_in1_data(0), clk);

        pulse_out(av_out2_ready, clk);
        pulse_out(av_in2_valid, clk);
        pulse_out(av_in2_data(0), clk);
        wait for CLK_PERIOD;

        

        -- Change data values
        av_in1_data  <= x"1234";
        av_in2_data  <= x"5678";
        av_out1_ready <= '1';
        av_out2_ready <= '1';
        wait for CLK_PERIOD;

        assert av_out1_data = x"1234"
            report "sel=0: out1_data mismatch, expected 1234" severity error;
        assert av_out2_data = x"5678"
            report "sel=0: out2_data mismatch, expected 5678" severity error;

        wait for CLK_PERIOD * 2;

        -----------------------------------------------------------------------
        -- sel = '1' : Bypass (in2 -> out1, out2 disabled)
        -----------------------------------------------------------------------
        sel <= '1';

        av_in1_data  <= x"CCCC";
        av_in1_valid <= '1';
        av_in2_data  <= x"DDDD";
        av_in2_valid <= '1';
        av_out1_ready <= '1';
        av_out2_ready <= '1';
        wait for CLK_PERIOD;

        -- out1 should get in2 data
        assert av_out1_data = x"DDDD"
            report "sel=1: out1_data mismatch, expected DDDD (bypass from in2)" severity error;
        assert av_out1_valid = '1'
            report "sel=1: out1_valid should follow in2_valid=1" severity error;

        -- out2 should be disabled
        assert av_out2_data = x"0000"
            report "sel=1: out2_data should be 0000" severity error;
        assert av_out2_valid = '0'
            report "sel=1: out2_valid should be 0" severity error;

        -- Ready routing in bypass mode
        assert av_in1_ready = '1'
            report "sel=1: in1_ready should follow out2_ready=1" severity error;
        assert av_in2_ready = '0'
            report "sel=1: in2_ready should be 0 in bypass" severity error;

        -- Test valid de-assertion
        av_in2_valid <= '0';
        wait for CLK_PERIOD;

        assert av_out1_valid = '0'
            report "sel=1: out1_valid should follow in2_valid=0" severity error;

        wait for CLK_PERIOD * 2;

       wait for CLK_PERIOD;
        --visualize paths with pulses
        av_in1_data <= (others=>'0');
        av_in2_data <= (others=>'0');
        av_in1_valid <= '0';
        av_in2_valid <= '0';
        av_out1_ready <= '0';
        av_out2_ready <= '0';
        wait for CLK_PERIOD;
        
        pulse_out(av_out1_ready, clk);
        pulse_out(av_in1_valid, clk);
        pulse_out(av_in1_data(0), clk);

        pulse_out(av_out2_ready, clk);
        pulse_out(av_in2_valid, clk);
        pulse_out(av_in2_data(0), clk);
        wait for CLK_PERIOD;

        -----------------------------------------------------------------------
        -- Toggle sel back to '0'
        -----------------------------------------------------------------------
        sel <= '0';
        av_in1_data  <= x"F00D";
        av_in1_valid <= '1';
        av_in2_data  <= x"CAFE";
        av_in2_valid <= '1';
        wait for CLK_PERIOD;

        assert av_out1_data = x"F00D"
            report "sel=0 (return): out1_data mismatch" severity error;
        assert av_out2_data = x"CAFE"
            report "sel=0 (return): out2_data mismatch" severity error;

        wait for CLK_PERIOD * 3;

        report "*** Simulation finished ***" severity note;
        wait;
    end process;

end architecture sim;
