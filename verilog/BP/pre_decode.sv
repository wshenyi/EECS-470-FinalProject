module pre_docode(
    input INST inst,
    input valid,
    output logic cond_branch, uncond_branch,
    output logic jump, link    // JAL is jump insn JALR is link insn
);
    always_comb begin
        cond_branch   = `FALSE;
        uncond_branch = `FALSE;
        jump    = `FALSE;
        link    = `FALSE;
        if (valid) begin
            casez (inst)
            `RV32_JAL: begin
                uncond_branch = `TRUE;
                jump    = `TRUE;
            end
            `RV32_JALR: begin
                uncond_branch = `TRUE;
                link   = `TRUE;
            end
            `RV32_BEQ, `RV32_BNE, `RV32_BLT, `RV32_BGE,
            `RV32_BLTU, `RV32_BGEU: begin
                cond_branch = `TRUE;
            end
            endcase
        end
    end

    
endmodule