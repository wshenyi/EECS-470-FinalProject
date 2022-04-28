
module testbench;
    parameter   REQS = 2;
    logic                               clock;
    logic                               reset;
    logic                               enable;
    logic                               squash_signal_in;
    MT_RS_PACKET          [1:0]         mt_rs_in;
    DP_PACKET             [1:0]         dp_packet_in;
    ROB_RS_PACKET         [1:0]         rob_in; 
    CDB_PACKET            [1:0]         cdb_in; 
   

    
    logic                                leave_one_slot_empty;
    logic                                slot_full;
    RS_ENTRY_PACKET       [`RS_SIZE-1:0] GOLDEN_RS_STATUS;
    RS_IS_PACKET         [REQS-1:0]      GOLDEN_rs_ex_out; 
    logic                [REQS-1:0]      GOLDEN_rs_ex_valid_out;
    logic                                fifo_empty;
    RS_IS_PACKET                         result_out, g_result_out;
    
    integer i,j;
    integer wptr,g_wptr, rptr;
    RS #(.REQS(REQS))T0 ( .clock(clock),
            .reset(reset),
            .enable(enable),
            .mt_rs_in(mt_rs_in),
            .dp_packet_in(dp_packet_in),
            .rob_in(rob_in),
            .cdb_in(cdb_in),
            .free(free),

            //output 
            .leave_one_slot_empty(leave_one_slot_empty),
            .slot_full(slot_full),
            .RS_OUT(RS_OUT),
            .ready(ready)
            );

    always begin
        #5;
        clock = ~clock;
    end


    // task compare_oldest_first;
    //     input RS_IS_PACKET  [REQS-1:0]   rs_ex_out; 
    //     input RS_IS_PACKET  [REQS-1:0]   GOLDEN_rs_ex_out; 
    //     begin
    //         if (GOLDEN_rs_ex_out!=rs_ex_out) begin
    //             //$display("tag:%h gtag:%h",rs_ex_out.Tag, GOLDEN_rs_ex_out.Tag);
                
    //             $display("@@@faild");
    //             //$finish;
    //         end
    //     end
    // endtask

    // task compare_correct_store;
    //     input RS_ENTRY_PACKET  GOLDEN_RS_STATUS;
    //     input RS_ENTRY_PACKET  RS_STATUS;
    //     begin
    //         if (GOLDEN_RS_STATUS!=RS_STATUS) begin
    //             $display("RS_STATUS.Tag:%h RS_STATUS.rs1_value:%h RS_STATUS.rs2_value:%h GOLDEN_RS_STATUS.Tag:%h busy:%h",RS_STATUS.Tag,RS_STATUS.rs1_value,RS_STATUS.rs2_value,GOLDEN_RS_STATUS.Tag, GOLDEN_RS_STATUS.busy);
               
    //             $display("@@@faild");
    //             //$finish;
    //         end
    //     end
    // endtask

    task rs_entry_in;
        input  reset;
        input  integer cycle; 
        input  DP_PACKET        [1:0] dp;
        input  MT_RS_PACKET     [1:0] mt_rs_in;
        input  ROB_RS_PACKET    [1:0] rob_in;
        input  CDB_PACKET       [1:0] cdb_in;
        RS_ENTRY_PACKET        [`RS_SIZE-1:0] rs_mem; 
        RS_ENTRY_PACKET        rs_mem_noop; 
        `ifdef DEBUG                           
        output RS_ENTRY_PACKET  [`RS_SIZE-1:0] GOLDEN_RS_STATUS;
        `endif
        output RS_IS_PACKET     [REQS-1:0] GOLDEN_rs_ex_out;
        output                  [REQS-1:0] GOLDEN_rs_ex_valid_out;
        integer i, wptr, free_ptr;
        reg [`RS_SIZE:0] ready1;
        reg [`RS_SIZE:0] ready2;
        begin
            // rs_mem_noop is empty slot in RS
            rs_mem_noop     =   {1'b0,             //busy
                                {`XLEN{1'b0}},     // PC + 4
                                {`XLEN{1'b0}},     // PC

                                {`XLEN{1'b0}},    // reg A value
                                {`XLEN{1'b0}},    // reg B value

                                OPA_IS_RS1,     // ALU opa mux select (ALU_OPA_xxx *)
                                OPB_IS_RS2,     // ALU opb mux select (ALU_OPB_xxx *)
                                `NOP,           // instruction

                                `ZERO_REG,   // destination (writeback) register index
                                ALU_ADD,     // ALU function select (ALU_xxx *)
                                1'b0,        // does inst read memory?
                                1'b0,        // does inst write memory?
                                1'b0,        // is inst a conditional branch?
                                1'b0,        // is inst an unconditional branch?
                                1'b0,        // is this a halt?
                                1'b0,        // is this instruction illegal?
                                1'b0,        // is this a CSR operation? (we only used this as a cheap way to get return code)csr_op
                                1'b0,        // is inst a valid instruction to be counted for CPI calculations?

                                1'b1,        // is 1 if has source reg1 and source reg1 is not reg0
                                1'b1,        // is 1 if has source reg2 and source reg2 is not reg0
                               
                                {`ROB_ADDR_BITS{1'b0}},  //Tag
                                {`ROB_ADDR_BITS{1'b0}},  //Tag1
                                {`ROB_ADDR_BITS{1'b0}},  //Tag2
                                1'b0,                    //Tag1_valid
                                1'b0,                     //Tag2_valid
                                FUNC_ALU
                                };                                  


            // reset
            if (reset) begin
                rs_mem      ={(`RS_SIZE){rs_mem_noop}};
                ready1      = {(`RS_SIZE){1'b0}};
                ready2      = {(`RS_SIZE){1'b0}};
                wptr        = 0;
                free_ptr  = 0;
                GOLDEN_rs_ex_out = 0;
                GOLDEN_rs_ex_valid_out = 0;
            end
            else begin
                if (rs_mem[wptr].busy == 0 && wptr < `RS_SIZE-1) begin 
                    // fetch the dispatch and rob and rf signal if dispatch is enable
                    if (dp[0].dp_en & dp[1].dp_en) begin
                        rs_mem [wptr].busy         = 1;
                        rs_mem [wptr].NPC           = dp_packet_in[0].NPC;         // PC + 4
                        rs_mem [wptr].PC            = dp_packet_in[0].PC ; // PC
                        rs_mem [wptr].opa_select    = dp_packet_in[0].opa_select;   // ALU opa mux select (ALU_OPA_xxx *)
                        rs_mem [wptr].opb_select    = dp_packet_in[0].opb_select ;   // ALU opb mux select (ALU_OPB_xxx *)
                        rs_mem [wptr].inst          = dp_packet_in[0].inst;        // instruction
                        rs_mem [wptr].dest_reg_idx  = dp_packet_in[0].dest_reg_idx; // destination (writeback) register index
                        rs_mem [wptr].alu_func      = dp_packet_in[0].alu_func ;    // ALU function select (ALU_xxx *)
                        rs_mem [wptr].rd_mem        = dp_packet_in[0].rd_mem ;      //rd_mem
                        rs_mem [wptr].wr_mem        = dp_packet_in[0].wr_mem;       //wr_mem
                        rs_mem [wptr].cond_branch   = dp_packet_in[0].cond_branch ;  //cond
                        rs_mem [wptr].uncond_branch = dp_packet_in[0].uncond_branch;  //uncond
                        rs_mem [wptr].halt          = dp_packet_in[0].halt ;          //halt
                        rs_mem [wptr].illegal       = dp_packet_in[0].illegal;       //illegal
                        rs_mem [wptr].csr_op        = dp_packet_in[0].csr_op;        //csr_op
                        rs_mem [wptr].valid         = dp_packet_in[0].valid ;         //valid
                        rs_mem [wptr].rs1_exist     = dp_packet_in[0].rs1_exist;      // is 1 if has source reg1 and source reg1 is not reg0
                        rs_mem [wptr].rs2_exist     = dp_packet_in[0].rs2_exist;
                        rs_mem [wptr].func_unit     = dp_packet_in[0].func_unit;
                        rs_mem [wptr].Tag          = rob_in[0].Tag;
                        rs_mem [wptr].Tag1         = mt_rs_in[0].Tag1;
                        rs_mem [wptr].Tag2         = mt_rs_in[0].Tag2;
                        rs_mem [wptr].Tag1_valid   = mt_rs_in[0].Tag1_valid;
                        rs_mem [wptr].Tag2_valid   = mt_rs_in[0].Tag2_valid;

                        rs_mem [wptr+1].busy         = 1;
                        rs_mem [wptr+1].NPC           = dp_packet_in[1].NPC;         // PC + 4
                        rs_mem [wptr+1].PC            = dp_packet_in[1].PC ; // PC
                        rs_mem [wptr+1].opa_select    = dp_packet_in[1].opa_select;   // ALU opa mux select (ALU_OPA_xxx *)
                        rs_mem [wptr+1].opb_select    = dp_packet_in[1].opb_select ;   // ALU opb mux select (ALU_OPB_xxx *)
                        rs_mem [wptr+1].inst          = dp_packet_in[1].inst;        // instruction
                        rs_mem [wptr+1].dest_reg_idx  = dp_packet_in[1].dest_reg_idx; // destination (writeback) register index
                        rs_mem [wptr+1].alu_func      = dp_packet_in[1].alu_func ;    // ALU function select (ALU_xxx *)
                        rs_mem [wptr+1].rd_mem        = dp_packet_in[1].rd_mem ;      //rd_mem
                        rs_mem [wptr+1].wr_mem        = dp_packet_in[1].wr_mem;       //wr_mem
                        rs_mem [wptr+1].cond_branch   = dp_packet_in[1].cond_branch ;  //cond
                        rs_mem [wptr+1].uncond_branch = dp_packet_in[1].uncond_branch;  //uncond
                        rs_mem [wptr+1].halt          = dp_packet_in[1].halt ;          //halt
                        rs_mem [wptr+1].illegal       = dp_packet_in[1].illegal;       //illegal
                        rs_mem [wptr+1].csr_op        = dp_packet_in[1].csr_op;        //csr_op
                        rs_mem [wptr+1].valid         = dp_packet_in[1].valid ;         //valid
                        rs_mem [wptr+1].rs1_exist     = dp_packet_in[1].rs1_exist;      // is 1 if has source reg1 and source reg1 is not reg0
                        rs_mem [wptr+1].rs2_exist     = dp_packet_in[1].rs2_exist;
                        rs_mem [wptr+1].func_unit     = dp_packet_in[1].func_unit;
                        rs_mem [wptr+1].Tag          = rob_in[1].Tag;
                        rs_mem [wptr+1].Tag1         = mt_rs_in[1].Tag1;
                        rs_mem [wptr+1].Tag2         = mt_rs_in[1].Tag2;
                        rs_mem [wptr+1].Tag1_valid   = mt_rs_in[1].Tag1_valid;
                        rs_mem [wptr+1].Tag2_valid   = mt_rs_in[1].Tag2_valid;

                        //
                        //For dp[0]
                        //
                        //rs1_value fetched from ROB
                        if (mt_rs_in[0].Tag1_ready_in_rob) begin
                            rs_mem [wptr].rs1_value   = rob_in[0].rs1_value;
                        end
                        //rs1_value fetched from RF
                        else if (~mt_rs_in[0].Tag1_ready_in_rob) begin
                            rs_mem [wptr].rs1_value   = dp[0].rs1_value;
                        end

                        //rs2_value fetched from ROB
                        if (mt_rs_in[0].Tag2_ready_in_rob) begin
                            rs_mem [wptr].rs2_value   = rob_in[0].rs2_value;
                        end
                        //rs2_value fetched from RF
                        else if (~mt_rs_in[0].Tag2_ready_in_rob) begin
                            rs_mem [wptr].rs2_value   = dp[0].rs2_value;
                        end 

                        //
                        //For dp[1]
                        //
                        //rs1_value fetched from ROB
                        if (mt_rs_in[1].Tag1_ready_in_rob) begin
                            rs_mem [wptr+1].rs1_value   = rob_in[1].rs1_value;
                        end
                        //rs1_value fetched from RF
                        else if (~mt_rs_in[1].Tag1_ready_in_rob) begin
                            rs_mem [wptr+1].rs1_value   = dp[1].rs1_value;
                        end

                        //rs2_value fetched from ROB
                        if (mt_rs_in[1].Tag2_ready_in_rob) begin
                            rs_mem [wptr+1].rs2_value   = rob_in[1].rs2_value;
                        end
                        //rs2_value fetched from RF
                        else if (~mt_rs_in[1].Tag2_ready_in_rob) begin
                            rs_mem [wptr+1].rs2_value   = dp[1].rs2_value;
                        end 

                        wptr +=2;
                    end
                    else if (dp[0].dp_en == 1 && dp[1].dp_en == 0) begin
                        rs_mem [wptr].busy         = 1;
                        rs_mem [wptr].NPC           = dp_packet_in[0].NPC;         // PC + 4
                        rs_mem [wptr].PC            = dp_packet_in[0].PC ; // PC
                       
                        rs_mem [wptr].opa_select    = dp_packet_in[0].opa_select;   // ALU opa mux select (ALU_OPA_xxx *)
                        rs_mem [wptr].opb_select    = dp_packet_in[0].opb_select ;   // ALU opb mux select (ALU_OPB_xxx *)
                        rs_mem [wptr].inst          = dp_packet_in[0].inst;        // instruction
                        rs_mem [wptr].dest_reg_idx  = dp_packet_in[0].dest_reg_idx; // destination (writeback) register index
                        rs_mem [wptr].alu_func      = dp_packet_in[0].alu_func ;    // ALU function select (ALU_xxx *)
                        rs_mem [wptr].rd_mem        = dp_packet_in[0].rd_mem ;      //rd_mem
                        rs_mem [wptr].wr_mem        = dp_packet_in[0].wr_mem;       //wr_mem
                        rs_mem [wptr].cond_branch   = dp_packet_in[0].cond_branch ;  //cond
                        rs_mem [wptr].uncond_branch = dp_packet_in[0].uncond_branch;  //uncond
                        rs_mem [wptr].halt          = dp_packet_in[0].halt ;          //halt
                        rs_mem [wptr].illegal       = dp_packet_in[0].illegal;       //illegal
                        rs_mem [wptr].csr_op        = dp_packet_in[0].csr_op;        //csr_op
                        rs_mem [wptr].valid         = dp_packet_in[0].valid ;         //valid
                        rs_mem [wptr].rs1_exist     = dp_packet_in[0].rs1_exist;      // is 1 if has source reg1 and source reg1 is not reg0
                        rs_mem [wptr].rs2_exist     = dp_packet_in[0].rs2_exist;
                        rs_mem [wptr].func_unit     = dp_packet_in[0].func_unit;
                        rs_mem [wptr].Tag          = rob_in[0].Tag;
                        rs_mem [wptr].Tag1         = mt_rs_in[0].Tag1;
                        rs_mem [wptr].Tag2         = mt_rs_in[0].Tag2;
                        rs_mem [wptr].Tag1_valid   = mt_rs_in[0].Tag1_valid;
                        rs_mem [wptr].Tag2_valid   = mt_rs_in[0].Tag2_valid;
                        //
                        //For dp[0]
                        //
                        //rs1_value fetched from ROB
                        if (mt_rs_in[0].Tag1_ready_in_rob) begin
                            rs_mem [wptr].rs1_value   = rob_in[0].rs1_value;
                        end
                        //rs1_value fetched from RF
                        else if (~mt_rs_in[0].Tag1_ready_in_rob) begin
                            rs_mem [wptr].rs1_value   = dp[0].rs1_value;
                        end

                        //rs2_value fetched from ROB
                        if (mt_rs_in[0].Tag2_ready_in_rob) begin
                            rs_mem [wptr].rs2_value   = rob_in[0].rs2_value;
                        end
                        //rs2_value fetched from RF
                        else if (~mt_rs_in[0].Tag2_ready_in_rob) begin
                            rs_mem [wptr].rs2_value   = dp[0].rs2_value;
                        end 
                        wptr ++;
                    end
                    
                end
                else if (rs_mem[wptr].busy == 0 && wptr == `RS_SIZE-1) begin
                    if (dp[0].dp_en == 1) begin
                        rs_mem [wptr].busy         = 1;
                        rs_mem [wptr].NPC           = dp_packet_in[0].NPC;         // PC + 4
                        rs_mem [wptr].PC            = dp_packet_in[0].PC ; // PC
                        
                        rs_mem [wptr].opa_select    = dp_packet_in[0].opa_select;   // ALU opa mux select (ALU_OPA_xxx *)
                        rs_mem [wptr].opb_select    = dp_packet_in[0].opb_select ;   // ALU opb mux select (ALU_OPB_xxx *)
                        rs_mem [wptr].inst          = dp_packet_in[0].inst;        // instruction
                        rs_mem [wptr].dest_reg_idx  = dp_packet_in[0].dest_reg_idx; // destination (writeback) register index
                        rs_mem [wptr].alu_func      = dp_packet_in[0].alu_func ;    // ALU function select (ALU_xxx *)
                        rs_mem [wptr].rd_mem        = dp_packet_in[0].rd_mem ;      //rd_mem
                        rs_mem [wptr].wr_mem        = dp_packet_in[0].wr_mem;       //wr_mem
                        rs_mem [wptr].cond_branch   = dp_packet_in[0].cond_branch ;  //cond
                        rs_mem [wptr].uncond_branch = dp_packet_in[0].uncond_branch;  //uncond
                        rs_mem [wptr].halt          = dp_packet_in[0].halt ;          //halt
                        rs_mem [wptr].illegal       = dp_packet_in[0].illegal;       //illegal
                        rs_mem [wptr].csr_op        = dp_packet_in[0].csr_op;        //csr_op
                        rs_mem [wptr].valid         = dp_packet_in[0].valid ;         //valid
                        rs_mem [wptr].rs1_exist     = dp_packet_in[0].rs1_exist;      // is 1 if has source reg1 and source reg1 is not reg0
                        rs_mem [wptr].rs2_exist     = dp_packet_in[0].rs2_exist;
                        rs_mem [wptr].func_unit     = dp_packet_in[0].func_unit;
                        rs_mem [wptr].Tag          = rob_in[0].Tag;
                        rs_mem [wptr].Tag1         = mt_rs_in[0].Tag1;
                        rs_mem [wptr].Tag2         = mt_rs_in[0].Tag2;
                        rs_mem [wptr].Tag1_valid   = mt_rs_in[0].Tag1_valid;
                        rs_mem [wptr].Tag2_valid   = mt_rs_in[0].Tag2_valid;
                        //
                        //For dp[0]
                        //
                        //rs1_value fetched from ROB
                        if (mt_rs_in[0].Tag1_ready_in_rob) begin
                            rs_mem [wptr].rs1_value   = rob_in[0].rs1_value;
                        end
                        //rs1_value fetched from RF
                        else if (~mt_rs_in[0].Tag1_ready_in_rob) begin
                            rs_mem [wptr].rs1_value   = dp[0].rs1_value;
                        end

                        //rs2_value fetched from ROB
                        if (mt_rs_in[0].Tag2_ready_in_rob) begin
                            rs_mem [wptr].rs2_value   = rob_in[0].rs2_value;
                        end
                        //rs2_value fetched from RF
                        else if (~mt_rs_in[0].Tag2_ready_in_rob) begin
                            rs_mem [wptr].rs2_value   = dp[0].rs2_value;
                        end 
                    end
                    wptr ++;
                end
            end
            // tag CAM
            for (i=0;i<`RS_SIZE;i++) begin
                if (rs_mem[i].busy == 1) begin
                    // cdb_in[0].tag match tag1, ready1 set to 1, rs1_value is cdb_in[0].value 
                    if (cdb_in[0].valid == 1 && rs_mem[i].Tag1_valid == 1 && cdb_in[0].Tag == rs_mem [i].Tag1) begin
                        rs_mem [i].rs1_value   = cdb_in[0].Value;
                        ready1 [i]          = 1;
                    end
                    //cdb_in[0].tag match tag2, ready2 set to 1, rs2_value is cdb_in[0].value 
                    if (cdb_in[0].valid == 1 && rs_mem[i].Tag2_valid == 1 && cdb_in[0].Tag == rs_mem [i].Tag2) begin
                        rs_mem [i].rs2_value   = cdb_in[0].Value;
                        ready2 [i]          = 1;
                    end
                    //cdb_in[1].tag match tag1, ready1 set to 1, rs1_value is cdb_in[1].value 
                    if (cdb_in[1].valid == 1 && rs_mem[i].Tag1_valid == 1 && cdb_in[1].Tag == rs_mem [i].Tag1 ) begin
                        rs_mem [i].rs1_value   = cdb_in[1].Value;
                        ready1 [i]          = 1;
                    end
                    //cdb_in[1].tag match tag2, ready2 set to 1, rs2_value is cdb_in[1].value 
                    if (cdb_in[1].valid == 1 && rs_mem[i].Tag2_valid == 1 && cdb_in[1].Tag == rs_mem [i].Tag2) begin
                        rs_mem [i].rs2_value   = cdb_in[1].Value;
                        ready2 [i]          = 1;
                    end
                    //has no tag1
                    if (~rs_mem [i].Tag1_valid) begin
                        ready1 [i]          = 1;
                    end
                    // has no tag2
                    if (~rs_mem [i].Tag2_valid) begin
                        ready2 [i]          = 1;
                    end 
                end
            end
            //
            //squeeze queue
            //

            //find lowest slot that is ready to issue
            for (i=0; i<`RS_SIZE; i++) begin
                if ((ready1[i] | ~rs_mem [i].rs1_exist) & (ready2[i] | ~rs_mem [i].rs2_exist) ) begin
                    free_ptr = i;
                    GOLDEN_rs_ex_out[0].NPC           = rs_mem[i].NPC;
                    GOLDEN_rs_ex_out[0].PC            = rs_mem[i].PC;

                    GOLDEN_rs_ex_out[0].rs1_value     = rs_mem[i].rs1_value;
                    GOLDEN_rs_ex_out[0].rs2_value     = rs_mem[i].rs2_value;
                    GOLDEN_rs_ex_out[0].inst          = rs_mem[i].inst;

                    GOLDEN_rs_ex_out[0].opa_select    = rs_mem[i].opa_select;
                    GOLDEN_rs_ex_out[0].opb_select    = rs_mem[i].opb_select;
                    GOLDEN_rs_ex_out[0].dest_reg_idx  = rs_mem[i].dest_reg_idx;
                    GOLDEN_rs_ex_out[0].alu_func      = rs_mem[i].alu_func;
                    GOLDEN_rs_ex_out[0].rd_mem        = rs_mem[i].rd_mem;
                    GOLDEN_rs_ex_out[0].wr_mem        = rs_mem[i].wr_mem;
                    GOLDEN_rs_ex_out[0].cond_branch   = rs_mem[i].cond_branch;
                    GOLDEN_rs_ex_out[0].uncond_branch = rs_mem[i].uncond_branch;
                    GOLDEN_rs_ex_out[0].halt          = rs_mem[i].halt;
                    GOLDEN_rs_ex_out[0].illegal       = rs_mem[i].illegal;
                    GOLDEN_rs_ex_out[0].csr_op        = rs_mem[i].csr_op; 
                    GOLDEN_rs_ex_out[0].valid         = rs_mem[i].valid; 

                    GOLDEN_rs_ex_out[0].Tag           = rs_mem[i].Tag ;  
                    GOLDEN_rs_ex_out[0].func_unit     = rs_mem[i].func_unit;

                    GOLDEN_rs_ex_valid_out[0]         = 1;
                    break;
                end
            end
            if (i != `RS_SIZE) begin
                //squeeze queue
                for (int k=free_ptr; k<`RS_SIZE; k++) begin
                    if (k ==  `RS_SIZE-1) begin
                        rs_mem [k] = rs_mem_noop;
                        ready1 [k] = 0;
                        ready2 [k] = 0;
                        //$display("debug busy[%1.0d]:%h",k,rs_mem[k].busy);
                    end else begin
                        rs_mem [k] = rs_mem [k+1];
                        ready1 [k] = ready1 [k+1];
                        ready2 [k] = ready2 [k+1];
                        //$display("debug busy[%1.0d]:%h debug busy[%1.0d]:%h",k,rs_mem[k].busy,k+1,rs_mem[k+1].busy);
                    end
                    
                end
                wptr--;
                free_ptr = 0;
            end
            
            //find second lowest slot that is ready to issue
            for (i=0; i<`RS_SIZE; i++) begin
                if ((ready1[i] | ~rs_mem [i].rs1_exist) & (ready2[i] | ~rs_mem [i].rs2_exist) ) begin
                    free_ptr = i;
                    GOLDEN_rs_ex_out[1].NPC           = rs_mem[i].NPC;
                    GOLDEN_rs_ex_out[1].PC            = rs_mem[i].PC;

                    GOLDEN_rs_ex_out[1].rs1_value     = rs_mem[i].rs1_value;
                    GOLDEN_rs_ex_out[1].rs2_value     = rs_mem[i].rs2_value;
                    GOLDEN_rs_ex_out[1].inst          = rs_mem[i].inst;

                    GOLDEN_rs_ex_out[1].opa_select    = rs_mem[i].opa_select;
                    GOLDEN_rs_ex_out[1].opb_select    = rs_mem[i].opb_select;
                    GOLDEN_rs_ex_out[1].dest_reg_idx  = rs_mem[i].dest_reg_idx;
                    GOLDEN_rs_ex_out[1].alu_func      = rs_mem[i].alu_func;
                    GOLDEN_rs_ex_out[1].rd_mem        = rs_mem[i].rd_mem;
                    GOLDEN_rs_ex_out[1].wr_mem        = rs_mem[i].wr_mem;
                    GOLDEN_rs_ex_out[1].cond_branch   = rs_mem[i].cond_branch;
                    GOLDEN_rs_ex_out[1].uncond_branch = rs_mem[i].uncond_branch;
                    GOLDEN_rs_ex_out[1].halt          = rs_mem[i].halt;
                    GOLDEN_rs_ex_out[1].illegal       = rs_mem[i].illegal;
                    GOLDEN_rs_ex_out[1].csr_op        = rs_mem[i].csr_op; 
                    GOLDEN_rs_ex_out[1].valid         = rs_mem[i].valid; 

                    GOLDEN_rs_ex_out[1].Tag           = rs_mem[i].Tag ; 
                    GOLDEN_rs_ex_out[1].func_unit     = rs_mem[i].func_unit;
                    GOLDEN_rs_ex_valid_out[1]         = 1;
                    break;
                end
            end
            if (i != `RS_SIZE) begin
                //squeeze queue
                for (int n=free_ptr; n<`RS_SIZE; n++) begin
                    if (n ==  `RS_SIZE-1) begin
                        rs_mem [n] = rs_mem_noop;
                        ready1 [n] = 0;
                        ready2 [n] = 0;
                    end else begin
                        rs_mem [n] = rs_mem [n+1];
                        ready1 [n] = ready1 [n+1];
                        ready2 [n] = ready2 [n+1];
                    end
                end
                wptr --;
                free_ptr = 0;
            end
            
            //$display("debug:%1.0d %h %h",i, rs_mem[i-1].busy, wptr);
            `ifdef DEBUG
            GOLDEN_RS_STATUS = rs_mem;
            `endif 
        end
    endtask


    task FIFO_RS_EX;
    input RS_IS_PACKET     [REQS-1:0] result_in;
    input                  [REQS-1:0] valid;
    input RS_IS_PACKET     [REQS-1:0] g_result_in;
    input                  [REQS-1:0] g_valid;
    input reset;
    input push;
    input pop;
    output integer wptr,g_wptr, rptr;
    RS_IS_PACKET [200:0] mem, g_mem;
    begin
        if (reset) begin
            wptr = 0;
            g_wptr = 0;
            rptr = 0;
            mem = 0;
            g_mem = 0;
        end
        else begin
            if (push) begin
                if (valid[0] == 1 && valid[1] == 1) begin
                    mem [wptr]   = result_in[0];
                    mem [wptr+1] = result_in[1];
                    wptr = wptr+2;
                end
                if (valid[0] == 1 && valid[1] == 0) begin
                    mem [wptr]   = result_in[0];
                    wptr = wptr+1;
                end

                //golden_result_in
                if (g_valid[0] == 1 && g_valid[1] == 1) begin
                    g_mem [wptr]   = g_result_in[0];
                    g_mem [wptr+1] = g_result_in[1];
                    g_wptr +=2;
                end
                if (g_valid[0] == 1 && g_valid[1] == 0) begin
                    g_mem [wptr]   = g_result_in[0];
                    g_wptr ++;
                end
                
            end
            if (pop) begin
                if(g_mem[rptr] == mem[rptr] ) begin
                    $display("Tag[%1.0d]:%h", rptr, mem[rptr].Tag);
                    rptr ++; 
                end else begin
                    $display("@@@fail");
                    $finish;
                end
            end
        end
    end
    endtask

    initial begin
        $dumpvars;
        clock   = 0;
        reset   = 1;
        enable  = 1;
/////////////////////////////////////////////////////////////////////////
//                                                                     
//   dispatch signal                                             
//                                                                                                                                                                                                                                                                                                                                                                                                 
/////////////////////////////////////////////////////////////////////////
        dp_packet_in[0]  = {{`XLEN{1'b0}},    // PC + 4
                                {`XLEN{1'b0}},     // PC

                                {`XLEN{1'b0}},    // reg A value 
                                {`XLEN{1'b0}},    // reg B value

                                OPA_IS_RS1,     // ALU opa mux select (ALU_OPA_xxx *)
                                OPB_IS_RS2,     // ALU opb mux select (ALU_OPB_xxx *)
                                `NOP,    // instruction

                                `ZERO_REG,    // destination (writeback) register index
                                ALU_ADD,     // ALU function select (ALU_xxx *)
                                1'b0,    //rd_mem
                                1'b0,    //wr_mem
                                1'b0,    //cond
                                1'b0,    //uncond
                                1'b0,    //halt
                                1'b0,    //illegal
                                1'b0,    //csr_op
                                1'b1,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
        
                                1'b1,    //dp_en
                                ALU

        };

        dp_packet_in[1]  = {{`XLEN{1'b0}},    // PC + 4
                                {`XLEN{1'b0}},     // PC

                                {`XLEN{1'b0}},    // reg A value 
                                {`XLEN{1'b0}},    // reg B value

                                OPA_IS_RS1,     // ALU opa mux select (ALU_OPA_xxx *)
                                OPB_IS_RS2,     // ALU opb mux select (ALU_OPB_xxx *)
                                `NOP,    // instruction

                                `ZERO_REG,    // destination (writeback) register index
                                ALU_ADD,     // ALU function select (ALU_xxx *)
                                1'b0,    //rd_mem
                                1'b0,    //wr_mem
                                1'b0,    //cond
                                1'b0,    //uncond
                                1'b0,    //halt
                                1'b0,    //illegal
                                1'b0,    //csr_op
                                1'b1,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1,    //dp_en
                                ALU

        };

        

/////////////////////////////////////////////////////////////////////////
//                                                                     
// maptable signal                                             
/////////////////////////////////////////////////////////////////////////  
        mt_rs_in[0].Tag1_ready_in_rob = 0;
        mt_rs_in[0].Tag2_ready_in_rob = 0;
        mt_rs_in[0].Tag1              = 0;
        mt_rs_in[0].Tag2              = 0;
        mt_rs_in[0].Tag2_valid        = 0;
        mt_rs_in[0].Tag2_valid        = 0;

        mt_rs_in[1].Tag1_ready_in_rob = 0;
        mt_rs_in[1].Tag2_ready_in_rob = 0;
        mt_rs_in[1].Tag1              = 0;
        mt_rs_in[1].Tag2              = 0;
        mt_rs_in[1].Tag2_valid        = 0;
        mt_rs_in[1].Tag2_valid        = 0;

        
/////////////////////////////////////////////////////////////////////////
//                                                                     
// rob signal                                             
/////////////////////////////////////////////////////////////////////////      
        rob_in[0].rs2_value    = 0;
        rob_in[0].rs1_value    = 0;
        rob_in[0].Tag       = 0;
        rob_in[1].rs2_value    = 0;
        rob_in[1].rs1_value    = 0;
        rob_in[1].Tag       = 0;

/////////////////////////////////////////////////////////////////////////
//                                                                     
// cdb_in signal                                             
/////////////////////////////////////////////////////////////////////////                                                                                                                                                                                           /////////////////////////////////////////////////////////////////////////
        cdb_in[0].Tag   = 0;
        cdb_in[0].Value = 0;
        cdb_in[0].valid = 0;

        cdb_in[1].Tag   = 0;
        cdb_in[1].Value = 0;
        cdb_in[1].valid = 0;

        rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
        FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
/////////////////////////////////////////////////////////////////////////
//
// test 1: check if older DISPATCH_PACKET is stored in the lower address of RS
//        
//
/////////////////////////////////////////////////////////////////////////
        for (i=0;i<20;i++) begin
            @(negedge clock);
            reset   = 0;
            dp_packet_in[0]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1,    //dp_en
                                ALU

        };
            mt_rs_in[0].Tag1            = $random%32;
            mt_rs_in[0].Tag2            = $random%32;
            mt_rs_in[0].Tag1_valid      = 0;
            mt_rs_in[0].Tag2_valid      = 0;

            dp_packet_in[1]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1,    //dp_en
                                ALU

        };
            mt_rs_in[1].Tag1            = $random%32;
            mt_rs_in[1].Tag2            = $random%32;
            mt_rs_in[1].Tag1_valid      = 0;
            mt_rs_in[1].Tag2_valid      = 0;  

            rob_in[0].Tag       = $random%32;
            rob_in[1].Tag       = $random%32;  

            
            rs_entry_in(reset, i, 
                dp_packet_in, 
                mt_rs_in, 
                rob_in,cdb_in, 
                `ifdef DEBUG
                GOLDEN_RS_STATUS, 
                `endif
                GOLDEN_rs_ex_out, 
                GOLDEN_rs_ex_valid_out);

            FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );

            
        end
        

        @(negedge clock);
        while (rptr != wptr && rptr != g_wptr) begin
            
            FIFO_RS_EX(
                    rs_ex_out,
                    rs_ex_valid_out,
                    GOLDEN_rs_ex_out,
                    GOLDEN_rs_ex_valid_out,
                    reset,
                    0,
                    1,
                    wptr,g_wptr, rptr
                    ); 
        end  
    
        $display("@@@test1_pass");
        @(negedge clock);
        reset = 1;
        rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
        FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
/////////////////////////////////////////////////////////////////////////
//
// test 2: check when dispatch[1] is not enable
//       
//
/////////////////////////////////////////////////////////////////////////
       
        for (i=0;i<20;i++) begin
            @(negedge clock);
            reset   = 0;
            dp_packet_in[0]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1,    //dp_en
                                ALU

        };
            mt_rs_in[0].Tag1            = $random%32;
            mt_rs_in[0].Tag2            = $random%32;
            mt_rs_in[0].Tag1_valid      = 0;
            mt_rs_in[0].Tag2_valid      = 0;

            dp_packet_in[1]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                1'b0,    //dp_en
                                ALU
                                

        };
            mt_rs_in[1].Tag1            = $random%32;
            mt_rs_in[1].Tag2            = $random%32;
            mt_rs_in[1].Tag1_valid      = 0;
            mt_rs_in[1].Tag2_valid      = 0;  

            rob_in[0].Tag       = 2*i;
            rob_in[1].Tag       = 2*i+1;  

            
            rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
            FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );

        end
        @(negedge clock);
        while (rptr != wptr && rptr != g_wptr) begin
            
            FIFO_RS_EX(
                    rs_ex_out,
                    rs_ex_valid_out,
                    GOLDEN_rs_ex_out,
                    GOLDEN_rs_ex_valid_out,
                    reset,
                    0,
                    1,
                    wptr,g_wptr, rptr
                    ); 
        end 
        
        $display("@@@test2_pass");
        
        //
        //reset
        //
        @(negedge clock);
        reset = 1;
        rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
        FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
/////////////////////////////////////////////////////////////////////////
//
// test 3: check when dispatch[0] is not enable 
//       
//
/////////////////////////////////////////////////////////////////////////
        
        for (i=0;i<32;i++) begin
            @(negedge clock);
            reset   = 0;
            dp_packet_in[0]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b0,    //dp_en
                                ALU

        };
            mt_rs_in[0].Tag1            = $random%32;
            mt_rs_in[0].Tag2            = $random%32;
            mt_rs_in[0].Tag1_valid      = 0;
            mt_rs_in[0].Tag2_valid      = 0;

            dp_packet_in[1]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid

                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                               
                                1'b1,    //dp_en
                                ALU

        };
            mt_rs_in[1].Tag1            = $random%32;
            mt_rs_in[1].Tag2            = $random%32;
            mt_rs_in[1].Tag1_valid      = 0;
            mt_rs_in[1].Tag2_valid      = 0;  

            rob_in[0].Tag       = $random%32;
            rob_in[1].Tag       = $random%32;  
            rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
            FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
        end

        @(negedge clock);
         while (rptr != wptr && rptr != g_wptr) begin
            
            FIFO_RS_EX(
                    rs_ex_out,
                    rs_ex_valid_out,
                    GOLDEN_rs_ex_out,
                    GOLDEN_rs_ex_valid_out,
                    reset,
                    0,
                    1,
                    wptr,g_wptr, rptr
                    ); 
        end  
        
       
        $display("@@@test3_pass");
        //
        //reset
        //
        @(negedge clock);
        reset = 1;
        rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
        FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
///////////////////////////////////////////////////////////////////////////
//
// test 4: random enable
//       
//
///////////////////////////////////////////////////////////////////////////
       repeat (25) begin
            @(negedge clock);
            reset   = 0;
            dp_packet_in[0]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                $random%2,
                                ALU    //dp_en

        };
            mt_rs_in[0].Tag1            = $random%32;
            mt_rs_in[0].Tag2            = $random%32;
            mt_rs_in[0].Tag1_valid      = 0;
            mt_rs_in[0].Tag2_valid      = 0;

            dp_packet_in[1]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                $random%2,
                                ALU    //dp_en

        };
            mt_rs_in[1].Tag1            = $random%32;
            mt_rs_in[1].Tag2            = $random%32;
            mt_rs_in[1].Tag1_valid      = 0;
            mt_rs_in[1].Tag2_valid      = 0;  

            rob_in[0].Tag       = $random%32;
            rob_in[1].Tag       = $random%32;  
            rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
            FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
        end
        
    
        @(negedge clock);
         while (rptr != wptr && rptr != g_wptr) begin
            
            FIFO_RS_EX(
                    rs_ex_out,
                    rs_ex_valid_out,
                    GOLDEN_rs_ex_out,
                    GOLDEN_rs_ex_valid_out,
                    reset,
                    0,
                    1,
                    wptr,g_wptr, rptr
                    ); 
        end  
       
        $display("@@@test4_pass");
        
        //
        //reset
        //
        @(negedge clock);
        reset = 1;
        rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);

        FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
/////////////////////////////////////////////////////////////////////////
//
// test 5: check cdb_in tag match, both cdb_in is valid
//       
//
/////////////////////////////////////////////////////////////////////////
        for (j=0; j<`RS_SIZE;j++) begin
            for (i=0;i<20;i++) begin
                @(negedge clock);
                reset   = 0;
                dp_packet_in[0]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1,    //dp_en
                                ALU

        };
                mt_rs_in[0].Tag1            = 2*i;
                mt_rs_in[0].Tag2            = 2*i;
                mt_rs_in[0].Tag1_valid      = 1;
                mt_rs_in[0].Tag2_valid      = 1;

                dp_packet_in[1]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1,    //dp_en
                               ALU

        };
                mt_rs_in[1].Tag1            = 2*i+1;
                mt_rs_in[1].Tag2            = 2*i+1;
                mt_rs_in[1].Tag1_valid      = 1;
                mt_rs_in[1].Tag2_valid      = 1;  

                rob_in[0].Tag       = 2*i;
                rob_in[1].Tag       = 2*i+1; 
                
                

                cdb_in[0].Tag = j;
                cdb_in[0].Value = $random%32;

                cdb_in[1].Tag = j+1;               
                cdb_in[1].Value = $random%32;        
                {cdb_in[1].valid, cdb_in[0].valid} = $random%4;
                rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
            FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
            end
            @(negedge clock);
            while (rptr != wptr && rptr != g_wptr) begin
            
                FIFO_RS_EX(
                        rs_ex_out,
                        rs_ex_valid_out,
                        GOLDEN_rs_ex_out,
                        GOLDEN_rs_ex_valid_out,
                        reset,
                        0,
                        1,
                        wptr,g_wptr, rptr
                        ); 
            end 
            
            $display("@@@test5.%1.0d_pass",j);
            //
            //reset
            //
            @(negedge clock);
            reset = 1;
            rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
            FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
        end
    
/////////////////////////////////////////////////////////////////////////
//
// test 5a: check cdb_in tag match, both tag.valid is random
//       
//
/////////////////////////////////////////////////////////////////////////
        for (j=0; j<`RS_SIZE;j++) begin
            for (i=0;i<20;i++) begin
                @(negedge clock);
                reset   = 0;
                dp_packet_in[0]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1,    //dp_en
                                ALU

        };
                mt_rs_in[0].Tag1            = 2*i;
                mt_rs_in[0].Tag2            = 2*i;
                mt_rs_in[0].Tag1_valid      = $random%2;
                mt_rs_in[0].Tag2_valid      = $random%2;

                dp_packet_in[1]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1,    //dp_en
                               ALU

        };
                mt_rs_in[1].Tag1            = 2*i+1;
                mt_rs_in[1].Tag2            = 2*i+1;
                mt_rs_in[1].Tag1_valid      = $random%2;
                mt_rs_in[1].Tag2_valid      = $random%2;  

                rob_in[0].Tag       = 2*i;
                rob_in[1].Tag       = 2*i+1; 
                
                

                cdb_in[0].Tag = j;
                cdb_in[0].Value = $random%32;

                cdb_in[1].Tag = j+1;               
                cdb_in[1].Value = $random%32;        
                {cdb_in[1].valid, cdb_in[0].valid} = $random%4;
                rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
                FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
            end
            @(negedge clock);
            while (rptr != wptr && rptr != g_wptr) begin
            
                FIFO_RS_EX(
                        rs_ex_out,
                        rs_ex_valid_out,
                        GOLDEN_rs_ex_out,
                        GOLDEN_rs_ex_valid_out,
                        reset,
                        0,
                        1,
                        wptr,g_wptr, rptr
                        ); 
            end 
            
            $display("@@@test5a.%1.0d_pass",j);
            //
            //reset
            //
            @(negedge clock);
            reset = 1;
            rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
            FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
        end

/////////////////////////////////////////////////////////////////////////
//
// test 5b: check cdb_in tag match, both tag.valid is random rs_exist is random
//       
//
/////////////////////////////////////////////////////////////////////////
        for (j=0; j<`RS_SIZE;j++) begin
            for (i=0;i<20;i++) begin
                @(negedge clock);
                reset   = 0;
                dp_packet_in[0]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1,    //dp_en
                               ALU

        };
                mt_rs_in[0].Tag1            = 2*i;
                mt_rs_in[0].Tag2            = 2*i;
                mt_rs_in[0].Tag1_valid      = $random%2;
                mt_rs_in[0].Tag2_valid      = $random%2;
                

                dp_packet_in[1]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1,    //dp_en
                                ALU

        };
                mt_rs_in[1].Tag1            = 2*i+1;
                mt_rs_in[1].Tag2            = 2*i+1;
                mt_rs_in[1].Tag1_valid      = $random%2;
                mt_rs_in[1].Tag2_valid      = $random%2;  

                rob_in[0].Tag       = 2*i;
                rob_in[1].Tag       = 2*i+1; 
                
                dp_packet_in[0].rs1_exist = 1;
                dp_packet_in[0].rs2_exist = 1;
                dp_packet_in[1].rs1_exist = 1;
                dp_packet_in[1].rs2_exist = 1;

                cdb_in[0].Tag = j;
                cdb_in[0].Value = $random%32;

                cdb_in[1].Tag = j+1;               
                cdb_in[1].Value = $random%32;        
                {cdb_in[1].valid, cdb_in[0].valid} = $random%4;
                rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
                FIFO_RS_EX(
                    rs_ex_out,
                    rs_ex_valid_out,
                    GOLDEN_rs_ex_out,
                    GOLDEN_rs_ex_valid_out,
                    reset,
                    1,
                    0,
                    wptr,g_wptr, rptr
                    );
            end
            @(negedge clock);
            while (rptr != wptr && rptr != g_wptr) begin
            
                FIFO_RS_EX(
                        rs_ex_out,
                        rs_ex_valid_out,
                        GOLDEN_rs_ex_out,
                        GOLDEN_rs_ex_valid_out,
                        reset,
                        0,
                        1,
                        wptr,g_wptr, rptr
                        ); 
            end 
            $display("@@@test5b.%1.0d_pass",j);
            //
            //reset
            //
            @(negedge clock);
            reset = 1;
            rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
            FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
        end

/////////////////////////////////////////////////////////////////////////
//
// test 5c: check cdb_in tag match, both dp.en is random
//       
//
/////////////////////////////////////////////////////////////////////////
        for (j=0; j<`RS_SIZE;j++) begin
            for (i=0;i<50;i++) begin
                @(negedge clock);
                reset   = 0;
                dp_packet_in[0]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1,    //dp_en
                                ALU

        };
                mt_rs_in[0].Tag1            = 2*i;
                mt_rs_in[0].Tag2            = 2*i;
                mt_rs_in[0].Tag1_valid      = $random%2;
                mt_rs_in[0].Tag2_valid      = $random%2;
                

                dp_packet_in[1]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                              
                                1'b1 ,   //dp_en
                                ALU

        };
                mt_rs_in[1].Tag1            = 2*i+1;
                mt_rs_in[1].Tag2            = 2*i+1;
                mt_rs_in[1].Tag1_valid      = $random%2;
                mt_rs_in[1].Tag2_valid      = $random%2;  

                rob_in[0].Tag       = 2*i;
                rob_in[1].Tag       = 2*i+1; 
                
                dp_packet_in[0].rs1_exist = 1;
                dp_packet_in[0].rs2_exist = 0;
                dp_packet_in[1].rs1_exist = 1;
                dp_packet_in[1].rs2_exist = 0;

                cdb_in[0].Tag = j;
                cdb_in[0].Value = $random%32;

                cdb_in[1].Tag = j+1;               
                cdb_in[1].Value = $random%32;        
                {cdb_in[1].valid, cdb_in[0].valid} = 0;
                rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
                FIFO_RS_EX(
                    rs_ex_out,
                    rs_ex_valid_out,
                    GOLDEN_rs_ex_out,
                    GOLDEN_rs_ex_valid_out,
                    reset,
                    1,
                    0,
                    wptr,g_wptr, rptr
                    );
            end
            @(negedge clock);
           
           
            //
            //reset
            //
            @(negedge clock);
            reset = 1;
            rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
            FIFO_RS_EX(
                    rs_ex_out,
                    rs_ex_valid_out,
                    GOLDEN_rs_ex_out,
                    GOLDEN_rs_ex_valid_out,
                    reset,
                    1,
                    0,
                    wptr,g_wptr, rptr
                    );
        end

/////////////////////////////////////////////////////////////////////////
//
// test 6: check when inst has no tag
//       
//
/////////////////////////////////////////////////////////////////////////
        for (i=0;i<16;i++) begin
            @(negedge clock);
            reset   = 0;
            dp_packet_in[0]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1,    //dp_en
                                ALU
        };
            mt_rs_in[0].Tag1            = $random%32;
            mt_rs_in[0].Tag2            = $random%32;
            mt_rs_in[0].Tag1_valid      = 0;
            mt_rs_in[0].Tag2_valid      = 0;
            mt_rs_in[0].Tag1_ready_in_rob = 1;

            dp_packet_in[1]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1,    //dp_en
                               ALU

        };
            mt_rs_in[1].Tag1            = $random%32;
            mt_rs_in[1].Tag2            = $random%32;
            mt_rs_in[1].Tag1_valid      = 0;
            mt_rs_in[1].Tag2_valid      = 0;
            mt_rs_in[0].Tag1_ready_in_rob = 1;  

            rob_in[0].Tag       = $random%32;
            rob_in[1].Tag       = $random%32;  
            rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
            FIFO_RS_EX(
                    rs_ex_out,
                    rs_ex_valid_out,
                    GOLDEN_rs_ex_out,
                    GOLDEN_rs_ex_valid_out,
                    reset,
                    1,
                    0,
                    wptr,g_wptr, rptr
                    );
        end


        @(negedge clock);
        while (rptr != wptr && rptr != g_wptr) begin
            
                FIFO_RS_EX(
                        rs_ex_out,
                        rs_ex_valid_out,
                        GOLDEN_rs_ex_out,
                        GOLDEN_rs_ex_valid_out,
                        reset,
                        0,
                        1,
                        wptr,g_wptr, rptr
                        ); 
            end 
        
       
        $display("@@@test6_pass");

        //
        //reset
        //
        @(negedge clock);
        reset = 1;
        rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
        FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );


