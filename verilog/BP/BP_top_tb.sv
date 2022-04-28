
module t0();
    logic clock, reset;
    logic squash_en;
    logic [1:0] [`XLEN-1:0] if_pc_in;    // pc from if stage  
    INST  [1:0] inst;    // predict pc taken or no taken
    logic [1:0] if_inst_valid;     
    logic [1:0][`XLEN-1:0] bp_pc_out, bp_npc_out;
    EX_BP_PACKET [1:0] ex_bp_packet_in;


    integer cnt,cnt_1;
    logic [1:0] flag;

    BP_top DUT(
        .clock(clock),
        .reset(reset),
        .ex_bp_packet_in(ex_bp_packet_in),
        .if_pc_in(if_pc_in),    //pc from if stage
        .inst(inst),    // instruction
        .valid(if_inst_valid),
        // output
        .bp_pc_out(bp_pc_out),
        .bp_npc_out(bp_npc_out)
    );

    


    always begin 
        #5;
        clock=~clock;
    end

    initial begin
        clock = 0;
        reset = 1;
        ex_bp_packet_in[0].con_br_en = 1;
        ex_bp_packet_in[0].br_en = 1;
        ex_bp_packet_in[1].con_br_en = 1;
        ex_bp_packet_in[1].br_en = 1;
        cnt   = 0;
        cnt_1 = 0;
        flag  = 0;
        ex_bp_packet_in[0].PC = 0;
        ex_bp_packet_in[1].PC = 0;
        ex_bp_packet_in[0].con_br_taken = 0;
        ex_bp_packet_in[1].con_br_taken = 0;
        ex_bp_packet_in[0].tg_pc = 0;
        ex_bp_packet_in[1].tg_pc = 0;
        if_inst_valid = 2'b00;
        squash_en = 0;
        @(negedge clock);
        reset = 0;
        if_pc_in[0] = 0; 
        if_pc_in[1] = 4; 
        for (int i=0;i<20;i++) begin
            @(negedge clock);
            if_inst_valid = 2'b11;
            if_pc_in[0] = 8*i+8; 
            if_pc_in[1] = 8*i+12; 
            inst[0] = `NOP;
            inst[1] = 32'h6F;
            if (i>=5) begin
                ex_bp_packet_in[0].PC = 8*(i-5)+8;
                ex_bp_packet_in[1].PC = 8*(i-5)+12;
                inst[0] = `NOP;
                inst[1] = 32'h67;
                ex_bp_packet_in[0].br_en =1;
                ex_bp_packet_in[1].br_en =1;
                ex_bp_packet_in[0].con_br_taken = 1;
                ex_bp_packet_in[1].con_br_taken = 1;
                ex_bp_packet_in[0].tg_pc = 8*(i-5)+20;
                ex_bp_packet_in[1].tg_pc = 8*(i-5)+24;
                if (i >=10) begin
                    ex_bp_packet_in[0].br_en =1;
                    ex_bp_packet_in[1].br_en =1;
                    ex_bp_packet_in[0].con_br_taken = 0; 
                    ex_bp_packet_in[1].con_br_taken = 0; 
                end
            end
        end
        repeat (10)@(negedge clock);
        for (int j=0;j<20;j++) begin
            @(negedge clock);
            if_pc_in[0] = 8*j; 
            if_pc_in[1] = 8*j+4; 
            inst[0] = 32'h6F;
            inst[1] = 32'h67;
            if (j>=5) begin
                ex_bp_packet_in[0].PC = 8*(j-5);
                ex_bp_packet_in[1].PC = 8*(j-5)+4;
                inst[0] = 32'h67;
                inst[1] = 32'h6F;
                ex_bp_packet_in[0].br_en =1;
                ex_bp_packet_in[1].br_en =0;
                ex_bp_packet_in[0].con_br_taken = 1;
                ex_bp_packet_in[1].con_br_taken = 0;
                ex_bp_packet_in[0].tg_pc = 8*(j-5)+20;
                ex_bp_packet_in[1].tg_pc = 8*(j-5)+24;
                if (j >=10) begin
                    ex_bp_packet_in[0].br_en =0;
                    ex_bp_packet_in[0].con_br_taken = 0; 
                end
            end
        end
       
        $finish;

    end

endmodule 