//ditto explanation likw write pointer handler module

module rdptr_handler(input r_en , rclk ,rstn , input [3:0]w_ptr_sync , output [3:0] rd_ptr_gray , output [2:0]rd_addr , output rd_empty);

reg [3:0]rd_ptr;

assign rd_empty= (rd_ptr_gray[3:0] == w_ptr_sync[3:0] );
assign rd_ptr_gray = rd_ptr ^ (rd_ptr>>1);
assign rd_addr[2:0]= rd_ptr[2:0];

always@(posedge rclk)begin

    if(!rstn) begin
    rd_ptr<=0;
    end
    else if(!rd_empty && r_en )
    rd_ptr<=rd_ptr +1;

end
endmodule