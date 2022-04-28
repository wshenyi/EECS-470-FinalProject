module testbench;
    // Inputs
    logic clock, reset, squash_en;
    logic [3:0]   mem2proc_response;        // Tag from memory about current request
    logic [63:0]  mem2proc_data;            // Data coming back from memory
    logic [3:0]   mem2proc_tag;  
    logic         mem2Icache_ack;
    IF_ICACHE_PACKET [1:0] if_icache_packet;

    // Outputs
    BUS_COMMAND       Icache2mem_command;
    logic [`XLEN-1:0] Icache2mem_addr;
    ICACHE_IF_PACKET [1:0] Icache_IF_packet;

    // Debug
    logic [31:0] clock_count;
    logic [63:0] proc2Dmem_data;

    mem memory(
        .clk(clock),
        .proc2mem_addr(Icache2mem_addr),
        .proc2mem_data(proc2Dmem_data),
        .proc2mem_command(Icache2mem_command),
        .mem2proc_response(mem2proc_response),
        .mem2proc_data(mem2proc_data),
        .mem2proc_tag(mem2proc_tag)
    );

    icache icache_0(
        // Inputs
        .clock(clock),
        .reset(reset),
        .squash_en(squash_en),
        .mem2Icache_response_in(mem2proc_response),  // from mem, note the "I"
        .mem2Icache_data_in(mem2proc_data),    // from mem
        .mem2Icache_tag_in(mem2proc_tag),    // from mem
        .mem2Icache_ack_in(mem2Icache_ack),
        .IF_Icache_packet_in(if_icache_packet),

        // Outputs
        .Icache2mem_command_out(Icache2mem_command),  // output to mem
        .Icache2mem_addr_out(Icache2mem_addr),    // output to mem
        .Icache_IF_packet_out(Icache_IF_packet)
    );

    always begin
        #5;
        clock = ~clock;
    end

    always @(posedge clock) begin
        if(reset) begin
            clock_count <= `SD 0;
        end else begin
            clock_count <= `SD (clock_count + 1);
        end

        // Stop if the pipeline stuck in an infinite loop
        if (clock_count > 1000) begin
            #100 $finish;
        end
    end

    initial begin
        clock = 1'b0;
        reset = 1'b1;
        squash_en = 1'b0;
        proc2Dmem_data = '0;


        @(posedge clock);
        reset = 1'b0;
        for(int i = 0; i < 0; i+=8) begin
            for(int j = 0; j < 2; j++) begin
                if_icache_packet[j].Icache_addr_in = i + j * 4;
                if_icache_packet[j].Icache_request = 1;
            end
            @(posedge clock);
            mem2Icache_ack = (|mem2proc_response) && (|Icache2mem_command);

            if (Icache_IF_packet[0].Icache_valid_out) begin
                $display("===");
                $display(Icache_IF_packet[0].Icache_data_out);
            end
            if (Icache_IF_packet[1].Icache_valid_out) begin
                $display("===");
                $display(Icache_IF_packet[1].Icache_data_out);
            end
        end

    end

endmodule