/////////////////////////////////////////////////////////////////////////
//
// test 7: check inst ready_in_rob bit is 1 
//       
//
/////////////////////////////////////////////////////////////////////////
        for (i=0;i<16;i++) begin
            @(negedge clock);
            reset   = 0;
            dp_packet_in[0]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1,    //dp_en
                                ALU

        };
            mt_rs_in[0].Tag1            = $random%32;
            mt_rs_in[0].Tag2            = $random%32;
            mt_rs_in[0].Tag1_valid      = 1;
            mt_rs_in[0].Tag2_valid      = 1;
            mt_rs_in[0].Tag1_ready_in_rob = 1;

            dp_packet_in[1]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1,    //dp_en
                                ALU

        };
            mt_rs_in[1].Tag1            = $random%32;
            mt_rs_in[1].Tag2            = $random%32;
            mt_rs_in[1].Tag1_valid      = 1;
            mt_rs_in[1].Tag2_valid      = 1;
            mt_rs_in[0].Tag1_ready_in_rob = 1;  

            rob_in[0].Tag       = $random%32;
            rob_in[1].Tag       = $random%32;  
            rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
            FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );

        end

        @(negedge clock);
        while (rptr != wptr && rptr != g_wptr) begin
            
                FIFO_RS_EX(
                        rs_ex_out,
                        rs_ex_valid_out,
                        GOLDEN_rs_ex_out,
                        GOLDEN_rs_ex_valid_out,
                        reset,
                        0,
                        1,
                        wptr,g_wptr, rptr
                        ); 
            end 
       
       
        $display("@@@test7_pass");
        //
        //reset
        //
        @(negedge clock);
        reset = 1;
        rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
        FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );

