module testbench;

    // Input ports declaration
    logic   clock, reset, enable;
    CDB_PACKET    [1:0] CDB_packet;         // Come from Complete stage
    DP_PACKET     [1:0]  DP_packet;         // Come from Dispatch stage to tell the stride of tail pointer
    MT_ROB_PACKET [1:0] MT_ROB_packet;
    
    // Output ports declaration
    logic         [1:0] dp_available;       // Output ROB space to tell how many space left in ROB
    logic               squash_signal;      // Output a signal when ROB squash and other components need to syn with it
    CP_RT_PACKET  [1:0] CP_RT_packet;      
    ROB_RS_PACKET [1:0] ROB_RS_packet;      // At Dispatch stage, output dispatched tag and value of source reg
    ROB_MT_PACKET [1:0] ROB_MT_packet;      // At Dispatch stage, output dispatched tag

    RT_PACKET     [1:0] RT_packet;          // At Retire stage, output retire register and value to regfiles and map table

    // Ports declaration for debug
    `ifdef DEBUG
    logic [$clog2(`ROB_SIZE)-1:0] head;
    logic [$clog2(`ROB_SIZE)-1:0] tail;
    logic [$clog2(`ROB_SIZE):0]  space;
    ROB_ENTRY [`ROB_SIZE-1:0]  content;
    `endif
    
    // Variables declaration for simulation
    integer unsigned head_s = 0, tail_s = 0;
    integer space_s = 32;
    integer squash_signal_s = 0;
    ROB_ENTRY [`ROB_SIZE-1:0] content_s = 0;

    // Instance declaration
    ROB rob(
        //Inputs
        .reset  (reset),
        .clock  (clock),
        .enable (enable),
        .squash_signal(squash_signal),
        .CDB_packet_in(CDB_packet),
        .DP_packet_in(DP_packet),
        .MT_ROB_packet_in(MT_ROB_packet),
        //Outputs
        .dp_available(dp_available),
        .CP_RT_packet_out(CP_RT_packet),
        .ROB_RS_packet_out(ROB_RS_packet),
        .ROB_MT_packet_out(ROB_MT_packet)
        //Debug
        `ifdef DEBUG
        ,
        .head_out(head),
        .tail_out(tail),
        .space_out(space),
        .content_out(content)
        `endif
    );

    rt_stage rt_stage(
        // Inputs
        .CP_RT_packet_in(CP_RT_packet),
        //Outputs
        .RT_packet_out(RT_packet),
        .squash_signal_out(squash_signal)
    );

    function CDB_PACKET [1:0] CDB_packet_generator;
        input logic if_squash; // If contain squash signal
        integer unsigned tag1, tag2, length;
        begin
            length = `ROB_SIZE - space_s;
            tag1 = head_s;
            tag2 = head_s;
            CDB_packet_generator[0] = $urandom;
            CDB_packet_generator[1] = $urandom;

            CDB_packet_generator[0].valid = 0;
            CDB_packet_generator[1].valid = 0;

            if (length > 16) begin
                for(int i = 0; i < length; i++) begin
                    if (content_s[tag1].cp_bit == 0) begin
                        CDB_packet_generator[0].valid = $urandom%2;
                        break;
                    end
                    else tag1 = (tag1 + 1) % `ROB_SIZE;
                end
                for(int j = 0; j < length; j++) begin
                    if (content_s[tag2].cp_bit == 0 && tag1 != tag2) begin
                        CDB_packet_generator[1].valid = $urandom%2;
                        break;
                    end
                    else tag2 = (tag2 + 1) % `ROB_SIZE;
                end
            end

            CDB_packet_generator[0].Tag   = tag1;
            CDB_packet_generator[1].Tag   = tag2;
            CDB_packet_generator[0].Value = $urandom;
            CDB_packet_generator[1].Value = $urandom;
            if (CDB_packet_generator[0].valid && if_squash) begin
                CDB_packet_generator[0].take_branch= $urandom%2;
            end 
            else begin
                CDB_packet_generator[0].take_branch= 0;
            end
            if (CDB_packet_generator[1].valid && if_squash) begin
                CDB_packet_generator[1].take_branch= $urandom%2;
            end 
            else begin
                CDB_packet_generator[1].take_branch= 0;
            end
        end
    endfunction //CDB_packet_generator

    function MT_ROB_PACKET [1:0] MT_ROB_packet_generator;
        begin
            MT_ROB_packet_generator[0].RegS1_Tag    = $urandom%32;
            MT_ROB_packet_generator[0].RegS2_Tag    = $urandom%32;
            MT_ROB_packet_generator[0].valid_vector = $urandom%4;
            MT_ROB_packet_generator[1].RegS1_Tag    = $urandom%32;
            MT_ROB_packet_generator[1].RegS2_Tag    = $urandom%32;
            MT_ROB_packet_generator[1].valid_vector = $urandom%4;
        end
    endfunction //MT_ROB_packet_generator

    function DP_PACKET [1:0] DP_packet_generator;
        DP_packet_generator[0] = $urandom;
        DP_packet_generator[1] = $urandom;
        begin
            if (space_s == 0) begin
                DP_packet_generator[0].dp_en         = 0;
                DP_packet_generator[1].dp_en         = 0;
            end
            else if (space_s == 1) begin
                DP_packet_generator[0].dp_en         = $urandom%2;
                DP_packet_generator[1].dp_en         = 0;
            end
            else begin
                DP_packet_generator[0].dp_en         = $urandom%2;
                DP_packet_generator[1].dp_en         = $urandom%2;
            end
            DP_packet_generator[0].dest_reg_idx  = $urandom%32;
            DP_packet_generator[1].dest_reg_idx  = $urandom%32;
        end
    endfunction //DP_packet_generator

    task ROB_simulator;
        input   CDB_PACKET    [1:0] CDB_packet_in;      // Come from Complete stage
        input   DP_PACKET     [1:0] DP_packet_in;       // Come from Dispatch stage to tell the stride of tail pointer
        input   MT_ROB_PACKET [1:0] MT_ROB_packet_in;   // At Dispatch stage, tell Tags (#ROB) for s1 and s2

        integer correct;
        correct = 1;

        if (reset || squash_signal_s) begin
            head_s    = 0;
            tail_s    = 0;
            content_s = 0;
            squash_signal_s = 0;
            space_s = 32;
        end
        else if (enable) begin
            integer unsigned head_origin, head_cp_bit_origin;

            if (space_s == 0 && dp_available != 0 
             || space_s == 1 && dp_available != 1
             || space_s >= 2 && dp_available != 2)correct = 0;
            `ifdef DEBUG
            if ( !(space_s == space && head_s == head && tail_s == tail) ) correct = 0;
            `endif
            if (!correct) begin
                `ifdef DEBUG
                $display("Time:%5.0f head_s:%d head:%d tail_s:%d tail:%d space_s:%d space:%d dp:%d", $time, head_s, head, tail_s, tail, space_s, space, dp_available);
                `endif
                $display("@@@Failed due to space inconsistence");
                $finish;
            end

            // Retire stage
            head_origin = head_s;
            head_cp_bit_origin = content_s[head_s].cp_bit;
            if (content_s[head_s].cp_bit == 1) begin
                if (content_s[head_s].ep_bit == 1) begin
                    squash_signal_s = 1;
                    if (! (
                           RT_packet[0].retire_reg == 0
                        && RT_packet[0].retire_tag == 0
                        && RT_packet[0].valid      == content_s[head_s].cp_bit
                        && squash_signal == squash_signal_s)) correct = 0;
                end else begin
                    squash_signal_s = 0;
                    if ( !(
                           RT_packet[0].retire_reg == content_s[head_s].reg_idx
                        && RT_packet[0].value      == content_s[head_s].value
                        && RT_packet[0].retire_tag == head_s
                        && RT_packet[0].valid      == content_s[head_s].cp_bit
                        ))correct = 0;
                    head_s = (head_s + 1) % 32;
                    space_s = space_s + 1;
                end
                content_s[head_origin].cp_bit = 0;
            end else begin
                squash_signal_s = 0;
                // if (! RT_packet[0] === 0) correct = 0;
            end

            if (!correct) begin
                $display("@@@1st ins failed at retire stage");
                `ifdef DEBUG
                $display("Time:%4.0f head:%1d cp_bit_s:%1b cp_bit:%b ep_bit_s:%b ep_bit:%b squash_signal:%b squash_signal_s:%1b", $time, 
                head_origin, head_cp_bit_origin, {content[head_origin].cp_bit}, 
                {content_s[head_origin].ep_bit}, {content[head_origin].ep_bit},
                squash_signal, squash_signal_s);
                `endif
                $finish;
            end

            head_cp_bit_origin = content_s[head_s].cp_bit;
            if (head_s == (head_origin + 1)%32 && content_s[head_s].cp_bit == 1) begin
                if (content_s[head_s].ep_bit || content_s[head_origin].ep_bit) begin
                    squash_signal_s = 1;
                    if (! (
                           RT_packet[1].retire_reg == 0
                        && RT_packet[1].retire_tag == 0
                        && RT_packet[1].valid      == content_s[head_s].cp_bit
                        && squash_signal == squash_signal_s)) correct = 0;
                end else begin
                    squash_signal_s = 0;
                    if ( !(
                        RT_packet[1].retire_reg   == content_s[head_s].reg_idx
                        && RT_packet[1].value == content_s[head_s].value
                        && RT_packet[1].retire_tag   == head_s
                        && RT_packet[1].valid        == content_s[head_s].cp_bit
                        && squash_signal == squash_signal_s)) correct = 0;
                    content_s[head_s].cp_bit = 0;
                    head_s = (head_s + 1) % 32;
                    space_s = space_s + 1;
                end
            end else begin
                if (content_s[head_origin].ep_bit) begin
                    squash_signal_s = 1;
                end
                else begin
                    squash_signal_s = 0;
                end
                if (! squash_signal == squash_signal_s) correct = 0;
            end

            if (!correct) begin
                $display("@@@2nd ins failed at retire stage");
                `ifdef DEBUG
                $display("Time:%4.0f cp_bit_s:%1b cp_bit:%b ep_bit_s:%b ep_bit:%b squash_signal:%b squash_signal_s:%1b", $time, 
                head_cp_bit_origin, {content[head_origin + 1].cp_bit}, 
                {content_s[head_origin + 1].ep_bit}, {content[head_origin + 1].ep_bit},
                squash_signal, squash_signal_s);
                `endif
                $finish;
            end

            // Complete stage
            for(integer unsigned i = 0; i < `CDB_SIZE; i++) begin
                if(CDB_packet_in[i].valid == 1) begin
                    content_s[CDB_packet_in[i].Tag].value = CDB_packet_in[i].Value;
                    content_s[CDB_packet_in[i].Tag].cp_bit = 1'b1;
                    content_s[CDB_packet_in[i].Tag].ep_bit = CDB_packet_in[i].take_branch;
                end
            end

            // Dispatch stage
            if (DP_packet_in[0].dp_en) begin
                if (! (
                ROB_RS_packet[0].Tag == tail_s
                && ROB_MT_packet[0].Tag == tail_s)) correct = 0;
                content_s[tail_s].reg_idx = DP_packet_in[0].dest_reg_idx;
                tail_s = (tail_s + 1) % 32;
                space_s = space_s - 1;
            end
            else begin
                if(! (ROB_RS_packet[0].Tag == 0 && ROB_MT_packet[0].Tag == 0)) correct = 0;
            end

            if (!correct) begin
                $display("@@@1st ins failed at dispatch stage");
                `ifdef DEBUG
                $display("Time:%5.0f tail_s:%2d tail:%d space_s:%2d space:%d dp:%d", $time, tail_s, tail, space_s, space, dp_available);
                for (int i = 0; i < 2; i++) begin
                    $display("ROB_RS_packet[%1d].Tag:%d ROB_MT_packet[%1d].Tag:%d", i, ROB_RS_packet[i].Tag, i, ROB_MT_packet[i].Tag, i);
                end
                `endif
                $finish;
            end

            if (DP_packet_in[0].dp_en && DP_packet_in[1].dp_en) begin
                if (! (
                ROB_RS_packet[1].Tag == tail_s
                && ROB_MT_packet[1].Tag == tail_s)) correct = 0;
                content_s[tail_s].reg_idx = DP_packet_in[1].dest_reg_idx;
                tail_s = (tail_s + 1) % 32;
                space_s = space_s - 1;
            end
            else begin
                if(! (ROB_RS_packet[1].Tag == 0 && ROB_MT_packet[1].Tag == 0)) correct = 0;
            end

            if (!correct) begin
                $display("@@@2nd ins failed at dispatch stage");
                `ifdef DEBUG
                $display("Time:%5.0f tail_s:%2d tail:%d space_s:%2d space:%d dp:%d", $time, tail_s, tail, space_s, space, dp_available);
                for (int i = 0; i < 2; i++) begin
                    $display("ROB_RS_packet[%1d].Tag:%d ROB_MT_packet[%1d].Tag:%d", i, ROB_RS_packet[i].Tag, i, ROB_MT_packet[i].Tag, i);
                end
                `endif
                $finish;
            end
        
            if (MT_ROB_packet_in[0].valid_vector[0] == 1) begin
                if( ! ROB_RS_packet[0].rs1_value == content_s[MT_ROB_packet_in[0].RegS1_Tag].value) correct = 0;
            end
            else begin
                if( ! ROB_RS_packet[0].rs1_value == 0) correct = 0;
            end
            if (MT_ROB_packet_in[0].valid_vector[1] == 1) begin
                if( ! ROB_RS_packet[0].rs2_value == content_s[MT_ROB_packet_in[0].RegS2_Tag].value) correct = 0;
            end
            else begin
                if( ! ROB_RS_packet[0].rs2_value == 0) correct = 0;
            end
            if (MT_ROB_packet_in[1].valid_vector[0] == 1) begin
                if( ! ROB_RS_packet[1].rs1_value == content_s[MT_ROB_packet_in[1].RegS1_Tag].value) correct = 0;
            end
            else begin
                if( ! ROB_RS_packet[1].rs1_value == 0) correct = 0;
            end
            if (MT_ROB_packet_in[1].valid_vector[1] == 1) begin
                if( ! ROB_RS_packet[1].rs2_value == content_s[MT_ROB_packet_in[1].RegS2_Tag].value) correct = 0;
            end
            else begin
                if( ! ROB_RS_packet[1].rs2_value == 0) correct = 0;
            end
            
            if (!correct) begin
                $display("@@@Failed at dispatch stage");
                `ifdef DEBUG
                $display("Time:%5.0f tail_s:%2d tail:%d space_s:%2d space:%d dp:%d", $time, tail_s, tail, space_s, space, dp_available);
                for (int i = 0; i < 2; i++) begin
                    $display("valid_vector:%b ROB_RS_packet[%1d].rs1_value:%d store_value:%d ROB_RS_packet[%1d].rs2_value:%d store_value:%d ", 
                    MT_ROB_packet_in[i].valid_vector,
                    i, ROB_RS_packet[i].rs1_value, content_s[MT_ROB_packet_in[0].RegS1_Tag].value,
                    i, ROB_RS_packet[i].rs2_value, content_s[MT_ROB_packet_in[0].RegS2_Tag].value);
                end
                `endif
                $finish;
            end

            // Structure hazard detection
            assert (space_s <= 32) 
            else begin
                $error("space overflow! dp:%d space_s: %3d", dp_available, space_s);
                $finish;
            end
            
        end
    endtask

    // Setup the clock
    always begin
        #5;
        clock = ~clock;
    end

    // Begin testbench
    initial begin
        // Initialize
		reset = 1'b1;
        clock = 1'b0;
        enable = 1'b1;
        @(negedge clock);
        reset = 1'b0;
        $display("Init finish!");

        // ----------------------------Test Begin----------------------------

        // Full fill ROB
        for (int unsigned i = 0; i < `ROB_SIZE; i++) begin
            DP_packet[0].dest_reg_idx     = $urandom%32;
            DP_packet[0].dp_en            = 1;
            DP_packet[1].dest_reg_idx     = $urandom%32;
            DP_packet[1].dp_en            = 1;
            MT_ROB_packet[0].RegS1_Tag    = $urandom%32;
            MT_ROB_packet[0].RegS2_Tag    = $urandom%32;
            MT_ROB_packet[0].valid_vector = $urandom%4;
            MT_ROB_packet[1].RegS1_Tag    = $urandom%32;
            MT_ROB_packet[1].RegS2_Tag    = $urandom%32;
            MT_ROB_packet[1].valid_vector = $urandom%4;
            CDB_packet[0].Tag   = $urandom%32;
            CDB_packet[0].Value = $urandom;
            CDB_packet[0].valid = 0;
            CDB_packet[0].take_branch= 0;
            CDB_packet[1].Tag   = $urandom%32;
            CDB_packet[1].Value = $urandom;
            CDB_packet[1].valid = 0;
            CDB_packet[1].take_branch= 0;
        end

        // Random test with no squash signal
        for (integer i = 0; i < 3000; i++) begin
            if (squash_signal_s) begin
                CDB_packet = 0;
                MT_ROB_packet = 0;
                DP_packet  = 0;
            end
            else begin
                CDB_packet = CDB_packet_generator(0);
                MT_ROB_packet = MT_ROB_packet_generator();
                DP_packet  = DP_packet_generator();
            end
            @(posedge clock) ROB_simulator(CDB_packet, DP_packet, MT_ROB_packet);

            `ifdef DEBUG
            $display("Time:%4.0f squash:%1d ep_en:%b dp_en:%b cp_en%b rt:%b space:%d space_s:%2d head:%d head_s:%2d tail:%d tail_s:%2d", $time, 
            squash_signal_s, {CDB_packet[1].take_branch, CDB_packet[0].take_branch}, {DP_packet[1].dp_en, DP_packet[0].dp_en}, {CDB_packet[1].valid, CDB_packet[0].valid},
            {RT_packet[1].valid, RT_packet[0].valid}, space, space_s, head, head_s, tail, tail_s);
            `endif
        end

        // Random test with squash signal
        for (integer i = 0; i < 3000; i++) begin
            if (squash_signal_s) begin
                CDB_packet = 0;
                MT_ROB_packet = 0;
                DP_packet  = 0;
            end
            else begin
                CDB_packet = CDB_packet_generator(1);
                MT_ROB_packet = MT_ROB_packet_generator();
                DP_packet  = DP_packet_generator();
            end
            @(posedge clock) ROB_simulator(CDB_packet, DP_packet, MT_ROB_packet);

            `ifdef DEBUG
            $display("Time:%4.0f squash:%1d ep_en:%b dp_en:%b cp_en%b rt:%b space:%d space_s:%2d head:%d head_s:%2d tail:%d tail_s:%2d", $time, 
            squash_signal_s, {CDB_packet[1].take_branch, CDB_packet[0].take_branch}, {DP_packet[1].dp_en, DP_packet[0].dp_en}, {CDB_packet[1].valid, CDB_packet[0].valid},
            {RT_packet[1].valid, RT_packet[0].valid}, space, space_s, head, head_s, tail, tail_s);
            `endif
        end

        $display("@@@Passed");
        $finish;

    end

endmodule