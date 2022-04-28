module t1();
    INST  inst;
    logic if_valid;    //  1 if the instruction is valid
    logic cond_branch, uncond_branch;
    logic jump, link;    // JAL is jump insn JALR is link insn

    pre_docode DUT(
    .inst(inst),
    .if_valid(if_valid),    //  1 if the instruction is valid
    .cond_branch(cond_branch), 
    .uncond_branch(uncond_branch),
    .jump(jump), 
    .link(link)    // JAL is jump insn JALR is link insn
    );

    initial begin
        if_valid = 0;
        inst = `NOP;
        
        for (int i=0;i<300;i++) begin
            #1;
            inst = i;
        end
        $finish;


    end
endmodule
