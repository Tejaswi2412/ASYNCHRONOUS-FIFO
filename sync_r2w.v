module sync_r2w(input [3:0]rd_ptr_gray , input wclk , output[3:0] rd_ptr_sync);

reg [3:0] FF1, FF2;

always@(posedge wclk)begin

    FF1<=rd_ptr_gray;
    FF2<=FF1;
end
assign rd_ptr_sync=FF2;

endmodule