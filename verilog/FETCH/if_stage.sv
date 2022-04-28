/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  if_stage.v                                          //
//                                                                     //
//  Description :  instruction fetch (IF) stage of the pipeline;       // 
//                 fetch instruction, compute next PC location, and    //
//                 send them down the pipeline.                        //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

module if_stage(
	input clock,                  // system clock
	input reset,                  // system reset
	input dp_stall,                  // signal from insn_buffer
	input squash_en,              // from Retire stage, 1 if squashing is needed
	input                      [`XLEN-1:0] squashed_new_PC_in,
	input  			  	 [`IF_SIZE-1:0] [`XLEN-1:0] bp_pc, bp_npc,
	input  ICACHE_IF_PACKET [`IF_SIZE-1:0] icache_if_packet_in,
	input  bp_taken,

	output IF_DP_PACKET     [`IF_SIZE-1:0] if_dp_packet_out, // to insn_buffer
	output IF_DP_PACKET     [`IF_SIZE-1:0] if_bp_packet_out,
	output IF_ICACHE_PACKET [`IF_SIZE-1:0] if_icache_packet_out
);

	logic  reset_flag;
	logic  PC_enable;
	logic  Icache_valid_out;
	reg [`XLEN-1:0] PC_reg  [`IF_SIZE-1:0]; // PC of the first insn we are currently fetching
	reg [`XLEN-1:0] NPC_reg [`IF_SIZE-1:0];

    // stall PC when insn buffer is full
	assign Icache_valid_out = icache_if_packet_in[0].Icache_valid_out & icache_if_packet_in[1].Icache_valid_out;
    assign PC_enable = ~dp_stall & Icache_valid_out;

    assign NPC_reg[0] = squash_en ? squashed_new_PC_in : 
                         bp_pc[0];
    assign NPC_reg[1] = squash_en ? squashed_new_PC_in + 4 : 
                         bp_pc[1];

	always_comb begin
		for (int i = 0; i < `IF_SIZE; i++) begin
			if_icache_packet_out[i].Icache_addr_in = if_dp_packet_out[i].PC;
			if_icache_packet_out[i].Icache_request = ~dp_stall & ~squash_en;
		end
	end

	

	always_comb begin
		if_dp_packet_out[0].inst  = icache_if_packet_in[0].Icache_data_out;
		if_dp_packet_out[0].valid = PC_enable & icache_if_packet_in[0].Icache_valid_out;
		if_dp_packet_out[0].PC    = PC_reg[0];
		if_dp_packet_out[0].NPC   = squash_en ? squashed_new_PC_in + 4 : bp_npc[0];

		if_dp_packet_out[1].inst  = icache_if_packet_in[1].Icache_data_out;
		if_dp_packet_out[1].valid = PC_enable & icache_if_packet_in[1].Icache_valid_out & (!bp_taken|squash_en);
		if_dp_packet_out[1].PC    = PC_reg[1];
		if_dp_packet_out[1].NPC   = squash_en ? squashed_new_PC_in + 8 : bp_npc[1];
	end

	always_comb begin
		if_bp_packet_out[0].inst  = icache_if_packet_in[0].Icache_data_out;
		if_bp_packet_out[0].valid = PC_enable & icache_if_packet_in[0].Icache_valid_out;
		if_bp_packet_out[0].PC    = PC_reg[0];
		if_bp_packet_out[0].NPC   = squash_en ? squashed_new_PC_in + 4 : bp_npc[0];

		if_bp_packet_out[1].inst  = icache_if_packet_in[1].Icache_data_out;
		if_bp_packet_out[1].valid = PC_enable & icache_if_packet_in[1].Icache_valid_out;
		if_bp_packet_out[1].PC    = PC_reg[1];
		if_bp_packet_out[1].NPC   = squash_en ? squashed_new_PC_in + 8 : bp_npc[1];
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset)
			for (int unsigned i = 0; i < `IF_SIZE; i++) begin
				PC_reg[i] <= `SD i * 4;
			end
		else if (squash_en | (PC_enable & Icache_valid_out)) begin
			PC_reg <= `SD NPC_reg;
		end 
	end  // always

endmodule  // module if_stage
