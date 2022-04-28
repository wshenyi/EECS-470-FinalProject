//  `define DEBUG
module t0();
    logic clock, reset;
    logic [1:0] wr_en;
    logic [1:0][`BHT_WIDTH-1:0] bht_if_in;    // output the value stored in BHT to PHT
    logic [1:0][`BHT_WIDTH-1:0] bht_ex_in;    // output the value stored in BHT to PHT
    logic [1:0] [`XLEN-1:0] ex_pc_in;  // pc from ex stage 
    logic [1:0] take_branch;    // taken or no taken from ex stage  
    logic [1:0] [`XLEN-1:0] if_pc_in;    // pc from if stage    
    logic [1:0] predict_taken;    // predict pc taken or no taken

    `ifdef DEBUG
    PHT_STATE state_debug [`PHT_SIZE-1:0] [`H_SIZE-1:0];;
    `endif 

    PHT DUT (
        .clock(clock), 
        .reset(reset),
        .wr_en(wr_en),
        .ex_pc_in(ex_pc_in),  // pc from ex stage 
        .take_branch(take_branch),    // taken or no taken from ex stage  
        .if_pc_in(if_pc_in),    // pc from if stage 
        .bht_if_in(bht_if_in),   
        .bht_ex_in(bht_ex_in),
        `ifdef DEBUG
        .state_debug(state_debug),
    `endif 
        .predict_taken(predict_taken)    // predict pc taken or no taken
        );

    always begin
        #5;
        clock = ~clock;
    end

    initial begin
        clock = 0;
        reset = 1;
        wr_en = 0;
        bht_if_in[1]=0;
        bht_ex_in[1] = 0;
        ex_pc_in[1] = 0;
        take_branch[1] = 0;
        if_pc_in[1] = 0;
        for (int i=0;i<40;i++) begin
            @(negedge clock);
            reset = 0;
            wr_en = 1;
            bht_if_in[0] =  i;
            bht_ex_in[0] = i;
            ex_pc_in[0] = i+1;
            take_branch[0] = 1;
            if_pc_in[0] = i;
        end   
        $finish;
    end

endmodule