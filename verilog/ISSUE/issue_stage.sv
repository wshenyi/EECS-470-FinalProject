module issue (
    input  RS_IS_PACKET  [`RS_SIZE-1:0] rs_is_packet_in,
    input                [`RS_SIZE-1:0] req,
    input                            ALU0_stall_in, ALU1_stall_in, ld_stall_in, st_stall_in,
    output IS_EX_PACKET    is_ex_packet_alu0,is_ex_packet_alu1,is_ex_packet_ld,is_ex_packet_st,is_ex_packet_mult,             
    output logic         [`RS_SIZE-1:0] free
);
    FUNC_UNIT     [1:0]    func_out; // function unit selected by ps
    IS_EX_PACKET  [1:0]    is_ex_packet_bus;
    logic         [2*`RS_SIZE-1:0] gnt_bus;
    logic         [`RS_SIZE-1:0] gnt_bus_1, gnt_bus_2;
    FUNC_UNIT     [`RS_SIZE-1:0] func_in;
    logic         [`RS_SIZE-1:0] rd_mem_in;
    logic         [`RS_SIZE-1:0] wr_mem_in;
    integer i,j;

    assign gnt_bus_1  = gnt_bus[`RS_SIZE-1 -: `RS_SIZE];
    assign gnt_bus_2  = gnt_bus[2*`RS_SIZE-1 -:`RS_SIZE];

    genvar k;
    for (k=0;k<`RS_SIZE;k=k+1) begin
        assign func_in[k]    = rs_is_packet_in[k].func_unit;  
        assign rd_mem_in[k]  = rs_is_packet_in[k].rd_mem;
        assign wr_mem_in[k]  = rs_is_packet_in[k].wr_mem;
    end
    
// generate free signal and send to RS
    ps_fu #(.WIDTH(`RS_SIZE))fu_ctrl (
        .req(req),
        .func_in(func_in),
        .ALU0_stall_in(ALU0_stall_in),
        .ALU1_stall_in(ALU1_stall_in),
        .ld_stall_in(ld_stall_in),
        .st_stall_in(st_stall_in),
        .rd_mem(rd_mem_in),
        .wr_mem(wr_mem_in),
        .gnt(free),
        .gnt_bus(gnt_bus),
        .func_out(func_out)
    );
