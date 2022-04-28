`define DEBUG

module mt_testbench; 

    // Ports declaration
    logic   clk, reset; 
    DP_PACKET         [1:0] DP_packet_in;        // from dispatch stage, needs valid signal
    RT_PACKET         [1:0] RT_packet_in;        // from retire stage
    ROB_MT_PACKET     [1:0] ROB_DP_packet_in;    // from ROB, at dispatch stage
    CDB_PACKET        [1:0] CDB_packet_in;       // from CDB, use CAM to match ROB#, add plus sign at complete stage 

    // Outputs
    MT_ROB_PACKET     [1:0] MT_ROB_woTag_out;    // ROB # of rs, send to ROB 2*2
    MT_RS_PACKET      [1:0] MT_RS_wTag_out;       // ROB # and tag of rs, send to RS 2*2


    // Instance declaration
    maptable tb(
        // Inputs
        .clock              (clk), 
        .DP_packet_in       (DP_packet_in),
        .RT_packet_in       (RT_packet_in),
        .ROB_DP_packet_in   (ROB_DP_packet_in),
        .CDB_packet_in      (CDB_packet_in),
        .reset              (reset), 
        // Outputs
        .MT_ROB_woTag_out   (MT_ROB_woTag_out),
        .MT_RS_wTag_out     (MT_RS_wTag_out)
    ); 

        // Setup the clock
    always begin
        #5;
        clk = ~clk;
    end

    initial begin
        // Initialize
        clk = 1'b0;
        DP_packet_in = 0; 
        RT_packet_in[0].retire_reg = 0; 
        RT_packet_in[0].value = 0; 
        RT_packet_in[0].retire_tag = 0; 
        RT_packet_in[0].valid = 0; 
        RT_packet_in[0].wr_en = 0;
        RT_packet_in[1].retire_reg = 0; 
        RT_packet_in[1].value = 0; 
        RT_packet_in[1].retire_tag = 0; 
        RT_packet_in[1].valid = 0; 
        RT_packet_in[1].wr_en = 0;
        ROB_DP_packet_in = 0;
        CDB_packet_in = 0;
        reset = 1; 
        @(negedge clk);
        @(negedge clk);
        reset = 0; 
        @(negedge clk);
        @(negedge clk);  
        DP_packet_in[0].dp_en = 1;
        DP_packet_in[0].dest_reg_idx = 2; 
        ROB_DP_packet_in[0].Tag = 2; 
        @(negedge clk);
        DP_packet_in[0].dp_en = 0; // one clk cycle can write in
        @(negedge clk);  

    // write ROB# and plus sign functions

    //     for (int i=0; i<16; i++) begin // dp write ROB#
    //         @(negedge clk);
    //         DP_packet_in[0].dp_en = 1;
    //         DP_packet_in[1].dp_en = 1;
    //         DP_packet_in[0].dest_reg_idx = i; 
    //         DP_packet_in[1].dest_reg_idx = i+16; 
    //         ROB_DP_packet_in[0].Tag = i; 
    //         ROB_DP_packet_in[1].Tag =5'b10000 + i; 
    //     end

    //     @(negedge clk);
    //     DP_packet_in[0].dp_en = 0;
    //     DP_packet_in[1].dp_en = 0;

    //     for (int i=0; i<16; i++) begin // CDB cp write plus sign
    //         @(negedge clk);
    //         CDB_packet_in[0].valid = 1;
    //         CDB_packet_in[0].Tag = i; 
    //     end

    //     @(negedge clk);
    //     CDB_packet_in[0].valid = 0;

    //     for (int i=0; i<16; i++) begin // CDB cp write plus sign
    //         @(negedge clk);
    //         CDB_packet_in[1].valid = 1;
    //         CDB_packet_in[1].Tag =5'b10000 + i; 
    //     end

    //     @(negedge clk);
    //     CDB_packet_in[1].valid = 0;

    //     for (int i=0; i<16; i++) begin // rt
    //         @(negedge clk);
    //         RT_packet_in[0].valid = 1;
    //         RT_packet_in[0].retire_tag = i; 
    //     end
        
    //     @(negedge clk);
    //     RT_packet_in[0].valid = 0;

    //     for (int i=0; i<16; i++) begin // rt
    //         @(negedge clk);
    //         RT_packet_in[1].valid = 1;
    //         RT_packet_in[1].retire_tag =5'b10000 + i; 
    //     end
        
    //     @(negedge clk);
    //     RT_packet_in[1].valid = 0;

    // // read functions
    //     repeat(10) begin 
    //         @(negedge clk);
    //         DP_packet_in[0].inst.r.rs1 = $random;
    //         DP_packet_in[0].inst.r.rs2 = $random;
    //         DP_packet_in[1].inst.r.rs1 = $random;
    //         DP_packet_in[1].inst.r.rs2 = $random;
    //     end

    //     @(negedge clk);
    //     DP_packet_in[0].inst.r.rs1 = 0;
    //     DP_packet_in[0].inst.r.rs2 = 0;
    //     DP_packet_in[1].inst.r.rs1 = 0;
    //     DP_packet_in[1].inst.r.rs2 = 0;

    //     assert(MT_RS_wTag_out[0].Tag1_ready_in_rob == 0);
    //     assert(MT_RS_wTag_out[0].Tag2_ready_in_rob == 0);
    //     assert(MT_RS_wTag_out[0].Tag1_valid == 0);
    //     assert(MT_RS_wTag_out[0].Tag1_valid == 0);
    //     assert(MT_RS_wTag_out[1].Tag1_ready_in_rob == 0);
    //     assert(MT_RS_wTag_out[1].Tag2_ready_in_rob == 0);
    //     assert(MT_RS_wTag_out[1].Tag1_valid == 0);
    //     assert(MT_RS_wTag_out[1].Tag1_valid == 0);        

    // // forward function
    //     repeat(10) begin
    //     @(negedge clk);
    //     CDB_packet_in[0].valid = 1;
    //     CDB_packet_in[0].Tag = $random; 
    //     DP_packet_in[0].inst.r.rs1 = CDB_packet_in[0].Tag; 
    //     assert(MT_RS_wTag_out[0].Tag1_ready_in_rob == 1); 
    //     assert(MT_RS_wTag_out[0].Tag1_valid == 1);    
    //     end

    //     @(negedge clk);
    //     CDB_packet_in[0].valid = 1;
    //     CDB_packet_in[0].Tag = 0; 
    //     DP_packet_in[0].inst.r.rs1 = CDB_packet_in[0].Tag; 
    //     assert(MT_RS_wTag_out[0].Tag1_ready_in_rob == 0); 
    //     assert(MT_RS_wTag_out[0].Tag1_valid == 0);    

    //     @(negedge clk);
    //     CDB_packet_in[0].valid = 0;

    //     repeat(10) begin
    //     @(negedge clk);
    //     RT_packet_in[0].valid = 1;
    //     RT_packet_in[0].retire_tag = $random; 
    //     DP_packet_in[0].inst.r.rs1 = RT_packet_in[0].retire_tag; 
    //     assert(MT_RS_wTag_out[0].Tag1_ready_in_rob == 0); 
    //     assert(MT_RS_wTag_out[0].Tag1_valid == 0);    
    //     end

    //     @(negedge clk);
    //     RT_packet_in[0].valid = 0;
        @(negedge clk);
        DP_packet_in[0].dp_en = 1;
        DP_packet_in[1].dp_en = 1;
        DP_packet_in[0].inst = 32'hDEAD_BEEF;
        ROB_DP_packet_in[0].Tag = 5'h0B;
        ROB_DP_packet_in[1].Tag = 5'h0C;
        @(negedge clk);
        DP_packet_in[0].dp_en = 0;
        DP_packet_in[1].dp_en = 0;



        DP_packet_in[0].inst.r.rs1 = 5'h1A;
        DP_packet_in[0].inst.r.rs2 = 5'h1A;
        DP_packet_in[0].dest_reg_idx = 5'h1A;
        
        DP_packet_in[1].inst.r.rs1 = 5'h1A;
        DP_packet_in[1].inst.r.rs2 = 5'h1A;
        DP_packet_in[1].dest_reg_idx = 5'h1A;
        
        repeat (2)@(negedge clk);

        @(negedge clk);
        CDB_packet_in[1].valid = 0;

        for (int i=0; i<16; i++) begin // rt
            @(negedge clk);
            RT_packet_in[0].valid = $random;
            RT_packet_in[0].retire_tag = i; 
        end
        
        @(negedge clk);
        RT_packet_in[0].valid = 0;

        for (int i=0; i<16; i++) begin // rt
            @(negedge clk);
            RT_packet_in[1].valid = 1;
            RT_packet_in[1].retire_tag =5'b10000 + i; 
        end
        
        @(negedge clk);
        RT_packet_in[1].valid = 0;

    // read functions
        repeat(10) begin 
            @(negedge clk);
            DP_packet_in[0].inst.r.rs1 = $random;
            DP_packet_in[0].inst.r.rs2 = $random;
            DP_packet_in[1].inst.r.rs1 = $random;
            DP_packet_in[1].inst.r.rs2 = $random;
        end

        @(negedge clk);
        DP_packet_in[0].inst.r.rs1 = 0;
        DP_packet_in[0].inst.r.rs2 = 0;
        DP_packet_in[1].inst.r.rs1 = 0;
        DP_packet_in[1].inst.r.rs2 = 0;

        assert(MT_RS_wTag_out[0].Tag1_ready_in_rob == 0);
        assert(MT_RS_wTag_out[0].Tag2_ready_in_rob == 0);
        assert(MT_RS_wTag_out[0].Tag1_valid == 0);
        assert(MT_RS_wTag_out[0].Tag2_valid == 0);
        assert(MT_RS_wTag_out[1].Tag1_ready_in_rob == 0);
        assert(MT_RS_wTag_out[1].Tag2_ready_in_rob == 0);
        assert(MT_RS_wTag_out[1].Tag1_valid == 0);
        assert(MT_RS_wTag_out[1].Tag1_valid == 0);        

    // forward function
        repeat(10) begin // forwar complete
        @(negedge clk);
        CDB_packet_in[0].valid = 1;
        CDB_packet_in[0].Tag = $random; 
        DP_packet_in[0].inst.r.rs1 = CDB_packet_in[0].Tag; 
        # 1; 
        assert(MT_RS_wTag_out[0].Tag1_ready_in_rob == 1); 
        assert(MT_RS_wTag_out[0].Tag1_valid == 1);    
        end

        @(negedge clk);
        CDB_packet_in[0].valid = 1;
        CDB_packet_in[0].Tag = 0; 
        DP_packet_in[0].inst.r.rs1 = 0; 
        # 1; 
        assert(MT_RS_wTag_out[0].Tag1_ready_in_rob == 0); 
        assert(MT_RS_wTag_out[0].Tag1_valid == 0);    

    // write all ROB tag to completed

        for (int i=0; i<16; i++) begin // CDB cp write plus sign
            @(negedge clk);
            CDB_packet_in[0].valid = 1;
            CDB_packet_in[0].Tag = i; 
            CDB_packet_in[1].valid = 1;
            CDB_packet_in[1].Tag =5'b10000 + i; 
        end

        @(negedge clk);
        CDB_packet_in[0].valid = 0;
        CDB_packet_in[1].valid = 0;

    // forward retire
        @(negedge clk);
        CDB_packet_in[1].valid = 0;
        repeat(10) begin
        @(negedge clk);
        RT_packet_in[0].valid = 1'b1;
        RT_packet_in[0].retire_tag = $random%32; 
        DP_packet_in[0].inst.r.rs1 = RT_packet_in[0].retire_tag; 
        # 1; 
        assert(MT_RS_wTag_out[0].Tag1_ready_in_rob == 0); 
        assert(MT_RS_wTag_out[0].Tag1_valid == 0);    
        end

        @(negedge clk);
        RT_packet_in[0].valid = 1;
        RT_packet_in[0].retire_tag = 0; 
        DP_packet_in[0].inst.r.rs1 = 0; 
        # 1; 
        assert(MT_RS_wTag_out[0].Tag1_ready_in_rob == 0); 
        assert(MT_RS_wTag_out[0].Tag1_valid == 0); 

        @(negedge clk);
        reset = 1; 
        @(negedge clk);
        @(negedge clk);

        // RAW dependency forwarding
        repeat(10) begin
        @(negedge clk);
        DP_packet_in[0].dp_en = 1;
        DP_packet_in[1].rs1_exist = 1;
        DP_packet_in[0].dest_reg_idx = $random; 
        ROB_DP_packet_in[0].Tag = $random; 
        DP_packet_in[1].dp_en = 0;
        DP_packet_in[1].inst.r.rs1 = DP_packet_in[0].dest_reg_idx; 
        # 1;
        assert(MT_RS_wTag_out[1].Tag1_ready_in_rob == 0);
        assert(MT_RS_wTag_out[1].Tag1_valid == 1);
        end

        @(negedge clk); 
        DP_packet_in[1].rs1_exist = 0; 

        repeat(10) begin
        @(negedge clk);
        DP_packet_in[0].dp_en = 1;
        DP_packet_in[1].rs2_exist = 1; 
        DP_packet_in[0].dest_reg_idx = $random; 
        ROB_DP_packet_in[0].Tag = $random; 
        DP_packet_in[1].dp_en = 0;
        DP_packet_in[1].inst.r.rs2 = DP_packet_in[0].dest_reg_idx; 
        # 1;
        assert(MT_RS_wTag_out[1].Tag2_ready_in_rob == 0);
        assert(MT_RS_wTag_out[1].Tag2_valid == 1);
        end


        $display ("@@@Passed@@@");
        
        # 100; 
      $finish;
    end

endmodule