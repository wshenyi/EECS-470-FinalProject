
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
    logic                 [`RS_SIZE-1:0]  free;
    logic          [$clog2(`SQ_SIZE)-1:0]       tail_pos_1, tail_pos_2;
   

    logic                                leave_one_slot_empty;
    logic                                slot_full;
    RS_IS_PACKET          [`RS_SIZE-1:0] rs_out;
    logic                 [`RS_SIZE-1:0] ready;
    
    integer i,j;
    integer wptr,g_wptr, rptr;
    RS #(.REQS(REQS))T0 ( .clock(clock),
            .reset(reset),
            .enable(enable),
            .squash_signal_in(squash_signal_in),
            .mt_rs_in(mt_rs_in),
            .dp_packet_in(dp_packet_in),
            .tail_pos_1(tail_pos_1),
            .tail_pos_2(tail_pos_2),
            .rob_in(rob_in),
            .cdb_in(cdb_in),
            .free(free),
            //output 
            .leave_one_slot_empty(leave_one_slot_empty),
            .slot_full(slot_full),
            .RS_OUT(rs_out),
            .ready(ready)
            );

    always begin
        #5;
        clock = ~clock;
    end    
    initial begin
        $dumpvars;
        clock   = 0;
        reset   = 1;
        enable  = 1;
        squash_signal_in = 0;
        free    = 16'h0000;
        tail_pos_1 = 0;
        tail_pos_2 = 0;

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
                                FUNC_ALU

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
                                FUNC_ALU

        };

        

/////////////////////////////////////////////////////////////////////////
//                                                                     
// maptable signal                                             
/////////////////////////////////////////////////////////////////////////  
        mt_rs_in[0].Tag1_ready_in_rob = 0;
        mt_rs_in[0].Tag2_ready_in_rob = 0;
        mt_rs_in[0].Tag1              = 1;
        mt_rs_in[0].Tag2              = 1;
        mt_rs_in[0].Tag1_valid        = 1;
        mt_rs_in[0].Tag2_valid        = 1;

        mt_rs_in[1].Tag1_ready_in_rob = 0;
        mt_rs_in[1].Tag2_ready_in_rob = 0;
        mt_rs_in[1].Tag1              = 1;
        mt_rs_in[1].Tag2              = 1;
        mt_rs_in[1].Tag1_valid        = 1;
        mt_rs_in[1].Tag2_valid        = 1;

        
/////////////////////////////////////////////////////////////////////////
//                                                                     
// rob signal                                             
/////////////////////////////////////////////////////////////////////////      
        rob_in[0].rs2_value    = 1;
        rob_in[0].rs1_value    = 1;
        rob_in[0].Tag       = 1;
        rob_in[1].rs2_value    = 1;
        rob_in[1].rs1_value    = 1;
        rob_in[1].Tag       = 1;

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

        @(negedge clock);
        reset = 0;
        repeat (20) @(negedge clock) begin
            dp_packet_in[0].func_unit = FUNC_MULT;
            dp_packet_in[1].func_unit = FUNC_ALU;
            dp_packet_in[0].func_unit = FUNC_MULT;
            dp_packet_in[1].func_unit = FUNC_ALU;
            tail_pos_1 = $urandom;
            tail_pos_2 = $urandom;
        end
        @(negedge clock);
        free    = 16'h0020;
        repeat (20) @(negedge clock); 
        $finish;
    end
endmodule
