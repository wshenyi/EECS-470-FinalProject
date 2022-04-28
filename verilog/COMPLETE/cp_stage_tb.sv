`timescale 1ns/100ps
module testbench;
    EX_CP_PACKET        ex_cp_packet_alu0, ex_cp_packet_alu1, ex_cp_packet_mult, ex_cp_packet_mem;
    CDB_PACKET [1:0]    cdb_packet_out;
    logic ALU0_stall_out, ALU1_stall_out;

    logic [3:0] cnt;

    cp_stage DUT(
        .ex_cp_packet_alu0(ex_cp_packet_alu0),
        .ex_cp_packet_alu1(ex_cp_packet_alu1),
        .ex_cp_packet_mult(ex_cp_packet_mult),
        .ex_cp_packet_mem(ex_cp_packet_mem),
        .cdb_packet_out(cdb_packet_out),
        .ALU0_stall_out(ALU0_stall_out),
        .ALU1_stall_out(ALU1_stall_out)
    );


    initial begin
        ex_cp_packet_mult = 0;
        ex_cp_packet_mem  = 0;
        ex_cp_packet_alu0 = 0;
        ex_cp_packet_alu1 = 0;
        #1;
        ex_cp_packet_alu0.valid = 1;
        ex_cp_packet_alu0.Tag = 3;
        ex_cp_packet_alu1.valid = 1;
        ex_cp_packet_alu1.Tag = 4;
        ex_cp_packet_mem.valid = 1;
        ex_cp_packet_mem.Tag = 2;
        ex_cp_packet_mult.valid = 1;
        ex_cp_packet_mult.Tag = 1;
        #1;
        for (int j = 0;j<16;j++) begin
        cnt = j;
        ex_cp_packet_alu1.valid = cnt[3];
        ex_cp_packet_alu0.valid = cnt[2];
        ex_cp_packet_mem.valid = cnt[1];
        ex_cp_packet_mult.valid = cnt[0];
        #1;
        end
        
        $finish;
    end
endmodule