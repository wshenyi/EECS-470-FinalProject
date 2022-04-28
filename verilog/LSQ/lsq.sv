// `define DEBUG

// TODO: change to match DCACHE_PLANB_IN_PACKET and DCACHE_PLANB_OUT_PACKET
// TODO: add st_stall_out to tell ISSUE to stop new store instruction 
// TODO: add priority_state to determine retire > load or load > retire
// TODO: add ld_need_dcache to indicate whether loading from dcache is needed; determines lsq_dcache_packet_out.lsq_is_requesting
// TODO: add dcache_rd_ready, dcache_retire_ready; to indicate whether dcache_lsq_packet_in.value is rd_value or something else // done
module lsq(
    input clock, reset, squash,
    // dispatch signals
    input DP_PACKET [1:0] dp_packet_in,
    // execute signals
    input EX_MEM_PACKET ex_cp_mem_in_ld,
    input EX_MEM_PACKET ex_cp_mem_in_st,
    // dcache signals
    // ximin debug
    input DCACHE_PLANB_OUT_PACKET dcache_lsq_packet_in,
    // retire signals
    input RT_PACKET [1:0] rt_packet_in,
    

    // to dispatch
    output logic [1:0] dp_available,
    // to RS
    output logic [$clog2(`SQ_SIZE)-1:0] tail_pos_1, tail_pos_2,
	output logic ld_stall_out, st_stall_out,
    // to complete
    output EX_CP_PACKET lsq_cp_packet_out,
    // to dcache
    output DCACHE_PLANB_IN_PACKET lsq_dcache_packet_out,
	// which retire packet fails to retire (same order as the retire_packet)
	// failed = 1, success = 0
    // to ROB
	output logic [1:0] retire_disable

    `ifdef DEBUG
		,
		output SQ_ENTRY [`SQ_SIZE-1:0] sq_tbl,
		output logic [$clog2(`SQ_SIZE):0] head, head_n, tail, tail_n,
		output logic [$clog2(`SQ_SIZE)-1:0] head_idx, tail_idx,
		output logic [$clog2(`SQ_SIZE)-1:0] space_available,

		// retire
		output logic [`XLEN-1:0] retire_addr, retire_value,
		output logic [2:0] retire_mem_size,
		output logic retire_valid,

		// execute packets are valid and requests services
		output logic ex_ld_valid, ex_st_valid,

		// load vars  
		output logic [`XLEN-1:0] dcache_rd_value,
		output logic dcache_ready, dcache_rd_ready, dcache_retire_ready,
		output logic ld_valid,
		output logic [`XLEN-1:0] ld_value,
		output logic sq_ld_halt, // stop entire loading until all old store have addr and value
		output logic [`XLEN-1:0] sq_ld_value,
		output SQ_FOUND_BYTE [3:0] sq_ld_found,
		output logic [3:0] ld_valid_byte,

		output logic add_flag,
		// priority_state = 0 => retire > load, load > store
		// priority_state = 1 => load > retire, load > store
		output logic priority_state, priority_state_n,
		// ld_need_dcache indicates whether load can be completed without dcache_load
		output logic ld_need_dcache
    `endif
);

    `ifndef DEBUG
        SQ_ENTRY [`SQ_SIZE-1:0] sq_tbl;
        logic [$clog2(`SQ_SIZE):0] head, head_n, tail, tail_n;
        logic [$clog2(`SQ_SIZE)-1:0] head_idx, tail_idx;
        logic [$clog2(`SQ_SIZE)-1:0] space_available;

        // retire
        logic [`XLEN-1:0] retire_addr, retire_value;
        logic [2:0] retire_mem_size;
        logic retire_valid;

        // execute packets are valid and requests services
        logic ex_ld_valid, ex_st_valid;

        // load vars  
        logic [`XLEN-1:0] dcache_rd_value;
        logic dcache_ready, dcache_rd_ready, dcache_retire_ready;
        logic ld_valid;
        logic [`XLEN-1:0] ld_value;
        logic sq_ld_halt; // stop entire loading until all old store have addr and value
        logic [`XLEN-1:0] sq_ld_value;
        SQ_FOUND_BYTE [3:0] sq_ld_found;
        logic [3:0] ld_valid_byte;

        logic add_flag;
        // priority_state = 0 => retire > load, load > store
        // priority_state = 1 => load > retire, load > store
        logic priority_state, priority_state_n;
        logic ld_need_dcache;
    `endif

    // decode dcache_lsq_packet_in to rd_ready and rd_value
    always_comb begin
        dcache_ready = dcache_lsq_packet_in.completed;
        dcache_rd_value = dcache_lsq_packet_in.value;
    end

    assign head_idx = head[$clog2(`SQ_SIZE)-1:0];
    assign tail_idx = tail[$clog2(`SQ_SIZE)-1:0];
    assign tail_pos_1 = tail_idx;

    assign ex_ld_valid = ex_cp_mem_in_ld.valid & ex_cp_mem_in_ld.rd_mem;
    assign ex_st_valid = ex_cp_mem_in_st.valid & ex_cp_mem_in_st.wr_mem;

    // for dispatch new insns check number of store insns to add
    always_comb begin
        tail_n = tail;
        add_flag = 0;
        tail_pos_2 = tail_idx;
        if(dp_packet_in[0].valid && dp_packet_in[0].wr_mem) begin
            tail_pos_2 = tail_idx + 1;
        end
        for(int unsigned i = 0; i < 2; i++) begin
           if(dp_packet_in[i].valid && dp_packet_in[i].wr_mem) begin
               if(!add_flag) begin
                   tail_n = tail + 1;
                   add_flag = 1;
               end
               else begin
                   tail_n = tail + 2;
               end
           end
        end
    end

	logic [$clog2(`SQ_SIZE)-1:0] head_idx_plus_one;
	always_comb begin
		if(head_idx == 3'h7) begin
			head_idx_plus_one = 0;
		end
		else begin
			head_idx_plus_one = head_idx + 1;
		end
	end
	//assign head_idx_plus_one = head_idx + 1;

    // for retire, output to dcache
    always_comb begin
        // retire is valid when there is a match
        // retire_valid do not check dcache_ready to avoid loop
        retire_valid = 0;
        retire_addr = {sq_tbl[head_idx].word_addr, sq_tbl[head_idx].res_addr};
		retire_value = sq_tbl[head_idx].value;
		retire_mem_size = sq_tbl[head_idx].mem_size;
        head_n = head;
		retire_disable = 0;
        if(rt_packet_in[0].valid && rt_packet_in[0].retire_tag == sq_tbl[head_idx].ROB_tag && sq_tbl[head_idx].valid) begin
            retire_valid = 1;
            if(dcache_retire_ready) begin
                head_n = head + 1;
            end
            // first retire valid:
            // 1. dcache_retire_ready + second retire another store => second fail
            // 2. dcache_retire_ready + second retire not store => all pass
            // 3. dcache_retire not ready => first and second retire fail
            if(!dcache_retire_ready) begin
                retire_disable = 2'b11;
            end
            if(rt_packet_in[1].valid && sq_tbl[head_idx_plus_one].valid && rt_packet_in[1].retire_tag == sq_tbl[head_idx_plus_one].ROB_tag) begin
                retire_disable[1] = 1;
            end
        end
        else if(rt_packet_in[1].valid && rt_packet_in[1].retire_tag == sq_tbl[head_idx].ROB_tag && sq_tbl[head_idx].valid) begin
            retire_valid = 1;
            if(dcache_retire_ready) begin
                head_n = head + 1;
            end
            // second retire valid:
            // 1. dcache_retire_ready => no retire miss
            // 2. dcache_retire not ready => second retire miss
            if(!dcache_retire_ready) begin
                retire_disable[1] = 1;
            end
        end
    end

    // check if dcache_ready is for retire or load
    always_comb begin
        dcache_retire_ready = 0;
        dcache_rd_ready = 0;
        if(dcache_ready) begin
            // retire > load
            if(!priority_state) begin
                if(retire_valid) begin
                    dcache_retire_ready = 1;
                end
                else if(ex_ld_valid) begin
                    dcache_rd_ready = 1;
                end
            end
            // load > retire
            else begin
                if(ex_ld_valid) begin
                    dcache_rd_ready = 1;
                end
                else if(retire_valid) begin
                    dcache_retire_ready = 1;
                end
            end
        end
    end


    //////////////// for load /////////////
    logic [1:0] tmp_offset;
	logic [$clog2(`SQ_SIZE)-1:0] sq_pos_minus_one;
	// temporary logic for representing unsigned integer i in the following block
	logic [$clog2(`XLEN)-1:0] byte_addr_i;

    // get value from sq_tbl
    always_comb begin
        sq_ld_value = 0;
        sq_ld_halt = 0;
        sq_ld_found = 0;
		byte_addr_i = 0;
		sq_pos_minus_one = 0;
        // when not storing and valid loading
        if(ex_ld_valid) begin
            for(int unsigned i = 0; i < `SQ_SIZE; i++) begin
                // head before tail
                if(head[$clog2(`SQ_SIZE)] == tail[$clog2(`SQ_SIZE)]) begin
                    if(i >= head_idx && i < tail_idx && i < ex_cp_mem_in_ld.sq_pos) begin
                        if(sq_tbl[i].valid == 1'b0) begin
                            sq_ld_halt = 1;
                        end
                        else if(sq_tbl[i].word_addr == ex_cp_mem_in_ld.alu_result[`XLEN-1:2] && !sq_ld_halt) begin
                            // same address checking code
                            case(sq_tbl[i].mem_size[1:0])
                                // byte
                                2'b00: begin
									// below is sq_ld_value[...] = sq_tbl[i].value[7:0]
									for(int unsigned tmp_i = 0; tmp_i < 8; tmp_i++) begin
										sq_ld_value[{sq_tbl[i].res_addr, 3'b000} + tmp_i] = sq_tbl[i].value[tmp_i];
									end
									sq_ld_found[sq_tbl[i].res_addr].found = 1;
                                    sq_ld_found[sq_tbl[i].res_addr].found_pos = i;
                                end
                                // half-word
                                2'b01: begin
									// below is sq_ld_value[...] = sq_tbl[i].value[15:0]
									for(int unsigned tmp_i = 0; tmp_i < 16; tmp_i++) begin
										sq_ld_value[{sq_tbl[i].res_addr, 3'b000} + tmp_i] = sq_tbl[i].value[tmp_i];
									end
									sq_ld_found[sq_tbl[i].res_addr].found = 1;
									sq_ld_found[sq_tbl[i].res_addr + 1].found = 1;
                                    sq_ld_found[sq_tbl[i].res_addr].found_pos = i;
                                    sq_ld_found[sq_tbl[i].res_addr + 1].found_pos = i;
                                end
                                // word
                                2'b10: begin
                                    for(int unsigned tmp_i = 0; tmp_i < 4; tmp_i++) begin
                                        sq_ld_found[tmp_i].found = 1;
                                        sq_ld_found[tmp_i].found_pos = i;
                                    end
                                    sq_ld_value = sq_tbl[i].value;
                                end
                            endcase
                        end
                    end
                end
                // tail before head
                else begin
					if(ex_cp_mem_in_ld.sq_pos == 0) begin
						sq_pos_minus_one = 3'h7;
					end
					else begin
						sq_pos_minus_one = ex_cp_mem_in_ld.sq_pos-1;
					end
                    // upper half
                    if( sq_pos_minus_one < tail_idx && (i < ex_cp_mem_in_ld.sq_pos || i >= head_idx ) ) begin
                        if(sq_tbl[i].valid == 1'b0) begin
                            sq_ld_halt = 1;
                        end 
                        // on upper half
                        else if(sq_tbl[i].word_addr == ex_cp_mem_in_ld.alu_result[`XLEN-1:2] && i < ex_cp_mem_in_ld.sq_pos && !sq_ld_halt) begin
                            // same address checking code
                            case(sq_tbl[i].mem_size[1:0])
                                // byte
                                2'b00: begin
									// below is sq_ld_value[...] = sq_tbl[i].value[7:0]
									for(int unsigned tmp_i = 0; tmp_i < 8; tmp_i++) begin
										sq_ld_value[{sq_tbl[i].res_addr, 3'b000} + tmp_i] = sq_tbl[i].value[tmp_i];
									end
									sq_ld_found[sq_tbl[i].res_addr].found = 1;
									sq_ld_found[sq_tbl[i].res_addr].found_upper = 1;
                                    sq_ld_found[sq_tbl[i].res_addr].found_pos = i;
                                end
                                // half-word
                                2'b01: begin
									// below is sq_ld_value[...] = sq_tbl[i].value[15:0]
									for(int unsigned tmp_i = 0; tmp_i < 16; tmp_i++) begin
										sq_ld_value[{sq_tbl[i].res_addr, 3'b000} + tmp_i] = sq_tbl[i].value[tmp_i];
									end
									sq_ld_found[sq_tbl[i].res_addr].found = 1;
									sq_ld_found[sq_tbl[i].res_addr + 1].found = 1;
									sq_ld_found[sq_tbl[i].res_addr].found_upper = 1;
									sq_ld_found[sq_tbl[i].res_addr + 1].found_upper = 1;

                                    sq_ld_found[sq_tbl[i].res_addr].found_pos = i;
                                    sq_ld_found[sq_tbl[i].res_addr + 1].found_pos = i;
                                end
                                // word
                                2'b10: begin
                                    for(int unsigned tmp_i = 0; tmp_i < 4; tmp_i++) begin
                                        sq_ld_found[tmp_i].found = 1;
										sq_ld_found[tmp_i].found_upper = 1;
                                        sq_ld_found[tmp_i].found_pos = i;
                                    end
                                    sq_ld_value = sq_tbl[i].value;
                                end
                            endcase
                        end
                        // on lower half
                        else if(sq_tbl[i].word_addr == ex_cp_mem_in_ld.alu_result[`XLEN-1:2] && i >= head_idx && !sq_ld_halt) begin
                            // same address checking code
                            case(sq_tbl[i].mem_size[1:0])
                                // byte
                                2'b00: begin
									if(!sq_ld_found[sq_tbl[i].res_addr].found_upper) begin
										// below is sq_ld_value[...] = sq_tbl[i].value[7:0]
										for(int unsigned tmp_i = 0; tmp_i < 8; tmp_i++) begin
											sq_ld_value[{sq_tbl[i].res_addr, 3'b000} + tmp_i] = sq_tbl[i].value[tmp_i];
										end
										sq_ld_found[sq_tbl[i].res_addr].found = 1;
                                        sq_ld_found[sq_tbl[i].res_addr].found_pos = i;
									end
                                end
                                // half-word
                                2'b01: begin
									if(!sq_ld_found[sq_tbl[i].res_addr].found_upper) begin
                                        sq_ld_found[sq_tbl[i].res_addr].found = 1;
                                        sq_ld_found[sq_tbl[i].res_addr].found_pos = i;
										// below is sq_ld_value[...] = sq_tbl[i].value[7:0]
										for(int unsigned tmp_i = 0; tmp_i < 8; tmp_i++) begin
											sq_ld_value[{sq_tbl[i].res_addr, 3'b000} + tmp_i] = sq_tbl[i].value[tmp_i];
										end
									end
									if(!sq_ld_found[sq_tbl[i].res_addr + 1].found_upper) begin
                                        sq_ld_found[sq_tbl[i].res_addr + 1].found = 1;
                                        sq_ld_found[sq_tbl[i].res_addr + 1].found_pos = i;
										// below is sq_ld_value[...] = sq_tbl[i].value[15:8]
										for(int unsigned tmp_i = 0; tmp_i < 8; tmp_i++) begin
											sq_ld_value[{sq_tbl[i].res_addr + 1, 3'b000} + tmp_i] = sq_tbl[i].value[8 + tmp_i];
										end
									end
                                end
                                // word
                                2'b10: begin
                                    for(int unsigned tmp_i = 0; tmp_i < 4; tmp_i++) begin
										if(!sq_ld_found[tmp_i].found_upper) begin
                                            sq_ld_found[tmp_i].found_pos = i;
											sq_ld_found[tmp_i].found = 1;
											byte_addr_i = tmp_i;
											for(int unsigned tmp_j = 0; tmp_j < 8; tmp_j++) begin
												//bit_addr_j = tmp_j[31:0];
												sq_ld_value[{byte_addr_i, 3'b000} + tmp_j] = sq_tbl[i].value[{byte_addr_i, 3'b000} + tmp_j];
											end
										end
                                    end
                                end
                            endcase
                        end
                    end
                    // lower half
                    else if( sq_pos_minus_one >= head_idx && i <= sq_pos_minus_one && i >= head_idx) begin
                        if(sq_tbl[i].valid == 1'b0) begin
                            sq_ld_halt = 1;
                        end
                        else if(sq_tbl[i].word_addr == ex_cp_mem_in_ld.alu_result[`XLEN-1:2] && !sq_ld_halt) begin
                            // same address checking code
                            case(sq_tbl[i].mem_size[1:0])
                                // byte
                                2'b00: begin
									// below is sq_ld_value[...] = sq_tbl[i].value[7:0]
									for(int unsigned tmp_i = 0; tmp_i < 8; tmp_i++) begin
										sq_ld_value[{sq_tbl[i].res_addr, 3'b000} + tmp_i] = sq_tbl[i].value[tmp_i];
									end
									sq_ld_found[sq_tbl[i].res_addr].found = 1;
                                    sq_ld_found[sq_tbl[i].res_addr].found_pos = i;
                                end
                                // half-word
                                2'b01: begin
									// below is sq_ld_value[...] = sq_tbl[i].value[15:0]
									for(int unsigned tmp_i = 0; tmp_i < 16; tmp_i++) begin
										sq_ld_value[{sq_tbl[i].res_addr, 3'b000} + tmp_i] = sq_tbl[i].value[tmp_i];
									end
									sq_ld_found[sq_tbl[i].res_addr].found = 1;
									sq_ld_found[sq_tbl[i].res_addr + 1].found = 1;

                                    sq_ld_found[sq_tbl[i].res_addr].found_pos = i;
                                    sq_ld_found[sq_tbl[i].res_addr + 1].found_pos = i;
                                end
                                // word
                                2'b10: begin
                                    for(int unsigned tmp_i = 0; tmp_i < 4; tmp_i++) begin
                                        sq_ld_found[tmp_i].found = 1;
                                        sq_ld_found[tmp_i].found_pos = i;
                                    end
                                    sq_ld_value = sq_tbl[i].value;
                                end
                            endcase
                        end
                    end
                end
            end
        end
    end

	// temporary logic for representing unsigned integer i in the following block
	logic [$clog2(`XLEN)-1:0] byte_addr_i_s;


    // judge ld_value
    // ld_valid only when load_value correctly and not retiring and not storing
    // ld_need_dcache = true if load need dcache
    always_comb begin
        ld_value = 0;
		ld_valid = 0;
		ld_valid_byte = 0;
        ld_need_dcache = 0;
		tmp_offset = 0;
		byte_addr_i_s = 0;
        if(ex_ld_valid && !sq_ld_halt) begin
			tmp_offset = ex_cp_mem_in_ld.alu_result[1:0];
			case(ex_cp_mem_in_ld.mem_size[1:0])
				// byte
				2'b00: begin
					if(sq_ld_found[tmp_offset].found) begin
						for(int unsigned tmp_i= 0; tmp_i< 8; tmp_i++) begin
							ld_value[tmp_i] = sq_ld_value[{tmp_offset, 3'b000} + tmp_i];
						end
						ld_valid = 1;
					end
                    // read when dcache is ready:
                    // 1. ready for read
					else begin
                        ld_need_dcache = 1;
                        if(dcache_rd_ready) begin
                            for(int unsigned tmp_i= 0; tmp_i< 8; tmp_i++) begin
                                ld_value[tmp_i] = dcache_rd_value[tmp_i];
                            end
                            ld_valid = 1;
                        end
                    end
				end
				// half-word
				2'b01: begin
					for(int unsigned i = 0; i < 2; i++) begin
						byte_addr_i_s = i;
						if(sq_ld_found[tmp_offset + i].found) begin
							for(int unsigned tmp_i= 0; tmp_i< 8; tmp_i++) begin
								ld_value[{byte_addr_i_s, 3'b000} + tmp_i] = sq_ld_value[{tmp_offset + byte_addr_i_s, 3'b000} + tmp_i];
							end
							ld_valid_byte[i] = 1;
						end
						else begin
                            ld_need_dcache = 1; 
                            if(dcache_rd_ready) begin
                                for(int unsigned tmp_i= 0; tmp_i< 8; tmp_i++) begin
                                    ld_value[{byte_addr_i_s, 3'b000} + tmp_i] = dcache_rd_value[{byte_addr_i_s, 3'b000} + tmp_i];
                                end
                                ld_valid_byte[i] = 1;
                            end
                        end
					end
					ld_valid = ld_valid_byte[0] & ld_valid_byte[1];
				end
				// word
				2'b10: begin
					for(int unsigned i = 0; i < 4; i++) begin
						byte_addr_i_s = i;
						if(sq_ld_found[i].found) begin
							for(int unsigned tmp_i= 0; tmp_i< 8; tmp_i++) begin
								ld_value[{byte_addr_i_s, 3'b000} + tmp_i] = sq_ld_value[{byte_addr_i_s, 3'b000} + tmp_i];
							end
							ld_valid_byte[i] = 1;
						end
						else begin
                            ld_need_dcache = 1;
                            if(dcache_rd_ready) begin
                                for(int unsigned tmp_i= 0; tmp_i< 8; tmp_i++) begin
                                    ld_value[{byte_addr_i_s, 3'b000} + tmp_i] = dcache_rd_value[{byte_addr_i_s, 3'b000} + tmp_i];
                                end
                                ld_valid_byte[i] = 1;
                            end
                        end
					end
					ld_valid = ld_valid_byte[0] & ld_valid_byte[1] & ld_valid_byte[2] & ld_valid_byte[3];
				end
			endcase
        end
    end

    // construct lsq to complete packet
    // also tells RS to stop issuing more store if store stall
    always_comb begin
        lsq_cp_packet_out = 0;
        st_stall_out = 0;
        // load only if correct load and no store
        if(ld_valid) begin
            // load complete first, valid store will wait
            if(ex_st_valid) begin
                st_stall_out = 1;
            end

            lsq_cp_packet_out.NPC = ex_cp_mem_in_ld.NPC;
            lsq_cp_packet_out.done = 1;
            lsq_cp_packet_out.valid = 1;
            lsq_cp_packet_out.inst = ex_cp_mem_in_ld.inst;
            lsq_cp_packet_out.dest_reg_idx = ex_cp_mem_in_ld.dest_reg_idx;
            lsq_cp_packet_out.Tag = ex_cp_mem_in_ld.Tag;
            if (~ex_cp_mem_in_ld.mem_size[2]) begin //is this an signed/unsigned load?
				// byte
				if (ex_cp_mem_in_ld.mem_size[1:0] == 2'b00)
					lsq_cp_packet_out.Value = {{(`XLEN-8){ld_value[7]}}, ld_value[7:0]};
				// half-word
				else if  (ex_cp_mem_in_ld.mem_size[1:0] == 2'b01) 
					lsq_cp_packet_out.Value = {{(`XLEN-16){ld_value[15]}}, ld_value[15:0]};
				// word
				else lsq_cp_packet_out.Value = ld_value;
			end else begin
				if (ex_cp_mem_in_ld.mem_size[1:0] == 2'b00)
					lsq_cp_packet_out.Value = {{(`XLEN-8){1'b0}}, ld_value[7:0]};
				else if  (ex_cp_mem_in_ld.mem_size[1:0] == 2'b01)
					lsq_cp_packet_out.Value = {{(`XLEN-16){1'b0}}, ld_value[15:0]};
				else lsq_cp_packet_out.Value = ld_value;
			end
        end
        // store always goes to complete if valid
        else if(ex_st_valid) begin
            lsq_cp_packet_out.NPC = ex_cp_mem_in_st.NPC;
            lsq_cp_packet_out.done = 1;
            lsq_cp_packet_out.valid = 1;
            lsq_cp_packet_out.inst = ex_cp_mem_in_st.inst;
            lsq_cp_packet_out.dest_reg_idx = ex_cp_mem_in_st.dest_reg_idx;
            lsq_cp_packet_out.Tag = ex_cp_mem_in_st.Tag;
        end
    end

	// tell RS and execute fail to load to stop more load insn
    // 1. when load fail
    always_comb begin
        ld_stall_out = 0;
        if(ex_ld_valid) begin
            // 1. dcache load miss
            // 2. sq empty entry
            if(!ld_valid) begin
                ld_stall_out = 1;
            end
        end
    end

    // decide how priority_state changes
    always_comb begin
        priority_state_n = priority_state;
        // retire > load
        if(!priority_state) begin
            // when no retire, 
            // and load wants to read dcache but dcache miss
            // change to load > retire
            if(!retire_valid) begin
                if(ex_ld_valid && ld_need_dcache && !dcache_rd_ready) begin
                    priority_state_n = 1;
                end 
            end
        end
        // load > retire
        else begin
            // when load does not use dcache
            // and retire wants to use dcache but dcache miss
            // change to retire > load
            if(! (ex_ld_valid && ld_need_dcache)) begin
                if(retire_valid && !dcache_retire_ready) begin
                    priority_state_n = 0;
                end
            end
        end
    end

    // construct lsq to dcache packet
    always_comb begin
        lsq_dcache_packet_out = 0;
        // retire > load
        if(!priority_state) begin
            // retire first
            // if retire is possible, ignore dcache_retire_ready to avoid loop
            if(retire_valid) begin
                lsq_dcache_packet_out.lsq_is_requesting = 1;
                lsq_dcache_packet_out.address = retire_addr;
                if (~retire_mem_size[2]) begin //is this an signed/unsigned load?
                    // byte
                    if (retire_mem_size[1:0] == 2'b00)
                        lsq_dcache_packet_out.value = {{(`XLEN-8){retire_value[7]}}, retire_value[7:0]};
                    // half-word
                    else if  (retire_mem_size[1:0] == 2'b01) 
                        lsq_dcache_packet_out.value = {{(`XLEN-16){retire_value[15]}}, retire_value[15:0]};
                    // word
                    else lsq_dcache_packet_out.value = retire_value;
                end else begin
                    if (retire_mem_size[1:0] == 2'b00)
                        lsq_dcache_packet_out.value = {{(`XLEN-8){1'b0}}, retire_value[7:0]};
                    else if  (retire_mem_size[1:0] == 2'b01)
                        lsq_dcache_packet_out.value = {{(`XLEN-16){1'b0}}, retire_value[15:0]};
                    else lsq_dcache_packet_out.value = retire_value;
                end
                lsq_dcache_packet_out.is_store = 1;
                lsq_dcache_packet_out.mem_size =  retire_mem_size[1:0];
            end
            // load dcache
            else if(ex_ld_valid && ld_need_dcache) begin
                lsq_dcache_packet_out.lsq_is_requesting = 1;
                lsq_dcache_packet_out.address = ex_cp_mem_in_ld.alu_result;
                lsq_dcache_packet_out.mem_size = ex_cp_mem_in_ld.mem_size[1:0];
            end 
        end
        // load > retire
        else begin
            // load first
            if(ex_ld_valid && ld_need_dcache) begin
                lsq_dcache_packet_out.lsq_is_requesting = 1;
                lsq_dcache_packet_out.address = ex_cp_mem_in_ld.alu_result;
                lsq_dcache_packet_out.mem_size = ex_cp_mem_in_ld.mem_size[1:0];
            end
            else if(retire_valid) begin
                lsq_dcache_packet_out.lsq_is_requesting = 1;
                lsq_dcache_packet_out.address = retire_addr;
                if (~retire_mem_size[2]) begin //is this an signed/unsigned load?
                    // byte
                    if (retire_mem_size[1:0] == 2'b00)
                        lsq_dcache_packet_out.value = {{(`XLEN-8){retire_value[7]}}, retire_value[7:0]};
                    // half-word
                    else if  (retire_mem_size[1:0] == 2'b01) 
                        lsq_dcache_packet_out.value = {{(`XLEN-16){retire_value[15]}}, retire_value[15:0]};
                    // word
                    else lsq_dcache_packet_out.value = retire_value;
                end else begin
                    if (retire_mem_size[1:0] == 2'b00)
                        lsq_dcache_packet_out.value = {{(`XLEN-8){1'b0}}, retire_value[7:0]};
                    else if  (retire_mem_size[1:0] == 2'b01)
                        lsq_dcache_packet_out.value = {{(`XLEN-16){1'b0}}, retire_value[15:0]};
                    else lsq_dcache_packet_out.value = retire_value;
                end
                lsq_dcache_packet_out.is_store = 1;
                lsq_dcache_packet_out.mem_size =  retire_mem_size[1:0];
            end
        end
    end

    // Judge structure hazard
    always_comb begin
        space_available = head[$clog2(`SQ_SIZE)-1:0] - tail[$clog2(`SQ_SIZE)-1:0];
        if (space_available == 0) begin
            if (tail[$clog2(`SQ_SIZE)] != head[$clog2(`SQ_SIZE)]) begin
                dp_available = 0;
            end
            else begin
                dp_available = 2;
            end
        end
        else begin
            if (space_available > `DP_SIZE) begin
                dp_available = 2;
            end
            else begin
                dp_available = 0;
            end
        end 
    end

	// synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if(reset) begin
            head <= `SD 0;
            tail <= `SD 0;
			//for(int unsigned i = 0; i < `SQ_SIZE; i++) begin
			//	sq_tbl[i].valid <= `SD 0;
			//end
			sq_tbl <= `SD 0;
            priority_state <= `SD 0;
        end
        else if (squash) begin
            head <= `SD 0;
            tail <= `SD 0;
			//for(int unsigned i = 0; i < `SQ_SIZE; i++) begin
			//	sq_tbl[i].valid <= `SD 0;
            //end
			sq_tbl <= `SD 0;
            priority_state <= `SD 0;
        end
        else begin
            // for retire
            if(retire_valid && dcache_retire_ready) begin
                sq_tbl[head_idx].valid <= `SD 1'b0;    
            end
            // for execute
            if(ex_st_valid) begin
                sq_tbl[ex_cp_mem_in_st.sq_pos].word_addr <= `SD ex_cp_mem_in_st.alu_result[`XLEN-1:2];
                sq_tbl[ex_cp_mem_in_st.sq_pos].res_addr <= `SD ex_cp_mem_in_st.alu_result[1:0];
                sq_tbl[ex_cp_mem_in_st.sq_pos].value <= `SD ex_cp_mem_in_st.rs2_value;
                sq_tbl[ex_cp_mem_in_st.sq_pos].mem_size <= `SD ex_cp_mem_in_st.mem_size;
                sq_tbl[ex_cp_mem_in_st.sq_pos].ROB_tag <= `SD ex_cp_mem_in_st.Tag;
                sq_tbl[ex_cp_mem_in_st.sq_pos].valid <= `SD 1'b1;
            end
            // for retire
            head <= `SD head_n;
            tail <= `SD tail_n;
            priority_state <= `SD priority_state_n;
        end
    end
endmodule
