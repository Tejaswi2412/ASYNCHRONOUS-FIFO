//rclk is used instead of wclk because write pointer enters in read domain hence both flip flops are driven by rclk not wclk.

module sync_w2r(input rclk, input[3:0] w_ptr_gray ,output[3:0]w_ptr_sync);  

// since it is driven by always block hence reg is used instead of wire. this ff1 and ff2  . 
//the output of first ff goes to input of second flip flop

//NOTE=  The flip flop are not the fancy other component . it is just the register who store the value and hold it for one complete clock cycle.
reg [3:0] FF1,FF2;   
 
always@(posedge rclk) begin

 FF1<=w_ptr_gray;
 FF2<= FF1;
end



assign w_ptr_sync = FF2;  //assign w_ptr_sync = FF2 is at the bottom simply because output is a wire, FF2 is a reg.
                    //You cannot declare output as reg and drive it from always block here — because the output just needs to reflect FF2's value continuously. That's exactly what assign does — it continuously connects FF2 to the output wire.

endmodule
