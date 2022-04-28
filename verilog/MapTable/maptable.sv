`timescale 1ns/100ps

module maptable (
    // Inputs
    input   clock, 
    input   DP_PACKET         [1:0] DP_packet_in,        // from dispatch stage, needs valid signal
    input   RT_PACKET         [1:0] RT_packet_in,        // from retire stage
    input   ROB_MT_PACKET     [1:0] ROB_DP_packet_in,    // from ROB, at dispatch stage
    input   CDB_PACKET        [1:0] CDB_packet_in,       // from CDB, use CAM to match ROB#, add plus sign at complete stage 
    input                           reset, 
    // Outputs
    output  MT_ROB_PACKET     [1:0] MT_ROB_woTag_out,    // ROB # of rs, send to ROB 2*2
    output  MT_RS_PACKET      [1:0] MT_RS_wTag_out       // ROB # and tag of rs, send to RS 2*2
); 
  // need to solve RAW hazard

    logic [$clog2(`ROB_SIZE)+1:0] dp_inst1_rs1, dp_inst1_rs2, dp_inst2_rs1, dp_inst2_rs2; 

    always_comb begin 
        
        // info of older dispatch inst
               MT_ROB_woTag_out[0].RegS1_Tag        = dp_inst1_rs1[$clog2(`ROB_SIZE)+1:2]; // send ROB# to ROB
               MT_ROB_woTag_out[0].RegS2_Tag        = dp_inst1_rs2[$clog2(`ROB_SIZE)+1:2];
               MT_ROB_woTag_out[0].valid_vector     = {dp_inst1_rs2[0],dp_inst1_rs1[0]};
               MT_RS_wTag_out[0].Tag1_ready_in_rob  = dp_inst1_rs1[1];  // send to RS      
               MT_RS_wTag_out[0].Tag2_ready_in_rob  = dp_inst1_rs2[1]; 
               MT_RS_wTag_out[0].Tag1_valid         = dp_inst1_rs1[0];        
               MT_RS_wTag_out[0].Tag2_valid         = dp_inst1_rs2[0]; 
               MT_RS_wTag_out[0].Tag1               = dp_inst1_rs1[$clog2(`ROB_SIZE)+1:2];        
               MT_RS_wTag_out[0].Tag2               = dp_inst1_rs2[$clog2(`ROB_SIZE)+1:2];   // send ROB# and tag to RS 

        // info of younger dispatch inst
            if (DP_packet_in[1].rs1_exist == 1             // if younger inst has rs1
                && DP_packet_in[0].dest_reg_idx != 0                  // if older inst has rdest
                && DP_packet_in[0].dest_reg_idx == DP_packet_in[1].inst.r.rs1) begin  // if rdest == rs1
                //forward rdest of older inst and set tag to not ready
               MT_ROB_woTag_out[1].RegS1_Tag        = ROB_DP_packet_in[0].Tag; // send ROB# to ROB
               MT_ROB_woTag_out[1].valid_vector[0]  = 1'b1;
               MT_RS_wTag_out[1].Tag1_ready_in_rob  = 1'b0;  // send to RS      
               MT_RS_wTag_out[1].Tag1_valid         = 1'b1;        
               MT_RS_wTag_out[1].Tag1               = ROB_DP_packet_in[0].Tag;        
            end else begin
               MT_ROB_woTag_out[1].RegS1_Tag        = dp_inst2_rs1[$clog2(`ROB_SIZE)+1:2]; // send ROB# to ROB
               MT_ROB_woTag_out[1].valid_vector[0]  = dp_inst2_rs1[0];
               MT_RS_wTag_out[1].Tag1_ready_in_rob  = dp_inst2_rs1[1];  // send to RS      
               MT_RS_wTag_out[1].Tag1_valid         = dp_inst2_rs1[0];        
               MT_RS_wTag_out[1].Tag1               = dp_inst2_rs1[$clog2(`ROB_SIZE)+1:2];        
            end

            if (DP_packet_in[1].rs2_exist == 1             // if younger inst has rs2
                && DP_packet_in[0].dest_reg_idx != 0                  // if older inst has rdest & rdest is not 0
                && DP_packet_in[0].dest_reg_idx == DP_packet_in[1].inst.r.rs2) begin  // if rdest == rs2
                //forward rdest of older inst and set tag to not ready
               MT_ROB_woTag_out[1].RegS2_Tag        = ROB_DP_packet_in[0].Tag; // send ROB# to ROB
               MT_ROB_woTag_out[1].valid_vector[1]  = 1'b1;  // send to ROB
               MT_RS_wTag_out[1].Tag2_ready_in_rob  = 1'b0;  // send to RS      
               MT_RS_wTag_out[1].Tag2_valid         = 1'b1;  // send to RS       
               MT_RS_wTag_out[1].Tag2               = ROB_DP_packet_in[0].Tag;  // send ROB# to RS      
            end else begin
               MT_ROB_woTag_out[1].RegS2_Tag        = dp_inst2_rs2[$clog2(`ROB_SIZE)+1:2]; // send ROB# to ROB
               MT_ROB_woTag_out[1].valid_vector[1]  = dp_inst2_rs2[0];
               MT_RS_wTag_out[1].Tag2_ready_in_rob  = dp_inst2_rs2[1];  // send to RS      
               MT_RS_wTag_out[1].Tag2_valid         = dp_inst2_rs2[0];        
               MT_RS_wTag_out[1].Tag2               = dp_inst2_rs2[$clog2(`ROB_SIZE)+1:2];        
            end
    end //always_comb

    MapTable_RF rf(
        .rda_idx     (DP_packet_in[0].inst.r.rs1),    // dispatch inst1 rs1
        .rdb_idx     (DP_packet_in[0].inst.r.rs2),    // dispatch inst1 rs2
        .rdc_idx     (DP_packet_in[1].inst.r.rs1),    // dispatch inst2 rs1
        .rdd_idx     (DP_packet_in[1].inst.r.rs2),    // dispatch inst2 rs2
        .wra_dp_idx  (DP_packet_in[0].dest_reg_idx),  // dispatch inst1 rdest, can be found in either DP_packet or ROB_MT_DP_PACKET
        .wrb_dp_idx  (DP_packet_in[1].dest_reg_idx),  // dispatch inst2 rdest, can be found in either DP_packet or ROB_MT_DP_PACKET
        .DP_ROB1     (ROB_DP_packet_in[0].Tag),       // dispatch inst1 ROB#
        .DP_ROB2     (ROB_DP_packet_in[1].Tag),       // dispatch inst2 ROB#
        .CDB_ROB1    (CDB_packet_in[0].Tag),          // complete inst1 ROB#
        .CDB_ROB2    (CDB_packet_in[1].Tag),          // complete inst2 ROB#
        .RT_ROB1     (RT_packet_in[0].retire_tag),    // retire inst1 ROB#
        .RT_ROB2     (RT_packet_in[1].retire_tag),    // retire inst2 ROB#
        .wra_dp_en   (DP_packet_in[0].dp_en),         // dispatch inst1 valid //what's diff between dp_en & valid
        .wrb_dp_en   (DP_packet_in[1].dp_en),         // dispatch inst2 valid
        .reset       (reset),
        .CDB_valid1  (CDB_packet_in[0].valid),        // complete inst1 valid
        .CDB_valid2  (CDB_packet_in[1].valid),        // complete inst1 valid
        .RT_valid1   (RT_packet_in[0].valid),         // retire inst1 valid 
        .RT_valid2   (RT_packet_in[1].valid),         // retire inst1 valid
        .wr_clk      (clock),
        .rda_out     (dp_inst1_rs1),  // dispatch inst1 rs1 ROB #
        .rdb_out     (dp_inst1_rs2),  // dispatch inst1 rs2 ROB #  
        .rdc_out     (dp_inst2_rs1),  // dispatch inst2 rs1 ROB #
        .rdd_out     (dp_inst2_rs2)   // dispatch inst2 rs2 ROB #
    );

endmodule