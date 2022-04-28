// EECS 470 W22 Group 13 Project
// Backup dcache.
//
// 2-way, write-back + write-allocate, blocking cache
// BLOCK_SIZE = 64 bits (8 bytes)
// CACHE_SIZE = 256 bytes
// Victim cache: None
//
// Simple calculation:
// there are 32 blocks.
//
// WARNING: MEMORY MUST WAIT FOR AT LEAST TWO CYCLES!!!
// Otherwise there are undefined behaviors.

`timescale 1ns/100ps


module dcache_planb(
    input clock, reset,
    // input from LSQ
    input DCACHE_PLANB_IN_PACKET dcache_in,
    // inputs from MEMORY
    input [3:0] Dmem2proc_response,
    input [63:0] Dmem2proc_data,
    input [3:0] Dmem2proc_tag,

    // output to LSQ (and ROB)
    output DCACHE_PLANB_OUT_PACKET dcache_out,
    // The entire internal cache data.
    // Used by testbench.sv
    output DCACHE_PLANB_SET [15:0] cache_data,
    // outputs to MEMORY
    output logic [`XLEN-1:0] proc2Dmem_addr,
    output logic [63:0] proc2Dmem_data,
    output BUS_COMMAND proc2Dmem_command
);
    DCACHE_STATE state;
    DCACHE_PLANB_SET [15:0] n_cache_data;
    logic [3:0] waiting_mem_tag; // the tag dcache should be expecting.

    logic address_valid;
    assign address_valid = (dcache_in.address < `MEM_SIZE_IN_BYTES);
    logic real_request; // 1 if dcache_in is really an effictive request (not)
    assign real_request = (dcache_in.lsq_is_requesting) && address_valid;

    logic [24:0] current_addr_tag;
    assign current_addr_tag = dcache_in.address[31:7];
    logic [3:0] current_addr_index;
    assign current_addr_index = dcache_in.address[6:3];
    logic [2:0] current_addr_offset;
    assign current_addr_offset = dcache_in.address[2:0];
    DCACHE_PLANB_SET current_set;
    assign current_set = cache_data[current_addr_index];
    logic line_0_hit, line_1_hit;
    assign line_0_hit = (current_set.line[0].tag == current_addr_tag) & current_set.line[0].valid;
    assign line_1_hit = (current_set.line[1].tag == current_addr_tag) & current_set.line[1].valid;

    logic miss;
    assign miss = (~line_0_hit & ~line_1_hit) & real_request;

    assign dcache_out.completed = (!address_valid) || (state == DCACHE_IDLE_HIT) && (real_request) && (~miss);

    logic [31:0] dcache_in_value_word;
    logic [15:0] dcache_in_value_half;
    logic [7:0] dcache_in_value_byte;
    assign dcache_in_value_word = dcache_in.value;
    assign dcache_in_value_half = dcache_in.value[15:0];
    assign dcache_in_value_byte = dcache_in.value[7:0];

    logic evict_line0, evict_line1;
    assign evict_line0 = miss & (current_set.last_accessed) & current_set.line[0].valid;
    assign evict_line1 = miss & (~current_set.last_accessed) &
    current_set.line[0].valid;


    logic current_line_idx;

    always_comb begin
        if (line_0_hit)
            current_line_idx = 1'b0;
        else if (line_1_hit)
            current_line_idx = 1'b1;
        else begin // miss case, find a new line
            current_line_idx = ~current_set.last_accessed;
        end
    end

    always_comb begin
        proc2Dmem_command = BUS_NONE;
        proc2Dmem_addr = 0;
        proc2Dmem_data = 32'hB16B00B5;
        if ((state == DCACHE_IDLE_HIT) && miss) begin
            proc2Dmem_command = BUS_LOAD;
            proc2Dmem_addr = {current_addr_tag, current_addr_index, 3'b0};
        end else if ((state == DCACHE_LD_EVICT) || (state == DCACHE_ST_EVICT)) begin
            if (evict_line0 || evict_line1) begin
                proc2Dmem_command = BUS_STORE;
                proc2Dmem_addr = {current_set.line[current_line_idx].tag, current_addr_index, 3'b0};
                proc2Dmem_data = current_set.line[current_line_idx].data;
            end
        end
    end

    always_comb begin
        n_cache_data = cache_data;
        if (((state == DCACHE_LD_WAIT) || (state == DCACHE_ST_WAIT)) && real_request) begin
            if ((waiting_mem_tag == Dmem2proc_tag) && (waiting_mem_tag != 3'b0)) begin
                n_cache_data[current_addr_index].line[current_line_idx].data = Dmem2proc_data;
                n_cache_data[current_addr_index].line[current_line_idx].valid = 1'b1;
                n_cache_data[current_addr_index].line[current_line_idx].tag = current_addr_tag;
            end
        end
        if (((state == DCACHE_ST_WAIT) && ((waiting_mem_tag == Dmem2proc_tag) && (waiting_mem_tag != 3'b0)))
        || ((state == DCACHE_IDLE_HIT) && ~miss && dcache_in.is_store)) begin
            if (dcache_in.mem_size[1:0] == 2'b10) begin 
                case (current_addr_offset[2])
                    1'b1: n_cache_data[current_addr_index].line[current_line_idx].data[63:32] = dcache_in.value;
                    1'b0: n_cache_data[current_addr_index].line[current_line_idx].data[31:0] = dcache_in.value;
                endcase
            end else if (dcache_in.mem_size[1:0] == 2'b01) begin
                case (current_addr_offset[2:1])
                    2'b11: n_cache_data[current_addr_index].line[current_line_idx].data[63:48] = dcache_in_value_half;
                    2'b10: n_cache_data[current_addr_index].line[current_line_idx].data[47:32] = dcache_in_value_half;
                    2'b01: n_cache_data[current_addr_index].line[current_line_idx].data[31:16] = dcache_in_value_half;
                    2'b00: n_cache_data[current_addr_index].line[current_line_idx].data[15:0] = dcache_in_value_half;
                endcase
            end else if (dcache_in.mem_size[1:0] == 2'b00) begin 
                case (current_addr_offset)
                    3'b111: n_cache_data[current_addr_index].line[current_line_idx].data[63:56] = dcache_in_value_byte;
                    3'b110: n_cache_data[current_addr_index].line[current_line_idx].data[55:48] = dcache_in_value_byte;
                    3'b101: n_cache_data[current_addr_index].line[current_line_idx].data[47:40] = dcache_in_value_byte;
                    3'b100: n_cache_data[current_addr_index].line[current_line_idx].data[39:32] = dcache_in_value_byte;
                    3'b011: n_cache_data[current_addr_index].line[current_line_idx].data[31:24] = dcache_in_value_byte;
                    3'b010: n_cache_data[current_addr_index].line[current_line_idx].data[23:16] = dcache_in_value_byte;
                    3'b001: n_cache_data[current_addr_index].line[current_line_idx].data[15:8] = dcache_in_value_byte;
                    3'b000: n_cache_data[current_addr_index].line[current_line_idx].data[7:0] = dcache_in_value_byte;
                endcase
            end
        end
        if ((state == DCACHE_IDLE_HIT) && ~miss && real_request) begin
            n_cache_data[current_addr_index].last_accessed = current_line_idx;
        end
    end
    
    always_comb begin
        if (current_addr_offset[2] == 1'b1) begin
            dcache_out.value = current_set.line[current_line_idx].data[63:32];
        end else begin
            dcache_out.value = current_set.line[current_line_idx].data[31:0];
        end
        case (dcache_in.mem_size[1:0])
            2'b01 : begin
                dcache_out.value >>= current_addr_offset[1] * 16;
                dcache_out.value[31:16] = 16'b0;
            end
            2'b00 : begin
                dcache_out.value >>= current_addr_offset[1:0] * 8;
                dcache_out.value[31:8] = 24'b0;
            end
            default : dcache_out.value = dcache_out.value;
        endcase
    end

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            for (int i = 0; i < 16; i++) begin
                cache_data[i].line[0].valid <= `SD 1'b0;
                cache_data[i].line[1].valid <= `SD 1'b0;
                cache_data[i].last_accessed <= `SD 1'b0;
            end
            state <= `SD DCACHE_IDLE_HIT;
            waiting_mem_tag <= `SD 4'b0;
        end else begin
            cache_data <= `SD n_cache_data;
            // State transitions
            if ((state == DCACHE_IDLE_HIT) && miss) begin
                waiting_mem_tag <= `SD Dmem2proc_response;
                if (dcache_in.is_store) begin
                    state <= `SD DCACHE_ST_EVICT;
                end else begin
                    state <= `SD DCACHE_LD_EVICT;
                end
            end else if (state == DCACHE_LD_EVICT) begin
                if (real_request)
                    state <= `SD DCACHE_LD_WAIT;
                else begin
                    state <= `SD DCACHE_IDLE_HIT;
                    waiting_mem_tag <= `SD 4'b0;
                end
            end else if (state == DCACHE_ST_EVICT) begin
                if (real_request)
                    state <= `SD DCACHE_ST_WAIT;
                else begin
                    state <= `SD DCACHE_IDLE_HIT;
                    waiting_mem_tag <= `SD 4'b0;
                end
            end else if (state == DCACHE_LD_WAIT) begin
                if (~real_request || ((waiting_mem_tag == Dmem2proc_tag) && (waiting_mem_tag != 3'b0))) begin
                    state <= `SD DCACHE_IDLE_HIT;
                    waiting_mem_tag <= `SD 4'b0;
                end
            end else if (state == DCACHE_ST_WAIT) begin
                if (~real_request || ((waiting_mem_tag == Dmem2proc_tag) && (waiting_mem_tag != 3'b0))) begin
                    state <= `SD DCACHE_IDLE_HIT;
                    waiting_mem_tag <= `SD 4'b0;
                end
            end
        end
    end

endmodule
