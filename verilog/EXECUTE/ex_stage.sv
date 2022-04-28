module ex_stage (
    input clock, reset, squash_in,
    input ex_cp_alu0_en, ex_cp_alu1_en,
    input IS_EX_PACKET is_ex_alu0,is_ex_alu1,is_ex_st,is_ex_ld,is_ex_mult,
    input EX_CP_PACKET lsq_cp_packet_in, 
    output EX_CP_PACKET ex_cp_alu0, ex_cp_alu1, ex_cp_mult, ex_cp_mem, 
    output EX_MEM_PACKET ex_lsq_store_out, ex_lsq_load_out, 
    output EX_BP_PACKET [1:0] ex_bp_packet_out
);
    
    alu_fu alu0(
	.clock(clock),               // system clock
	.reset(reset),               // system reset
    .enable(ex_cp_alu0_en),
    .squash_in(squash_in),
	.is_ex_packet_in(is_ex_alu0),
	.ex_cp_packet(ex_cp_alu0),
    .ex_bp_packet_out(ex_bp_packet_out[0])
    );

    alu_fu alu1(
	.clock(clock),               // system clock
	.reset(reset),               // system reset
    .enable(ex_cp_alu1_en),
    .squash_in(squash_in),
	.is_ex_packet_in(is_ex_alu1),
	.ex_cp_packet(ex_cp_alu1),
    .ex_bp_packet_out(ex_bp_packet_out[1])
    );

    mult_fu #(.XLEN(32),.NUM_STAGE(4)) m0(	
    .clock(clock),
    .reset(reset),
    .squash_in(squash_in),
    .is_ex_packet_in(is_ex_mult),
    .ex_cp_packet_out(ex_cp_mult)
    );

    mem_fu mem_fu(
    .clock(clock),
    .reset(reset),
    .squash_in(squash_in),
    .is_ex_st_packet_in(is_ex_st), 
	.is_ex_ld_packet_in(is_ex_ld), 
    .ex_mem_store_out(ex_lsq_store_out), 
    .ex_mem_load_out(ex_lsq_load_out)                
    );
	
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset)begin
			ex_cp_mem.Value <= `SD 0;
			ex_cp_mem.NPC <= `SD 0;
			ex_cp_mem.take_branch <= `SD 0;
			ex_cp_mem.inst <= `SD `NOP;
			ex_cp_mem.dest_reg_idx <= `SD `ZERO_REG;
			ex_cp_mem.halt <= `SD `FALSE;
			ex_cp_mem.illegal <= `SD `FALSE;
			ex_cp_mem.valid <= `SD 0;
			ex_cp_mem.done <= `SD 0;
			ex_cp_mem.Tag <= `SD 0;
		end
		else if (squash_in) begin
			ex_cp_mem.Value <= `SD 0;
			ex_cp_mem.NPC <= `SD 0;
			ex_cp_mem.take_branch <= `SD 0;
			ex_cp_mem.inst <= `SD `NOP;
			ex_cp_mem.dest_reg_idx <= `SD `ZERO_REG;
			ex_cp_mem.halt <= `SD `FALSE;
			ex_cp_mem.illegal <= `SD `FALSE;
			ex_cp_mem.valid <= `SD 0;
			ex_cp_mem.done <= `SD 0;
			ex_cp_mem.Tag <= `SD 0;
		end
		else begin
			ex_cp_mem <= `SD lsq_cp_packet_in;
		end
	end

endmodule
