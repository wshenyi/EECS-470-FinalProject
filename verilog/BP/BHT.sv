module BHT #(
    parameter BHT_INDEX = $clog2(`BHT_SIZE)
)(
    input  clock, reset, 
    // sinput squash_en,
    input  [1:0] wr_en,
    input  [1:0] [`XLEN-1:0] ex_pc_in,  // pc from ex stage 
    input  [1:0] take_branch,    // taken or no taken from ex stage  
    input  [1:0][`XLEN-1:0] if_pc_in,    // pc from if stage    
    output [1:0][`BHT_WIDTH-1:0] bht_if_out,    // output the value stored in BHT to PHT
    output [1:0][`BHT_WIDTH-1:0] bht_ex_out    // output the value stored in BHT to PHT
);
    logic [`BHT_WIDTH-1:0] bht [`BHT_SIZE-1:0];

    logic [BHT_INDEX-1:0] wptr [1:0];    // write pointer for refreshing the state  
    logic [BHT_INDEX-1:0] rptr [1:0];    // read pointer for finding the state 
    // calculate the address
    always_comb begin
        for (int i=0;i<2;i++) begin
            wptr[i] = ex_pc_in[i][2 +: BHT_INDEX];
            rptr[i] = if_pc_in[i][2 +: BHT_INDEX];
        end
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            for (int i=0;i<`BHT_SIZE;i++) begin
                bht[i] <= `SD 0;
            end
        end 
        // else if (squash_en) begin
        //     for (int i=0;i<`BHT_SIZE;i++) begin
        //         bht[i] <= `SD 0;
        //     end
        // end
        else begin
            if (wr_en[0] && wr_en[1] &&
                ( wptr[0] == wptr[1])) begin
                    bht[wptr[0]] <= `SD {bht[wptr[0]][`BHT_WIDTH-2:0],take_branch[0]};
            end
            else begin
                if (wr_en[0]) begin
                    bht[wptr[0]] <= `SD {bht[wptr[0]][`BHT_WIDTH-2:0],take_branch[0]};
                end
                if (wr_en[1])begin
                    bht [ wptr[1]] <= `SD {bht[wptr[1]][`BHT_WIDTH-2:0],take_branch[1]};
                end
            end
        end
    end 

    genvar j;
    for (j=0;j<2;j++) begin
        assign bht_if_out[j] = bht[rptr[j]];
        assign bht_ex_out[j] = bht[wptr[j]];
    end

endmodule
