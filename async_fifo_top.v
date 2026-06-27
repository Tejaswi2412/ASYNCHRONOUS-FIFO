module async_fifo_top(input [7:0]data_in, input wclk,rclk,w_en,r_en ,rst_n, wrst_n, output[7:0]data_out );


wire[3:0]rd_ptr_gray , rd_ptr_sync ,w_ptr_gray,w_ptr_sync ;
wire[2:0]waddr ,rd_addr;
wire rd_empty, w_full;


dual_port_ram dut1(.wclk(wclk) ,. rclk(rclk), .data_in(data_in), .data_out(data_out), .w_en(w_en) ,.r_en(r_en),.w_ptr(waddr) ,.rd_ptr(rd_addr));
wptr_handler dut2(.wclk(wclk),.wrst_n(wrst_n),.rd_ptr_sync(rd_ptr_sync),.w_ptr_gray(w_ptr_gray),.waddr(waddr),.w_full(w_full),.w_en(w_en));
rdptr_handler dut3(.rclk(rclk),.rst_n(rst_n),.w_ptr_sync(w_ptr_sync),.rd_ptr_gray(rd_ptr_gray),.rd_addr(rd_addr), .rd_empty(rd_empty) ,.r_en(r_en));
sync_w2r dut4(.rclk(rclk),.w_ptr_gray(w_ptr_gray),.w_ptr_sync(w_ptr_sync));
sync_r2w dut5(.wclk(wclk),.rd_ptr_gray(rd_ptr_gray),.rd_ptr_sync(rd_ptr_sync));

endmodule