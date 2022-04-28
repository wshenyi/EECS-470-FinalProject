/////////////////////////////////////////////////////////////////////////
//                                                                     
//   Modulename :  RS_one.sv                                               
//                                                                     
//  Description :  one slot of RS                                                    
//                                                                     
//                                                                     
//                                                                     
//                                                                     
/////////////////////////////////////////////////////////////////////////
module RS_one (
    input   clock, reset, enable,
    // Controls the squeeze mechanism of RS
    input   compress_sel_1, compress_sel_2,
    // One-hot encoding of which dispatch to look at
    // If slot_valid_i == 1, then this RS_one needs to fetch instruction from slot i
    input   slot_valid_1, slot_valid_2, 
    // From complete stage
    input   CDB_PACKET [1:0] cdb_in,
    // From maptable 
    input   MT_RS_PACKET [1:0] mt_rs_in,
    // Actual information from fetch buffer (?)
    // input   DP_PACKET   dp_packet_in[0],dp_packet_in[1], 
    input   DP_PACKET   [1:0] dp_packet_in,

    input      [$clog2(`SQ_SIZE)-1:0]       tail_pos_1,tail_pos_2,
    // Actual information from ROB
    input   ROB_RS_PACKET        [1:0] rob_in,
    input  squash_signal_in,
    // For squeeze mechanism.
    // UP_RS_entry_1 is the RS_one ifself,
    // UP_RS_entry_2 is the RS_one above it,
    // UP_RS_entry_3 is the RS_one 2 entries above.
    input   RS_ENTRY_PACKET     UP_RS_entry_1, UP_RS_entry_2, UP_RS_entry_3,

    input has_ld_from_above,

    // Out packet to FU (Issue stage)
    output  RS_IS_PACKET       RS_OUT,
    // ifself
    output  RS_ENTRY_PACKET     RS_entry,
    // 1 if the slot is empty (can take a new instruction)
    output  empty,
    // 1 if the slot is ready to free so that it can be sent to FU (Issue).
    output  ready,

    output logic has_ld_including_self                                            
);
    RS_ENTRY_PACKET   UP_RS_entry, N_RS_entry;
    RS_ENTRY_SEL RS_entry_sel;
    MATCH match1, match2;  
    logic [`XLEN-1:0] wake_up_value_1, wake_up_value_2;         // value after cdb_in.V mux 
    logic [`XLEN-1:0] INST1_value_in_1, INST1_value_in_2; 
    logic [`XLEN-1:0] INST2_value_in_1, INST2_value_in_2;       // value after ready_in_rob mux

    logic match_Tag1_valid, match_Tag2_valid;

    assign empty = ~UP_RS_entry.busy;

    //if rs1 is zero_reg, it has no dependence to other Reg_dest
    //when inst have no rs1, inst.r.rs1 == zero_reg
    //when inst have no rs2, inst.r.rs2 == zero_reg

    assign has_ld_including_self = (has_ld_from_above || RS_entry.rd_mem);

    

    assign RS_OUT.NPC           = RS_entry.NPC;
    assign RS_OUT.PC            = RS_entry.PC;

    assign RS_OUT.rs1_value     = RS_entry.rs1_value;
    assign RS_OUT.rs2_value     = RS_entry.rs2_value; 

    assign RS_OUT.opa_select    = RS_entry.opa_select;
    assign RS_OUT.opb_select    = RS_entry.opb_select;
    assign RS_OUT.inst          = RS_entry.inst;

    assign RS_OUT.dest_reg_idx  = RS_entry.dest_reg_idx;
    assign RS_OUT.alu_func      = RS_entry.alu_func;
    assign RS_OUT.rd_mem        = RS_entry.rd_mem;
    assign RS_OUT.wr_mem        = RS_entry.wr_mem;
    assign RS_OUT.cond_branch   = RS_entry.cond_branch;
    assign RS_OUT.uncond_branch = RS_entry.uncond_branch;
    assign RS_OUT.halt          = RS_entry.halt;
    assign RS_OUT.illegal       = RS_entry.illegal;
    assign RS_OUT.csr_op        = RS_entry.csr_op;
    assign RS_OUT.valid         = RS_entry.valid;

    assign RS_OUT.Tag           = RS_entry.Tag;       
    assign RS_OUT.func_unit     = RS_entry.func_unit;
    assign RS_OUT.tail_pos      = RS_entry.tail_pos;


    //CAM ready
    assign match1.tag1      = (cdb_in[0].Tag == N_RS_entry.Tag1) & cdb_in[0].valid & N_RS_entry.Tag1_valid;
    assign match1.tag2      = (cdb_in[0].Tag == N_RS_entry.Tag2) & cdb_in[0].valid & N_RS_entry.Tag2_valid;
    assign match2.tag1      = (cdb_in[1].Tag == N_RS_entry.Tag1) & cdb_in[1].valid & N_RS_entry.Tag1_valid;
    assign match2.tag2      = (cdb_in[1].Tag == N_RS_entry.Tag2) & cdb_in[1].valid & N_RS_entry.Tag2_valid;

    // assign n_rdy1           = ((cdb_in[0].Tag == N_RS_entry.Tag1) & cdb_in[0].valid) | ((cdb_in[1].Tag == N_RS_entry.Tag1) & cdb_in[1].valid) | ~N_RS_entry.Tag1_valid;
    // assign n_rdy2           = ((cdb_in[0].Tag == N_RS_entry.Tag2) & cdb_in[0].valid) | ((cdb_in[1].Tag == N_RS_entry.Tag2) & cdb_in[1].valid) | ~N_RS_entry.Tag2_valid;


    assign INST1_value_in_1 =(mt_rs_in[0].Tag1_ready_in_rob) ? rob_in[0].rs1_value : dp_packet_in[0].rs1_value;
    assign INST1_value_in_2 =(mt_rs_in[0].Tag2_ready_in_rob) ? rob_in[0].rs2_value : dp_packet_in[0].rs2_value;
    assign INST2_value_in_1 =(mt_rs_in[1].Tag1_ready_in_rob) ? rob_in[1].rs1_value : dp_packet_in[1].rs1_value;
    assign INST2_value_in_2 =(mt_rs_in[1].Tag2_ready_in_rob) ? rob_in[1].rs2_value : dp_packet_in[1].rs2_value;

    assign ready = (has_ld_from_above && RS_entry.rd_mem) ? 0 : (~RS_entry.Tag1_valid | ~RS_entry.rs1_exist) & (~RS_entry.Tag2_valid | ~RS_entry.rs2_exist) & RS_entry.busy;
    
    always_comb begin
        case ({compress_sel_1,compress_sel_2})
        2'b00: UP_RS_entry = UP_RS_entry_1;     //RS_entry[i] = RS_entry[i]
        2'b01: UP_RS_entry = UP_RS_entry_1;     //This is impossible 
        2'b10: UP_RS_entry = UP_RS_entry_2;     //RS_entry[i] = RS_entry[i+1]
        2'b11: UP_RS_entry = UP_RS_entry_3;     //RS_entry[i] = RS_entry[i+2]
        default:UP_RS_entry = UP_RS_entry_1;
        endcase
    end
    
    //if allocate? / allocate inst1/ allocate inst2
    always_comb begin
        case ({slot_valid_1, slot_valid_2})
        2'b00: RS_entry_sel     = NONE;
        2'b01: RS_entry_sel     = ~dp_packet_in[0].dp_en ? NONE: 
                                  dp_packet_in[1].dp_en  ? INST2: NONE;   
        2'b10: RS_entry_sel     = dp_packet_in[0].dp_en ? INST1 : NONE;
        default: RS_entry_sel   = NONE;
        endcase
    end

    //allocate inst
    always_comb begin
        case (RS_entry_sel)
        NONE: begin
            N_RS_entry = UP_RS_entry;                               //RS_entry[i] = RS_entry[i+n]
        end
        INST1: begin                                                //RS_entry[i] = INST1
            N_RS_entry.busy          = 1'b1;
            N_RS_entry.NPC           = dp_packet_in[0].NPC;         // PC + 4
            N_RS_entry.PC            = dp_packet_in[0].PC ; // PC
            N_RS_entry.rs1_value     = INST1_value_in_1;
            N_RS_entry.rs2_value     = INST1_value_in_2;
            N_RS_entry.opa_select    = dp_packet_in[0].opa_select;   // ALU opa mux select (ALU_OPA_xxx *)
            N_RS_entry.opb_select    = dp_packet_in[0].opb_select ;   // ALU opb mux select (ALU_OPB_xxx *)
            N_RS_entry.inst          = dp_packet_in[0].inst;        // instruction
            N_RS_entry.dest_reg_idx  = dp_packet_in[0].dest_reg_idx; // destination (writeback) register index
            N_RS_entry.alu_func      = dp_packet_in[0].alu_func ;    // ALU function select (ALU_xxx *)
            N_RS_entry.rd_mem        = dp_packet_in[0].rd_mem ;      //rd_mem
            N_RS_entry.wr_mem        = dp_packet_in[0].wr_mem;       //wr_mem
            N_RS_entry.cond_branch   = dp_packet_in[0].cond_branch ;  //cond
            N_RS_entry.uncond_branch = dp_packet_in[0].uncond_branch;  //uncond
            N_RS_entry.halt          = dp_packet_in[0].halt ;          //halt
            N_RS_entry.illegal       = dp_packet_in[0].illegal;       //illegal
            N_RS_entry.csr_op        = dp_packet_in[0].csr_op;        //csr_op
            N_RS_entry.valid         = dp_packet_in[0].valid ;         //valid
            N_RS_entry.rs1_exist     = dp_packet_in[0].rs1_exist;      // is 1 if has source reg1 and source reg1 is not reg0
            N_RS_entry.rs2_exist     = dp_packet_in[0].rs2_exist;     // is 1 if has source reg2 and source reg2 is not reg0
            N_RS_entry.func_unit     = dp_packet_in[0].func_unit;
            N_RS_entry.Tag           = rob_in[0].Tag;
            N_RS_entry.Tag1          = mt_rs_in[0].Tag1;
            N_RS_entry.Tag2          = mt_rs_in[0].Tag2;
            N_RS_entry.Tag1_valid    = mt_rs_in[0].Tag1_valid & ~mt_rs_in[0].Tag1_ready_in_rob;
            N_RS_entry.Tag2_valid    = mt_rs_in[0].Tag2_valid & ~mt_rs_in[0].Tag2_ready_in_rob;
            N_RS_entry.tail_pos      = tail_pos_1;
        end
        INST2: begin                                                //RS_entry[i] = INST2
            N_RS_entry.busy          = 1'b1;
            N_RS_entry.NPC           = dp_packet_in[1].NPC;         // PC + 4
            N_RS_entry.PC            = dp_packet_in[1].PC ; // PC
            N_RS_entry.rs1_value     = INST2_value_in_1;
            N_RS_entry.rs2_value     = INST2_value_in_2; 
            N_RS_entry.opa_select    = dp_packet_in[1].opa_select;   // ALU opa mux select (ALU_OPA_xxx *)
            N_RS_entry.opb_select    = dp_packet_in[1].opb_select ;   // ALU opb mux select (ALU_OPB_xxx *)
            N_RS_entry.inst          = dp_packet_in[1].inst;        // instruction
            N_RS_entry.dest_reg_idx  = dp_packet_in[1].dest_reg_idx; // destination (writeback) register index
            N_RS_entry.alu_func      = dp_packet_in[1].alu_func ;    // ALU function select (ALU_xxx *)
            N_RS_entry.rd_mem        = dp_packet_in[1].rd_mem ;      //rd_mem
            N_RS_entry.wr_mem        = dp_packet_in[1].wr_mem;       //wr_mem
            N_RS_entry.cond_branch   = dp_packet_in[1].cond_branch ;  //cond
            N_RS_entry.uncond_branch = dp_packet_in[1].uncond_branch;  //uncond
            N_RS_entry.halt          = dp_packet_in[1].halt ;          //halt
            N_RS_entry.illegal       = dp_packet_in[1].illegal;       //illegal
            N_RS_entry.csr_op        = dp_packet_in[1].csr_op;        //csr_op
            N_RS_entry.valid         = dp_packet_in[1].valid ;         //valid
            N_RS_entry.rs1_exist     = dp_packet_in[1].rs1_exist;      // is 1 if has source reg1 and source reg1 is not reg0
            N_RS_entry.rs2_exist     = dp_packet_in[1].rs2_exist;     // is 1 if has source reg2 and source reg2 is not reg0
            N_RS_entry.func_unit     = dp_packet_in[1].func_unit;
            N_RS_entry.Tag           = rob_in[1].Tag;
            N_RS_entry.Tag1          = mt_rs_in[1].Tag1;
            N_RS_entry.Tag2          = mt_rs_in[1].Tag2;
            N_RS_entry.Tag1_valid    = mt_rs_in[1].Tag1_valid & ~mt_rs_in[1].Tag1_ready_in_rob;
            N_RS_entry.Tag2_valid    = mt_rs_in[1].Tag2_valid & ~mt_rs_in[1].Tag2_ready_in_rob;
            N_RS_entry.tail_pos      = tail_pos_2;
        end
        default:begin
            N_RS_entry.busy          = 1'b0;
            N_RS_entry.NPC           = {`XLEN{1'b0}};         // PC + 4
            N_RS_entry.PC            = {`XLEN{1'b0}}; // PC
            N_RS_entry.rs1_value     = {`XLEN{1'b0}};
            N_RS_entry.rs2_value     = {`XLEN{1'b0}}; 
            N_RS_entry.opa_select    = OPA_IS_RS1;   // ALU opa mux select (ALU_OPA_xxx *)
            N_RS_entry.opb_select    = OPB_IS_RS2;   // ALU opb mux select (ALU_OPB_xxx *)
            N_RS_entry.inst          = `NOP;        // instruction
            N_RS_entry.dest_reg_idx  = `ZERO_REG; // destination (writeback) register index
            N_RS_entry.alu_func      = ALU_ADD;    // ALU function select (ALU_xxx *)
            N_RS_entry.rd_mem        = 1'b0;      //rd_mem
            N_RS_entry.wr_mem        = 1'b0;       //wr_mem
            N_RS_entry.cond_branch   = 1'b0;  //cond
            N_RS_entry.uncond_branch = 1'b0;  //uncond
            N_RS_entry.halt          = 1'b0;          //halt
            N_RS_entry.illegal       = 1'b0;       //illegal
            N_RS_entry.csr_op        = 1'b0;        //csr_op
            N_RS_entry.valid         = 1'b0;         //valid
            N_RS_entry.rs1_exist     = 1'b1;      // is 1 if has source reg1 and source reg1 is not reg0
            N_RS_entry.rs2_exist     = 1'b1;     // is 1 if has source reg2 and source reg2 is not reg0
            N_RS_entry.func_unit     = FUNC_ALU;
            N_RS_entry.Tag           = {`ROB_ADDR_BITS{1'b0}};
            N_RS_entry.Tag1          = {`ROB_ADDR_BITS{1'b0}};
            N_RS_entry.Tag2          = {`ROB_ADDR_BITS{1'b0}};
            N_RS_entry.Tag1_valid    = 1'b0;
            N_RS_entry.Tag2_valid    = 1'b0;
            N_RS_entry.tail_pos      = {($clog2(`SQ_SIZE)){1'b0}};
        end
        endcase
    end

     always_comb begin
        case ({match1.tag1,match2.tag1})
        2'b00:  wake_up_value_1 = N_RS_entry.rs1_value;
        2'b01:  wake_up_value_1 = cdb_in[1].Value;
        2'b10:  wake_up_value_1 = cdb_in[0].Value;
        default:wake_up_value_1 = N_RS_entry.rs1_value;
        endcase
    end

    always_comb begin
        case ({match1.tag2,match2.tag2})
        2'b00:  wake_up_value_2 = N_RS_entry.rs2_value;
        2'b01:  wake_up_value_2 = cdb_in[1].Value;
        2'b10:  wake_up_value_2 = cdb_in[0].Value;
        default:wake_up_value_2 = N_RS_entry.rs2_value;
        endcase
    end

    always_comb begin
        case ({match1.tag1,match2.tag1})
        2'b00:  begin match_Tag1_valid = N_RS_entry.Tag1_valid; end
        2'b01:  begin match_Tag1_valid = 0;                     end
        2'b10:  begin match_Tag1_valid = 0;                     end
        default:begin match_Tag1_valid = N_RS_entry.Tag1_valid; end
        endcase
    end

    always_comb begin
        case ({match1.tag2,match2.tag2})
        2'b00:  begin match_Tag2_valid = N_RS_entry.Tag2_valid; end
        2'b01:  begin match_Tag2_valid = 0;                     end
        2'b10:  begin match_Tag2_valid = 0;                     end
        default:begin match_Tag2_valid = N_RS_entry.Tag2_valid; end
        endcase
    end

   
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            RS_entry.busy          <= `SD 0;              // if RS entry is busy
            RS_entry.NPC           <= `SD {`XLEN{1'b0}};  // PC + 4
            RS_entry.PC            <= `SD {`XLEN{1'b0}};  // PC
            RS_entry.rs1_value     <= `SD 0;              // reg A value
            RS_entry.rs2_value     <= `SD 0;              // reg B value 
            RS_entry.opa_select    <= `SD OPA_IS_RS1;     // ALU opa mux select (ALU_OPA_xxx *)
            RS_entry.opb_select    <= `SD OPB_IS_RS2;     // ALU opb mux select (ALU_OPB_xxx *)
            RS_entry.inst          <= `SD `NOP;           // instruction
            RS_entry.dest_reg_idx  <= `SD `ZERO_REG;       // destination (writeback) register index
            RS_entry.alu_func      <= `SD ALU_ADD;        // ALU function select (ALU_xxx *)
            RS_entry.rd_mem        <= `SD 1'b0;           //rd_mem
            RS_entry.wr_mem        <= `SD 1'b0;    //wr_mem
            RS_entry.cond_branch   <= `SD 1'b0;    //cond
            RS_entry.uncond_branch <= `SD 1'b0;    //uncond
            RS_entry.halt          <= `SD 1'b0;    //halt
            RS_entry.illegal       <= `SD 1'b0;    //illegal
            RS_entry.csr_op        <= `SD 1'b0;    //csr_op
            RS_entry.valid         <= `SD 1'b0;    //valid
            RS_entry.rs1_exist     <= `SD 1'b1;    // is 1 if has source reg1 and source reg1 is not reg0
            RS_entry.rs2_exist     <= `SD 1'b1;    // is 1 if has source reg2 and source reg2 is not reg0
            RS_entry.Tag           <= `SD 0;
            RS_entry.Tag1          <= `SD 0;
            RS_entry.Tag2          <= `SD 0;
            RS_entry.Tag1_valid    <= `SD 0;
            RS_entry.Tag2_valid    <= `SD 0;
            RS_entry.func_unit     <= `SD FUNC_ALU;
            RS_entry.tail_pos      <= `SD 0;
        end 
        else if (squash_signal_in) begin
            RS_entry.busy          <= `SD 0;              // if RS entry is busy
            RS_entry.NPC           <= `SD {`XLEN{1'b0}};  // PC + 4
            RS_entry.PC            <= `SD {`XLEN{1'b0}};  // PC
            RS_entry.rs1_value     <= `SD 0;              // reg A value
            RS_entry.rs2_value     <= `SD 0;              // reg B value 
            RS_entry.opa_select    <= `SD OPA_IS_RS1;     // ALU opa mux select (ALU_OPA_xxx *)
            RS_entry.opb_select    <= `SD OPB_IS_RS2;     // ALU opb mux select (ALU_OPB_xxx *)
            RS_entry.inst          <= `SD `NOP;           // instruction
            RS_entry.dest_reg_idx  <= `SD `ZERO_REG;       // destination (writeback) register index
            RS_entry.alu_func      <= `SD ALU_ADD;        // ALU function select (ALU_xxx *)
            RS_entry.rd_mem        <= `SD 1'b0;           //rd_mem
            RS_entry.wr_mem        <= `SD 1'b0;    //wr_mem
            RS_entry.cond_branch   <= `SD 1'b0;    //cond
            RS_entry.uncond_branch <= `SD 1'b0;    //uncond
            RS_entry.halt          <= `SD 1'b0;    //halt
            RS_entry.illegal       <= `SD 1'b0;    //illegal
            RS_entry.csr_op        <= `SD 1'b0;    //csr_op
            RS_entry.valid         <= `SD 1'b0;    //valid
            RS_entry.rs1_exist     <= `SD 1'b1;    // is 1 if has source reg1 and source reg1 is not reg0
            RS_entry.rs2_exist     <= `SD 1'b1;    // is 1 if has source reg2 and source reg2 is not reg0
            RS_entry.Tag           <= `SD 0;
            RS_entry.Tag1          <= `SD 0;
            RS_entry.Tag2          <= `SD 0;
            RS_entry.Tag1_valid    <= `SD 0;
            RS_entry.Tag2_valid    <= `SD 0;
            RS_entry.func_unit     <= `SD FUNC_ALU;
            RS_entry.tail_pos      <= `SD 0;
        end
        else if (enable) begin
            RS_entry.busy          <= `SD N_RS_entry.busy;
            RS_entry.NPC           <= `SD N_RS_entry.NPC ;         // PC + 4
            RS_entry.PC            <= `SD N_RS_entry.PC;           // PC
            RS_entry.rs1_value     <= `SD wake_up_value_1;         // reg A value
            RS_entry.rs2_value     <= `SD wake_up_value_2;         // reg B value 
            RS_entry.opa_select    <= `SD N_RS_entry.opa_select;   // ALU opa mux select (ALU_OPA_xxx *)
            RS_entry.opb_select    <= `SD N_RS_entry.opb_select;   // ALU opb mux select (ALU_OPB_xxx *)
            RS_entry.inst          <= `SD N_RS_entry.inst ;        // instruction
            RS_entry.dest_reg_idx  <= `SD N_RS_entry.dest_reg_idx; // destination (writeback) register index
            RS_entry.alu_func      <= `SD N_RS_entry.alu_func ;    // ALU function select (ALU_xxx *)
            RS_entry.rd_mem        <= `SD N_RS_entry.rd_mem ;      //rd_mem
            RS_entry.wr_mem        <= `SD N_RS_entry.wr_mem;       //wr_mem
            RS_entry.cond_branch   <= `SD N_RS_entry.cond_branch;  //cond
            RS_entry.uncond_branch <= `SD N_RS_entry.uncond_branch;  //uncond
            RS_entry.halt          <= `SD N_RS_entry.halt ;          //halt
            RS_entry.illegal       <= `SD N_RS_entry.illegal ;       //illegal
            RS_entry.csr_op        <= `SD N_RS_entry.csr_op ;        //csr_op
            RS_entry.valid         <= `SD N_RS_entry.valid ;         //valid
            RS_entry.rs1_exist     <= `SD N_RS_entry.rs1_exist;      // is 1 if has source reg1 and source reg1 is not reg0
            RS_entry.rs2_exist     <= `SD N_RS_entry.rs2_exist ;     // is 1 if has source reg2 and source reg2 is not reg0
            RS_entry.func_unit     <= `SD N_RS_entry.func_unit;
            RS_entry.Tag           <= `SD N_RS_entry.Tag;
            RS_entry.Tag1          <= `SD N_RS_entry.Tag1;
            RS_entry.Tag2          <= `SD N_RS_entry.Tag2;
            RS_entry.Tag1_valid    <= `SD match_Tag1_valid;
            RS_entry.Tag2_valid    <= `SD match_Tag2_valid;
            RS_entry.tail_pos      <= `SD N_RS_entry.tail_pos;
        end 
    end

    // always_ff @(posedge clock) begin
    //     if (reset) begin
    //         RS_entry.Tag1_valid    <= `SD 0;
    //     end
    //     else if (squash_signal_in) begin
    //         RS_entry.Tag1_valid    <= `SD 0;
    //     end
    //     else if (enable) begin
    //         if (match1.tag1 == 1 || match2.tag1 == 1) begin
    //             RS_entry.Tag1_valid    <= `SD 0;
    //         end
    //         else begin
    //              RS_entry.Tag1_valid <= `SD N_RS_entry.Tag1_valid;
    //         end

    //     end
    // end

    // always_ff @(posedge clock) begin
    //     if (reset) begin
    //         RS_entry.Tag2_valid    <= `SD 0;
    //     end
    //     else if (squash_signal_in) begin
    //         RS_entry.Tag2_valid    <= `SD 0;
    //     end
    //     else if (enable) begin
    //         if (match1.tag2 == 1 || match2.tag2 == 1) begin
    //             RS_entry.Tag2_valid    <= `SD 0;
    //         end
    //         else begin
    //              RS_entry.Tag2_valid <= `SD N_RS_entry.Tag2_valid;
    //         end

    //     end
    // end



endmodule
