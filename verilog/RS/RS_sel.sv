/////////////////////////////////////////////////////////////////////////
//                                                                     
//   Modulename :  RS_sel.sv                                               
//                                                                     
//  Description :  select slot of RS to next stage                                                 
//                                                                     
//                                                                     
//                                                                     
//                                                                     
/////////////////////////////////////////////////////////////////////////
module RS_sel (
    input   RS_EX_PACKET   [`RS_SIZE-1:0] RS_OUT,
    input   [`RS_SIZE-1:0]  req,
    output  RS_EX_PACKET   rs_ex_out,
    output  logic valid
);
    integer i;
    logic   [$clog2(`RS_SIZE)-1:0] RS_addr;
    always_comb begin
        RS_addr  = {($clog2(`RS_SIZE)){1'b0}};
        for (i=0;i<`RS_SIZE;i=i+1) begin
            if (req[i]) begin
                RS_addr = i;
            end 
        end
    end

    always_comb begin
        rs_ex_out    = RS_OUT[RS_addr];
    end

    assign valid = (|req);




endmodule