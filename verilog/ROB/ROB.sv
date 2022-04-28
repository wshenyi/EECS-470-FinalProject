`timescale 1ns/100ps

// `define DEBUG
module ROB (
    // Inputs
    input   clock, reset, enable,
    input   logic               squash_signal,
    input   logic         [1:0] retire_disable,
    input   CDB_PACKET    [1:0] CDB_packet_in,      // Come from Complete stage
    input   DP_PACKET     [1:0] DP_packet_in,       // Come from Dispatch stage to tell the stride of tail pointer
    input   MT_ROB_PACKET [1:0] MT_ROB_packet_in,   // At Dispatch stage, tell Tags (#ROB) for s1 and s2

    // Outputs
    output  logic         [1:0] dp_available,       // Output ROB space to tell how many space left in ROB
    output  CP_RT_PACKET  [1:0] CP_RT_packet_out,   // At Retire stage, output retire register and value to regfiles and map table
    output  ROB_RS_PACKET [1:0] ROB_RS_packet_out,  // At Dispatch stage, output dispatched tag and value of source reg
    output  ROB_MT_PACKET [1:0] ROB_MT_packet_out   // At Dispatch stage, output dispatched tag

    // Debug
    `ifdef DEBUG
    ,
    output  logic [$clog2(`ROB_SIZE)-1:0] head_out,
    output  logic [$clog2(`ROB_SIZE)-1:0] tail_out,
    output  logic [$clog2(`ROB_SIZE):0] space_out,
    output  ROB_ENTRY [`ROB_SIZE-1:0] content_out
    `endif
);
    logic   [$clog2(`ROB_SIZE)-1:0] space_available;
    ROB_ENTRY   ROB_content   [`ROB_SIZE-1:0];        // Store Reg-Value-CP bit
    ROB_ENTRY   ROB_content_n [`ROB_SIZE-1:0];        // Store Reg-Value-CP bit

    logic	[$clog2(`ROB_SIZE):0] head, head_n, head_plus1; // head
    logic	[$clog2(`ROB_SIZE):0] tail, tail_n, tail_plus1; // tail

    assign tail_plus1 = tail + 1;
    assign head_plus1 = head + 1;
    `ifdef DEBUG
    assign head_out  = head[$clog2(`ROB_SIZE)-1:0];
    assign tail_out  = tail[$clog2(`ROB_SIZE)-1:0];
    assign space_out = space_available == 0 ? tail[$clog2(`ROB_SIZE)] != head[$clog2(`ROB_SIZE)] ? 0 : 32 : space_available;
    always_comb begin
        for (integer unsigned i = 0; i < `ROB_SIZE; i++) begin
            content_out[i] = ROB_content[i];
        end
    end
    `endif

    always_comb begin
        // Judge retire stage
        for (integer unsigned j = 0; j < `ROB_SIZE; j++) begin
            ROB_content_n [j].value     = ROB_content [j].value;
            ROB_content_n [j].cp_bit    = ROB_content [j].cp_bit;
            ROB_content_n [j].ep_bit    = ROB_content [j].ep_bit;
            ROB_content_n [j].illegal   = ROB_content [j].illegal;
            ROB_content_n [j].halt      = ROB_content [j].halt;
            ROB_content_n [j].NPC       = ROB_content [j].NPC;
            ROB_content_n [j].valid     = ROB_content [j].valid;
            ROB_content_n [j].wr_mem    = ROB_content [j].wr_mem;
        end
        case ({ROB_content[head_plus1[$clog2(`ROB_SIZE)-1:0]].cp_bit, ROB_content[head[$clog2(`ROB_SIZE)-1:0]].cp_bit})
            default: begin
                head_n = head;
            end
            2'b01: begin
                if (retire_disable[0]) begin
                    head_n = head;
                end 
                else begin
                    ROB_content_n[head[$clog2(`ROB_SIZE)-1:0]].cp_bit = 0;
                    head_n = head_plus1;
                end
            end
            2'b11: begin
                if (retire_disable[0]) begin
                    head_n = head;
                end 
                else if (ROB_content[head[$clog2(`ROB_SIZE)-1:0]].ep_bit == 1 || retire_disable == 2'b10) begin
                    ROB_content_n[head[$clog2(`ROB_SIZE)-1:0]].cp_bit = 0;
                    head_n = head_plus1;
                end 
                else begin
                    ROB_content_n[      head[$clog2(`ROB_SIZE)-1:0]].cp_bit = 0;
                    ROB_content_n[head_plus1[$clog2(`ROB_SIZE)-1:0]].cp_bit = 0;
                    head_n = head + 2;
                end
            end
        endcase

        // Judge complete stage
        for(integer unsigned i = 0; i < `CDB_SIZE; i++) begin
            if(CDB_packet_in[i].valid == 1'b1) begin
                ROB_content_n[CDB_packet_in[i].Tag].value     = CDB_packet_in[i].Value;
                ROB_content_n[CDB_packet_in[i].Tag].cp_bit    = 1'b1;
                ROB_content_n[CDB_packet_in[i].Tag].ep_bit    = CDB_packet_in[i].take_branch;
                ROB_content_n[CDB_packet_in[i].Tag].illegal   = CDB_packet_in[i].illegal;
                ROB_content_n[CDB_packet_in[i].Tag].halt      = CDB_packet_in[i].halt;
                ROB_content_n[CDB_packet_in[i].Tag].NPC       = CDB_packet_in[i].NPC;
                ROB_content_n[CDB_packet_in[i].Tag].valid     = CDB_packet_in[i].valid;
            end
        end
    end
    
    // Judge retire stage: output packet to retire stage
    assign CP_RT_packet_out[0].rob_entry = ROB_content[head[$clog2(`ROB_SIZE)-1:0]];
    assign CP_RT_packet_out[0].Tag       = head[$clog2(`ROB_SIZE)-1:0];
    assign CP_RT_packet_out[1].rob_entry = ROB_content[head_plus1[$clog2(`ROB_SIZE)-1:0]];
    assign CP_RT_packet_out[1].Tag       = head_plus1[$clog2(`ROB_SIZE)-1:0];

    // Judge dispatch stage: allocate new Tag (#ROB)
    always_comb begin   
        case ({DP_packet_in[1].dp_en, DP_packet_in[0].dp_en})
            default: begin
                // Process packet to RS
                ROB_RS_packet_out[0].Tag = 0;
                ROB_RS_packet_out[1].Tag = 0;
                // Process packet to map table
                ROB_MT_packet_out[0].Tag = 0;
                ROB_MT_packet_out[1].Tag = 0;
                tail_n = tail;
            end
            2'b01: begin
                // Process packet to RS
                ROB_RS_packet_out[0].Tag = tail[$clog2(`ROB_SIZE)-1:0];
                ROB_RS_packet_out[1].Tag = 0;
                // Process packet to map table
                ROB_MT_packet_out[0].Tag = tail[$clog2(`ROB_SIZE)-1:0];
                ROB_MT_packet_out[1].Tag = 0;
                tail_n = tail_plus1;
            end
            2'b11: begin
                // Process packet to RS
                ROB_RS_packet_out[0].Tag =       tail[$clog2(`ROB_SIZE)-1:0];
                ROB_RS_packet_out[1].Tag = tail_plus1[$clog2(`ROB_SIZE)-1:0];
                // Process packet to map table
                ROB_MT_packet_out[0].Tag =       tail[$clog2(`ROB_SIZE)-1:0];
                ROB_MT_packet_out[1].Tag = tail_plus1[$clog2(`ROB_SIZE)-1:0];
                tail_n = tail + 2;
            end
        endcase
    end

    always_comb begin
        case ({DP_packet_in[1].dp_en, DP_packet_in[0].dp_en})
            default: begin
                // Nothing happen
                for (integer unsigned k = 0; k < `ROB_SIZE; k++) begin
                    ROB_content_n[k].reg_idx = ROB_content[k].reg_idx;
                    ROB_content_n[k].PC      = ROB_content[k].PC;
                end
            end
            2'b01: begin
                // Allocate new entry
                for (integer unsigned k = 0; k < `ROB_SIZE; k++) begin
                    if (k == tail[$clog2(`ROB_SIZE)-1:0]) begin
                        ROB_content_n[k].reg_idx = DP_packet_in[0].dest_reg_idx;
                        ROB_content_n[k].PC      = DP_packet_in[0].PC;
                    end 
                    else begin
                        ROB_content_n[k].reg_idx = ROB_content[k].reg_idx;
                        ROB_content_n[k].PC      = ROB_content[k].PC;
                    end
                end
            end
            2'b11: begin
                // Allocate new entry
                for (integer unsigned k = 0; k < `ROB_SIZE; k++) begin
                    if (k == tail[$clog2(`ROB_SIZE)-1:0]) begin
                        ROB_content_n[k].reg_idx = DP_packet_in[0].dest_reg_idx;
                        ROB_content_n[k].PC      = DP_packet_in[0].PC;
                    end 
                    else if (k == tail_plus1[$clog2(`ROB_SIZE)-1:0]) begin
                        ROB_content_n[k].reg_idx = DP_packet_in[1].dest_reg_idx;
                        ROB_content_n[k].PC      = DP_packet_in[1].PC;
                    end
                    else begin
                        ROB_content_n[k].reg_idx = ROB_content[k].reg_idx;
                        ROB_content_n[k].PC      = ROB_content[k].PC;
                    end
                end
            end
        endcase
    end

    // Judge dispatch stage: obtain value for source1 and source2
    assign ROB_RS_packet_out[0].rs1_value = MT_ROB_packet_in[0].valid_vector[0] ? ROB_content[MT_ROB_packet_in[0].RegS1_Tag].value : 0;
    assign ROB_RS_packet_out[0].rs2_value = MT_ROB_packet_in[0].valid_vector[1] ? ROB_content[MT_ROB_packet_in[0].RegS2_Tag].value : 0;
    assign ROB_RS_packet_out[1].rs1_value = MT_ROB_packet_in[1].valid_vector[0] ? ROB_content[MT_ROB_packet_in[1].RegS1_Tag].value : 0;
    assign ROB_RS_packet_out[1].rs2_value = MT_ROB_packet_in[1].valid_vector[1] ? ROB_content[MT_ROB_packet_in[1].RegS2_Tag].value : 0;

    // Judge structure hazard
    always_comb begin
        space_available = head[$clog2(`ROB_SIZE)-1:0] - tail[$clog2(`ROB_SIZE)-1:0];
        if (space_available == 0) begin
            if (tail[$clog2(`ROB_SIZE)] != head[$clog2(`ROB_SIZE)]) begin
                dp_available = 0;
            end
            else begin
                dp_available = 2;
            end
        end
        else begin
            if (space_available >= 2) begin
                dp_available = 2;
            end
            else begin
                dp_available = space_available[1:0];
            end
        end 
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            ROB_content    <= `SD '{`ROB_SIZE{0}};
            head           <= `SD 0;
            tail           <= `SD 0;
        end else if (squash_signal) begin
            ROB_content    <= `SD '{`ROB_SIZE{0}};
            head           <= `SD 0;
            tail           <= `SD 0;
        end else if (enable) begin
            ROB_content    <= `SD ROB_content_n;
            head           <= `SD head_n;
            tail           <= `SD tail_n;
        end
    end

endmodule
