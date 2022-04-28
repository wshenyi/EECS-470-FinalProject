module testbench;
    logic clock, reset, enable;
    logic [1:0] dp_packets_count_in;
    logic squash_in;
    IF_DP_PACKET [1:0] if_packets_in;
    logic [1:0] available_in_size_out;
    IF_DP_PACKET [1:0] if_id_packets_out; 

    
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

    always begin
        #5;
        clock = ~clock;
    end

    initial begin
        clock = 0;
        reset = 1;
        enable = 1;
        dp_packets_count_in = 0;
        squash_in = 0;
        if_packets_in = 0;
        for (int i=0;i<13;i++) begin
        @(posedge clock);
        #1;
        reset = 0;
        if_packets_in[0].inst = 4*i+1;
        if_packets_in[1].inst = 4*i+2;
        if_packets_in[0].valid = 1;
        if_packets_in[1].valid = 1;
        dp_packets_count_in = 2;
        end
        @(posedge clock);
        #1;
        if_packets_in[0].inst = 32'hDEAD_BEEF;
        if_packets_in[1].inst = 32'hDEAD_BEEF;
        if_packets_in[0].valid = 1;
        if_packets_in[1].valid = 1;
        dp_packets_count_in = 2;
        
        for (int i=0;i<20;i++) begin
        @(posedge clock);
        #1;
        reset = 0;
        if_packets_in[0].inst = 4*i;
        if_packets_in[1].inst = 4*i+21;
        if_packets_in[0].valid = 1;
        if_packets_in[1].valid = 1;
        dp_packets_count_in = 0;
        end
        for (int i=0;i<20;i++) begin
        @(posedge clock);
        #1;
        reset = 0;
        if_packets_in[0].inst = 4*i;
        if_packets_in[1].inst = 4*i+31;
        if_packets_in[0].valid = 1;
        if_packets_in[1].valid = 1;
        dp_packets_count_in = 2;
        end
        for (int i=0;i<20;i++) begin
        @(posedge clock);
        #1;
        reset = 0;
        if_packets_in[0].inst = 4*i+41;
        if_packets_in[1].inst = 4*i+42;
        if_packets_in[0].valid = 1;
        if_packets_in[1].valid = 1;
        dp_packets_count_in = 2;
        end
        for (int i=0;i<20;i++) begin
        @(posedge clock);
        #1;
        reset = 0;
        if_packets_in[0].inst = 4*i+51;
        if_packets_in[1].inst = 4*i+52;
        if_packets_in[0].valid = 1;
        if_packets_in[1].valid = 0;
        dp_packets_count_in = 2;
        end
        
        for (int i=0;i<20;i++) begin
        @(posedge clock);
        reset = 0;
        if_packets_in[0].inst = 4*i;
        if_packets_in[1].inst = 4*i+1;
        if_packets_in[0].valid = 0;
        if_packets_in[1].valid = 0;
        dp_packets_count_in = 2;
        end
        
        $finish;
    end
endmodule
