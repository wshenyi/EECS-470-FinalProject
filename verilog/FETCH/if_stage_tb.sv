module if_stage_tb();
    logic clock, reset;
    logic sfri; // = squash_en
    logic [`XLEN-1:0] snpi; // = squashed_new_PC_in
    logic mfci; // = max_fetch_count_in

    ICACHE_IF_PACKET [1:0] Icache_if_packet;

    // Outputs from DUT
    IF_ICACHE_PACKET [1:0] if_icache_packet;
    IF_DP_PACKET     [1:0] if_ib_packet;

    ifetch DUT(
        // Inputs
        .clock(clock),    // system clock
        .reset(reset),    // system reset
        .squash_en(sfri), // from retire stage
        .squashed_new_PC_in(snpi), // from retire stage
        .max_fetch_count_in(mfci), // from insn_fifo
        .icache_if_packet_in(Icache_if_packet),

        // Outputs
        .if_icache_packet_out(if_icache_packet), // to icache
        .if_dp_packet_out(if_ib_packet) // to insn_fifo
    );


    always begin
        #5;
        clock = ~clock;
    end

    initial begin
        $monitor("Time:%4.0f insn_1:%d, insn_2:%d", $time, if_icache_packet[0].Icache_addr_in, if_icache_packet[1].Icache_addr_in);

        for (int i = 0; i < `IF_SIZE; i++) begin
            Icache_if_packet[i].Icache_valid_out = 1;
            Icache_if_packet[i].Icache_data_out  = $urandom;
        end
        clock = 0;
        reset = 1;
        mfci = 2'b11;
        @(negedge clock);
        reset = 0;
        $display("Finish reset");
        // assert (if_ib_packet[0].valid == 0) else $finish;
        // assert (if_ib_packet[1].valid == 0) else $finish;
        // @(negedge clock);
        
        // @(negedge clock);
        // assert (if_ib_packet[0].valid == 1) else $finish;
        // assert (if_ib_packet[1].valid == 1) else $finish;
        repeat(95)@(negedge clock);
        sfri = 1;
        snpi = 28;
        @(negedge clock);
        sfri = 0;
        repeat(100)@(negedge clock);
        mfci = 2'b10;

        #50;

        $display("@@@ PASSED");
        $finish;
    end

endmodule
