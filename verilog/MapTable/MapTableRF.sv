`timescale 1ns/100ps

module MapTable_RF(
        input   [4:0] rda_idx, rdb_idx, rdc_idx, rdd_idx,    // read index
        input   [4:0] wra_dp_idx, wrb_dp_idx,  // write index
        input   [$clog2(`ROB_SIZE)-1:0] DP_ROB1, DP_ROB2, CDB_ROB1, CDB_ROB2, RT_ROB1, RT_ROB2,    // write dispatch ROB#, CDB ROB#
        input         wra_dp_en,  wrb_dp_en, reset,
        input         CDB_valid1, CDB_valid2, RT_valid1, RT_valid2, wr_clk, 

        output logic [$clog2(`ROB_SIZE)+1:0] rda_out, rdb_out, rdc_out, rdd_out    // output ROB# with tags retire & complete done, dispatch undon
          
      );
  
  logic [31:0] [$clog2(`ROB_SIZE)+1:0] mt_reg; //store ROB# [$clog2(`ROB_SIZE)+1:2] and tag [1:0]

  logic   [$clog2(`ROB_SIZE)+1:0] rda_reg; 
  logic   [$clog2(`ROB_SIZE)+1:0] rdb_reg;
  logic   [$clog2(`ROB_SIZE)+1:0] rdc_reg;
  logic   [$clog2(`ROB_SIZE)+1:0] rdd_reg;

  assign rda_reg = mt_reg[rda_idx];
  assign rdb_reg = mt_reg[rdb_idx];
  assign rdc_reg = mt_reg[rdc_idx];
  assign rdd_reg = mt_reg[rdd_idx];

  // one hot addr, CDB match
  logic   [31:0]                  cp_ROB_add1, cp_ROB_add2, rt_ROB_add1, rt_ROB_add2;  
  logic                           wra_cp_en, wrb_cp_en, wra_rt_en, wrb_rt_en;
  logic retire_en2, retire_en11, retire_en12, retire_en13; 
  logic   [4:0] cp_ROB_idx1; 
  logic   [4:0] cp_ROB_idx2; 
  logic   [4:0] rt_ROB_idx1;
  logic   [4:0] rt_ROB_idx2;
  logic         cp_ROB_match_valid1, cp_ROB_match_valid2, rt_ROB_match_valid1, rt_ROB_match_valid2; 
 
  //
  // Read ports
  //

  Read_port rda(
    .rd_idx(rda_idx), 
    .wra_cp_idx(cp_ROB_idx1), 
    .wrb_cp_idx(cp_ROB_idx2), 
    .wra_rt_idx(rt_ROB_idx1),
    .wrb_rt_idx(rt_ROB_idx2),
    .wra_cp_en(wra_cp_en),
    .wrb_cp_en(wrb_cp_en),
    .wra_rt_en(wra_rt_en),
    .wrb_rt_en(wrb_rt_en),
    .rd_reg(rda_reg), 
    .rd_out(rda_out)
  ); 

  Read_port rdb(
    .rd_idx(rdb_idx), 
    .wra_cp_idx(cp_ROB_idx1), 
    .wrb_cp_idx(cp_ROB_idx2), 
    .wra_rt_idx(rt_ROB_idx1),
    .wrb_rt_idx(rt_ROB_idx2),
    .wra_cp_en(wra_cp_en),
    .wrb_cp_en(wrb_cp_en),
    .wra_rt_en(wra_rt_en),
    .wrb_rt_en(wrb_rt_en),
    .rd_reg(rdb_reg), 
    .rd_out(rdb_out)
  ); 

  Read_port rdc(
    .rd_idx(rdc_idx), 
    .wra_cp_idx(cp_ROB_idx1), 
    .wrb_cp_idx(cp_ROB_idx2), 
    .wra_rt_idx(rt_ROB_idx1),
    .wrb_rt_idx(rt_ROB_idx2),
    .wra_cp_en(wra_cp_en),
    .wrb_cp_en(wrb_cp_en),
    .wra_rt_en(wra_rt_en),
    .wrb_rt_en(wrb_rt_en),
    .rd_reg(rdc_reg), 
    .rd_out(rdc_out)
  ); 

  Read_port rdd(
    .rd_idx(rdd_idx), 
    .wra_cp_idx(cp_ROB_idx1), 
    .wrb_cp_idx(cp_ROB_idx2), 
    .wra_rt_idx(rt_ROB_idx1),
    .wrb_rt_idx(rt_ROB_idx2),
    .wra_cp_en(wra_cp_en),
    .wrb_cp_en(wrb_cp_en),
    .wra_rt_en(wra_rt_en),
    .wrb_rt_en(wrb_rt_en),
    .rd_reg(rdd_reg), 
    .rd_out(rdd_out)
  ); 

  //
  // Write port 
  // priority wrb_dp_en > wra_dp_en, younger ROB#2 > older ROB#1
  //
  always_ff @(posedge wr_clk) begin
    if (reset) begin
      mt_reg <= `SD 0; 
    end

    if (wrb_dp_en && !reset) begin
      mt_reg[wrb_dp_idx] <= `SD {DP_ROB2, `Not_Ready}; 
    end 

    if (wra_dp_en && (!wrb_dp_en || (wra_dp_idx != wrb_dp_idx)) && !reset) begin 
      mt_reg[wra_dp_idx] <= `SD {DP_ROB1, `Not_Ready}; 
    end 

    if (wrb_cp_en && (!wrb_dp_en || (cp_ROB_idx2 != wrb_dp_idx) || (wrb_dp_idx == 5'b0)) // not same idx as dp inst
                  && (!wra_dp_en || (cp_ROB_idx2 != wra_dp_idx) || (wra_dp_idx == 5'b0)) 
                  // && (!wrb_rt_en || (cp_ROB_idx1 != rt_ROB_idx2))
                  // && (!wra_rt_en || (cp_ROB_idx1 != rt_ROB_idx1))
                  && !reset) begin 
      mt_reg[cp_ROB_idx2] [1:0] <= `SD `Ready_in_ROB; 
    end

    if (wra_cp_en && (!wrb_dp_en || (cp_ROB_idx1 != wrb_dp_idx) || (wrb_dp_idx == 5'b0))     //ROB# of dp1, dp2, rt1, rt2 must be diff
                  && (!wra_dp_en || (cp_ROB_idx1 != wra_dp_idx) || (wra_dp_idx == 5'b0)) 
                  // && (!wrb_rt_en || (cp_ROB_idx1 != rt_ROB_idx2))
                  // && (!wra_rt_en || (cp_ROB_idx1 != rt_ROB_idx1))
                  && !reset) begin
      mt_reg[cp_ROB_idx1] [1:0] <= `SD `Ready_in_ROB; 
    end

    if (wrb_rt_en && (!wrb_dp_en || (wrb_dp_idx != rt_ROB_idx2) || (wrb_dp_idx == 5'b0))
                  && (!wra_dp_en || (wra_dp_idx != rt_ROB_idx2) || (wra_dp_idx == 5'b0)) 
                  && !reset) begin
      mt_reg[rt_ROB_idx2] [1:0] <= `SD `Ready_in_RF;
    end

    if (wra_rt_en && (!wrb_dp_en || (wrb_dp_idx != rt_ROB_idx1) || (wrb_dp_idx == 5'b0))
                  && (!wra_dp_en || (wra_dp_idx != rt_ROB_idx1) || (wra_dp_idx == 5'b0)) 
                  && !reset) begin 
      mt_reg[rt_ROB_idx1] [1:0] <= `SD `Ready_in_RF;
    end

  end //always_ff

  genvar i;  // find ROB# match, output one hot addr
  generate
    for(i = 0; i < 32; i++) begin
      assign cp_ROB_add1[i] = mt_reg[i]=={CDB_ROB1,`Not_Ready} ? 1 : 0;
      assign cp_ROB_add2[i] = mt_reg[i]=={CDB_ROB2,`Not_Ready}  ? 1 : 0;
      assign rt_ROB_add1[i] = mt_reg[i]=={RT_ROB1,`Ready_in_ROB}  ? 1 : 0;
      assign rt_ROB_add2[i] = mt_reg[i]=={RT_ROB2,`Ready_in_ROB}  ? 1 : 0;
    end
  endgenerate
  
  encoder cp1( // encode 32 bit one hot addr into 5 bit idx
    .one_hot_add(cp_ROB_add1), 
    .matched_ROB(cp_ROB_match_valid1),
    .idx(cp_ROB_idx1)
  );

  encoder cp2(
    .one_hot_add(cp_ROB_add2), 
    .matched_ROB(cp_ROB_match_valid2),
    .idx(cp_ROB_idx2)
  );

  encoder rt1(
    .one_hot_add(rt_ROB_add1), 
    .matched_ROB(rt_ROB_match_valid1),
    .idx(rt_ROB_idx1)
  );

  encoder rt2(
    .one_hot_add(rt_ROB_add2), 
    .matched_ROB(rt_ROB_match_valid2),
    .idx(rt_ROB_idx2)
  );

  assign wra_cp_en = cp_ROB_match_valid1 && CDB_valid1; // if ROB# matched and CDB broadcast, set plus sign enable
  assign wrb_cp_en = cp_ROB_match_valid2 && CDB_valid2;  
  assign wra_rt_en = rt_ROB_match_valid1 && RT_valid1;  // if ROB# matched and rt inst valid, set tag enable
  assign wrb_rt_en = rt_ROB_match_valid2 && RT_valid2;  

endmodule // map table regfile

module Read_port ( //no data forwarding, forward complete & retire tags
  input   [4:0] rd_idx,   // read index
  input   [4:0] wra_cp_idx, wrb_cp_idx, wra_rt_idx, wrb_rt_idx,  // write index
  input         wra_cp_en, wrb_cp_en, wra_rt_en, wrb_rt_en, 
  input   [$clog2(`ROB_SIZE)+1:0] rd_reg,

  output logic [$clog2(`ROB_SIZE)+1:0] rd_out    // read data
);
  always_comb begin
    if (rd_idx == `ZERO_REG)
      rd_out = 0; 
    // else if ((wra_cp_en && rd_idx == wra_cp_idx) | (wrb_cp_en && rd_idx == wrb_cp_idx)) //if rdest complete in this cycle
    //   rd_out = {rd_reg[$clog2(`ROB_SIZE)+1:2],`Ready_in_ROB};
    else if ((wra_rt_en && (rd_idx == wra_rt_idx)) | (wrb_rt_en && (rd_idx == wrb_rt_idx))) //if rdest retire in this cycle
      rd_out = {rd_reg[$clog2(`ROB_SIZE)+1:2],`Ready_in_RF};
    else
      rd_out = rd_reg;
  end //always
  
endmodule

module encoder (
  input   [31:0]  one_hot_add,

  output  logic   matched_ROB, 
  output  logic  [4:0]  idx
); 
  always_comb begin
    case (one_hot_add) 
    32'h1:        begin idx = 5'h0;  matched_ROB = 1; end
    32'h2:        begin idx = 5'h1;  matched_ROB = 1; end 
    32'h4:        begin idx = 5'h2;  matched_ROB = 1; end 
    32'h8:        begin idx = 5'h3;  matched_ROB = 1; end 
    32'h10:       begin idx = 5'h4;  matched_ROB = 1; end 
    32'h20:       begin idx = 5'h5;  matched_ROB = 1; end 
    32'h40:       begin idx = 5'h6;  matched_ROB = 1; end 
    32'h80:       begin idx = 5'h7;  matched_ROB = 1; end   
    32'h100:      begin idx = 5'h8;  matched_ROB = 1; end
    32'h200:      begin idx = 5'h9;  matched_ROB = 1; end
    32'h400:      begin idx = 5'ha;  matched_ROB = 1; end
    32'h800:      begin idx = 5'hb;  matched_ROB = 1; end
    32'h1000:     begin idx = 5'hc;  matched_ROB = 1; end
    32'h2000:     begin idx = 5'hd;  matched_ROB = 1; end
    32'h4000:     begin idx = 5'he;  matched_ROB = 1; end
    32'h8000:     begin idx = 5'hf;  matched_ROB = 1; end
    32'h10000:    begin idx = 5'h10; matched_ROB = 1; end
    32'h20000:    begin idx = 5'h11; matched_ROB = 1; end
    32'h40000:    begin idx = 5'h12; matched_ROB = 1; end
    32'h80000:    begin idx = 5'h13; matched_ROB = 1; end
    32'h100000:   begin idx = 5'h14; matched_ROB = 1; end
    32'h200000:   begin idx = 5'h15; matched_ROB = 1; end
    32'h400000:   begin idx = 5'h16; matched_ROB = 1; end
    32'h800000:   begin idx = 5'h17; matched_ROB = 1; end  
    32'h1000000:  begin idx = 5'h18; matched_ROB = 1; end
    32'h2000000:  begin idx = 5'h19; matched_ROB = 1; end
    32'h4000000:  begin idx = 5'h1a; matched_ROB = 1; end
    32'h8000000:  begin idx = 5'h1b; matched_ROB = 1; end
    32'h10000000: begin idx = 5'h1c; matched_ROB = 1; end
    32'h20000000: begin idx = 5'h1d; matched_ROB = 1; end
    32'h40000000: begin idx = 5'h1e; matched_ROB = 1; end
    32'h80000000: begin idx = 5'h1f; matched_ROB = 1; end
    default:      begin idx = 5'h0;  matched_ROB = 0; end 
    endcase 
  end
  
endmodule
