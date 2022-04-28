// 
// we only have 16 bit(64KB) address space here, each block has 8 Byte (3 bit), so 16 - 3 = 13 bit for tag & index
// Address[15:0] = {[15:7]:9-bit tag, [6:3]:4-bit idx, [2]:offset, [1:0]:2'b0}
// We use NRU to evict cache lines between different set
`timescale 1ns/100ps

module cache #(parameter LINE_NUM  = 16,
               parameter TAG_WIDTH = 9,
               parameter READ_WIDTH= 2 )(
        input  logic clock, reset, wr_en,
        input  logic wr_command, // 0 for miss read, 1 for miss write
        input  logic [$clog2(LINE_NUM)-1:0]       wr_idx, 
        input  logic [TAG_WIDTH-1:0]              wr_tag, 
        input  logic [63:0]                       wr_data,
        output logic [63:0]                       wr_data_old,
        output logic                              wr_valid,

        // At most 2 read access
        input  logic [READ_WIDTH-1:0] [$clog2(LINE_NUM)-1:0] rd_idx ,
        input  logic [READ_WIDTH-1:0] [TAG_WIDTH-1:0]        rd_tag ,
        output logic [READ_WIDTH-1:0] [63:0]                 rd_data ,
        output logic [READ_WIDTH-1:0]                        rd_valid ,
        output logic [LINE_NUM-1:0]                          block_valid,

        // write-back port
        output logic [63:0] wb_data,
        output logic [15:0] wb_addr,
        output logic        wb_dirty,
        output logic        wb_request,

        // expose for testbench
        output CACHE_LINE cache_table [LINE_NUM-1:0],

        // extra port for prefetch module
        input  logic [$clog2(LINE_NUM)-1:0] pref_idx ,
        input  logic [TAG_WIDTH-1:0]        pref_tag ,
        output logic                        pref_skip
    );

    // Read data
    always_comb begin
        for (int i = 0; i < READ_WIDTH; i++) begin
            rd_valid[i] = cache_table[rd_idx[i]].valid && (cache_table[rd_idx[i]].tag == rd_tag[i]);
            rd_data[i]  = cache_table[rd_idx[i]].data;
        end
    end

    // Writeback
    assign wb_request  = cache_table[wr_idx].dirty & wr_en & cache_table[wr_idx].valid & (wr_tag != cache_table[wr_idx].tag);
    assign wb_data     = cache_table[wr_idx].data;
    assign wb_addr     = {cache_table[wr_idx].tag, wr_idx, 3'b0};
    assign wb_dirty    = cache_table[wr_idx].dirty;

    always_comb begin
        for (int i = 0; i < LINE_NUM; i++) begin
            block_valid[i] = cache_table[i].valid;
        end
    end

    // Prefetching logic
    assign pref_skip   = cache_table[pref_idx].valid && cache_table[pref_idx].tag == pref_tag;
    // Write data
    assign wr_valid    = cache_table[wr_idx].valid   && cache_table[wr_idx].tag   == wr_tag;
    assign wr_data_old = cache_table[wr_idx].data;

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if(reset)begin
            for (int i =0; i < LINE_NUM; i++) begin
                cache_table[i] <= `SD 0;
            end
        end
        else if(wr_en) begin
            cache_table[wr_idx].data   <= `SD wr_data;
            cache_table[wr_idx].tag    <= `SD wr_tag;
            cache_table[wr_idx].valid  <= `SD 1;
            if (wr_command | rd_valid[0]) begin
                cache_table[wr_idx].dirty <= `SD 1'b1;
            end 
            else if (wb_request) begin
                cache_table[wr_idx].dirty <= `SD 1'b0;
            end
        end
    end


endmodule

//module victim_cache #(LINE_NUM=16)
