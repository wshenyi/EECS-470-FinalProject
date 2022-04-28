module t0();
    logic   clock, reset;
    logic  [1:0] wr_en;    // write target value in buffer
    logic  [1:0] [`XLEN-1:0] ex_pc_in;  // pc from ex stage 
    logic  [1:0] [`XLEN-1:0] ex_tg_pc_in;    // target pc from ex stage in 
    logic  [1:0][`XLEN-1:0] if_pc_in;    // pc from if stage    
    logic  [1:0] hit;    // 1 if pc hit buffer 
    logic  [1:0][`XLEN-1:0] predict_pc_out;

    BTB DUT(
    .clock(clock), 
    .reset(reset),
    .wr_en(wr_en),    // write target value in buffer
    .ex_pc_in(ex_pc_in),  // pc from ex stage 
    .ex_tg_pc_in(ex_tg_pc_in),    // target pc from ex stage in 
    .if_pc_in(if_pc_in),    // pc from if stage    
    .hit(hit),    // 1 if pc hit buffer 
    .predict_pc_out(predict_pc_out)
);

    always begin
        #5;
        clock = ~clock;
    end

    initial begin
        clock = 0;
        reset = 1;
        wr_en = 0;
        ex_pc_in = 0;
        ex_tg_pc_in = 0;
        if_pc_in = 0;
        for (int i=0;i<200;i++) begin
        @(negedge clock);
        reset = 0;
        wr_en[1:0] = 2'b11;
        ex_pc_in[0] = 4*i;
        ex_pc_in[1] = 4*i;
        ex_tg_pc_in[0] = 4*i+100;
        ex_tg_pc_in[1] = 4*i+200;
        if (i>=1) begin
        if_pc_in[0] = 4*(i-1);
        if_pc_in[1] = 4*(i-1)+4;
        end
        end
        $finish;
    end
endmodule