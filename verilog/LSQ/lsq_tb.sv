// `define DEBUG

module testbench;

    //---------------------- input --------------------//
    logic clock, reset, squash;
    // dispatch signals
    DP_PACKET [1:0] dp_packet_in;
    // execute signals
    EX_MEM_PACKET ex_cp_mem_in_ld;
    EX_MEM_PACKET ex_cp_mem_in_st;
    // dcache signals
    DCACHE_LSQ_PACKET dcache_lsq_packet_in;
    // retire signals
    RT_PACKET [1:0] rt_packet_in;
    
    //---------------------- output ------------------//
    // to dispatch
    logic [1:0] dp_available;
    // to RS
    logic [$clog2(`SQ_SIZE)-1:0] tail_pos_1, tail_pos_2;
	logic ld_stall_out, st_stall_out;
    // to complete
    EX_CP_PACKET lsq_cp_packet_out;
    // to dcache
    LSQ_DCACHE_PACKET lsq_dcache_packet_out;
    
    //------------------ debug variables -----------------//
    `ifdef DEBUG
    SQ_ENTRY [`SQ_SIZE-1:0] sq_tbl;
    logic [$clog2(`SQ_SIZE):0] head, head_n, tail, tail_n;
    logic [$clog2(`SQ_SIZE)-1:0] head_idx, tail_idx;
    logic [$clog2(`SQ_SIZE)-1:0] space_available;

    // retire
	logic dcache_ready;
    logic [`XLEN-1:0] retire_addr, retire_value;
    logic [2:0] retire_mem_size;
    logic retire_valid;
	logic [1:0] retire_disable; // to ROB

    // execute packets are valid and requests services
    logic ex_ld_valid, ex_st_valid;

    // load vars  
    logic [`XLEN-1:0] dcache_rd_value;
    logic ld_valid;
    logic [`XLEN-1:0] ld_value;
    logic sq_ld_halt; // stop entire loading until all old store have addr and value
    logic [`XLEN-1:0] sq_ld_value;
    SQ_FOUND_BYTE [3:0] sq_ld_found;
	logic [3:0] ld_valid_byte;

    logic add_flag;
    `endif


    // variables to control testbench random values
    int n_ex_st = 8;
    int n_tag = 0;
    int tmp_flg = 0;
    int n_ex_ld = 0;
    int n_retire = 0;
    int addr_range = 13;
    int test_rob_size = 20;

	`ifdef DEBUG
    // Instance declaration
    lsq lsq_dut(
        .clock(clock),
        .reset(reset),
        .squash(squash),
        .dp_packet_in(dp_packet_in),
        .ex_cp_mem_in_ld(ex_cp_mem_in_ld),
        .ex_cp_mem_in_st(ex_cp_mem_in_st),
        .dcache_lsq_packet_in(dcache_lsq_packet_in),
        .rt_packet_in(rt_packet_in),
        .dp_available(dp_available),
        .tail_pos_1(tail_pos_1),
        .tail_pos_2(tail_pos_2),
        .ld_stall_out(ld_stall_out),
        .lsq_cp_packet_out(lsq_cp_packet_out),
        .lsq_dcache_packet_out(lsq_dcache_packet_out),
		.retire_disable(retire_disable)
        `ifdef DEBUG
        ,
        .sq_tbl(sq_tbl),
        .head(head),
        .head_n(head_n),
        .tail(tail),
        .tail_n(tail_n),
        .head_idx(head_idx),
        .tail_idx(tail_idx),
        .space_available(space_available),
        .retire_addr(retire_addr),
        .retire_value(retire_value),
        .retire_mem_size(retire_mem_size),
        .retire_valid(retire_valid),
		.dcache_ready(dcache_ready),
        .ex_ld_valid(ex_ld_valid),
        .ex_st_valid(ex_st_valid),
        .dcache_rd_value(dcache_rd_value),
        .ld_valid(ld_valid),
        .ld_value(ld_value),
        .sq_ld_halt(sq_ld_halt),
        .sq_ld_value(sq_ld_value),
        .sq_ld_found(sq_ld_found),
        .ld_valid_byte(ld_valid_byte),
        .add_flag(add_flag)
        `endif
    );
	`endif

	`ifndef DEBUG
	// Instance declaration
    lsq lsq_dut(
        .clock(clock),
        .reset(reset),
        .squash(squash),
        .dp_packet_in(dp_packet_in),
        .ex_cp_mem_in_ld(ex_cp_mem_in_ld),
        .ex_cp_mem_in_st(ex_cp_mem_in_st),
        .dcache_lsq_packet_in(dcache_lsq_packet_in),
        .rt_packet_in(rt_packet_in),
        .dp_available(dp_available),
        .tail_pos_1(tail_pos_1),
        .tail_pos_2(tail_pos_2),
        .ld_stall_out(ld_stall_out),
		.st_stall_out(st_stall_out),
        .lsq_cp_packet_out(lsq_cp_packet_out),
        .lsq_dcache_packet_out(lsq_dcache_packet_out),
		.retire_disable(retire_disable)
    );
	`endif


    function DP_PACKET[1:0] DP_packet_generator;
        DP_packet_generator[0] = $urandom;
        DP_packet_generator[1] = $urandom;
        begin
            DP_packet_generator[0].valid = $urandom%2;
            DP_packet_generator[0].wr_mem = $urandom%2;
            
            DP_packet_generator[1].valid = $urandom%2;
            DP_packet_generator[1].wr_mem = $urandom%2;

			// make sure dispatch insn number <= dp_available
			if(dp_available == 0) begin
				DP_packet_generator[0].valid = 0;
				DP_packet_generator[1].valid = 0;
			end
			else if(dp_available == 1) begin
				tmp_flg = $urandom % 2;
				if(dp_packet_in[0].valid == 1 && dp_packet_in[1].valid) begin
					if(tmp_flg) begin
						dp_packet_in[0].valid = 0;
					end
					else begin
						dp_packet_in[1].valid = 1;
					end
				end
			end
        end
    endfunction

    function EX_MEM_PACKET EX_MEM_packet_st_generator;
        EX_MEM_packet_st_generator = 0;
        begin
            //int len = tail_idx - head_idx;
            //// completely full
            //if(len == 0 && dp_available == 0) begin
            //    len = `SQ_SIZE;
            //end
            //if(tail_idx < head_idx) begin
            //    len = `SQ_SIZE - head_idx + tail_idx;
            //end
            EX_MEM_packet_st_generator.valid = $urandom;
            EX_MEM_packet_st_generator.wr_mem = $urandom%2;
            //EX_MEM_packet_st_generator.sq_pos = $urandom % len + head_idx;
			EX_MEM_packet_st_generator.sq_pos = $urandom;
            EX_MEM_packet_st_generator.alu_result = $urandom % addr_range;
            EX_MEM_packet_st_generator.rs2_value = $urandom;
            EX_MEM_packet_st_generator.mem_size = $urandom % 3;
            if(EX_MEM_packet_st_generator.mem_size == 1) begin
                EX_MEM_packet_st_generator.alu_result = EX_MEM_packet_st_generator.alu_result - EX_MEM_packet_st_generator.alu_result % 2;  
            end
            else if(EX_MEM_packet_st_generator.mem_size == 2) begin
                EX_MEM_packet_st_generator.alu_result = EX_MEM_packet_st_generator.alu_result - EX_MEM_packet_st_generator.alu_result % 4;  
            end
            EX_MEM_packet_st_generator.Tag = $urandom % test_rob_size;
        end
    endfunction

    function EX_MEM_PACKET EX_MEM_packet_ld_generator;
        EX_MEM_packet_ld_generator = 0;
        begin
            //int len = tail_idx - head_idx;
            //// completely full
            //if(len == 0 && dp_available == 0) begin
            //    len = `SQ_SIZE;
            //end
            //if(tail_idx < head_idx) begin
            //    len = `SQ_SIZE - head_idx + tail_idx;
            //end
            EX_MEM_packet_ld_generator.valid = $urandom;
            EX_MEM_packet_ld_generator.rd_mem = $urandom%2;
			EX_MEM_packet_ld_generator.sq_pos = $urandom;
            //EX_MEM_packet_ld_generator.sq_pos = $urandom % len + head_idx;
            EX_MEM_packet_ld_generator.alu_result = $urandom % addr_range;
            EX_MEM_packet_ld_generator.rs2_value = $urandom;
            EX_MEM_packet_ld_generator.mem_size = $urandom % 3;
            if(EX_MEM_packet_ld_generator.mem_size == 1) begin
                EX_MEM_packet_ld_generator.alu_result = EX_MEM_packet_ld_generator.alu_result - EX_MEM_packet_ld_generator.alu_result % 2;  
            end
            else if(EX_MEM_packet_ld_generator.mem_size == 2) begin
                EX_MEM_packet_ld_generator.alu_result = EX_MEM_packet_ld_generator.alu_result - EX_MEM_packet_ld_generator.alu_result % 4;  
            end
            EX_MEM_packet_ld_generator.Tag = $urandom % test_rob_size;
        end
    endfunction

    function RT_PACKET[1:0] RT_packet_generator;
        RT_packet_generator[0] = $urandom;
        RT_packet_generator[1] = $urandom;
        begin
            RT_packet_generator[0].valid = $urandom%2;
            RT_packet_generator[0].retire_tag = $urandom % test_rob_size;
            
            RT_packet_generator[1].valid = $urandom%2;
            RT_packet_generator[1].retire_tag = $urandom % test_rob_size;
        end
    endfunction

    function DCACHE_LSQ_PACKET DCACHE_LSQ_packet_generator;
        DCACHE_LSQ_packet_generator = 0;
        begin
            DCACHE_LSQ_packet_generator.dcache_valid = $random%2;
            DCACHE_LSQ_packet_generator.rd_data = $random;
        end
    endfunction

    // only output contents and positions
    task LSQ_simulator;
        $display("Time:%4.0f", $time);
        //// --------------------------- SHOW INPUTS ------------------------- //
        //    // show dp_packet
        //    $display("dp_packet_in:");
        //    for(int i = 0; i < 2; i++) begin
        //        $display("\t valid:%1d wr_mem:%1d", dp_packet_in[i].valid, dp_packet_in[i].wr_mem);
        //    end
        //    // show ex_cp_mem_in_ld
        //    $display("ex_cp_mem_in_ld: valid:%1d rd_mem:%1d sq_pos:0x%h alu_result:0x%h mem_size:0x%h tag:0x%h", ex_cp_mem_in_ld.valid, ex_cp_mem_in_ld.rd_mem, ex_cp_mem_in_ld.sq_pos, ex_cp_mem_in_ld.alu_result, ex_cp_mem_in_ld.mem_size, ex_cp_mem_in_ld.Tag);
        //    // show ex_cp_mem_in_st
        //    $display("ex_cp_mem_in_st: valid:%1d wr_mem:%1d sq_pos:0x%h alu_result:0x%h rs2_value:0x%h mem_size:0x%h tag:0x%h", ex_cp_mem_in_st.valid, ex_cp_mem_in_st.wr_mem, ex_cp_mem_in_st.sq_pos, ex_cp_mem_in_st.alu_result, ex_cp_mem_in_st.rs2_value, ex_cp_mem_in_st.mem_size, ex_cp_mem_in_st.Tag);
        //    // show dcahche
        //    $display("dcache_lsq_packet_in: valid:0x%h data:0x%h", dcache_lsq_packet_in.dcache_valid, dcache_lsq_packet_in.rd_data);
        //    // show rt_packet
        //    $display("rt_packet:");
        //    for(int i = 0; i < 2; i++) begin
        //        $display("\t valid:%1d retire_tag:0x%h", rt_packet_in[i].valid, rt_packet_in[i].retire_tag);
        //    end

        //// -------------------------- SHOW OUTPUTS ---------------------------- //
        //    $display("dp_available:0x%h tail_pos_1:0x%h tail_pos_2:0x%h ld_stall_out:0x%h", dp_available, tail_pos_1, tail_pos_2, ld_stall_out);
            
        //    $display("lsq_cp_packet_out: Value:0x%h NPC:0x%h dest_reg_idx:0x%h halt:0x%h illegal:0x%h done:0x%h valid:0x%h Tag:0x%h", lsq_cp_packet_out.Value, lsq_cp_packet_out.NPC, lsq_cp_packet_out.dest_reg_idx, lsq_cp_packet_out.halt, lsq_cp_packet_out.illegal, lsq_cp_packet_out.done, lsq_cp_packet_out.valid, lsq_cp_packet_out.Tag);

        //    $display("lsq_dcache_packet_out: addr:0x%h wr_data:0x%h wr_en:0x%h rd_en:0x%h mem_size:0x%h", lsq_dcache_packet_out.addr, lsq_dcache_packet_out.wr_data, lsq_dcache_packet_out.wr_en, lsq_dcache_packet_out.rd_en, lsq_dcache_packet_out.mem_size);

		//	$display("retire_disable: %2b", retire_disable);
        
        //// -------------------------- SHOW DEBUG VARS --------------------------- //
        //    for(int i = 0; i < 4; i++) begin
        //        $display("sq_ld_found[%1d]: found:%1b found_upper:%1b found_pos:0x%h", i, sq_ld_found[i].found, sq_ld_found[i].found_upper, sq_ld_found[i].found_pos);
        //    end
        //    $display("sq_ld_halt:0x%h sq_ld_value:0x%h", sq_ld_halt, sq_ld_value);
        //    $display("ld_valid_byte: %4b", ld_valid_byte);
        //    $display("ld_valid:0x%h ld_stall_out:0x%h ld_value:0x%h", ld_valid, ld_stall_out, ld_value);
        //    $display("retire_valid:0x%h retire_mem_size:0x%h retire_addr:0x%h retire_value:0x%h", retire_valid, retire_mem_size, retire_addr, retire_value);
        //    for(int i = 0; i < `SQ_SIZE; i++) begin
        //        $display("0x%h | valid: %1d | word_addr: 0x%h | res_addr: %1d | value: 0x%h | mem_size: 0x%h | tag: 0x%h", 
        //        i, sq_tbl[i].valid, sq_tbl[i].word_addr * 4, sq_tbl[i].res_addr, sq_tbl[i].value,
        //        sq_tbl[i].mem_size, sq_tbl[i].ROB_tag);
        //    end
        //    $display("head:0x%h tail:0x%h dp_available:0x%h", head_idx, tail_idx, dp_available);

        $display("-----------------------------------------------");
    //
        // // test dispatch, tail
        // for(int i = 0; i < 2; i++) begin
        //     if(dp_packet_in[i].valid && dp_packet_in[i].wr_mem) begin
        //         tail += 1;
        //     end
        // end
        // correct_tmp = tail == tail_idx;
        // if(!correct_tmp) begin
        //     $display("@@@1st ins failed at dispatch stage");
        //     $display("expected tail: %d, actual tail: %d", tail, tail_idx);
        // end

        // correct = !correct_tmp ? correct_tmp : correct;

        // // test execute store
        // if(ex_cp_mem_in.valid && ex_cp_mem_in.wr_mem) begin
        //     int pos = ex_cp_mem_in.sq_pos;
        //     correct_tmp = 1;
        //     // valid pos inside sq_tbl
        //     if(pos >= head_idx || pos < tail_idx) begin
        //         correct_tmp = sq_tbl[pos].addr == ex_cp_mem_in.alu_result && 
        //                 sq_tbl[pos].addr == ex_cp_mem_in.alu_result &&
        //                 sq_tbl[pos].value == ex_cp_mem_in.rs2_value &&
        //                 sq_tbl[pos].mem_size == ex_cp_mem_in.mem_size &&
        //                 sq_tbl[pos].ROB_tag == ex_cp_mem_in.Tag &&
        //                 sq_tbl[pos].valid == 1'b1
        //     end
        //     else begin
        //         $display("@@@Invalid pos found in execute store packet");
        //         $display("head: %d, tail: %d, pos: %d", head_idx, tail_idx, pos);
        //     end
        //     if(!correct_tmp) begin
        //         $display("@@@1st ins failed at execute store stage");
        //     end
        // end

        // correct = !correct_tmp ? correct_tmp : correct;

        // // test execute load
        // if(ex_cp_mem_in.valid && ex_cp_mem_in.rd_mem) begin
        //     int pos = ex_cp_mem_in.sq_pos;
        //     correct_tmp = 1;
        //     int found_it = 0;
        //     // tail top, head down
        //     if(tail_idx <= head_idx) begin
        //         if(pos < tail_idx) begin
        //             // top first
        //             for(int i = pos-1; i >= 0; i--) begin
        //                 if(!sq_tbl[i].valid) begin
        //                     sq_ld_halt = 1'b1;
        //                     sq_ld_valid = 1'b0;
        //                     break;
        //                 end
        //                 else if(sq_tbl[i].addr == ex_cp_mem_in.alu_result) begin
        //                     correct_tmp = sq_ld_valid == 1'b1 && ld_value == sq_tbl[i].value;
        //                     found_it = 1;
        //                     break;
        //                 end
        //             end
        //             // bottom then
        //             if(!found_it)
        //             for(int i = pos-1; i >= head_idx; i--) begin
        //             end
        //         end
        //         // only bottom half to consider
        //         else if(pos >= head_idx) begin
        //             for(int i = pos-1; i >= head_idx; i--) begin
        //                 if(!sq_tbl[i].valid) begin
        //                     correct_tmp = sq_ld_halt == 1'b1 && sq_ld_valid == 1'b0;
        //                     break;
        //                 end
        //                 else if(sq_tbl[i].addr == ex_cp_mem_in.alu_result) begin
        //                     correct_tmp = sq_ld_valid == 1'b1 && ld_value == sq_tbl[i].value;
        //                     found_it = 1;
        //                     break;
        //                 end
        //             end
        //         end
        //         else begin
        //             $display("@@@Invalid pos found in execute load packet");
        //             $display("head: %d, tail: %d, pos: %d", head_idx, tail_idx, pos);
        //         end
        //     end
        //     // tail down, head up
        //     else if(tail_idx > head_idx) begin
            
        //     end
        // end
    endtask

    // Setup the clock
    always begin
        #20;
        clock = ~clock;
    end

    // Begin testbench
    initial begin
        // Initialize
		dp_packet_in = 0;
        ex_cp_mem_in_ld = 0;
        ex_cp_mem_in_st = 0;
		dcache_lsq_packet_in = 0;
		rt_packet_in = 0;
		
		reset = 1'b1;
        clock = 1'b0;
        squash = 1'b0;
        @(posedge clock);
        @(negedge clock);
        reset = 1'b0;
        $display("Init finish!");

        // ----------------------------Test Begin---------------------------- //
        @(posedge clock);
        @(negedge clock) LSQ_simulator();

        // ----------------------- Test Simple Load and whatnot Individually --------------------------- //
            //  // test dispatching to full
            //  $display("@@@Test dispatch to full");
            //  while(dp_available > 0) begin
            //      dp_packet_in = DP_packet_generator();
            //      tmp_flg = $urandom % 2;
            //      if(tmp_flg) begin
            //          dp_packet_in[0].valid = 1;
            //          dp_packet_in[1].valid = 0;
            //      end 
            //      else begin
            //          dp_packet_in[0].valid = 0;
            //          dp_packet_in[1].valid = 1;
            //      end
            //      ex_cp_mem_in_ld = 0;
            //      ex_cp_mem_in_st = 0;
            //      dcache_rd_value = $urandom;
            //      dcache_rd_ready = $urandom % 2;
            //      rt_packet_in = 0;
            //      @(posedge clock);
            //      @(negedge clock) LSQ_simulator(dp_packet_in, ex_cp_mem_in_ld, ex_cp_mem_in_st, dcache_rd_value, dcache_rd_ready, rt_packet_in);
            //  end

            //  // test execute store
            //  // fill first few entries
            //  $display("@@@Test execute store.");
            //  n_ex_st = 8;
            //  n_tag = 0;
            //  for(int i = 0; i < n_ex_st; i++) begin
            //      dp_packet_in = 0;
            //      ex_cp_mem_in_ld = 0;
            //      ex_cp_mem_in_st = EX_MEM_packet_generator();
            //     // debug ximin
            //      ex_cp_mem_in_st.rs2_value = $random;
            //      ex_cp_mem_in_st.valid = 1;
            //      ex_cp_mem_in_st.wr_mem = 1;
            //      ex_cp_mem_in_st.rd_mem = 0;
            //      ex_cp_mem_in_st.sq_pos = i;
            //      ex_cp_mem_in_st.Tag = n_tag;
            //      n_tag += 1;

            //     ex_cp_mem_in_st.alu_result = $urandom % addr_range;
            //     if(ex_cp_mem_in_st.mem_size == 1) begin
            //         ex_cp_mem_in_st.alu_result = ex_cp_mem_in_st.alu_result - ex_cp_mem_in_st.alu_result % 2;  
            //     end
            //     else if(ex_cp_mem_in_st.mem_size == 2) begin
            //         ex_cp_mem_in_st.alu_result = ex_cp_mem_in_st.alu_result - ex_cp_mem_in_st.alu_result % 4;  
            //     end

            //     dcache_rd_value = 0;
            //     //  dcache_rd_value = $urandom;
            //      dcache_rd_ready = $urandom % 2;
            //      rt_packet_in = 0;
            //      @(posedge clock);
            //      @(negedge clock) LSQ_simulator(dp_packet_in, ex_cp_mem_in_ld, ex_cp_mem_in_st, 
            //      dcache_rd_value, dcache_rd_ready, rt_packet_in);
            //  end

            //  // test execute load
            //  $display("@@@Test execute load.");
            //  n_ex_ld = 10;
            //  for(int i = 0; i < n_ex_ld; i++) begin
            //      dp_packet_in = 0;

            //      ex_cp_mem_in_st = 0;
            //      ex_cp_mem_in_ld = EX_MEM_packet_generator();
            //      ex_cp_mem_in_ld.valid = 1;
            //      ex_cp_mem_in_ld.wr_mem = 0;
            //      ex_cp_mem_in_ld.rd_mem = ~ld_stall_out;
            //     //  ximin debug
            //      ex_cp_mem_in_ld.sq_pos = $urandom;

            //     ex_cp_mem_in_ld.alu_result = $urandom % addr_range;
            //     if(ex_cp_mem_in_ld.mem_size == 1) begin
            //         ex_cp_mem_in_ld.alu_result = ex_cp_mem_in_ld.alu_result - ex_cp_mem_in_ld.alu_result % 2;  
            //     end
            //     else if(ex_cp_mem_in_ld.mem_size == 2) begin
            //         ex_cp_mem_in_ld.alu_result = ex_cp_mem_in_ld.alu_result - ex_cp_mem_in_ld.alu_result % 4;  
            //     end
                
            //      dcache_rd_value = $urandom;
            //      dcache_rd_ready = $urandom % 2;
            //      rt_packet_in = 0;
            //      @(posedge clock);
            //      @(negedge clock) LSQ_simulator(dp_packet_in, ex_cp_mem_in_ld, ex_cp_mem_in_st, 
            //      dcache_rd_value, dcache_rd_ready, rt_packet_in);
            //  end

            //  // test retire
            //  $display("@@@Test retire.");
            //  n_retire = 10;
            //  for(int i = 0; i < n_retire; i++) begin
            //      dp_packet_in = 0;
            //      ex_cp_mem_in_ld = 0;
            //      ex_cp_mem_in_st = 0;
            //      dcache_rd_value = $urandom;
            //      dcache_rd_ready = $urandom % 2;
        
            //      rt_packet_in = RT_packet_generator();
            //      tmp_flg = $urandom%2;
            //      rt_packet_in[tmp_flg].valid = 1;
            //      rt_packet_in[tmp_flg].retire_tag = i;

            //      @(posedge clock);
            //      @(negedge clock) LSQ_simulator(dp_packet_in, ex_cp_mem_in_ld, ex_cp_mem_in_st, 
            //      dcache_rd_value, dcache_rd_ready, rt_packet_in);
            //  end

            //  // 2nd round - test dispatch
            //  $display("@@@Test 2nd dispatch to full");
            //  while(dp_available > 0) begin
            //      dp_packet_in = DP_packet_generator();
            //      tmp_flg = $urandom % 2;
            //      if(tmp_flg) begin
            //          dp_packet_in[0].valid = 1;
            //          dp_packet_in[1].valid = 0;
            //      end 
            //      else begin
            //          dp_packet_in[0].valid = 0;
            //          dp_packet_in[1].valid = 1;
            //      end
            //      ex_cp_mem_in_ld = 0;
            //      ex_cp_mem_in_st = 0;
            //      dcache_rd_value = $urandom;
            //      dcache_rd_ready = $urandom % 2;
            //      rt_packet_in = 0;
            //      @(posedge clock);
            //      @(negedge clock) LSQ_simulator(dp_packet_in, ex_cp_mem_in_ld, ex_cp_mem_in_st, 
            //      dcache_rd_value, dcache_rd_ready, rt_packet_in);
            //  end

            //  // 2nd round - test execute store
            //  $display("@@@Test 2nd execute store.");
            //  for(int i = 0; i < n_ex_st; i++) begin
            //      dp_packet_in = 0;
            //      ex_cp_mem_in_ld = 0;
            //      ex_cp_mem_in_st = EX_MEM_packet_generator();
            //      // debug ximin
            //      ex_cp_mem_in_st.rs2_value = $random;
            //      ex_cp_mem_in_st.valid = 1;
            //      ex_cp_mem_in_st.wr_mem = 1;
            //      ex_cp_mem_in_st.rd_mem = 0;
            //      ex_cp_mem_in_st.sq_pos = i + n_ex_st;
            //      ex_cp_mem_in_st.Tag = n_tag;
            //      n_tag += 1;
            //     ex_cp_mem_in_st.alu_result = $urandom % addr_range;
            //     if(ex_cp_mem_in_st.mem_size == 1) begin
            //         ex_cp_mem_in_st.alu_result = ex_cp_mem_in_st.alu_result - ex_cp_mem_in_st.alu_result % 2;  
            //     end
            //     else if(ex_cp_mem_in_st.mem_size == 2) begin
            //         ex_cp_mem_in_st.alu_result = ex_cp_mem_in_st.alu_result - ex_cp_mem_in_st.alu_result % 4;  
            //     end

            //      dcache_rd_value = 0;
            //     //  dcache_rd_value = $urandom;
            //      dcache_rd_ready = $urandom % 2;
            //      rt_packet_in = 0;
            //      @(posedge clock);
            //      @(negedge clock) LSQ_simulator(dp_packet_in, ex_cp_mem_in_ld, ex_cp_mem_in_st, 
            //      dcache_rd_value, dcache_rd_ready, rt_packet_in);
            //  end

            //  // 2nd ronud - test execute load
            //  $display("@@@Test 2nd execute load.");
            //  for(int i = 0; i < n_ex_ld; i++) begin
            //      dp_packet_in = 0;

            //      ex_cp_mem_in_st = 0;
            //      ex_cp_mem_in_ld = EX_MEM_packet_generator();
            //      ex_cp_mem_in_ld.valid = 1;
            //      ex_cp_mem_in_ld.wr_mem = 0;
            //      ex_cp_mem_in_ld.rd_mem = ~ld_stall_out;
            //      //  ximin debug
            //      ex_cp_mem_in_ld.sq_pos = $urandom;
                
            //     ex_cp_mem_in_ld.alu_result = $urandom % addr_range;
            //     if(ex_cp_mem_in_ld.mem_size == 1) begin
            //         ex_cp_mem_in_ld.alu_result = ex_cp_mem_in_ld.alu_result - ex_cp_mem_in_ld.alu_result % 2;  
            //     end
            //     else if(ex_cp_mem_in_ld.mem_size == 2) begin
            //         ex_cp_mem_in_ld.alu_result = ex_cp_mem_in_ld.alu_result - ex_cp_mem_in_ld.alu_result % 4;  
            //     end
                
            //      dcache_rd_value = $urandom;
            //      dcache_rd_ready = $urandom % 2;
            //      rt_packet_in = 0;
            //      @(posedge clock);
            //      @(negedge clock) LSQ_simulator(dp_packet_in, ex_cp_mem_in_ld, ex_cp_mem_in_st, 
            //      dcache_rd_value, dcache_rd_ready, rt_packet_in);
            //  end

            // // 2nd round - test retire
            // // $display("@@@Test 2nd retire.");


        // ----------------------- Test signals and packets correctness ---------------------------- //
            $display("@@@Test signals and packets");
            // test dispatching to full
            $display("@@@Test dispatch to full");
            while(dp_available > 0) begin
                dp_packet_in = DP_packet_generator();
                // make sure dispatch insn number <= dp_available
                if(dp_available == 1) begin
                    tmp_flg = $urandom % 2;
                    if(dp_packet_in[0].valid == 1 && dp_packet_in[1].valid) begin
                        if(tmp_flg) begin
                            dp_packet_in[0].valid = 0;
                        end
                        else begin
                            dp_packet_in[1].valid = 1;
                        end
                    end
                end
                dcache_lsq_packet_in = DCACHE_LSQ_packet_generator();
                ex_cp_mem_in_ld = EX_MEM_packet_ld_generator();
                ex_cp_mem_in_st = EX_MEM_packet_st_generator();
                rt_packet_in = 0;
                @(posedge clock);
                @(negedge clock) LSQ_simulator();
                // @(posedge clock) LSQ_simulator();
            end

            // test execute store
            $display("@@@execute store to full.");
            n_ex_st = 16;
            n_tag = 0;
            for(int i = 0; i < n_ex_st; i++) begin
                ex_cp_mem_in_st = EX_MEM_packet_st_generator();
                ex_cp_mem_in_st.valid = 1;
                ex_cp_mem_in_st.wr_mem = 1;
                ex_cp_mem_in_st.rd_mem = 0;
                ex_cp_mem_in_st.sq_pos = i;
                if(ex_cp_mem_in_st.mem_size == 1) begin
                    ex_cp_mem_in_st.alu_result = ex_cp_mem_in_st.alu_result - ex_cp_mem_in_st.alu_result % 2;  
                end
                else if(ex_cp_mem_in_st.mem_size == 2) begin
                    ex_cp_mem_in_st.alu_result = ex_cp_mem_in_st.alu_result - ex_cp_mem_in_st.alu_result % 4;  
                end
                dp_packet_in = DP_packet_generator();
                dcache_lsq_packet_in = DCACHE_LSQ_packet_generator();
                ex_cp_mem_in_ld = EX_MEM_packet_ld_generator();
                rt_packet_in = 0;
                @(posedge clock);
                @(negedge clock) LSQ_simulator();
                // @(posedge clock) LSQ_simulator();
            end

            // test all random
            $display("@@@Test all random.");
            n_ex_st = 16;
            n_tag = 0;
            for(int i = 0; i < n_ex_st; i++) begin
                ex_cp_mem_in_st = EX_MEM_packet_st_generator();
                if(ex_cp_mem_in_st.mem_size == 1) begin
                    ex_cp_mem_in_st.alu_result = ex_cp_mem_in_st.alu_result - ex_cp_mem_in_st.alu_result % 2;  
                end
                else if(ex_cp_mem_in_st.mem_size == 2) begin
                    ex_cp_mem_in_st.alu_result = ex_cp_mem_in_st.alu_result - ex_cp_mem_in_st.alu_result % 4;  
                end
                dp_packet_in = DP_packet_generator();
                dcache_lsq_packet_in = DCACHE_LSQ_packet_generator();
                ex_cp_mem_in_ld = EX_MEM_packet_ld_generator();
                rt_packet_in = 0;
                @(posedge clock);
                @(negedge clock) LSQ_simulator();
                // @(posedge clock) LSQ_simulator();
            end

        $display("@@@Passed");
        $finish;

    end

endmodule
