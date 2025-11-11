library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.FIR_types.all;

entity uart is
    Port (
        clk     : in  STD_LOGIC;
        reset_n   : in  STD_LOGIC;
        pio_data_out: out STD_LOGIC_VECTOR (7 downto 0); -- debug and alive signals

         -- Filter Koeffs von Simon via UART
        FIR_Coeffs : out FIR_type_coeffs;         -- 64 x 16bit 

        uart_rxd : in  STD_LOGIC;
        uart_txd : out STD_LOGIC
    );
end uart;

architecture Behavioral of uart is

    component uart_nios is
        port (
            clk_clk                          : in  std_logic                     := 'X';             -- clk
            pio_0_external_connection_export : out std_logic_vector(7 downto 0);                     -- export
            pll_0_locked_export              : out std_logic;                                        -- export
            reset_reset_n                    : in  std_logic                     := 'X';             -- reset_n
            mm_bridge_0_m0_waitrequest       : in  std_logic                     := 'X';             -- waitrequest
            mm_bridge_0_m0_readdata          : in  std_logic_vector(31 downto 0) := (others => 'X'); -- readdata
            mm_bridge_0_m0_readdatavalid     : in  std_logic                     := 'X';             -- readdatavalid
            mm_bridge_0_m0_burstcount        : out std_logic_vector(0 downto 0);                     -- burstcount
            mm_bridge_0_m0_writedata         : out std_logic_vector(31 downto 0);                    -- writedata
            mm_bridge_0_m0_address           : out std_logic_vector(9 downto 0);                     -- address
            mm_bridge_0_m0_write             : out std_logic;                                        -- write
            mm_bridge_0_m0_read              : out std_logic;                                        -- read
            mm_bridge_0_m0_byteenable        : out std_logic_vector(3 downto 0);                     -- byteenable
            mm_bridge_0_m0_debugaccess       : out std_logic;                                        -- debugaccess
            clock_bridge_0_out_clk_clk       : out std_logic;
            uart_0_external_connection_rxd   : in  std_logic                     := 'X';             -- rxd
            uart_0_external_connection_txd   : out std_logic                                         -- txd                                         -- clk
        );
    end component uart_nios;


    signal pll_locked: std_logic;

    -- Avalon MM signals with simpler names
    signal av_mm_wait_req     : std_logic;
    signal av_mm_rdata        : std_logic_vector(31 downto 0);
    signal av_mm_rdata_valid  : std_logic;
    signal av_mm_burst_count  : std_logic_vector(0 downto 0);
    signal av_mm_wdata        : std_logic_vector(31 downto 0);
    signal av_mm_addr         : std_logic_vector(9 downto 0);
    signal av_mm_wr           : std_logic;
    signal av_mm_rd           : std_logic;
    signal av_mm_byte_en      : std_logic_vector(3 downto 0);
    signal av_mm_debug_access : std_logic;
    signal clk_out      : std_logic;
    signal pio_int      : std_logic_vector(7 downto 0);

    -- Buffer array signal
    --signal buffer_array : buffer_array_t;
    signal coeff_array : FIR_type_coeffs;

begin

    u0 : component uart_nios
        port map (
            reset_reset_n                    => reset_n,                    --                     reset.reset_n
            clk_clk                          => clk,                          --                       clk.clk
            pll_0_locked_export              => pll_locked,              --              pll_0_locked.export
            pio_0_external_connection_export => pio_int,  -- pio_0_external_connection.export
            mm_bridge_0_m0_waitrequest       => av_mm_wait_req,       --            mm_bridge_0_m0.waitrequest
            mm_bridge_0_m0_readdata          => av_mm_rdata,          --                          .readdata
            mm_bridge_0_m0_readdatavalid     => av_mm_rdata_valid,     --                          .readdatavalid
            mm_bridge_0_m0_burstcount        => av_mm_burst_count,        --                          .burstcount
            mm_bridge_0_m0_writedata         => av_mm_wdata,         --                          .writedata
            mm_bridge_0_m0_address           => av_mm_addr,           --                          .address
            mm_bridge_0_m0_write             => av_mm_wr,             --                          .write
            mm_bridge_0_m0_read              => av_mm_rd,              --                          .read
            mm_bridge_0_m0_byteenable        => av_mm_byte_en,        --                          .byteenable
            mm_bridge_0_m0_debugaccess       => av_mm_debug_access,       --                          .debugaccess
            clock_bridge_0_out_clk_clk       => clk_out,        --    clock_bridge_0_out_clk.clk
            uart_0_external_connection_rxd   => uart_rxd,        -- rxd
            uart_0_external_connection_txd   => uart_txd                                         -- txd

        );

    -- Avalon MM never waits
    av_mm_wait_req <= '0';

    -- test wise
    pio_data_out <= pio_int(0) & coeff_array(0)(6 downto 0);
    FIR_Coeffs <= coeff_array;

    -- Memory-mapped buffer access process
    process(clk_out, reset_n)
        variable addr_int : integer range 0 to 1023;
    begin
        if reset_n = '0' then
            -- Reset buffer array to zeros
            coeff_array <= (others => (others => '0'));
            av_mm_rdata <= (others => '0');
            av_mm_rdata_valid <= '0';
        elsif rising_edge(clk_out) then
            -- Convert address to integer
            addr_int := to_integer(unsigned(av_mm_addr));

            -- Default: no valid read data
            av_mm_rdata_valid <= '0';
            av_mm_rdata <= (others => '0');

            -- Handle write operations
            if av_mm_wr = '1' then
                if addr_int <= FILTER_TAPS-1 then
                    -- Write to buffer (only lower 16 bits, ignore upper 16 bits)
                    coeff_array(addr_int) <= av_mm_wdata(15 downto 0);
                end if;
                -- If address out of range, ignore write (no action needed)
            end if;

            -- Handle read operations
            if av_mm_rd = '1' then
                av_mm_rdata_valid <= '1';
                if addr_int <= FILTER_TAPS-1 then
                    -- Read from buffer (lower 16 bits, upper 16 bits = 0)
                    av_mm_rdata(15 downto 0) <= coeff_array(addr_int);
                    av_mm_rdata(31 downto 16) <= (others => '0');
                else
                    -- Address out of range, return all zeros
                    av_mm_rdata <= (others => '0');
                end if;
            end if;
        end if;
    end process;


end Behavioral;