/////////////////////////////////////////////////////////////////////////
//
// test 8: check oldest-first output
//       
//
/////////////////////////////////////////////////////////////////////////
        for (int i=0;i<8;i++) begin
            @(negedge clock);
            reset   = 0;
            dp_packet_in[0]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1,    //dp_en
                                ALU

        };
            mt_rs_in[0].Tag1            = 2*i;
            mt_rs_in[0].Tag2            = 2*i;
            mt_rs_in[0].Tag1_valid      = 1;
            mt_rs_in[0].Tag2_valid      = 1;

            dp_packet_in[1]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1,    //dp_en
                                ALU

        };
            mt_rs_in[1].Tag1            = 2*i+1;
            mt_rs_in[1].Tag2            = 2*i+1;
            mt_rs_in[1].Tag1_valid      = 1;
            mt_rs_in[1].Tag2_valid      = 1;  

            rob_in[0].Tag       = 2*i;
            rob_in[1].Tag       = 2*i+1;  
            rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);

        end

         for (int i=0;i<8;i++) begin
            @(negedge clock);
            dp_packet_in[0].dp_en = 0;
            dp_packet_in[1].dp_en = 0;

            cdb_in[0].Tag = 2*i;
            cdb_in[1].Tag = 2*i+1;
            cdb_in[0].Value = 2*i;
            cdb_in[1].Value = 2*i+1;
            cdb_in[0].valid = 1;
            cdb_in[1].valid = 1;
            rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out); 
            FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );  
        end
        @(negedge clock);
        while (rptr != wptr && rptr != g_wptr) begin
            
                FIFO_RS_EX(
                        rs_ex_out,
                        rs_ex_valid_out,
                        GOLDEN_rs_ex_out,
                        GOLDEN_rs_ex_valid_out,
                        reset,
                        0,
                        1,
                        wptr,g_wptr, rptr
                        ); 
            end 
        $display("@@@test8_pass");
        //
        //reset
        //
        @(negedge clock);
        reset = 1;
        rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
        FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
