/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  dp_stage.v                                          //
//                                                                     //
//  Description :  instruction dispatch (DP) stage of the pipeline;    // 
//                 decode the instruction fetch register operands, and // 
//                 compute immediate operand (if applicable)           // 
//                                                                     //
/////////////////////////////////////////////////////////////////////////



  // Decode an instruction: given instruction bits IR produce the
  // appropriate datapath control signals.
  //
  // This is a *combinational* module (basically a PLA).
  //
  // Note: This decoder has been modified to accommodate P6 arch. 
module decoder(

	//input [31:0] inst,
	//input valid_inst_in,  // ignore inst when low, outputs will
	                      // reflect noop (except valid_inst)
	//see sys_defs.svh for definition
	input IF_DP_PACKET if_packet,
	
	output ALU_OPA_SELECT opa_select,
	output ALU_OPB_SELECT opb_select,
	output DEST_REG_SEL   dest_reg, // mux selects
	output ALU_FUNC       alu_func,
	output logic rd_mem, wr_mem, cond_branch, uncond_branch,
	output logic csr_op,    // used for CSR operations, we only used this as 
	                        // a cheap way to get the return code out
	output logic halt,      // non-zero on a halt
	output logic illegal,    // non-zero on an illegal instruction
	output logic valid_inst,  // for counting valid instructions executed
	                        // and for making the fetch stage die on halts/
	                        // keeping track of when to allow the next
	                        // instruction out of fetch
	                        // 0 for HALT and illegal instructions (die on halt)
	output logic rs1_exist, rs2_exist, // Does this insn has rs1/rs2?
	output FUNC_UNIT functor_out // which FU will this insn goes to?
);

	INST inst;
	logic valid_inst_in;
	
	assign inst          = if_packet.inst;
	assign valid_inst_in = if_packet.valid;
	assign valid_inst    = valid_inst_in & ~illegal;
	
	always_comb begin
		// default control values:
		// - valid instructions must override these defaults as necessary.
		//	 opa_select, opb_select, and alu_func should be set explicitly.
		// - invalid instructions should clear valid_inst.
		// - These defaults are equivalent to a noop
		// * see sys_defs.vh for the constants used here
		opa_select = OPA_IS_RS1;
		opb_select = OPB_IS_RS2;
		alu_func = ALU_ADD;
		dest_reg = DEST_NONE;
		csr_op = `FALSE;
		rd_mem = `FALSE;
		wr_mem = `FALSE;
		cond_branch = `FALSE;
		uncond_branch = `FALSE;
		halt = `FALSE;
		illegal = `FALSE;
		rs1_exist = `FALSE;
		rs2_exist = `FALSE;
		functor_out = FUNC_ALU;
		if(valid_inst_in) begin
			casez (inst) 
				`RV32_LUI: begin
					dest_reg   = DEST_RD;
					opa_select = OPA_IS_ZERO;
					opb_select = OPB_IS_U_IMM;
				end
				`RV32_AUIPC: begin
					dest_reg   = DEST_RD;
					opa_select = OPA_IS_PC;
					opb_select = OPB_IS_U_IMM;
				end
				`RV32_JAL: begin
					dest_reg      = DEST_RD;
					opa_select    = OPA_IS_PC;
					opb_select    = OPB_IS_J_IMM;
					uncond_branch = `TRUE;
				end
				`RV32_JALR: begin
					dest_reg      = DEST_RD;
					opa_select    = OPA_IS_RS1;
					opb_select    = OPB_IS_I_IMM;
					uncond_branch = `TRUE;
					rs1_exist     = `TRUE;
				end
				`RV32_BEQ, `RV32_BNE, `RV32_BLT, `RV32_BGE,
				`RV32_BLTU, `RV32_BGEU: begin
					opa_select  = OPA_IS_PC;
					opb_select  = OPB_IS_B_IMM;
					cond_branch = `TRUE;
					rs1_exist   = `TRUE;
					rs2_exist   = `TRUE;
				end
				`RV32_LB, `RV32_LH, `RV32_LW,
				`RV32_LBU, `RV32_LHU: begin
					dest_reg    = DEST_RD;
					opb_select  = OPB_IS_I_IMM;
					rd_mem      = `TRUE;
					rs1_exist   = `TRUE;
					functor_out = FUNC_MEM;
				end
				`RV32_SB, `RV32_SH, `RV32_SW: begin
					opb_select  = OPB_IS_S_IMM;
					wr_mem      = `TRUE;
					rs1_exist   = `TRUE;
					rs2_exist   = `TRUE;
					functor_out = FUNC_MEM;
				end
				`RV32_ADDI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					rs1_exist  = `TRUE;
				end
				`RV32_SLTI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SLT;
					rs1_exist  = `TRUE;
				end
				`RV32_SLTIU: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SLTU;
					rs1_exist  = `TRUE;
				end
				`RV32_ANDI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_AND;
					rs1_exist  = `TRUE;
				end
				`RV32_ORI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_OR;
					rs1_exist  = `TRUE;
				end
				`RV32_XORI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_XOR;
					rs1_exist  = `TRUE;
				end
				`RV32_SLLI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SLL;
					rs1_exist  = `TRUE;
				end
				`RV32_SRLI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SRL;
					rs1_exist  = `TRUE;
				end
				`RV32_SRAI: begin
					dest_reg   = DEST_RD;
					opb_select = OPB_IS_I_IMM;
					alu_func   = ALU_SRA;
					rs1_exist  = `TRUE;
				end
				`RV32_ADD: begin
					dest_reg   = DEST_RD;
					rs1_exist  = `TRUE;
					rs2_exist  = `TRUE;
				end
				`RV32_SUB: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SUB;
					rs1_exist  = `TRUE;
					rs2_exist  = `TRUE;
				end
				`RV32_SLT: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SLT;
					rs1_exist  = `TRUE;
					rs2_exist  = `TRUE;
				end
				`RV32_SLTU: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SLTU;
					rs1_exist  = `TRUE;
					rs2_exist  = `TRUE;
				end
				`RV32_AND: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_AND;
					rs1_exist  = `TRUE;
					rs2_exist  = `TRUE;
				end
				`RV32_OR: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_OR;
					rs1_exist  = `TRUE;
					rs2_exist  = `TRUE;
				end
				`RV32_XOR: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_XOR;
					rs1_exist  = `TRUE;
					rs2_exist  = `TRUE;
				end
				`RV32_SLL: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SLL;
					rs1_exist  = `TRUE;
					rs2_exist  = `TRUE;
				end
				`RV32_SRL: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SRL;
					rs1_exist  = `TRUE;
					rs2_exist  = `TRUE;
				end
				`RV32_SRA: begin
					dest_reg   = DEST_RD;
					alu_func   = ALU_SRA;
					rs1_exist  = `TRUE;
					rs2_exist  = `TRUE;
				end
				`RV32_MUL: begin
					dest_reg    = DEST_RD;
					alu_func    = ALU_MUL;
					rs1_exist   = `TRUE;
					rs2_exist   = `TRUE;
					functor_out = FUNC_MULT;
				end
				`RV32_MULH: begin
					dest_reg    = DEST_RD;
					alu_func    = ALU_MULH;
					rs1_exist   = `TRUE;
					rs2_exist   = `TRUE;
					functor_out = FUNC_MULT;
				end
				`RV32_MULHSU: begin
					dest_reg    = DEST_RD;
					alu_func    = ALU_MULHSU;
					rs1_exist   = `TRUE;
					rs2_exist   = `TRUE;
					functor_out = FUNC_MULT;
				end
				`RV32_MULHU: begin
					dest_reg    = DEST_RD;
					alu_func    = ALU_MULHU;
					rs1_exist   = `TRUE;
					rs2_exist   = `TRUE;
					functor_out = FUNC_MULT;
				end
				`RV32_CSRRW, `RV32_CSRRS, `RV32_CSRRC: begin
					// TODO: Why CSR does not have dest_reg?
					csr_op    = `TRUE;
					rs1_exist = `TRUE;
				end
				`WFI: begin
					halt = `TRUE;
				end
				default: illegal = `TRUE;

		endcase // casez (inst)
		end // if(valid_inst_in)
	end // always
