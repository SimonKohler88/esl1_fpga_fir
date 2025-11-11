
module uart_nios (
	clk_clk,
	clock_bridge_0_out_clk_clk,
	mm_bridge_0_m0_waitrequest,
	mm_bridge_0_m0_readdata,
	mm_bridge_0_m0_readdatavalid,
	mm_bridge_0_m0_burstcount,
	mm_bridge_0_m0_writedata,
	mm_bridge_0_m0_address,
	mm_bridge_0_m0_write,
	mm_bridge_0_m0_read,
	mm_bridge_0_m0_byteenable,
	mm_bridge_0_m0_debugaccess,
	pio_0_external_connection_export,
	pll_0_locked_export,
	reset_reset_n,
	uart_0_external_connection_rxd,
	uart_0_external_connection_txd);	

	input		clk_clk;
	output		clock_bridge_0_out_clk_clk;
	input		mm_bridge_0_m0_waitrequest;
	input	[31:0]	mm_bridge_0_m0_readdata;
	input		mm_bridge_0_m0_readdatavalid;
	output	[0:0]	mm_bridge_0_m0_burstcount;
	output	[31:0]	mm_bridge_0_m0_writedata;
	output	[9:0]	mm_bridge_0_m0_address;
	output		mm_bridge_0_m0_write;
	output		mm_bridge_0_m0_read;
	output	[3:0]	mm_bridge_0_m0_byteenable;
	output		mm_bridge_0_m0_debugaccess;
	output	[7:0]	pio_0_external_connection_export;
	output		pll_0_locked_export;
	input		reset_reset_n;
	input		uart_0_external_connection_rxd;
	output		uart_0_external_connection_txd;
endmodule