/////////////////////////////////////////////////////////////////////////
//
// test 9: has no tag
//       
//
/////////////////////////////////////////////////////////////////////////
        for (int i=0;i<50;i++) begin
            @(negedge clock);
            reset   = 0;
            dp_packet_in[0]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1,    //dp_en
                                ALU

        };
            mt_rs_in[0].Tag1            = 2*i;
            mt_rs_in[0].Tag2            = 2*i;
            mt_rs_in[0].Tag1_valid      = 0;
            mt_rs_in[0].Tag2_valid      = 0;

            dp_packet_in[1]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                               
                                1'b1,    //dp_en
                                ALU

        };
            mt_rs_in[1].Tag1            = 2*i+1;
            mt_rs_in[1].Tag2            = 2*i+1;
            mt_rs_in[1].Tag1_valid      = 0;
            mt_rs_in[1].Tag2_valid      = 0;  

            rob_in[0].Tag       = 2*i;
            rob_in[1].Tag       = 2*i+1; 

            cdb_in[0].Tag = 2*i;
            cdb_in[1].Tag = 2*i+1;
            cdb_in[0].Value = $random%32;
            cdb_in[1].Value = $random%32;
            cdb_in[0].valid = 0;
            cdb_in[1].valid = 0; 
           rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);  
            FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
        end
        @(negedge clock);
        while (rptr != wptr && rptr != g_wptr) begin
            FIFO_RS_EX(
                    rs_ex_out,
                    rs_ex_valid_out,
                    GOLDEN_rs_ex_out,
                    GOLDEN_rs_ex_valid_out,
                    reset,
                    0,
                    1,
                    wptr,g_wptr, rptr
                    ); 
        end 
        $display("@@@test9 pass");
        //
        //reset
        //
        @(negedge clock);
        reset = 1;
        rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
        FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
