/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  RS.sv                                               //
//                                                                     //
//  Description :                                                      // 
//                                                                     //
//                                                                     //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////
module RS (
    input                                   clock, reset, enable,
    input   MT_RS_PACKET        [1:0]       mt_rs_in, 
    input   DP_PACKET           [1:0]       dp_packet_in,
    input   ROB_RS_PACKET       [1:0]       rob_in,          
    input   CDB_PACKET          [1:0]       cdb_in,  

    input      [$clog2(`SQ_SIZE)-1:0]       tail_pos_1, tail_pos_2,
    // input from issue stage   
    input               [`RS_SIZE-1:0]      free,          
    input                                   squash_signal_in,
   
    
    output                                  leave_one_slot_empty,
    output                                  slot_full,
    output RS_IS_PACKET    [`RS_SIZE-1:0]   RS_OUT,                             //tag, rs1_value, rs2_value (NUM = RS_SIZE)
    output                 [`RS_SIZE-1:0]   ready                                  // if the slot is ready to free
);
                      
    logic   [`RS_SIZE-1:0]      empty;
    logic   [`RS_SIZE-1:0]      slot_valid_1, slot_valid_2;
    logic   [`RS_SIZE-1:0]      sel_1;
    logic   [`RS_SIZE-1:0]      sel_2;
    
    RS_ENTRY_PACKET  [`RS_SIZE+1:0] RS_entry_tmp;
    RS_ENTRY_PACKET   RS_entry_noop;


    assign RS_entry_noop =  {1'b0,             //busy
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
                            FUNC_ALU,        // function unit
                            {($clog2(`SQ_SIZE)){1'b0}}    // tail position
                            };                                  

    assign RS_entry_tmp [`RS_SIZE+1]    = RS_entry_noop;                
    assign RS_entry_tmp [`RS_SIZE]      = RS_entry_noop;

    //find if RS has only one slot empty
    assign leave_one_slot_empty = empty[`RS_SIZE-1] & ~empty[`RS_SIZE-2];
    assign slot_full            = ~empty[`RS_SIZE-1];

    //compress the instruction in RS slot
    sel_ctl  compress_ctl
    ( .req(free),               // if instruction can be free
      .sel_1(sel_1),             
      .sel_2(sel_2)             // if instruction need to move zero slot /one slot/ two slots
    );

    //indicate which slot in RS is valid
    allocate allocate2RS (
        .req(empty),            //empty(no-busy)
        .gnt_1(slot_valid_1),   //if slot_1 is valid
        .gnt_2(slot_valid_2)   //if slot_2 is valid
    );
        
    logic [`RS_SIZE+2:0] has_ld_cum;
    assign has_ld_cum[0] = 1'b0;

    genvar n;
    generate 
        for (n=0; n<`RS_SIZE; n=n+1) begin
            RS_one IQ(
                //input
                .clock(clock),
                .reset(reset),
                .squash_signal_in(squash_signal_in),
                .enable(enable),
                .compress_sel_1(sel_1[n]),              // if instruction need to move zero slot /one slot/ two slots
                .compress_sel_2(sel_2[n]),              // if instruction need to move zero slot /one slot/ two slots
                .slot_valid_1(slot_valid_1[n]),         //if slot_1 is valid
                .slot_valid_2(slot_valid_2[n]),         //if slot_2 is valid
                .cdb_in(cdb_in),
                .mt_rs_in(mt_rs_in),
                .dp_packet_in(dp_packet_in),
                .tail_pos_1(tail_pos_1),
                .tail_pos_2(tail_pos_2),
                .rob_in(rob_in),
                .UP_RS_entry_1(RS_entry_tmp[n]),        //next_state of RS_entry[i] is RS_entry[i]
                .UP_RS_entry_2(RS_entry_tmp[n+1]),      //next_state of RS_entry[i] is RS_entry[i+1]
                .UP_RS_entry_3(RS_entry_tmp[n+2]),      //next_state of RS_entry[i] is RS_entry[i+2]
                .has_ld_from_above(has_ld_cum[n]),
                //output
                .RS_OUT(RS_OUT[n]),                     //tag, rs1_value, rs2_value (NUM = RS_SIZE)
                .RS_entry(RS_entry_tmp[n]),
                .empty(empty[n]),                       //if the slot is empty(no-busy)
                .ready(ready[n]),                       // if the slot is ready to free
                .has_ld_including_self(has_ld_cum[n+1])
            );
        end
    endgenerate

    

    // issue #(.WIDTH(`RS_SIZE)) issue_stage(
    //     //input
    //     .rs_is_packet_in(RS_OUT),
    //     .req(ready),
    //     .ALU0_stall_in(ALU0_stall_in),
    //     .ALU1_stall_in(ALU1_stall_in),
    //     //output 
    //     .rs_is_alu0_out(rs_is_alu0_out),
    //     .rs_is_alu1_out(rs_is_alu1_out),
    //     .rs_is_mult_out(rs_is_mult_out),
    //     .rs_is_mem_out(rs_is_mem_out),
    //     .free(free),
    //     .rs_is_alu0_vld(rs_is_alu0_vld), 
    //     .rs_is_alu1_vld(rs_is_alu1_vld), 
    //     .rs_is_mult_vld(rs_is_mult_vld), 
    //     .rs_is_mem_vld(rs_is_mem_vld)
    // );
    

endmodule



