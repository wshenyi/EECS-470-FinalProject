// module t0();
//     logic clock, reset, squash_in;
//     logic ex_cp_alu0_en, ex_cp_alu1_en;
//     IS_EX_PACKET is_ex_alu0,is_ex_alu1,is_ex_mem,is_ex_mult;
//     //output
//     EX_CP_PACKET ex_cp_alu0, ex_cp_alu1, ex_cp_mult, ex_cp_mem;
//     EX_BP_PACKET [1:0] ex_bp_packet_out;

//     ex_stage DUT(
//         .clock(clock),
//         .reset(reset),
//         .squash_in(squash_in),
//         .ex_cp_alu0_en(ex_cp_alu0_en),
//         .ex_cp_alu1_en(ex_cp_alu1_en),
//         .is_ex_alu0(is_ex_alu0),
//         .is_ex_alu1(is_ex_alu1),
//         .is_ex_mem(is_ex_mem),
//         .is_ex_mult(is_ex_mult),
//         // Output 
//         .ex_cp_alu0(ex_cp_alu0),
//         .ex_cp_alu1(ex_cp_alu1),
//         .ex_cp_mult(ex_cp_mult),
//         .ex_bp_packet_out(ex_bp_packet_out),
//         .ex_cp_mem(ex_cp_mem));
    
//     always begin
//         #5;
//         clock =~clock;
//     end


//     initial begin
//         clock = 0;
//         reset = 1;
//         squash_in = 0;
//         ex_cp_alu0_en = 1;
//         ex_cp_alu1_en = 1;
//         is_ex_alu0 = 0;
//         is_ex_alu0.valid = 1;
//         is_ex_alu0.Tag = 1;
//         is_ex_alu0.NPC = 0;
//         is_ex_alu0.PC  = 0;
//         is_ex_alu0.rs1_value = 2;
//         is_ex_alu0.rs2_value = 2;
//         is_ex_alu0.inst.b.rs1 = 2;
//         is_ex_alu0.inst.b.rs2 = 3;
//         is_ex_alu0.inst.b.s  = 0;
//         is_ex_alu0.inst.b.f  = 0;
//         is_ex_alu0.inst.b.of  = 0;
//         is_ex_alu0.inst.b.et  = 4'h8;
//         is_ex_alu0.inst.b.funct3 = 0;
//         is_ex_alu0.opa_select = OPA_IS_PC;
//         is_ex_alu0.opb_select = OPB_IS_B_IMM;

//         is_ex_alu1 = 0;
//         is_ex_alu1.valid = 1;
//         is_ex_alu1.Tag = 2;
//         is_ex_alu1.NPC = 0;
//         is_ex_alu1.PC  = 0;
//         is_ex_alu1.rs1_value = 2;
//         is_ex_alu1.rs2_value = 2;
//         is_ex_alu1.inst.b.rs1 = 2;
//         is_ex_alu1.inst.b.rs2 = 3;
//         is_ex_alu1.inst.b.s  = 0;
//         is_ex_alu1.inst.b.f  = 0;
//         is_ex_alu1.inst.b.of  = 0;
//         is_ex_alu1.inst.b.et  = 4'h4;
//         is_ex_alu1.inst.b.funct3 = 0;
//         is_ex_alu1.opa_select = OPA_IS_PC;
//         is_ex_alu1.opb_select = OPB_IS_B_IMM;

//         is_ex_mem = 0;
//         is_ex_mem.valid = 1;
//         is_ex_mem.Tag = 3;

//         is_ex_mult = 0;
//         is_ex_mult.valid = 1;
//         is_ex_mult.Tag = 4;
//         for (int i =0;i<10;i++) begin
//             @(negedge clock);
//             reset = 0;
//             is_ex_alu0.Tag = i;
//             is_ex_alu1.Tag = i;
//             is_ex_alu0.cond_branch = 1;
//             is_ex_alu1.cond_branch = 1;
//             is_ex_alu0.PC = 8*i;
//             is_ex_alu1.PC = 8*i+4;
//             is_ex_alu0.NPC = 8*i+4;
//             is_ex_alu1.NPC = 8*i+8;
//             if (i == 5) begin
//                 is_ex_alu0.rs1_value = 2;
//                 is_ex_alu0.rs2_value = 3;
//             end
//         end
//         @(negedge clock);
//         ex_cp_alu0_en = 0;
//         is_ex_alu0.Tag = 5'h1F;
//         is_ex_alu1.Tag = 5'h1F;

//         for (int j =0;j<10;j++) begin
//             @(negedge clock);
//             reset = 0;
//             is_ex_alu0.Tag = j;
//             is_ex_alu1.Tag = j;
//         end

//         @(negedge clock);
//         ex_cp_alu1_en = 0;
//         is_ex_alu0.Tag = 5'h1F;
//         is_ex_alu1.Tag = 5'h1F;
//         for (int k =0;k<10;k++) begin
//             @(negedge clock);
//             reset = 0;
//             is_ex_alu0.Tag = k;
//             is_ex_alu1.Tag = k;
//         end
//         $finish;

//     end 
// endmodule 