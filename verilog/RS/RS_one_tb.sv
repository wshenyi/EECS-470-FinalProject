
module t1;
    logic   clock, reset, enable;
    logic   compress_sel_1, compress_sel_2;
    logic   slot_valid_1, slot_valid_2;
    logic   INST1_valid, INST2_valid;
    logic   [`ROB_ADDR_BITS-1:0] CDB1_Tag, CDB2_Tag;
       RS_PACKET_IN        RS_packet_in_1, RS_packet_in_2; 
      RS_ENTRY_PACKET     UP_RS_entry_1, UP_RS_entry_2, UP_RS_entry_3;
    RS_OUT_PACKET       RS_OUT;
    RS_ENTRY_PACKET     RS_entry_tmp;
    logic  empty;  // if the slot is empty



    RS_one DUT(
                    //input
                    .clock(clock),
                    .reset(reset),
                    .enable(enable),
                    .compress_sel_1(compress_sel_1),
                    .compress_sel_2(compress_sel_1),
                    .slot_valid_1(slot_valid_1),
                    .slot_valid_2(slot_valid_2),
                    .INST1_valid(INST1_valid),
                    .INST2_valid(INST2_valid),
                    .CDB1_Tag(CDB1_Tag),
                    .CDB2_Tag(CDB2_Tag),
                    .RS_packet_in_1(RS_packet_in_1),
                    .RS_packet_in_2(RS_packet_in_2),
                    .UP_RS_entry_1(UP_RS_entry_1),
                    .UP_RS_entry_2(UP_RS_entry_2),
                    .UP_RS_entry_3(UP_RS_entry_3),
                    //output
                    .RS_OUT(RS_OUT),
                    .RS_entry(RS_entry_tmp),
                    .empty(empty)
                );

    always begin
        #5;
        clock = ~clock;
    end

    initial begin
        clock   = 0;
        reset   = 1;
        enable  = 1;
        
        INST1_valid = 0;
        INST2_valid = 0;
        RS_packet_in_1.Tag    = 0;
        RS_packet_in_1.Tag1   = 0;
        RS_packet_in_1.Tag2   = 0;
        RS_packet_in_1.Value1   = 0;
        RS_packet_in_1.Value2   = 0;
        RS_packet_in_1.valid1   = 1;
        RS_packet_in_1.valid2   = 1;
        CDB1_Tag = 0;

        RS_packet_in_2.Tag    = 0;
        RS_packet_in_2.Tag1   = 0;
        RS_packet_in_2.Tag2   = 0;
        RS_packet_in_2.Value1   = 0;
        RS_packet_in_2.Value2   = 0;
        RS_packet_in_2.valid1   = 1;
        RS_packet_in_2.valid2   = 1;
        CDB2_Tag = 0;

        compress_sel_1= 1;
        compress_sel_1 = 1;
        slot_valid_1 = 0;
        slot_valid_2 = 0;
        UP_RS_entry_1={$random,$random};
        UP_RS_entry_2={$random,$random};
        UP_RS_entry_3={$random,$random};



        repeat (10) @(negedge clock);
        reset   = 0;
        repeat (10) @(negedge clock);
        $finish;
    end


endmodule