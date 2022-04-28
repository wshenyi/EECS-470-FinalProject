
module BP_top (
    input  clock, reset,
    // input  [1:0] con_br_en,br_en,
    // input  squash_en,
    // input  [1:0] [`XLEN-1:0] ex_pc_in,  // pc from ex stage 
    // input  [1:0] [`XLEN-1:0] ex_tg_pc_in,    // target pc from ex stage in 
    // input  [1:0] con_br_taken,    // 1 if con_br taken 
    input  [1:0] [`XLEN-1:0] if_pc_in,    // pc from if stage
    input  INST  [1:0] inst,    // instruction
    input EX_BP_PACKET  [1:0] ex_bp_packet_in,
    input [1:0] valid,
    
    output logic [1:0] [`XLEN-1:0] bp_pc_out,
    output logic [1:0] [`XLEN-1:0] bp_npc_out,
    output logic bp_taken
);
    logic [1:0][`BHT_WIDTH-1:0] bht_if_out;    // output the value stored in BHT to PHT
    logic [1:0][`BHT_WIDTH-1:0] bht_ex_out;    // output the value stored in BHT to PHT
    logic [`XLEN-1:0] link_pc;    // link pc
    logic push;    // 1 if instruction is JAL
    logic pop;     // 1 if instruction is JALR   
    logic [1:0] predict_taken;
    

    // BTB output
    logic [1:0] hit;    // 1 if pc hit buffer 
    logic [1:0][`XLEN-1:0] predict_pc_out;

    // RAS output
    logic [`XLEN-1:0] return_addr;    // return pc only when  current insn is JALR

    // pre_decoder output
    logic [1:0] cond_branch, uncond_branch;
    logic [1:0] jump,link;
    
    assign bp_taken = link[0] | (jump[0] & hit[0]) | (cond_branch[0] & predict_taken[0] & hit[0]);
    
    

    // control the RAS 
    always_comb begin
        if (jump[0]) begin
            push = valid[0];
            pop  = 0;
        end
        else if (link[0]) begin
            push = 0;
            pop  = valid[0];
        end 
        else begin
            if (jump[1]) begin
                push = valid[1];
                pop  = 0; 
            end
            else if (link[1]) begin
                push = 0;
                pop  = valid[1];
            end
            else begin
                push = 0;
                pop  = 0;
            end
        end
    end

    assign link_pc = jump[0] ?  if_pc_in[0] : if_pc_in[1];
    

    // choose next pc
    always_comb begin
        if (link[0]) begin
            bp_npc_out[0] = return_addr;
            bp_npc_out[1] = return_addr + 4;
            bp_pc_out[0] = return_addr;
            bp_pc_out[1] = return_addr + 4;
        end
        else if (jump[0] && hit[0]) begin
            bp_npc_out[0] = predict_pc_out[0];
            bp_npc_out[1] = predict_pc_out[0] + 4;
            bp_pc_out[0] =  predict_pc_out[0];
            bp_pc_out[1] =  predict_pc_out[0] + 4;
        end
        else if (cond_branch[0] && predict_taken[0] && hit[0]) begin
            bp_npc_out[0] = predict_pc_out[0];
            bp_npc_out[1] = predict_pc_out[0] + 4;
            bp_pc_out[0] =  predict_pc_out[0];
            bp_pc_out[1] =  predict_pc_out[0] + 4;
        end
        else if (link[1]) begin
            bp_npc_out[0] = if_pc_in[0] + 4;
            bp_npc_out[1] = return_addr;
            bp_pc_out[0] =  return_addr;
            bp_pc_out[1] =  return_addr+4;
        end
        else if (jump[1] && hit[1]) begin
            bp_npc_out[0] = if_pc_in[0] + 4;
            bp_npc_out[1] = predict_pc_out[1];
            bp_pc_out[0] =  predict_pc_out[1];
            bp_pc_out[1] =  predict_pc_out[1]+4;
        end
        else if (cond_branch[1] &&
            predict_taken[1] && hit[1]) begin
            bp_npc_out[0] = if_pc_in[0] + 4;
            bp_npc_out[1] = predict_pc_out[1];
            bp_pc_out[0] =  predict_pc_out[1];
            bp_pc_out[1] =  predict_pc_out[1]+4;
        end
        else begin
            bp_npc_out[0] = if_pc_in[0] + 4;
            bp_npc_out[1] = if_pc_in[1] + 4;
            bp_pc_out[0] =  if_pc_in[0] + 8;
            bp_pc_out[1] =  if_pc_in[1] + 8;
        end
    end

   


    genvar i;
    generate 
    for (i=0;i<2;i++) begin
        pre_docode pre_decode_0(
        .inst(inst[i]),
        // output
        .valid(valid[i]),
        .cond_branch(cond_branch[i]), 
        .uncond_branch(uncond_branch[i]),
        .jump(jump[i]),    // JAL is jump insn 
        .link(link[i])     // JALR is link insn
        );
    end
    endgenerate

    BHT bht_0(
    .clock(clock), 
    .reset(reset), 
    // .squash_en(squash_en),
    .wr_en({ex_bp_packet_in[1].con_br_en,ex_bp_packet_in[0].con_br_en}),    // 1 if insn is cond_branch
    .ex_pc_in({ex_bp_packet_in[1].PC,ex_bp_packet_in[0].PC}),  // pc from ex stage 
    .take_branch({ex_bp_packet_in[1].con_br_taken,ex_bp_packet_in[0].con_br_taken}),    // 1 if con_branch taken 
    .if_pc_in(if_pc_in),    // pc from if stage 
    //output    
    .bht_if_out(bht_if_out),    // output the value stored in BHT to PHT
    .bht_ex_out(bht_ex_out)
    );

    PHT pht_0 (
    .clock(clock), 
    .reset(reset),
    .wr_en({ex_bp_packet_in[1].con_br_en,ex_bp_packet_in[0].con_br_en}),    // 1 if insn is cond_branch
    .ex_pc_in({ex_bp_packet_in[1].PC,ex_bp_packet_in[0].PC}),  // pc from ex stage 
    .take_branch({ex_bp_packet_in[1].con_br_taken,ex_bp_packet_in[0].con_br_taken}),    // 1 if con_branch taken 
    .if_pc_in(if_pc_in),    // pc from if stage 
    .bht_if_in(bht_if_out),   
    .bht_ex_in(bht_ex_out),
    //output
    .predict_taken(predict_taken)    // predict pc taken or no taken
    );

    BTB btb_0 (
    .clock(clock), 
    .reset(reset),
    .wr_en({ex_bp_packet_in[1].br_en,ex_bp_packet_in[0].br_en}),    // 1 if insn is branch (con/uncon)
    .ex_pc_in({ex_bp_packet_in[1].PC,ex_bp_packet_in[0].PC}),  // pc from ex stage 
    .ex_tg_pc_in({ex_bp_packet_in[1].tg_pc, ex_bp_packet_in[0].tg_pc}),    // target pc from ex stage in 
    .if_pc_in(if_pc_in),    // pc from if stage 
    //output   
    .hit(hit),    // 1 if pc hit buffer 
    .predict_pc_out(predict_pc_out)
    );

    RAS ras_0(
        .clock(clock),
        .reset(reset),
        .push(push),
        .pop(pop),
        .pc(link_pc),
        .return_addr(return_addr)
    );

    
endmodule