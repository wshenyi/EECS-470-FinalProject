module mem_fu(
	input clock,               // system clock
	input reset,               // system reset 
	input squash_in,
	input  IS_EX_PACKET   is_ex_ld_packet_in,is_ex_st_packet_in,
	output EX_MEM_PACKET  ex_mem_store_out,
	output EX_MEM_PACKET   ex_mem_load_out
);
	
	EX_MEM_PACKET	ex_ld_packet, ex_st_packet; 

	//logic [`XLEN-1:0] alu_result;
	// Pass-throughs
	assign ex_ld_packet.NPC = is_ex_ld_packet_in.NPC;
	assign ex_ld_packet.inst = is_ex_ld_packet_in.inst;
	assign ex_ld_packet.rs2_value = is_ex_ld_packet_in.rs2_value;
	assign ex_ld_packet.rd_mem = is_ex_ld_packet_in.rd_mem;
	assign ex_ld_packet.wr_mem = is_ex_ld_packet_in.wr_mem;
	assign ex_ld_packet.dest_reg_idx = is_ex_ld_packet_in.dest_reg_idx;
	assign ex_ld_packet.halt = is_ex_ld_packet_in.halt;
	assign ex_ld_packet.illegal = is_ex_ld_packet_in.illegal;
	assign ex_ld_packet.valid = is_ex_ld_packet_in.valid;
	assign ex_ld_packet.csr_op = is_ex_ld_packet_in.csr_op;
	assign ex_ld_packet.mem_size = is_ex_ld_packet_in.inst.r.funct3;
    assign ex_ld_packet.sq_pos = is_ex_ld_packet_in.tail_pos;
    assign ex_ld_packet.Tag = is_ex_ld_packet_in.Tag; //ROB#

	assign ex_mem_load_out = ex_ld_packet; 
	
	logic [`XLEN-1:0] opb_mux_ld_out;

	 //
	 // ALU opB mux
	 //
	always_comb begin
		// Default value, Set only because the case isnt full.  If you see this
		// value on the output of the mux you have an invalid opb_select
		opb_mux_ld_out = `XLEN'hfacefeed;
		case (is_ex_ld_packet_in.opb_select)
			OPB_IS_I_IMM: opb_mux_ld_out = `RV32_signext_Iimm(is_ex_ld_packet_in.inst); // load
			OPB_IS_S_IMM: opb_mux_ld_out = `RV32_signext_Simm(is_ex_ld_packet_in.inst); // store
		endcase 
	end

	assign ex_ld_packet.alu_result = is_ex_ld_packet_in.rs1_value + opb_mux_ld_out; 


	assign ex_st_packet.NPC = is_ex_st_packet_in.NPC;
	assign ex_st_packet.inst = is_ex_st_packet_in.inst;
	assign ex_st_packet.rs2_value = is_ex_st_packet_in.rs2_value;
	assign ex_st_packet.rd_mem = is_ex_st_packet_in.rd_mem;
	assign ex_st_packet.wr_mem = is_ex_st_packet_in.wr_mem;
	assign ex_st_packet.dest_reg_idx = is_ex_st_packet_in.dest_reg_idx;
	assign ex_st_packet.halt = is_ex_st_packet_in.halt;
	assign ex_st_packet.illegal = is_ex_st_packet_in.illegal;
	assign ex_st_packet.valid = is_ex_st_packet_in.valid;
	assign ex_st_packet.mem_size = is_ex_st_packet_in.inst.r.funct3;
	assign ex_st_packet.csr_op = is_ex_st_packet_in.csr_op;
    assign ex_st_packet.sq_pos = is_ex_st_packet_in.tail_pos;
    assign ex_st_packet.Tag = is_ex_st_packet_in.Tag; //ROB#

	assign ex_mem_store_out = ex_st_packet; 
	
	logic [`XLEN-1:0] opb_mux_st_out;

	 //
	 // ALU opB mux
	 //
	always_comb begin
		// Default value, Set only because the case isnt full.  If you see this
		// value on the output of the mux you have an invalid opb_select
		opb_mux_st_out = `XLEN'hfacefeed;
		case (is_ex_st_packet_in.opb_select)
			OPB_IS_I_IMM: opb_mux_st_out = `RV32_signext_Iimm(is_ex_st_packet_in.inst); // load
			OPB_IS_S_IMM: opb_mux_st_out = `RV32_signext_Simm(is_ex_st_packet_in.inst); // store
		endcase 
	end

	assign ex_st_packet.alu_result = is_ex_st_packet_in.rs1_value + opb_mux_st_out; 

	// always_ff @(posedge clock) begin
	// 	if (reset)begin
	// 		ex_mem_load_out <= `SD 0; 
	// 	end
	// 	else if (squash_in) begin
	// 		ex_mem_load_out <= `SD 0; 
	// 	end
	// 	else if (load_enable && ex_mem_packet.rd_mem ) begin
	// 		ex_mem_load_out <= `SD ex_mem_packet;
	// 	end
	// 	else begin
	// 		ex_mem_load_out <= `SD 0;
	// 	end
	// end

endmodule // module ex_stage

