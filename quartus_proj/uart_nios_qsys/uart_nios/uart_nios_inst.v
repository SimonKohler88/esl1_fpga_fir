	uart_nios u0 (
		.clk_clk                          (<connected-to-clk_clk>),                          //                       clk.clk
		.clock_bridge_0_out_clk_clk       (<connected-to-clock_bridge_0_out_clk_clk>),       //    clock_bridge_0_out_clk.clk
		.mm_bridge_0_m0_waitrequest       (<connected-to-mm_bridge_0_m0_waitrequest>),       //            mm_bridge_0_m0.waitrequest
		.mm_bridge_0_m0_readdata          (<connected-to-mm_bridge_0_m0_readdata>),          //                          .readdata
		.mm_bridge_0_m0_readdatavalid     (<connected-to-mm_bridge_0_m0_readdatavalid>),     //                          .readdatavalid
		.mm_bridge_0_m0_burstcount        (<connected-to-mm_bridge_0_m0_burstcount>),        //                          .burstcount
		.mm_bridge_0_m0_writedata         (<connected-to-mm_bridge_0_m0_writedata>),         //                          .writedata
		.mm_bridge_0_m0_address           (<connected-to-mm_bridge_0_m0_address>),           //                          .address
		.mm_bridge_0_m0_write             (<connected-to-mm_bridge_0_m0_write>),             //                          .write
		.mm_bridge_0_m0_read              (<connected-to-mm_bridge_0_m0_read>),              //                          .read
		.mm_bridge_0_m0_byteenable        (<connected-to-mm_bridge_0_m0_byteenable>),        //                          .byteenable
		.mm_bridge_0_m0_debugaccess       (<connected-to-mm_bridge_0_m0_debugaccess>),       //                          .debugaccess
		.pio_0_external_connection_export (<connected-to-pio_0_external_connection_export>), // pio_0_external_connection.export
		.pll_0_locked_export              (<connected-to-pll_0_locked_export>),              //              pll_0_locked.export
		.reset_reset_n                    (<connected-to-reset_reset_n>)                     //                     reset.reset_n
	);

