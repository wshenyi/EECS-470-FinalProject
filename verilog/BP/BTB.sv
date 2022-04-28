module BTB #(
    parameter BTB_INDEX = $clog2(`BTB_SIZE)
) (
    input  clock, reset,
    input  [1:0] wr_en,    // write target value in buffer
    input  [1:0] [`XLEN-1:0] ex_pc_in,  // pc from ex stage 
    input  [1:0] [`XLEN-1:0] ex_tg_pc_in,    // target pc from ex stage in 
    input  [1:0][`XLEN-1:0] if_pc_in,    // pc from if stage    
    output logic [1:0] hit,    // 1 if pc hit buffer 
    output logic [1:0][`XLEN-1:0] predict_pc_out
);
    logic [`TAG_SIZE+`VAL_SIZE-1:0] mem [`BTB_SIZE-1:0];
    logic [`BTB_SIZE-1:0] valid;    // 1 if address store valid target PC
   

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            for (int i=0;i<`BTB_SIZE;i++) begin
            mem [i] <= `SD 0;
            end
            valid <= `SD 0;
        end
        else begin
            // if two pc return from ex stage is same, BTB will record the ex_tg_pc_in[0]
            // doesn't matter because it is just a guss
            if (wr_en[0] && wr_en[1] && 
            (ex_pc_in[0][2 +: BTB_INDEX]==ex_pc_in[1][2 +: BTB_INDEX])) begin
            mem [ex_pc_in[0][2 +: BTB_INDEX]] <= `SD 
            {ex_pc_in[0][BTB_INDEX+2 +: `TAG_SIZE],
            ex_tg_pc_in[0][2 +: `VAL_SIZE]};
            valid[ex_pc_in[0][2 +: BTB_INDEX]] <= `SD 1'b1;
            end 
            else begin
                if (wr_en[0]) begin
                    mem [ex_pc_in[0][2 +: BTB_INDEX]] <= `SD 
                    {ex_pc_in[0][BTB_INDEX+2 +: `TAG_SIZE],
                    ex_tg_pc_in[0][2 +: `VAL_SIZE]};
                    valid[ex_pc_in[0][2 +: BTB_INDEX]] <= `SD 1'b1;
                end 
                if (wr_en[1]) begin
                    mem [ex_pc_in[1][2 +: BTB_INDEX]] <= `SD 
                    {ex_pc_in[1][BTB_INDEX+2 +: `TAG_SIZE],
                    ex_tg_pc_in[1][2 +: `VAL_SIZE]};
                    valid[ex_pc_in[1][2 +: BTB_INDEX]] <= `SD 1'b1;
                end
            end
        end
    end

    genvar j,k;
    for (j=0;j<2;j++) begin
    assign   predict_pc_out[j] = 
            {if_pc_in[j][`XLEN-1:`VAL_SIZE+2],
            mem[if_pc_in[j][BTB_INDEX+1-:BTB_INDEX]][`VAL_SIZE-1:0],
            {2{1'b0}}};    
    end



    for (k=0;k<2;k++) begin
    assign  hit[k] = 
            (if_pc_in[k][BTB_INDEX+2 +: `TAG_SIZE] == 
            mem[if_pc_in[k][BTB_INDEX+1-:BTB_INDEX]][`VAL_SIZE +: `TAG_SIZE])&
            valid[if_pc_in[k][BTB_INDEX+1-:BTB_INDEX]];
    end

endmodule
