module t1();

    logic clock;    // system clock
	logic reset;    // system reset
    logic stall;    // signal from insn_buffer
    logic squash_from_retire_in;    // squash signal
    logic Icache2proc_valid_in;
    logic [`XLEN-1:0] squashed_new_PC_in;
    logic [63:0] Icache2proc_data_in;
	logic [1:0] [`XLEN-1:0] bp_pc;
    logic [`XLEN-1:0] proc2Icache_addr_out;
	IF_ID_PACKET  [1:0] if_packet_out;   // Output data packet from IF going to ID, see sys_defs for signal information 


    ifetch DUT(
    .clock(clock),    // system clock
	.reset(reset),    // system reset
    .stall(stall),    // signal from insn_buffer
    .squash_from_retire_in(squash_from_retire_in),    // squash signal
    .Icache2proc_valid_in(Icache2proc_valid_in),
    .squashed_new_PC_in(squashed_new_PC_in),
    .Icache2proc_data_in(Icache2proc_data_in),
	.bp_pc(bp_pc),
    .proc2Icache_addr_out(proc2Icache_addr_out),
	.if_packet_out(if_packet_out)         // Output data packet from IF going to ID, see sys_defs for signal information 
);
    always begin
        #5;
        clock = ~clock;
    end

    initial begin
        clock = 0;
        reset = 1;
        stall = 0;
        bp_pc[0] = 8;
        bp_pc[1] = 12;
        Icache2proc_data_in = 0;
        squash_from_retire_in = '0;
        Icache2proc_valid_in = 1;
        @(negedge clock);
            reset = 0;
        for (int i =0;i<64;i++) begin
            @(negedge clock);
            reset = 0;
            bp_pc[0] = 4*i+8;
            bp_pc[1] = 4*i+12;
            Icache2proc_data_in[31:0]  = 2*i;
            Icache2proc_data_in[63:32] = 2*i+1;
            if(i==30) begin
                squash_from_retire_in =1;
              
                stall =1;
            end
            if(i==31) begin
                squash_from_retire_in =0;
            end
            if(i==35) begin
                 stall =0;
            end
            if(i==40) begin
                squash_from_retire_in =0;
            
            end
            if(i==41) begin
                squash_from_retire_in =0;
            end
        end
        $finish;
    end

endmodule
