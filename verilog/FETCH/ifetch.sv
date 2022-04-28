module ifetch(
    input clock,    // system clock
	input reset,    // system reset
    input stall,    // signal from insn_buffer
    input squash_from_retire_in,    // squash signal
    input Icache2proc_valid_in,
    input [`XLEN-1:0] squashed_new_PC_in,
    input [63:0] Icache2proc_data_in,
	input [1:0] [`XLEN-1:0] bp_pc, bp_npc,
    output logic [`XLEN-1:0] proc2Icache_addr_out,
	output IF_ID_PACKET  [1:0] if_packet_out         // Output data packet from IF going to ID, see sys_defs for signal information 

);

    logic  reset_flag;

    logic  [1:0][`XLEN-1:0]  pc_reg;             // PC we are currently fetching
    logic  [1:0][`XLEN-1:0]  next_pc;
	logic           	     PC_enable;


    // stall PC when insn buffer is full
    assign PC_enable = ~stall & Icache2proc_valid_in;
    

    // Instruction address in memory
	assign proc2Icache_addr_out = {pc_reg[0][`XLEN-1:3], 3'b0};    

    // fetch the data from memory
    // always_comb begin
    //     case (pc_reg[2])
    //     1'b0: begin
    //           if_packet_out[0].inst = Icache2proc_data_in[31:0];
    //           if_packet_out[1].inst = Icache2proc_data_in[63:32];

    //           if_packet_out[0].valid = 1'b1 & ~stall & ~reset_flag;
    //           if_packet_out[1].valid = 1'b1 & ~stall & ~reset_flag;

    //           if_packet_out[0].PC = pc_reg;
    //           if_packet_out[1].PC = pc_reg + 4;

    //           if_packet_out[0].NPC = if_packet_out[1].PC;
    //           if_packet_out[1].NPC = if_packet_out[1].PC + 4;
    //           end
    //     1'b1: begin
    //           if_packet_out[0].inst = Icache2proc_data_in[63:32];
    //           if_packet_out[1].inst = 32'hDEAD_BEEF;

    //           if_packet_out[0].valid = 1'b1 & ~stall & ~reset_flag;
    //           if_packet_out[1].valid = 1'b0;

    //           if_packet_out[0].PC = pc_reg;
    //           if_packet_out[1].PC = 32'hDEAD_BEEF;

    //           if_packet_out[0].NPC = if_packet_out[1].PC;
    //           if_packet_out[1].NPC = 32'hDEAD_BEEF;
    //           end
    //     endcase
    // end

	assign if_packet_out[0].inst = Icache2proc_data_in[31:0];
	assign if_packet_out[1].inst = Icache2proc_data_in[63:32];

	assign if_packet_out[0].valid = PC_enable;
	assign if_packet_out[1].valid = PC_enable;

	assign if_packet_out[0].PC = pc_reg[0];
	assign if_packet_out[1].PC = pc_reg[1];

	assign if_packet_out[0].NPC = squash_from_retire_in ? squashed_new_PC_in +4 : bp_npc[0];
	assign if_packet_out[1].NPC = squash_from_retire_in ? squashed_new_PC_in +8 : bp_npc[1];
    
    

  
    // if taken branch NPC is target PC, else if PC =0 or PC/4 is odd, NPC is PC+4 
    assign next_pc[0] = squash_from_retire_in ? squashed_new_PC_in : 
                         bp_pc[0];
    assign next_pc[1] = squash_from_retire_in ? squashed_new_PC_in + 4 : 
                         bp_pc[1];
						
    
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            pc_reg[0] <= `SD  32'h0;
			pc_reg[1] <= `SD  32'h4;
        end 
        else if (PC_enable | squash_from_retire_in) begin
            pc_reg[0] <= `SD  next_pc[0];
			pc_reg[1] <= `SD  next_pc[1];
        end
	end
	
	

endmodule  // module if_stage