/////////////////////////////////////////////////////////////////////////
//
// test 10:  random
//       
//
/////////////////////////////////////////////////////////////////////////
        for (int i=0;i<50;i++) begin
            @(negedge clock);
            reset   = 0;
            dp_packet_in[0]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1,    //dp_en
                                ALU

        };
            mt_rs_in[0].Tag1            = 2*i;
            mt_rs_in[0].Tag2            = 2*i;
            mt_rs_in[0].Tag1_valid      = $random%2;
            mt_rs_in[0].Tag2_valid      = $random%2;

            dp_packet_in[1]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                               
                                1'b1,    //dp_en
                                ALU

        };
            mt_rs_in[1].Tag1            = 2*i+1;
            mt_rs_in[1].Tag2            = 2*i+1;
            mt_rs_in[1].Tag1_valid      = $random%2;
            mt_rs_in[1].Tag2_valid      = $random%2;  

            rob_in[0].Tag       = 2*i;
            rob_in[1].Tag       = 2*i+1; 

            cdb_in[0].Tag = 2*i;
            cdb_in[1].Tag = 2*i+1;
            cdb_in[0].Value = $random%32;
            cdb_in[1].Value = $random%32;
            cdb_in[0].valid = 0;
            cdb_in[1].valid = 0; 
           rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
            FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
           
        end
        @(negedge clock);
        while (rptr != wptr && rptr != g_wptr) begin
            FIFO_RS_EX(
                    rs_ex_out,
                    rs_ex_valid_out,
                    GOLDEN_rs_ex_out,
                    GOLDEN_rs_ex_valid_out,
                    reset,
                    0,
                    1,
                    wptr,g_wptr, rptr
                    ); 
        end 
        $display("@@@test10 pass");
        //
        //reset
        //
        @(negedge clock);
        reset = 1;
        rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
        FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
