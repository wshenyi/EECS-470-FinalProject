module ps_fu #(
    parameter WIDTH = 16
) (
    input  wire      [WIDTH-1:0]    req, // ready signal from RS slot
    input  FUNC_UNIT [WIDTH-1:0]    func_in, // function unit
    input                           ALU0_stall_in, ALU1_stall_in,                   
    output logic       [WIDTH-1:0]  gnt,
    output logic      [2*WIDTH-1:0] gnt_bus,
    output FUNC_UNIT [1:0]          func_out // function unite chosen by ps stage 1 
);
    logic [WIDTH-1:0]  gnt_bus_alu, gnt_bus_mult, gnt_bus_mem ; 
    FUNC_UNIT         func_out_alu, func_out_mult, func_out_mem;
    logic [WIDTH-1:0]  gnt_bus_alu_s, gnt_bus_mult_s, gnt_bus_mem_s ;  
    FUNC_UNIT         func_out_alu_s, func_out_mult_s, func_out_mem_s;

    


    ////////////////////////////
    //ps stage 1
    //////////////////////////////
    ps_stage_1 #(.WIDTH(WIDTH))ps_s1 (
        .req(req),
        .ALU0_stall_in(ALU0_stall_in),
        .func_in(func_in),
        .gnt(gnt_bus[WIDTH-1 -: WIDTH]),
        .func_out(func_out[0])
    );

    //////////////////////////
    //ps stage 2
    /////////////////////////

    //
    //no mask have alu stall
    //
    ps_no_mask_s #(.WIDTH(WIDTH))ps_alu_s (
        .gnt_stage_1(gnt_bus[WIDTH-1 -: WIDTH]),
        .req(req),
        .func_in(func_in),
        .gnt(gnt_bus_alu_s),
        .func_out(func_out_alu_s)
    );
    //
    //mask mult have alu stall
    //
    ps_mask_mult_s #(.WIDTH(WIDTH))ps_mult_s (
        .gnt_stage_1(gnt_bus[WIDTH-1 -: WIDTH]),
        .req(req),
        .func_in(func_in),
        .gnt(gnt_bus_mult_s),
        .func_out(func_out_mult_s)
    );
    //
    //mask load or store have alu stall
    //
    ps_mask_mem_s #(.WIDTH(WIDTH))ps_mem_s (
        .gnt_stage_1(gnt_bus[WIDTH-1 -: WIDTH]),
        .req(req),
        .func_in(func_in),
        .gnt(gnt_bus_mem_s),
        .func_out(func_out_mem_s)
    );

    //
    //no mask no alu stall
    //
    ps_no_mask #(.WIDTH(WIDTH))ps_alu (
        .gnt_stage_1(gnt_bus[WIDTH-1 -: WIDTH]),
        .req(req),
        .func_in(func_in),
        .gnt(gnt_bus_alu),
        .func_out(func_out_alu)
    );
    //
    //mask mult no alu stall
    //
    ps_mask_mult #(.WIDTH(WIDTH))ps_mult (
        .gnt_stage_1(gnt_bus[WIDTH-1 -: WIDTH]),
        .req(req),
        .func_in(func_in),
        .gnt(gnt_bus_mult),
        .func_out(func_out_mult)
    );
    //
    //mask load or store no alu stall
    //
    ps_mask_mem #(.WIDTH(WIDTH))ps_mem (
        .gnt_stage_1(gnt_bus[WIDTH-1 -: WIDTH]),
        .req(req),
        .func_in(func_in),
        .gnt(gnt_bus_mem),
        .func_out(func_out_mem)
    );
    
    always_comb begin
        case ({func_out[0],ALU0_stall_in, ALU1_stall_in})
        ///////////////////////////
        //when first FU is ALU 
        ///////////////////////////////

        //ALU0 and ALU1 is not stall, no mask of ALU in second stage
        {{ALU},{1'b0},{1'b0}}:  begin
                                gnt_bus[2*WIDTH-1 -: WIDTH] = gnt_bus_alu;
                                func_out[1]                 = func_out_alu;
        
                                end
        //ALU0 is not stall but ALU1 is stall, need mask of ALU in second stage
        {{ALU},{1'b0},{1'b1}}: begin
                                gnt_bus[2*WIDTH-1 -: WIDTH] = gnt_bus_alu_s;
                                func_out[1]                 = func_out_alu_s;
                                
                                end
        //impossible situation
        {{ALU},{1'b1},{1'b1}}: begin
                                gnt_bus[2*WIDTH-1 -: WIDTH] = '0;
                                func_out[1]                 = NOP;
                               
                                end


        ///////////////////////////////
        //when first FU is MULT
        ///////////////////////////////////

        //ALU0 and ALU1 is not stall, no mask of ALU in second stage
        {{MULT},{1'b0},{1'b0}}:begin
                                gnt_bus[2*WIDTH-1 -: WIDTH] = gnt_bus_mult;
                                func_out[1]                 = func_out_mult;
                               
                                end
        //ALU0 is not stall but ALU1 is stall, no mask of ALU in second stage                        
        {{MULT},{1'b0},{1'b1}}:begin
                                gnt_bus[2*WIDTH-1 -: WIDTH] = gnt_bus_mult;
                                func_out[1]                 = func_out_mult;
                                
                                end
        //ALU0 and ALU1 is stall, need mask of ALU in second stage 
        {{MULT},{1'b1},{1'b1}}:begin
                                gnt_bus[2*WIDTH-1 -: WIDTH] = gnt_bus_mult_s;
                                func_out[1]                 = func_out_mult_s;
                               
                                end
        ///////////////////////////////
        //when first FU is MEM
        ///////////////////////////////////

        //ALU0 and ALU1 is not stall, no mask of ALU in second stage
        {{MEM},{1'b0},{1'b0}}:begin
                                gnt_bus[2*WIDTH-1 -: WIDTH] = gnt_bus_mem;
                                func_out[1]                 = func_out_mem;
                              
                                end
        //ALU0 is not stall but ALU1 is stall, no mask of ALU in second stage 
        {{MEM},{1'b0},{1'b1}}:begin
                                gnt_bus[2*WIDTH-1 -: WIDTH] = gnt_bus_mem;
                                func_out[1]                 = func_out_mem;
                            
                                end
        //ALU0 and ALU1 is stall, need mask of ALU in second stage 
        {{MEM},{1'b1},{1'b1}}:begin
                                gnt_bus[2*WIDTH-1 -: WIDTH] = gnt_bus_mem_s;
                                func_out[1]                 = func_out_mem_s;
                               
                                end
        ///////////////////////////////
        //when first FU is NOP no req in first stage
        ///////////////////////////////////
        default:              begin
                                gnt_bus[2*WIDTH-1 -: WIDTH] = '0;
                                func_out[1]                 = NOP;
                              
                                end
        endcase
    end

    assign gnt = gnt_bus[2*WIDTH-1 -: WIDTH] | gnt_bus[WIDTH-1 -: WIDTH];
endmodule