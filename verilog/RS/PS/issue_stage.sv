module issue #(
    parameter WIDTH = 16
) (
    input  RS_IS_PACKET  [WIDTH-1:0] rs_is_packet_in,
    input                [WIDTH-1:0] req,
    input                            ALU0_stall_in, ALU1_stall_in,
    output RS_IS_PACKET              rs_is_alu0_out, rs_is_alu1_out, rs_is_mult_out, rs_is_mem_out,
    output logic         [WIDTH-1:0] free,
    output logic                     rs_is_alu0_vld, rs_is_alu1_vld, rs_is_mult_vld, rs_is_mem_vld
);
    FUNC_UNIT     [1:0]    func_out; // function unit selected by ps
    RS_IS_PACKET  [1:0]    rs_is_packet_out;
    logic         [2*WIDTH-1:0] gnt_bus;
    logic         [WIDTH-1:0] gnt_bus_1, gnt_bus_2;
    FUNC_UNIT     [WIDTH-1:0] func_in;
    integer i,j;

    assign gnt_bus_1  = gnt_bus[WIDTH-1 -: WIDTH];
    assign gnt_bus_2  = gnt_bus[2*WIDTH-1 -:WIDTH];

    genvar k;
    for (k=0;k<WIDTH;k=k+1) begin
        assign func_in[k]    = rs_is_packet_in[k].func_unit;  
    end
    
// generate free signal and send to RS
    ps_fu #(.WIDTH(WIDTH))fu_ctrl (
        .req(req),
        .func_in(func_in),
        .ALU0_stall_in(ALU0_stall_in),
        .ALU1_stall_in(ALU1_stall_in),
        .gnt(free),
        .gnt_bus(gnt_bus),
        .func_out(func_out)
    );