/////////////////////////////////////////////////////////////////////////
//
// test 11: rs1 doesn't exist
//       
//
/////////////////////////////////////////////////////////////////////////
        for (int i=0;i<50;i++) begin
            @(negedge clock);
            reset   = 0;
            dp_packet_in[0]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b0,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1 ,   //dp_en
                                ALU

        };
            
            mt_rs_in[0].Tag1            = 2*i;
            mt_rs_in[0].Tag2            = 2*i;
            mt_rs_in[0].Tag1_valid      = 1;
            mt_rs_in[0].Tag2_valid      = 1;

            dp_packet_in[1]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b0,    //rs1_exist
                                1'b1,    //rs2_exist
                                
                                1'b1,    //dp_en
                                ALU

        };
            
            mt_rs_in[1].Tag1            = 2*i+1;
            mt_rs_in[1].Tag2            = 2*i+1;
            mt_rs_in[1].Tag1_valid      = 1;
            mt_rs_in[1].Tag2_valid      = 1;  

            rob_in[0].Tag       = 2*i;
            rob_in[1].Tag       = 2*i+1; 

            cdb_in[0].Tag = 2*i;
            cdb_in[1].Tag = 2*i+1;
            cdb_in[0].Value = $random%32;
            cdb_in[1].Value = $random%32;
            cdb_in[0].valid = 0;
            cdb_in[1].valid = 0; 
           rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
            FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
          
        end
        @(negedge clock);
        while (rptr != wptr && rptr != g_wptr) begin
            FIFO_RS_EX(
                    rs_ex_out,
                    rs_ex_valid_out,
                    GOLDEN_rs_ex_out,
                    GOLDEN_rs_ex_valid_out,
                    reset,
                    0,
                    1,
                    wptr,g_wptr, rptr
                    ); 
        end 
        $display("@@@test11 pass");
        //
        //reset
        //
        @(negedge clock);
        reset = 1;

        rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
        FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
