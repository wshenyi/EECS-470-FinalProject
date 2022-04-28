module t0 ();
    logic clock,reset;
    RT_PACKET [1:0] rt_packet ;
    IF_DP_PACKET [`IF_SIZE-1:0] if_id_packet_in;
	logic [1:0] dp_available; // from ROB, how many slots are left in ROB
	logic leave_one_slot_empty, slot_full; // from RS, how many slots are left in RS
    DP_PACKET [`DP_SIZE-1:0] dp_packet;
	// to insn_buffer, number of dp_packets could be sent in this cycle
	logic [$clog2(`DP_SIZE):0] actual_dp_packets_count;
    logic [1:0] LSQ_dp_available; // from LSQ.dp_available

    dp_stage DUT (
		// Inputs
		.clock(clock),
		.reset(reset),
		.rt_packet(rt_packet), // connect to ROB.RT_PACKET_out
		.if_dp_packet_in(if_id_packet_in),
		.slots_left_rob_in(dp_available), // connect to ROB.dp_availble
		.slots_1_rs_in(leave_one_slot_empty), // connect to RS.leave_one_slot_empty
		.slots_0_rs_in(slot_full), // connect to RS.slot_full
        .slots_left_lsq_in(LSQ_dp_available),
		
		// Outputs
		.dp_packet_out(dp_packet), // going down to RS, ROB, MapTable
		.dp_packet_count_out(actual_dp_packets_count) // going up to insn_buffer
	);

    always begin
        #5;
        clock = ~clock;
    end

    initial begin
        clock = 0;
        reset = 1;
        rt_packet[0] = 0;
        rt_packet[1] = 0;
        if_id_packet_in[0] = { 1'b1,
                            `NOP,
                            {`XLEN{1'b0}},
                            {`XLEN{1'b0}}};
        if_id_packet_in[1] = { 1'b1,
                            `NOP,
                            {`XLEN{1'b0}},
                            {`XLEN{1'b0}}};
        dp_available = 2;
        leave_one_slot_empty = 0;
        slot_full = 0;
        LSQ_dp_available = 2;
        @(negedge clock);
        reset = 0;
        for (int i=0;i<10;i++) begin
            @(negedge clock);
            if_id_packet_in[0].PC = 32'hDEAD_BEEF;
            if_id_packet_in[1].PC = 32'hCAFE_B00D;
            if (i == 5) begin
                leave_one_slot_empty = 1;
                dp_available = 1;
            end
        end
        $finish;
    end
endmodule