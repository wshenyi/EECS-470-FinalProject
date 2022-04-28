module PHT #(
    parameter PHT_INDEX = $clog2(`PHT_SIZE)
) (
    input  clock, reset,
    input  [1:0] wr_en,
    input  [1:0] [`XLEN-1:0] ex_pc_in,  // pc from ex stage 
    input  [1:0] take_branch,    // taken or no taken from ex stage  
    input  [1:0] [`XLEN-1:0] if_pc_in,    // pc from if stage 
    input  [1:0] [`BHT_WIDTH-1:0] bht_if_in,  
    input  [1:0] [`BHT_WIDTH-1:0] bht_ex_in,  
    output logic [1:0] predict_taken    // predict pc taken or no taken
);
    PHT_STATE  state [`PHT_SIZE-1:0] [`H_SIZE-1:0];
    PHT_STATE  n_state [`PHT_SIZE-1:0] [`H_SIZE-1:0];

    logic [PHT_INDEX-1:0] wptr [1:0];    // write pointer for refreshing the state  
    logic [PHT_INDEX-1:0] rptr [1:0];    // read pointer for finding the state 
    
    always_comb begin
        for (int i=0;i<2;i++) begin
            wptr[i] = ex_pc_in[i][2 +: PHT_INDEX];
            rptr[i] = if_pc_in[i][2 +: PHT_INDEX];
        end
    end
    
    always_comb begin
        for (int j=0;j<`PHT_SIZE;j++) begin
            for (int m=0;m<`H_SIZE;m++) begin
                n_state[j][m] = state[j][m];
            end
        end
        case (state[wptr[1]][bht_ex_in[1]])
        NT_STRONG: n_state[wptr[1]][bht_ex_in[1]] = take_branch[1] ? NT_WEAK : NT_STRONG;
        NT_WEAK:   n_state[wptr[1]][bht_ex_in[1]] = take_branch[1] ? T_STRONG  : NT_STRONG;
        T_WEAK:    n_state[wptr[1]][bht_ex_in[1]] = take_branch[1] ? T_STRONG : NT_STRONG;
        T_STRONG:  n_state[wptr[1]][bht_ex_in[1]] = take_branch[1] ? T_STRONG : T_WEAK;
        endcase
        //if wptr[0] == wptr[1], we will record pc[0](taken/notake)
        case (state[wptr[0]][bht_ex_in[0]])
        NT_STRONG: n_state[wptr[0]][bht_ex_in[0]] = take_branch[0] ? NT_WEAK : NT_STRONG;
        NT_WEAK:   n_state[wptr[0]][bht_ex_in[0]] = take_branch[0] ? T_STRONG  : NT_STRONG;
        T_WEAK:    n_state[wptr[0]][bht_ex_in[0]] = take_branch[0] ? T_STRONG : NT_STRONG;
        T_STRONG:  n_state[wptr[0]][bht_ex_in[0]] = take_branch[0] ? T_STRONG : T_WEAK;
        endcase
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            for (int k=0;k<`PHT_SIZE;k++) begin
                for (int n=0;n<`H_SIZE;n++) begin
                    state[k][n] <= `SD  NT_WEAK;
                end
            end
        end
        else if (wr_en[0] | wr_en[1]) begin
            if (wr_en[0] && wr_en[1] &&
                ( wptr[0] == wptr[1])) begin
                    state [ wptr[0]][bht_ex_in[0]] <= `SD n_state[wptr[0]][bht_ex_in[0]];
            end
            else begin
                if (wr_en[0]) begin
                    state [ wptr[0]][bht_ex_in[0]] <= `SD n_state[wptr[0]][bht_ex_in[0]];
                end
                if (wr_en[1])begin
                    state [ wptr[1]][bht_ex_in[1]] <= `SD n_state[wptr[1]][bht_ex_in[1]];
                end
            end
        end
    end

    
    always_comb begin
        for (int n=0;n<2;n++) begin
            predict_taken[n] = 
            ((state[rptr[n]][bht_if_in[n]]== T_WEAK) | (state[rptr[n]][bht_if_in[n]]== T_STRONG)) ? 1 : 0;
        end 
    end

endmodule