/////////////////////////////////////////////////////////////////////////
//
// test 12: rs2 doesn't exist
//       
//
/////////////////////////////////////////////////////////////////////////
        for (int i=0;i<50;i++) begin
            @(negedge clock);
            reset   = 0;
            dp_packet_in[0]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b0,    //rs2_exist
                                1'b1 ,   //dp_en
                                ALU

        };
            mt_rs_in[0].Tag1            = 2*i;
            mt_rs_in[0].Tag2            = 2*i;
            mt_rs_in[0].Tag1_valid      = 1;
            mt_rs_in[0].Tag2_valid      = 1;

            dp_packet_in[1]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b0,    //rs2_exist
                                1'b1   , //dp_en
                                ALU
        };
            mt_rs_in[1].Tag1            = 2*i+1;
            mt_rs_in[1].Tag2            = 2*i+1;
            mt_rs_in[1].Tag1_valid      = 1;
            mt_rs_in[1].Tag2_valid      = 1;  

            rob_in[0].Tag       = 2*i;
            rob_in[1].Tag       = 2*i+1; 

            cdb_in[0].Tag = 2*i;
            cdb_in[1].Tag = 2*i+1;
            cdb_in[0].Value = $random%32;
            cdb_in[1].Value = $random%32;
            cdb_in[0].valid = 0;
            cdb_in[1].valid = 0; 
            rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
            FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
        end
        @(negedge clock);
        while (rptr != wptr && rptr != g_wptr) begin
            FIFO_RS_EX(
                    rs_ex_out,
                    rs_ex_valid_out,
                    GOLDEN_rs_ex_out,
                    GOLDEN_rs_ex_valid_out,
                    reset,
                    0,
                    1,
                    wptr,g_wptr, rptr
                    ); 
        end 
        $display("@@@test12 pass");
        //
        //reset
        //
        @(negedge clock);
        reset = 1;
        rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
        FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
////////////////////////////////////////////////////////////////////////
//
// test 13: both doesn't exist
//       
//
/////////////////////////////////////////////////////////////////////////
        for (int i=0;i<50;i++) begin
            @(negedge clock);
            reset   = 0;
            dp_packet_in[0]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b0,    //rs1_exist
                                1'b0,    //rs2_exist
                                1'b1  ,  //dp_en
                                ALU

        };
            
            mt_rs_in[0].Tag1            = 2*i;
            mt_rs_in[0].Tag2            = 2*i;
            mt_rs_in[0].Tag1_valid      = 1;
            mt_rs_in[0].Tag2_valid      = 1;

            dp_packet_in[1]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                $random%2,
                                1'b1 ,   //dp_en
                                ALU

        };
            mt_rs_in[1].Tag1            = 2*i+1;
            mt_rs_in[1].Tag2            = 2*i+1;
            mt_rs_in[1].Tag1_valid      = 1;
            mt_rs_in[1].Tag2_valid      = 1;  

            rob_in[0].Tag       = 2*i;
            rob_in[1].Tag       = 2*i+1; 

            cdb_in[0].Tag = 2*i;
            cdb_in[1].Tag = 2*i+1;
            cdb_in[0].Value = $random%32;
            cdb_in[1].Value = $random%32;
            cdb_in[0].valid = 0;
            cdb_in[1].valid = 0; 
            rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
            FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
        end
        @(negedge clock);
        while (rptr != wptr && rptr != g_wptr) begin
            FIFO_RS_EX(
                    rs_ex_out,
                    rs_ex_valid_out,
                    GOLDEN_rs_ex_out,
                    GOLDEN_rs_ex_valid_out,
                    reset,
                    0,
                    1,
                    wptr,g_wptr, rptr
                    ); 
        end 
        $display("@@@test13 pass");
        //
        //reset
        //
        @(negedge clock);
        reset = 1;
        rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
        FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
