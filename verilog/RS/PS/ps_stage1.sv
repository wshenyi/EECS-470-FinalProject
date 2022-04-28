module ps_stage_1 #(parameter WIDTH = 16) (
    input  wire      [WIDTH-1:0] req, // ready signal from RS slot
    input  FUNC_UNIT [WIDTH-1:0] func_in, // function unit
    input  wire                  ALU0_stall_in,
    output wand      [WIDTH-1:0] gnt, // grant the oldest ready slot
    output FUNC_UNIT             func_out // function unite chosen by ps stage 1
   
);
    wire [1:0] func_in_tmp [WIDTH-1:0]; 
    wor  [1:0] func_out_tmp;
    wire    [WIDTH-1:0]    req_tmp;
    wire    [WIDTH-1:0]    alu_bit;

    // mask alu function unit
    genvar k;
    //split packet 
    for (k=0;k<WIDTH;k=k+1) 
    begin:split
        assign alu_bit[k] = (func_in[k] == ALU && ALU0_stall_in == 1'b1) ? 1'b1 : 1'b0;
    end
// mask alu function unit
    genvar n;
    for (n=0;n<WIDTH;n=n+1)
    begin:mask_alu
        assign req_tmp[n] = req[n] & ~alu_bit[n];
    end




//priority selector
    genvar i;

    for (i = 0; i < WIDTH-1 ; i = i + 1) begin 
        assign gnt [WIDTH-1:i] = {{(WIDTH-1-i){~req_tmp[i]}},req_tmp[i]};
    end

    assign gnt[WIDTH-1] = req_tmp[WIDTH-1];
// select func
    assign {func_out[1],func_out[0]}     = {func_out_tmp[1], func_out_tmp[0]}; 
    genvar j;
    for (j=0; j< WIDTH; j = j + 1) begin
        assign func_in_tmp [j] = func_in [j] & {2{gnt[j]}}; 
    end
    for (j=0; j< WIDTH; j = j + 1) begin
        assign func_out_tmp    = func_in_tmp [j];
    end


endmodule 