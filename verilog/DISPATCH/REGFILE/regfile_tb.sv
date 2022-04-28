module t0;
    // inputs
    logic [1:0][4:0] rda_idx, rdb_idx, wr_idx; // read/write index, n-way
    logic [1:0][`XLEN-1:0] wr_data; // write data
    logic [1:0] wr_en;
    logic wr_clk;
    // outputs
    logic [1:0][`XLEN-1:0] rda_out, rdb_out; // read data

    regfile DUT (
        .rda_idx(rda_idx),
        .rdb_idx(rdb_idx),
        .wr_idx(wr_idx),
        .wr_data(wr_data),
        .wr_en(wr_en),
        .wr_clk(wr_clk),
        .rda_out(rda_out),
        .rdb_out(rdb_out)
    );

    always begin
        #5;
        wr_clk = ~wr_clk;
    end

    initial begin
        wr_clk = 0;
        wr_en = 0;
        wr_data = 0;
        rda_idx = 0;
        rdb_idx = 0;
        wr_idx = 0;
        for (int i=0;i<32;i++) begin
        @(negedge wr_clk);
        wr_en = 2'b11;
        wr_idx[0] = i;
        wr_data[0] = 32'hDEAD_BEEF;
        wr_idx[1] = i;
        wr_data[1] = 32'hFFFF_FFFF;
        end
        repeat (10) @(negedge wr_clk);
        for (int i=0;i<32;i++) begin
        @(negedge wr_clk);
        rda_idx = i;
        rdb_idx = i+1;
        end

        $finish;
    end

endmodule