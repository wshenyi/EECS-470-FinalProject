module testbench;

    // Ports declaration
    logic   wra_dp_en, wrb_dp_en, wr_clk;
    logic   [4:0] rda_idx, rdb_idx, rdc_idx, rdd_idx, wra_dp_idx, wrb_dp_idx;         
    logic   [$clog2(`ROB_SIZE)-1:0] DP_ROB1, DP_ROB2, CDB_ROB1, CDB_ROB2, RT_ROB1, RT_ROB2; 
    logic   [$clog2(`ROB_SIZE)+1:0] rda_out, rdb_out, rdc_out, rdd_out; 
    // Instance declaration
    MapTable_RF tb(
        //Inputs
        .rda_idx  (rda_idx),
        .rdb_idx  (rdb_idx),
        .rdc_idx  (rdc_idx),
        .rdd_idx  (rdd_idx),
        .wra_dp_idx  (wra_dp_idx),
        .wrb_dp_idx  (wrb_dp_idx),
        .DP_ROB1 (DP_ROB1),
        .DP_ROB2 (DP_ROB2),
        .CDB_ROB1 (CDB_ROB1), 
        .CDB_ROB2 (CDB_ROB2),
        .RT_ROB1  (RT_ROB1),
        .RT_ROB2  (RT_ROB2),
        .wra_dp_en  (wra_dp_en), 
        .wrb_dp_en  (wrb_dp_en),
        .wr_clk  (wr_clk),
        .rda_out  (rda_out),
        .rdb_out  (rdb_out),
        .rdc_out  (rdc_out),
        .rdd_out  (rdd_out)
    );


    // Setup the clock
    always begin
        #5;
        wr_clk = ~wr_clk;
    end

    // Begin testbench
    initial begin


        // Initialize
        wr_clk = 1'b0;
        @(negedge clock);
        reset = 1'b0;
        CDB_packet.valid_vector = 2'b00;
        dp_packet.valid_vector = 4'b0000;
        @(negedge clock);

        // ----------------------------Test Begin----------------------------

        for(integer j = 0; j < `CDB_SIZE; j++) begin
            CDB_packet.Tag[j]  = j+5;
            CDB_packet.value   = 32'b1;
        end
        CDB_packet.valid_vector = 2'b01;
        for(integer j = 0; j < `DP_SIZE; j++) begin
            dp_packet.dest_reg[j]  = 5'b00000;
        end
        dp_packet.valid_vector = 2'b11;
        
        for (integer i = 0; i < `XLEN/2; i++) begin
            @(negedge clock);
        end

        $display("@@@Passed");
        $finish;

    end

// initial begin
//         // Initialize
//         wr_clk = 1'b0;
//         # 100; 
//       $finish;
// end
endmodule