endmodule // decoder


module dp_stage(
	// inputs
	input clock, // system clock
	input reset, // system reset
	input RT_PACKET [1:0] rt_packet,  // from ROB, in Retire stage
	input IF_DP_PACKET [`IF_SIZE-1:0] if_dp_packet_in,
	input [1:0] slots_left_rob_in, // from ROB, how many slots are left in ROB
	input slots_1_rs_in, slots_0_rs_in, // from RS, how many slots are left in RS
	input [1:0] slots_left_lsq_in, // from LSQ, how many "Store" entries left in LSQ
	
	// outputs
	// to RS, ROB, MapTable: multiple packets dispatched
	output DP_PACKET [1:0] dp_packet_out,
	// to insn_buffer, number of dp_packets could be sent in this cycle
	output logic [1:0] dp_packet_count_out
);
	IF_DP_PACKET [1:0] insn_buffer_out;
	// if_dp_packet_in gives insns stores in insn_buffer
	assign insn_buffer_out = if_dp_packet_in;


	logic [1:0] slots_left_rs_in;
	always_comb begin
		case ({slots_1_rs_in, slots_0_rs_in})
			2'b00 : slots_left_rs_in = 2'b10;
			2'b10 : slots_left_rs_in = 2'b01;
			2'b01 : slots_left_rs_in = 2'b00;
			default : slots_left_rs_in = 2'b00;
		endcase
	end

	// always_comb begin
	// 	if (slots_left_rs_in <= insn_buffer_out_size && slots_left_rs_in <= slots_left_rob_in) begin
	// 		dp_packet_count_out = slots_left_rs_in;
	// 	end else if (slots_left_rob_in <= insn_buffer_out_size) begin
	// 		dp_packet_count_out = slots_left_rob_in;
	// 	end else begin
	// 		dp_packet_count_out = insn_buffer_out_size;
	// 	end
	// end

	always_comb begin
		if (slots_left_rob_in <= slots_left_rs_in) begin
			if (slots_left_lsq_in < slots_left_rob_in)
				dp_packet_count_out = slots_left_lsq_in;
			else
				dp_packet_count_out = slots_left_rob_in;
		end else begin
			if (slots_left_lsq_in < slots_left_rs_in)
				dp_packet_count_out = slots_left_lsq_in;
			else
				dp_packet_count_out = slots_left_rs_in;
		end
	end



	DEST_REG_SEL [1:0] dest_reg_select; 

	// Instantiate the register file used by this pipeline
	// Sadly, our regFile is only 2-way
	regfile regf_0 (
		.rda_idx({insn_buffer_out[1].inst.r.rs1, insn_buffer_out[0].inst.r.rs1}),
		.rda_out({dp_packet_out[1].rs1_value, dp_packet_out[0].rs1_value}), 
		.rdb_idx({insn_buffer_out[1].inst.r.rs2, insn_buffer_out[0].inst.r.rs2}),
		.rdb_out({dp_packet_out[1].rs2_value, dp_packet_out[0].rs2_value}),

		.wr_clk(clock),
		.wr_en({rt_packet[1].valid, rt_packet[0].valid}),
		.wr_idx({rt_packet[1].retire_reg, rt_packet[0].retire_reg}),
		.wr_data({rt_packet[1].value, rt_packet[0].value})
	);

	// instantiate the instruction decoder(s)
	generate
		genvar i;
		for (i = 0; i < `DP_SIZE; i++) begin
			assign dp_packet_out[i].inst  = insn_buffer_out[i].inst;
			assign dp_packet_out[i].NPC   = if_dp_packet_in[i].NPC;
			assign dp_packet_out[i].PC    = if_dp_packet_in[i].PC;
			assign dp_packet_out[i].dp_en = dp_packet_out[i].valid;
			decoder decorder_elem (
				// input
				.if_packet(insn_buffer_out[i]),
				// outputs
				.opa_select(dp_packet_out[i].opa_select),
				.opb_select(dp_packet_out[i].opb_select),
				.dest_reg(dest_reg_select[i]),
				.alu_func(dp_packet_out[i].alu_func),
				.rd_mem(dp_packet_out[i].rd_mem),
				.wr_mem(dp_packet_out[i].wr_mem),
				.cond_branch(dp_packet_out[i].cond_branch),
				.uncond_branch(dp_packet_out[i].uncond_branch),
				.csr_op(dp_packet_out[i].csr_op),
				.halt(dp_packet_out[i].halt),
				.illegal(dp_packet_out[i].illegal),
				.valid_inst(dp_packet_out[i].valid),
				.rs1_exist(dp_packet_out[i].rs1_exist),
				.rs2_exist(dp_packet_out[i].rs2_exist),
				.functor_out(dp_packet_out[i].func_unit)
			);
		end
	endgenerate


	// mux to generate dest_reg_idx based on
	// the dest_reg_select output from decoder
	always_comb begin
		for (int j = 0; j < `DP_SIZE; j++) begin
			case (dest_reg_select[j])
				DEST_RD:    dp_packet_out[j].dest_reg_idx = insn_buffer_out[j].inst.r.rd;
				DEST_NONE:  dp_packet_out[j].dest_reg_idx = `ZERO_REG;
				default:    dp_packet_out[j].dest_reg_idx = `ZERO_REG; 
			endcase
		end
	end
   
endmodule // module dp_stage