// mux instruction in RS
    always_comb begin
        rs_is_packet_out[0] = '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},    // PC
				{`XLEN{1'b0}},    // reg A value
				{`XLEN{1'b0}},    // reg B value 
				OPA_IS_RS1, 
				OPB_IS_RS2, 
				`NOP,            // instruction
				`ZERO_REG,       // destination (writeback) register index 
				ALU_ADD,         // ALU function select (ALU_xxx *)
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0,  //valid
                {`ROB_ADDR_BITS{1'b0}}, // Tag
                NOP    //FU
			}; 
        for (i = 0; i < WIDTH ; i = i + 1) begin
            if (gnt_bus_1[i]) begin
                rs_is_packet_out[0] = rs_is_packet_in[i];
            end else begin
                rs_is_packet_out[0] = rs_is_packet_out[0];
            end
        end
    end

    always_comb begin
        rs_is_packet_out[1] = '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},    // PC
				{`XLEN{1'b0}},    // reg A value
				{`XLEN{1'b0}},    // reg B value 
				OPA_IS_RS1, 
				OPB_IS_RS2, 
				`NOP,            // instruction
				`ZERO_REG,       // destination (writeback) register index 
				ALU_ADD,         // ALU function select (ALU_xxx *)
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0,  //valid
                {`ROB_ADDR_BITS{1'b0}}, // Tag
                NOP    //FU
			}; 
        for (j = 0; j < WIDTH ; j = j + 1) begin
            if (gnt_bus_2[j]) begin
                rs_is_packet_out[1] = rs_is_packet_in[j];
            end else begin
                rs_is_packet_out[1] = rs_is_packet_out[1];
            end
        end
    end
//fu entry valid  
    always_comb begin
        rs_is_alu0_out = '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},    // PC
				{`XLEN{1'b0}},    // reg A value
				{`XLEN{1'b0}},    // reg B value 
				OPA_IS_RS1, 
				OPB_IS_RS2, 
				`NOP,            // instruction
				`ZERO_REG,       // destination (writeback) register index 
				ALU_ADD,         // ALU function select (ALU_xxx *)
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0,  //valid
                {`ROB_ADDR_BITS{1'b0}}, // Tag
                NOP    //FU
			}; 
        rs_is_alu0_vld = 1'b0;

        rs_is_alu1_out = '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},    // PC
				{`XLEN{1'b0}},    // reg A value
				{`XLEN{1'b0}},    // reg B value 
				OPA_IS_RS1, 
				OPB_IS_RS2, 
				`NOP,            // instruction
				`ZERO_REG,       // destination (writeback) register index 
				ALU_ADD,         // ALU function select (ALU_xxx *)
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0,  //valid
                {`ROB_ADDR_BITS{1'b0}}, // Tag
                NOP    //FU
			}; 
        rs_is_alu1_vld = 1'b0;

        rs_is_mult_out = '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},    // PC
				{`XLEN{1'b0}},    // reg A value
				{`XLEN{1'b0}},    // reg B value 
				OPA_IS_RS1, 
				OPB_IS_RS2, 
				`NOP,            // instruction
				`ZERO_REG,       // destination (writeback) register index 
				ALU_ADD,         // ALU function select (ALU_xxx *)
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0,  //valid
                {`ROB_ADDR_BITS{1'b0}}, // Tag
                NOP    //FU
			}; 
        rs_is_mult_vld = 1'b0;

        rs_is_mem_out = '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},    // PC
				{`XLEN{1'b0}},    // reg A value
				{`XLEN{1'b0}},    // reg B value 
				OPA_IS_RS1, 
				OPB_IS_RS2, 
				`NOP,            // instruction
				`ZERO_REG,       // destination (writeback) register index 
				ALU_ADD,         // ALU function select (ALU_xxx *)
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0,  //valid
                {`ROB_ADDR_BITS{1'b0}}, // Tag
                NOP    //FU
			}; 
        rs_is_mem_vld = 1'b0;
        case({func_out[0], func_out[1]})
        {{ALU},{ALU}}:  begin
                        rs_is_alu0_out = rs_is_packet_out [0];
                        rs_is_alu0_vld = 1'b1;
                        rs_is_alu1_out = rs_is_packet_out [1];
                        rs_is_alu1_vld = 1'b1;
                        end
        {{ALU},{MULT}}: begin
                        rs_is_alu0_out = rs_is_packet_out [0];
                        rs_is_alu0_vld = 1'b1;
                        rs_is_mult_out = rs_is_packet_out [1];
                        rs_is_mult_vld = 1'b1;
                        end 
        {{ALU},{MEM}}:  begin
                        rs_is_alu0_out = rs_is_packet_out [0];
                        rs_is_alu0_vld = 1'b1;
                        rs_is_mem_out  = rs_is_packet_out [1];
                        rs_is_mem_vld = 1'b1;
                        end 
        {{ALU},{NOP}}:  begin
                        rs_is_alu0_out = rs_is_packet_out [0];
                        rs_is_alu0_vld = 1'b1;
                        end
        //////////////////////////////////////////////////////////////
        {{MULT},{ALU}}:  begin
                        rs_is_mult_out = rs_is_packet_out [0];
                        rs_is_mult_vld = 1'b1;
                        rs_is_alu0_out = rs_is_packet_out [1];
                        rs_is_alu0_vld = 1'b1;
                        end
        {{MULT},{MEM}}:  begin
                        rs_is_mult_out = rs_is_packet_out [0];
                        rs_is_mult_vld = 1'b1;
                        rs_is_mem_out  = rs_is_packet_out [1];
                        rs_is_mem_vld = 1'b1;
                        end 
        {{MULT},{NOP}}:  begin
                        rs_is_mult_out = rs_is_packet_out [0];
                        rs_is_mult_vld = 1'b1;
                        end 
        //////////////////////////////////////////////////////////////
        {{MEM},{ALU}}:  begin
                        rs_is_mem_out = rs_is_packet_out [0];
                        rs_is_mem_vld = 1'b1;
                        rs_is_alu0_out = rs_is_packet_out [1];
                        rs_is_alu0_vld = 1'b1;
                        end
        {{MEM},{MULT}}: begin
                        rs_is_mem_out = rs_is_packet_out [0];
                        rs_is_mem_vld = 1'b1;
                        rs_is_mult_out = rs_is_packet_out [1];
                        rs_is_mult_vld = 1'b1;
                        end 
        {{MEM},{NOP}}:  begin
                        rs_is_mem_out = rs_is_packet_out [0];
                        rs_is_mem_vld = 1'b1;
                        end 
        endcase
    end

    


    
endmodule