/////////////////////////////////////////////////////////////////////////
//
// test 14:  both doesn't exist
//       
//
/////////////////////////////////////////////////////////////////////////
        for (int i=0;i<50;i++) begin
            @(negedge clock);
            reset   = 0;
            dp_packet_in[0]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b1,    //rs1_exist
                                1'b1,    //rs2_exist
                                $random%2,
                                1'b1,    //dp_en
                                ALU

        };
            
            mt_rs_in[0].Tag1            = 2*i;
            mt_rs_in[0].Tag2            = 2*i;
            mt_rs_in[0].Tag1_valid      = 1;
            mt_rs_in[0].Tag2_valid      = 1;

            dp_packet_in[1]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b0,    //rs1_exist
                                1'b0,    //rs2_exist
                                1'b1 ,   //dp_en
                                ALU

        };
            mt_rs_in[1].Tag1            = 2*i+1;
            mt_rs_in[1].Tag2            = 2*i+1;
            mt_rs_in[1].Tag1_valid      = 1;
            mt_rs_in[1].Tag2_valid      = 1;  

            rob_in[0].Tag       = 2*i;
            rob_in[1].Tag       = 2*i+1; 

            cdb_in[0].Tag = 2*i;
            cdb_in[1].Tag = 2*i+1;
            cdb_in[0].Value = $random%32;
            cdb_in[1].Value = $random%32;
            cdb_in[0].valid = 0;
            cdb_in[1].valid = 0; 
           rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
            FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
           
        end
        @(negedge clock);
        while (rptr != wptr && rptr != g_wptr) begin
            FIFO_RS_EX(
                    rs_ex_out,
                    rs_ex_valid_out,
                    GOLDEN_rs_ex_out,
                    GOLDEN_rs_ex_valid_out,
                    reset,
                    0,
                    1,
                    wptr,g_wptr, rptr
                    ); 
        end 
        $display("@@@test14 pass");
        //
        //reset
        //
        @(negedge clock);
        reset = 1;
        rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
        FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
/////////////////////////////////////////////////////////////////////////
//
// test 15:  both doesn't exist
//       
//
/////////////////////////////////////////////////////////////////////////
        for (int i=0;i<50;i++) begin
            @(negedge clock);
            reset   = 0;
            dp_packet_in[0]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b0,    //rs1_exist
                                1'b0,    //rs2_exist
                                1'b1 ,   //dp_en
                                ALU

        };
            mt_rs_in[0].Tag1            = 2*i;
            mt_rs_in[0].Tag2            = 2*i;
            mt_rs_in[0].Tag1_valid      = 1;
            mt_rs_in[0].Tag2_valid      = 1;

            dp_packet_in[1]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                1'b0,    //rs1_exist
                                1'b0,    //rs2_exist
                                1'b1 ,   //dp_en
                                ALU

        };
            mt_rs_in[1].Tag1            = 2*i+1;
            mt_rs_in[1].Tag2            = 2*i+1;
            mt_rs_in[1].Tag1_valid      = 1;
            mt_rs_in[1].Tag2_valid      = 1;  

            rob_in[0].Tag       = 2*i;
            rob_in[1].Tag       = 2*i+1; 

            cdb_in[0].Tag = 2*i;
            cdb_in[1].Tag = 2*i+1;
            cdb_in[0].Value = $random%32;
            cdb_in[1].Value = $random%32;
            cdb_in[0].valid = 0;
            cdb_in[1].valid = 0; 
           rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
            FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
           
        end
        @(negedge clock);
        while (rptr != wptr && rptr != g_wptr) begin
            FIFO_RS_EX(
                    rs_ex_out,
                    rs_ex_valid_out,
                    GOLDEN_rs_ex_out,
                    GOLDEN_rs_ex_valid_out,
                    reset,
                    0,
                    1,
                    wptr,g_wptr, rptr
                    ); 
        end 
        $display("@@@test15 pass");
        //
        //reset
        //
        @(negedge clock);
        reset = 1;
        rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
        FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
/////////////////////////////////////////////////////////////////////////
//
// test 16: rs1 doesn't exist (random)
//       
//
/////////////////////////////////////////////////////////////////////////
        for (int i=0;i<50;i++) begin
            @(negedge clock);
            reset   = 0;
            dp_packet_in[0]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                $random%2,    //rs1_exist
                                $random%2,    //rs2_exist
                                1'b1 ,   //dp_en
                                ALU

        };
            mt_rs_in[0].Tag1            = 2*i;
            mt_rs_in[0].Tag2            = 2*i;
            mt_rs_in[0].Tag1_valid      = 1;
            mt_rs_in[0].Tag2_valid      = 1;

            dp_packet_in[1]  = {$random%32,    // PC + 4
                                $random%32,     // PC

                                $random%32,    // reg A value 
                                $random%32,    // reg B value

                                $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
                                $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
                                $random%32,    // instruction

                                $random%32,    // destination (writeback) register index
                                $random%18,     // ALU function select (ALU_xxx *)
                                $random%2,    //rd_mem
                                $random%2,    //wr_mem
                                $random%2,    //cond
                                $random%2,    //uncond
                                $random%2,    //halt
                                $random%2,    //illegal
                                $random%2,    //csr_op
                                $random%2,     //valid
                                $random%2,    //rs1_exist
                                $random%2,    //rs2_exist
                                1'b1    ,//dp_en
                                ALU

        };
            mt_rs_in[1].Tag1            = 2*i+1;
            mt_rs_in[1].Tag2            = 2*i+1;
            mt_rs_in[1].Tag1_valid      = 1;
            mt_rs_in[1].Tag2_valid      = 1;  

            rob_in[0].Tag       = 2*i;
            rob_in[1].Tag       = 2*i+1; 

            cdb_in[0].Tag = 2*i;
            cdb_in[1].Tag = 2*i+1;
            cdb_in[0].Value = $random%32;
            cdb_in[1].Value = $random%32;
            cdb_in[0].valid = 0;
            cdb_in[1].valid = 0; 
           rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
            FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
        
        end
        @(negedge clock);
        while (rptr != wptr && rptr != g_wptr) begin
            FIFO_RS_EX(
                    rs_ex_out,
                    rs_ex_valid_out,
                    GOLDEN_rs_ex_out,
                    GOLDEN_rs_ex_valid_out,
                    reset,
                    0,
                    1,
                    wptr,g_wptr, rptr
                    ); 
        end 
        $display("@@@test16 pass");
        //
        //reset
        //
        @(negedge clock);
        reset = 1;
        rs_entry_in(reset, i, 
                    dp_packet_in, 
                    mt_rs_in, 
                    rob_in,
                    cdb_in, 
                    `ifdef DEBUG
                    GOLDEN_RS_STATUS, 
                    `endif
                    GOLDEN_rs_ex_out, 
                    GOLDEN_rs_ex_valid_out);
        FIFO_RS_EX(
                rs_ex_out,
                rs_ex_valid_out,
                GOLDEN_rs_ex_out,
                GOLDEN_rs_ex_valid_out,
                reset,
                1,
                0,
                wptr,g_wptr, rptr
                );
/////////////////////////////////////////////////////////////////////////
//
// test 11: rs1 doesn't exist (random)
//       
//
/////////////////////////////////////////////////////////////////////////
        // for (int i=0;i<200;i++) begin
        //     @(negedge clock);
        //     reset   = 0;
        //     dp_packet_in[0]  = {$random%32,    // PC + 4
        //                         $random%32,     // PC

        //                         $random%32,    // reg A value 
        //                         $random%32,    // reg B value

        //                         $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
        //                         $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
        //                         $random%32,    // instruction

        //                         $random%32,    // destination (writeback) register index
        //                         $random%18,     // ALU function select (ALU_xxx *)
        //                         $random%2,    //rd_mem
        //                         $random%2,    //wr_mem
        //                         $random%2,    //cond
        //                         $random%2,    //uncond
        //                         $random%2,    //halt
        //                         $random%2,    //illegal
        //                         $random%2,    //csr_op
        //                         $random%2,     //valid
        //                         $random%2,    //rs1_exist
        //                         $random%2,    //rs2_exist
        //                         $random%2    //dp_en

        // };
        //     mt_rs_in[0].Tag1            = $random%32;
        //     mt_rs_in[0].Tag2            = $random%32;
        //     mt_rs_in[0].Tag1_valid      = $random%2;
        //     mt_rs_in[0].Tag2_valid      = $random%2;

        //     dp_packet_in[1]  = {$random%32,    // PC + 4
        //                         $random%32,     // PC

        //                         $random%32,    // reg A value 
        //                         $random%32,    // reg B value

        //                         $random%4,     // ALU opa mux select (ALU_OPA_xxx *)
        //                         $random%6,     // ALU opb mux select (ALU_OPB_xxx *)
        //                         $random%32,    // instruction

        //                         $random%32,    // destination (writeback) register index
        //                         $random%18,     // ALU function select (ALU_xxx *)
        //                         $random%2,    //rd_mem
        //                         $random%2,    //wr_mem
        //                         $random%2,    //cond
        //                         $random%2,    //uncond
        //                         $random%2,    //halt
        //                         $random%2,    //illegal
        //                         $random%2,    //csr_op
        //                         $random%2,     //valid
        //                         $random%2,    //rs1_exist
        //                         $random%2,    //rs2_exist
        //                         $random%2    //dp_en

        // };
        //     mt_rs_in[1].Tag1            = $random%32;
        //     mt_rs_in[1].Tag2            = $random%32;
        //     mt_rs_in[1].Tag1_valid      = $random%2 ;
        //     mt_rs_in[1].Tag2_valid      = $random%2 ;  

        //     rob_in[0].Tag       = $random%32;
        //     rob_in[1].Tag       = $random%32; 

        //     cdb_in[0].Tag = $random%32;
        //     cdb_in[1].Tag = $random%32;
        //     cdb_in[0].Value = $random%32;
        //     cdb_in[1].Value = $random%32;
        //     cdb_in[0].valid = $random%2 ;
        //     cdb_in[1].valid = $random%2 ; 
           
        // end
        $finish;
    end
endmodule
