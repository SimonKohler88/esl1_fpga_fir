	component uart_nios is
		port (
			clk_clk                          : in  std_logic                     := 'X';             -- clk
			clock_bridge_0_out_clk_clk       : out std_logic;                                        -- clk
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
			pio_0_external_connection_export : out std_logic_vector(7 downto 0);                     -- export
			pll_0_locked_export              : out std_logic;                                        -- export
			reset_reset_n                    : in  std_logic                     := 'X'              -- reset_n
		);
	end component uart_nios;

	u0 : component uart_nios
		port map (
			clk_clk                          => CONNECTED_TO_clk_clk,                          --                       clk.clk
			clock_bridge_0_out_clk_clk       => CONNECTED_TO_clock_bridge_0_out_clk_clk,       --    clock_bridge_0_out_clk.clk
			mm_bridge_0_m0_waitrequest       => CONNECTED_TO_mm_bridge_0_m0_waitrequest,       --            mm_bridge_0_m0.waitrequest
			mm_bridge_0_m0_readdata          => CONNECTED_TO_mm_bridge_0_m0_readdata,          --                          .readdata
			mm_bridge_0_m0_readdatavalid     => CONNECTED_TO_mm_bridge_0_m0_readdatavalid,     --                          .readdatavalid
			mm_bridge_0_m0_burstcount        => CONNECTED_TO_mm_bridge_0_m0_burstcount,        --                          .burstcount
			mm_bridge_0_m0_writedata         => CONNECTED_TO_mm_bridge_0_m0_writedata,         --                          .writedata
			mm_bridge_0_m0_address           => CONNECTED_TO_mm_bridge_0_m0_address,           --                          .address
			mm_bridge_0_m0_write             => CONNECTED_TO_mm_bridge_0_m0_write,             --                          .write
			mm_bridge_0_m0_read              => CONNECTED_TO_mm_bridge_0_m0_read,              --                          .read
			mm_bridge_0_m0_byteenable        => CONNECTED_TO_mm_bridge_0_m0_byteenable,        --                          .byteenable
			mm_bridge_0_m0_debugaccess       => CONNECTED_TO_mm_bridge_0_m0_debugaccess,       --                          .debugaccess
			pio_0_external_connection_export => CONNECTED_TO_pio_0_external_connection_export, -- pio_0_external_connection.export
			pll_0_locked_export              => CONNECTED_TO_pll_0_locked_export,              --              pll_0_locked.export
			reset_reset_n                    => CONNECTED_TO_reset_reset_n                     --                     reset.reset_n
		);

