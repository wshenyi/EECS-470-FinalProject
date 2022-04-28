module ps_no_mask_s #(parameter WIDTH = 16) (
    input  wire      [WIDTH-1:0] gnt_stage_1,// earlier granted bits
    input  wire      [WIDTH-1:0] req, // ready signal from RS slot
    input  FUNC_UNIT [WIDTH-1:0] func_in, // function unit
    output wand      [WIDTH-1:0] gnt, // grant the oldest ready slot
    output FUNC_UNIT             func_out // function unite chosen by ps stage 1
    
);
    wire    [WIDTH-1:0]    req_tmp;
    wire [1:0] func_in_tmp [WIDTH-1:0]; 
    wor     [1:0] func_out_tmp;
    wire    [WIDTH-1:0]    alu_bit;
    genvar i;
    for (i=0;i<WIDTH;i=i+1) 
    begin:split
        assign alu_bit[i] = (func_in[i] == FUNC_ALU ) ? 1'b1 : 1'b0;

    end
    // mask out  granted bit from first request
    genvar j;
    for (j=0;j<WIDTH;j=j+1)
    begin:mask_mult
        assign req_tmp[j] = ~gnt_stage_1[j] & req[j] & ~alu_bit[j];
    end
    
    //priority selector
    genvar n;

    for (n = 0; n < WIDTH-1 ; n = n + 1) begin 
        assign gnt [WIDTH-1:n] = {{(WIDTH-1-n){~req_tmp[n]}},req_tmp[n]};
    end

    assign gnt[WIDTH-1] = req_tmp[WIDTH-1];

    // select func
    assign {func_out[1],func_out[0]}     = {func_out_tmp[1], func_out_tmp[0]}; 
    genvar k;
    for (k=0; k< WIDTH; k = k + 1) begin
        assign func_in_tmp [k] = func_in [k] & {2{gnt[k]}}; 
    end
    for (k=0; k< WIDTH; k = k + 1) begin
        assign func_out_tmp    = func_in_tmp [k];
    end

endmodule