///////////////////////////////////
// mux out instruction in RS
//
///////////////////////////////////
    always_comb begin
        is_ex_packet_bus[0] = '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},    // PC

				{`XLEN{1'b0}},    // reg A value
				{`XLEN{1'b0}},    // reg B value 

				OPA_IS_RS1, // ALU opa mux select (ALU_OPA_xxx *)
				OPB_IS_RS2, // ALU opb mux select (ALU_OPB_xxx *)
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
                {($clog2(`SQ_SIZE)){1'b0}}
			}; 
        for (i = 0; i < `RS_SIZE ; i = i + 1) begin
            if (gnt_bus_1[i]) begin
                is_ex_packet_bus[0].NPC = rs_is_packet_in[i].NPC;
                is_ex_packet_bus[0].PC = rs_is_packet_in[i].PC;
                is_ex_packet_bus[0].rs1_value = rs_is_packet_in[i].rs1_value;
                is_ex_packet_bus[0].rs2_value = rs_is_packet_in[i].rs2_value;
                is_ex_packet_bus[0].opa_select = rs_is_packet_in[i].opa_select;
                is_ex_packet_bus[0].opb_select = rs_is_packet_in[i].opb_select;
                is_ex_packet_bus[0].inst  = rs_is_packet_in[i].inst;
                is_ex_packet_bus[0].dest_reg_idx = rs_is_packet_in[i].dest_reg_idx;
                is_ex_packet_bus[0].alu_func = rs_is_packet_in[i].alu_func;
                is_ex_packet_bus[0].rd_mem = rs_is_packet_in[i].rd_mem;
                is_ex_packet_bus[0].wr_mem = rs_is_packet_in[i].wr_mem;
                is_ex_packet_bus[0].cond_branch = rs_is_packet_in[i].cond_branch;
                is_ex_packet_bus[0].uncond_branch = rs_is_packet_in[i].uncond_branch;
                is_ex_packet_bus[0].halt = rs_is_packet_in[i].halt;
                is_ex_packet_bus[0].illegal = rs_is_packet_in[i].illegal;
                is_ex_packet_bus[0].csr_op = rs_is_packet_in[i].csr_op;
                is_ex_packet_bus[0].valid = rs_is_packet_in[i].valid;
                is_ex_packet_bus[0].Tag  = rs_is_packet_in[i].Tag;
                is_ex_packet_bus[0].tail_pos  = rs_is_packet_in[i].tail_pos;
            end else begin
                is_ex_packet_bus[0] = is_ex_packet_bus[0];
            end
        end
    end

    always_comb begin
        is_ex_packet_bus[1] = '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},    // PC

				{`XLEN{1'b0}},    // reg A value
				{`XLEN{1'b0}},    // reg B value 

				OPA_IS_RS1, // ALU opa mux select (ALU_OPA_xxx *)
				OPB_IS_RS2, // ALU opb mux select (ALU_OPB_xxx *)
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
                {($clog2(`SQ_SIZE)){1'b0}}
			}; 
        for (j = 0; j < `RS_SIZE ; j = j + 1) begin
            if (gnt_bus_2[j]) begin
                is_ex_packet_bus[1].NPC = rs_is_packet_in[j].NPC;
                is_ex_packet_bus[1].PC = rs_is_packet_in[j].PC;
                is_ex_packet_bus[1].rs1_value = rs_is_packet_in[j].rs1_value;
                is_ex_packet_bus[1].rs2_value = rs_is_packet_in[j].rs2_value;
                is_ex_packet_bus[1].inst = rs_is_packet_in[j].inst;
                is_ex_packet_bus[1].opa_select = rs_is_packet_in[j].opa_select;
                is_ex_packet_bus[1].opb_select = rs_is_packet_in[j].opb_select;
                is_ex_packet_bus[1].dest_reg_idx = rs_is_packet_in[j].dest_reg_idx;
                is_ex_packet_bus[1].alu_func = rs_is_packet_in[j].alu_func;
                is_ex_packet_bus[1].rd_mem = rs_is_packet_in[j].rd_mem;
                is_ex_packet_bus[1].wr_mem = rs_is_packet_in[j].wr_mem;
                is_ex_packet_bus[1].cond_branch = rs_is_packet_in[j].cond_branch;
                is_ex_packet_bus[1].uncond_branch = rs_is_packet_in[j].uncond_branch;
                is_ex_packet_bus[1].halt = rs_is_packet_in[j].halt;
                is_ex_packet_bus[1].illegal = rs_is_packet_in[j].illegal;
                is_ex_packet_bus[1].csr_op = rs_is_packet_in[j].csr_op;
                is_ex_packet_bus[1].valid = rs_is_packet_in[j].valid;
                is_ex_packet_bus[1].Tag  = rs_is_packet_in[j].Tag;
                is_ex_packet_bus[1].tail_pos  = rs_is_packet_in[j].tail_pos;
            end else begin
                is_ex_packet_bus[1] = is_ex_packet_bus[1];
            end
        end
    end
////////////////////////////////////
// 
// select 2 dp_packet into FU  
//
///////////////////////////////////
    always_comb begin
        is_ex_packet_alu0 = '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},    // PC

				{`XLEN{1'b0}},    // reg A value
				{`XLEN{1'b0}},    // reg B value 

				OPA_IS_RS1, // ALU opa mux select (ALU_OPA_xxx *)
				OPB_IS_RS2, // ALU opb mux select (ALU_OPB_xxx *)
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
                {($clog2(`SQ_SIZE)){1'b0}}
			};

        is_ex_packet_alu1 = '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},    // PC

				{`XLEN{1'b0}},    // reg A value
				{`XLEN{1'b0}},    // reg B value 

				OPA_IS_RS1, // ALU opa mux select (ALU_OPA_xxx *)
				OPB_IS_RS2, // ALU opb mux select (ALU_OPB_xxx *)
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
                {($clog2(`SQ_SIZE)){1'b0}}
			}; 

        is_ex_packet_mult = '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},    // PC

				{`XLEN{1'b0}},    // reg A value
				{`XLEN{1'b0}},    // reg B value 

				OPA_IS_RS1, // ALU opa mux select (ALU_OPA_xxx *)
				OPB_IS_RS2, // ALU opb mux select (ALU_OPB_xxx *)
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
                {($clog2(`SQ_SIZE)){1'b0}}
			}; 

        is_ex_packet_ld = '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},    // PC

				{`XLEN{1'b0}},    // reg A value
				{`XLEN{1'b0}},    // reg B value 

				OPA_IS_RS1, // ALU opa mux select (ALU_OPA_xxx *)
				OPB_IS_RS2, // ALU opb mux select (ALU_OPB_xxx *)
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
                {($clog2(`SQ_SIZE)){1'b0}}
			}; 
        is_ex_packet_st = '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},    // PC

				{`XLEN{1'b0}},    // reg A value
				{`XLEN{1'b0}},    // reg B value 

				OPA_IS_RS1, // ALU opa mux select (ALU_OPA_xxx *)
				OPB_IS_RS2, // ALU opb mux select (ALU_OPB_xxx *)
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
                {($clog2(`SQ_SIZE)){1'b0}}
			}; 

        case({func_out[0], func_out[1]})
        {{FUNC_ALU},{FUNC_ALU}}:  begin
                        is_ex_packet_alu0 = is_ex_packet_bus [0];
                        is_ex_packet_alu1 = is_ex_packet_bus [1];
                        end
        {{FUNC_ALU},{FUNC_MULT}}: begin
                        if(ALU0_stall_in == 1'b1)begin
                        is_ex_packet_alu1 = is_ex_packet_bus [0];
                        is_ex_packet_mult = is_ex_packet_bus [1];
                        end
                        else begin
                        is_ex_packet_alu0 = is_ex_packet_bus [0];
                        is_ex_packet_mult = is_ex_packet_bus [1];
                        end
                        end 
        {{FUNC_ALU},{FUNC_MEM}}:  begin
                        if(ALU0_stall_in == 1'b1)begin
                        is_ex_packet_alu1 = is_ex_packet_bus [0];
                        if (is_ex_packet_bus[1].rd_mem) begin
                        is_ex_packet_ld = is_ex_packet_bus[1];
                        end else begin
                        is_ex_packet_st = is_ex_packet_bus[1];
                        end
                        end
                        else begin
                        is_ex_packet_alu0 = is_ex_packet_bus [0];
                        if (is_ex_packet_bus[1].rd_mem) begin
                        is_ex_packet_ld = is_ex_packet_bus[1];
                        end else begin
                        is_ex_packet_st = is_ex_packet_bus[1];
                        end
                        end
                        end 
        {{FUNC_ALU},{FUNC_NOP}}:  begin
                        if(ALU0_stall_in == 1'b1)begin
                        is_ex_packet_alu1 = is_ex_packet_bus [0];
                        end
                        else begin
                        is_ex_packet_alu0 = is_ex_packet_bus [0];
                        end
                        end
        //////////////////////////////////////////////////////////////
        {{FUNC_MULT},{FUNC_ALU}}:  begin
                        if(ALU0_stall_in == 1'b1)begin
                        is_ex_packet_mult = is_ex_packet_bus [0];
                        is_ex_packet_alu1 = is_ex_packet_bus [1];
                        end
                        else begin
                        is_ex_packet_mult = is_ex_packet_bus [0];
                        is_ex_packet_alu0 = is_ex_packet_bus [1];
                        end
                        end
        {{FUNC_MULT},{FUNC_MEM}}:  begin
                        is_ex_packet_mult = is_ex_packet_bus [0];
                        if (is_ex_packet_bus[1].rd_mem) begin
                        is_ex_packet_ld = is_ex_packet_bus[1];
                        end else begin
                        is_ex_packet_st = is_ex_packet_bus[1];
                        end
                        end 
        {{FUNC_MULT},{FUNC_NOP}}:  begin
                        is_ex_packet_mult = is_ex_packet_bus [0];
                        end 
        //////////////////////////////////////////////////////////////
        {{FUNC_MEM},{FUNC_ALU}}:  begin
                        if(ALU0_stall_in == 1'b1)begin
                        if (is_ex_packet_bus[0].rd_mem) begin
                        is_ex_packet_ld = is_ex_packet_bus[0];
                        end else begin
                        is_ex_packet_st = is_ex_packet_bus[0];
                        end
                        is_ex_packet_alu1 = is_ex_packet_bus [1];
                        end
                        else begin
                        if (is_ex_packet_bus[0].rd_mem) begin
                        is_ex_packet_ld = is_ex_packet_bus[0];
                        end else begin
                        is_ex_packet_st = is_ex_packet_bus[0];
                        end
                        is_ex_packet_alu0 = is_ex_packet_bus [1];
                        end
                        end
        {{FUNC_MEM},{FUNC_MULT}}: begin
                        if (is_ex_packet_bus[0].rd_mem) begin
                        is_ex_packet_ld = is_ex_packet_bus[0];
                        end else begin
                        is_ex_packet_st = is_ex_packet_bus[0];
                        end
                        is_ex_packet_mult = is_ex_packet_bus [1];
                        end 
        {{FUNC_MEM},{FUNC_NOP}}:  begin
                        if (is_ex_packet_bus[0].rd_mem) begin
                        is_ex_packet_ld = is_ex_packet_bus[0];
                        end else begin
                        is_ex_packet_st = is_ex_packet_bus[0];
                        end
                        end 
        endcase
    end

    


    
endmodule