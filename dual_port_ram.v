module dual_port_ram(input wclk,rclk, input[7:0] data_in , input[3:0] w_ptr , rd_ptr , input w_en , r_en ,output reg[7:0]data_out);

reg [7:0]memory [0:7];          //array declaration in verilog is -> data width first and array size later. 8 slots, each 8 bits wide — the actual storage room

always@(posedge wclk )begin      //two always block is used as two separate clock domains are present . one clock domain handles writing and other one hanadles reading of data.
    if(w_en) 
      memory[w_ptr]<= data_in;
end

always@(posedge rclk)begin
    if(r_en)
      data_out<= memory[rd_ptr];              //memory[0] means slot 0 , memory[1] means slot 1 and so on.if we put data_out<=data_in then the data given by sensor is directly goes to output but we need to store first and read later.
end
endmodule
