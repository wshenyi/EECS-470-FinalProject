/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  regfile.v                                           //
//                                                                     //
//  Description :  This module creates the Regfile used by the ID and  // 
//                 WB Stages of the Pipeline. (2-way)                  //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __REGFILE_V__
`define __REGFILE_V__



module regfile (
    // inputs
    input [1:0][4:0] rda_idx, rdb_idx, wr_idx, // read/write index, n-way
    input [1:0][`XLEN-1:0] wr_data, // write data
    input [1:0] wr_en,
    input wr_clk,

    // outputs
    output logic [1:0][`XLEN-1:0] rda_out, rdb_out // read data
);
    logic [31:0] [`XLEN-1:0] registers; // 32, 64-bit Registers
    logic [4:0] true_wr_idx_0;
    assign true_wr_idx_0 = (wr_idx[0] == wr_idx[1]) ? `ZERO_REG : wr_idx[0];
    // first write might be overwritten by the second

    // read ports, with forwarding
    // genvar i;
    // generate
    //     for (i = 0; i < 2; i++) begin
    //         always_comb begin : portA
    //             if (rda_idx[i] == `ZERO_REG) begin
    //                 rda_out[i] = 0;
    //             end else if (wr_en[1] && (rda_idx[i] == wr_idx[1])) begin
    //                 rda_out[i] = wr_data[1];
    //             end else if (wr_en[0] && (rda_idx[i] == wr_idx[0])) begin
    //                 rda_out[i] = wr_data[0];
    //             end else begin
    //                 rda_out = registers[rda_idx[i]];
    //             end
    //         end
    //         always_comb begin : portB
    //             if (rdb_idx[i] == `ZERO_REG) begin
    //                 rdb_out[i] = 0;
    //             end else if (wr_en[1] && (rdb_idx[i] == wr_idx[1])) begin
    //                 rdb_out[i] = wr_data[1];
    //             end else if (wr_en[0] && (rdb_idx[i] == wr_idx[0])) begin
    //                 rdb_out[i] = wr_data[0];
    //             end else begin
    //                 rdb_out = registers[rdb_idx[i]];
    //             end
    //         end
    //     end
    // endgenerate

    always_comb begin
        for (int i = 0; i < 2; i++) begin
            if (rda_idx[i] == `ZERO_REG) begin
                rda_out[i] = 0;
            end else if (wr_en[1] && (rda_idx[i] == wr_idx[1])) begin
                rda_out[i] = wr_data[1];
            end else if (wr_en[0] && (rda_idx[i] == wr_idx[0])) begin
                rda_out[i] = wr_data[0];
            end else begin
                rda_out[i] = registers[rda_idx[i]];
            end
            if (rdb_idx[i] == `ZERO_REG) begin
                rdb_out[i] = 0;
            end else if (wr_en[1] && (rdb_idx[i] == wr_idx[1])) begin
                rdb_out[i] = wr_data[1];
            end else if (wr_en[0] && (rdb_idx[i] == wr_idx[0])) begin
                rdb_out[i] = wr_data[0];
            end else begin
                rdb_out[i] = registers[rdb_idx[i]];
            end
        end
    end


    //
    // Write ports
    //
    always_ff @(posedge wr_clk) begin
        if (wr_en[0]) begin
            registers[true_wr_idx_0] <= `SD wr_data[0];
        end
        if (wr_en[1]) begin
            registers[wr_idx[1]] <= `SD wr_data[1];
        end
    end


endmodule // regfile
`endif //__REGFILE_V__
