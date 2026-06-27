//This module handles all the write operation .
module wptr_handler(input w_en , input wclk , input[3:0]rd_ptr_sync,input wrst_n,     //active low reset 
                    output[3:0]w_ptr_gray, output [2:0]waddr, output w_full);

reg[3:0]w_ptr;

assign waddr=w_ptr[2:0];
assign w_ptr_gray = w_ptr ^ (w_ptr >>1);      //(w_ptr >>1) ..it is shifted by one position and then original is xored with shifted version. when the bits are shifted the lower bit is dropped and lost while 0 fills up the msb position in shifted version.
assign w_full= (rd_ptr_sync[2:0]==w_ptr_gray[2:0]) && (rd_ptr_sync[3] != w_ptr_gray[3]);

always@(posedge wclk)begin

        if(!wrst_n)begin             //reset =1 , reset the pointer, otherwise increment the pointer if the condition of not full and w_en is true
            w_ptr<=0;
        end
        else if(w_en && !w_full)

        w_ptr<=w_ptr+1;

    end

endmodule