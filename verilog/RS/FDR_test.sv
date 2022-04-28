module t1();
    logic clock, reset, insn_enable, rs_enable;


    logic [1:0] [63:0] mem2Icache_data;
    logic [1:0] [`XLEN-1:0] Icache2mem_addr;
    logic [`XLEN-1:0] target_pc;
    IF_DP_PACKET [3:0] if_id_packet_out;

    logic squash_in;
    IF_DP_PACKET [1:0] if_id_packets_out;
    logic full;
    DP_PACKET [1:0] dp_packet_out;
	// to insn_buffer, number of dp_packets could be sent in this cycle
	logic [1:0] dp_packets_count_out;
     logic                                leave_one_slot_empty;
    logic                                slot_full;
    RS_IS_PACKET          [`RS_SIZE-1:0] rs_out;
    logic                 [`RS_SIZE-1:0] ready;

    logic [`RS_SIZE-1:0] free;


    logic [1:0] dp_available;
    assign dp_available = 2;


    assign insn_enable = 1;
    assign rs_enable = 1;
    assign free = 0;

    ifetch ifetch_0(
    .clock(clock),    // system clock
	.reset(reset),    // system reset
    .stall(insn_full),    // signal from insn_buffer
    .squash_from_retire_in(squash_signal),    // squash signal
    .Icache2proc_valid_in(Icache_valid_out),
    .squashed_new_PC_in(RT_NPC),
    .Icache2proc_data_in(Icache_data_out),
	.bp_pc(bp_pc),
    .bp_npc(bp_npc),
    .proc2Icache_addr_out(proc2Icache_addr),
	.if_packet_out(if_packet_out)         // Output data packet from IF going to ID, see sys_defs for signal information 
);

    insn_buffer DUT(
        .clock(clock),
        .reset(reset),
        .enable(enable),
        .dp_packets_count_in(dp_packets_count_in),
        .squash_in(squash_in),
        .if_packets_in(if_packets_in),
        //output 
        //.available_in_size_out(available_in_size_out),
        .if_id_packets_out(if_id_packets_out),
        .buffer_full(full)
    );
    dp_stage dp (
		// Inputs
		.clock(clock),
		.reset(reset),
		.rt_packet(), // connect to ROB.RT_PACKET_out
		.if_id_packet_in(if_id_packets_out),
		.slots_left_rob_in(dp_available), // connect to ROB.dp_availble
		.slots_1_rs_in(leave_one_slot_empty), // connect to RS.leave_one_slot_empty
		.slots_0_rs_in(slot_full), // connect to RS.slot_full
		
		// Outputs
		.dp_packet_out(dp_packet_out), // going down to RS, ROB, MapTable
		.dp_packets_count_out(dp_packets_count_out) // going up to insn_buffer
	);

    RS rs ( .clock(clock),
            .reset(reset),
            .enable(rs_enable),
            .squash_signal_in(squash_in),
            .mt_rs_in(),
            .dp_packet_in(dp_packet_out),
            .rob_in(),
            .cdb_in(),
            .free(free),
            //output 
            .leave_one_slot_empty(leave_one_slot_empty),
            .slot_full(slot_full),
            .RS_OUT(rs_out),
            .ready(ready)
            );

    always begin
        #5;
        clock = ~clock;
    end

    initial begin
        clock = 0;
        reset = 1;

        squash_in = 0;
        @(negedge clock);
            reset = 0;
        for (int i =0;i<64;i++) begin
            @(negedge clock);
            reset = 0;
            mem2Icache_data[0][31:0]  = 4*i;
            mem2Icache_data[0][63:32] = 4*i+1;
            mem2Icache_data[1][31:0]  = 4*i+2;
            mem2Icache_data[1][63:32] = 4*i+3;
            if(i==30) begin
                squash_in =1;
                target_pc = 12;
            end
            if(i==31) begin
                squash_in =0;
            end
            if(i==40) begin
                squash_in =1;
                target_pc = 8;
            end
            if(i==41) begin
                squash_in =0;
            end
        end
        $finish;
    end
endmodule