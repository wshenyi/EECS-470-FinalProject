// EECS 470 W22 Group 13 Project
// Testbench for dcache_planb.

`timescale 1ns/100ps
`define CACHE_MODE

import "DPI-C" function void print_header(string str);
import "DPI-C" function void print_cycles();
import "DPI-C" function void print_stage(string div, int inst, int npc, int valid_inst);
import "DPI-C" function void print_reg(int wb_reg_wr_data_out_hi, int wb_reg_wr_data_out_lo,
                                       int wb_reg_wr_idx_out, int wb_reg_wr_en_out);
import "DPI-C" function void print_membus(int proc2mem_command, int mem2proc_response,
                                          int proc2mem_addr_hi, int proc2mem_addr_lo,
                                          int proc2mem_data_hi, int proc2mem_data_lo);
import "DPI-C" function void print_close();


module tb();
    // Inputs
    logic clock, reset;
    DCACHE_PLANB_IN_PACKET dcache_in;
    logic [3:0] Dmem2proc_response;
    logic [63:0] Dmem2proc_data;
    logic [3:0] Dmem2proc_tag;

    // Outputs
    DCACHE_PLANB_OUT_PACKET dcache_out;
    DCACHE_PLANB_SET [15:0] cache_data;
    logic [`XLEN-1:0] proc2Dmem_addr;
    logic [63:0] proc2Dmem_data;
    logic [1:0] proc2Dmem_command;

    logic [`XLEN-4:0] flush_addr; // For cache flushing

    dcache_planb DUT (
        .clock(clock),
        .reset(reset),
        .dcache_in(dcache_in),
        // inputs from MEMORY
        .Dmem2proc_response(Dmem2proc_response),
        .Dmem2proc_data(Dmem2proc_data),
        .Dmem2proc_tag(Dmem2proc_tag),
        // output to LSQ (and ROB)
        .dcache_out(dcache_out),
        // The entire internal cache data.
        // Used by testbench.sv
        .cache_data(cache_data),
        // outputs to MEMORY
        .proc2Dmem_addr(proc2Dmem_addr),
        .proc2Dmem_data(proc2Dmem_data),
        .proc2Dmem_command(proc2Dmem_command)
    );

    task show_mem_with_decimal;
        input [31:0] start_addr;
        input [31:0] end_addr;
        int showing_data;
        begin
            $display("@@@");
            showing_data=0;
            for(int k=start_addr;k<=end_addr; k=k+1)
                if (memory.unified_memory[k] != 0) begin
                    $display("@@@ mem[0x%2h] = %x : %0d", k*8, memory.unified_memory[k], 
                                                            memory.unified_memory[k]);
                    showing_data=1;
                end else if(showing_data!=0) begin
                    $display("@@@");
                    showing_data=0;
                end
            $display("@@@");
        end
    endtask  // task show_mem_with_decimal

    mem memory(
        .clk(clock),
        .proc2mem_addr(proc2Dmem_addr),
        .proc2mem_data(proc2Dmem_data),
        .proc2mem_command(proc2Dmem_command),
        .mem2proc_response(Dmem2proc_response),
        .mem2proc_data(Dmem2proc_data),
        .mem2proc_tag(Dmem2proc_tag)
    );

    always begin
        #5;
        clock = ~clock;
    end

    initial begin
        clock = 1'b0;
        reset = 1'b1;
        dcache_in.lsq_is_requesting = 1'b0;
        dcache_in.address = 32'h00000000;
        dcache_in.is_store = 1'b0;
        dcache_in.value = 32'h00000000;
        dcache_in.mem_size = 3'b010;

        @(posedge clock);
        `SD;
        @(posedge clock);
        `SD;
        $display("Initializing memory...");
        $readmemh("program.mem", memory.unified_memory);

        repeat (2) @(posedge clock);
    
        `SD;
        reset = 1'b0;
        @(posedge clock);
        `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000000;
        // miss
        `SD
        @(posedge dcache_out.completed);
        `SD;
        assert(dcache_out.value == 32'h00800113) else begin
            $display("Actual value is: 0x%8h", dcache_out.value);
            $finish;
        end

        @(posedge clock);
        `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000004;
        dcache_in.mem_size = 3'b001;
        // hit
        `SD;
        assert(dcache_out.value == 32'h000021b7) else begin
            $display("Actual value is: 0x%8h", dcache_out.value);
            $finish;
        end

        @(posedge clock);
         `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000008;
        dcache_in.mem_size = 3'b010;
        // miss
        @(posedge dcache_out.completed);
        `SD;
        assert(dcache_out.value == 32'h7bb18193) else begin
            $display("Actual value is: 0x%8h", dcache_out.value);
            $finish;
        end


        // Fetch a block that's the same size with 0x0
        @(posedge clock);
         `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000080;
        // miss
        @(posedge dcache_out.completed);
        `SD;
        assert(dcache_out.value == 32'h023606b3) else begin
            $display("Actual value is: 0x%8h", dcache_out.value);
            $finish;
        end

        // Now write (store)!
        @(posedge clock);
         `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000000;
        dcache_in.mem_size = 3'b010;
        dcache_in.is_store = 1'b1;
        dcache_in.value = 32'hDEADBEEF;
        // hit
        
        
        // Evict mechanism!
        @(posedge clock);
         `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000100;
        dcache_in.mem_size = 3'b010;
        dcache_in.is_store = 1'b0;
        dcache_in.value = 32'h00000000;
        // miss
        @(posedge dcache_out.completed);
        `SD;
        assert(dcache_out.value == 32'h00000000) else begin
            $display("Actual value is: 0x%8h", dcache_out.value);
            $finish;
        end

        // Now retire stall should be 1...
        @(posedge clock);
         `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000080;
        dcache_in.mem_size = 3'b010;
        dcache_in.is_store = 1'b1;
        dcache_in.value = 32'hBAD22222;
        // miss
        @(posedge dcache_out.completed);
        `SD;

        // Byte addressable read!
        // 0x48
        @(posedge clock);
         `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000048;
        dcache_in.mem_size = 3'b100;
        dcache_in.is_store = 1'b0;
        dcache_in.value = 32'h00000000;
        // miss
        @(posedge dcache_out.completed);
        `SD;
        assert(dcache_out.value == 32'h00000013) else begin
            $display("Actual value is: 0x%8h", dcache_out.value);
            $finish;
        end
        // 0x49
        @(posedge clock);
         `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000049;
        dcache_in.mem_size = 3'b100;
        dcache_in.is_store = 1'b0;
        dcache_in.value = 32'h00000000;
        // hit
        `SD;
        assert(dcache_out.value == 32'h00000002) else begin
            $display("Actual value is: 0x%8h", dcache_out.value);
            $finish;
        end
        // 0x4a
        @(posedge clock);
         `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h0000004b;
        dcache_in.mem_size = 3'b100;
        dcache_in.is_store = 1'b0;
        dcache_in.value = 32'h00000000;
        // hit
        `SD;
        assert(dcache_out.value == 32'h000000b5) else begin
            $display("Actual value is: 0x%8h", dcache_out.value);
            $finish;
        end
        // 0x4e
        @(posedge clock);
         `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h0000004e;
        dcache_in.mem_size = 3'b000;
        dcache_in.is_store = 1'b0;
        dcache_in.value = 32'h00000000;
        // hit
        `SD;
        assert(dcache_out.value == 32'h000000c2) else begin
            $display("Actual value is: 0x%8h", dcache_out.value);
            $finish;
        end

        // Now half-words!
        // 0x96
        @(posedge clock);
         `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000096;
        dcache_in.mem_size = 3'b001;
        dcache_in.is_store = 1'b0;
        dcache_in.value = 32'h00000000;
        // miss
        @(posedge dcache_out.completed);
        `SD;
        assert(dcache_out.value == 32'h00000106) else begin
            $display("Actual value is: 0x%8h", dcache_out.value);
            $finish;
        end
        // 0x92
        @(posedge clock);
         `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000092;
        dcache_in.mem_size = 3'b001;
        dcache_in.is_store = 1'b0;
        dcache_in.value = 32'h00000000;
        // hit
        `SD;
        assert(dcache_out.value == 32'h00000105) else begin
            $display("Actual value is: 0x%8h", dcache_out.value);
            $finish;
        end
        // 0x94
        @(posedge clock);
         `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000094;
        dcache_in.mem_size = 3'b001;
        dcache_in.is_store = 1'b0;
        dcache_in.value = 32'h00000000;
        // hit
        `SD;
        assert(dcache_out.value == 32'h00005613) else begin
            $display("Actual value is: 0x%8h", dcache_out.value);
            $finish;
        end
        // 0x90
        @(posedge clock);
         `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000090;
        dcache_in.mem_size = 3'b001;
        dcache_in.is_store = 1'b0;
        dcache_in.value = 32'h00000000;
        // hit
        `SD;
        assert(dcache_out.value == 32'h0000d593) else begin
            $display("Actual value is: 0x%8h", dcache_out.value);
            $finish;
        end
        
        // Now byte-addressable writes!
        // Most error-prone situations!
        // Fetch a block that goes to the same set as 0x90
        // 0x12
        @(posedge clock);
         `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000012;
        dcache_in.mem_size = 3'b000;
        dcache_in.is_store = 1'b1;
        dcache_in.value = 32'hFFFFFFFF;
        // miss
        `SD;
        @(posedge dcache_out.completed);
        `SD;
        // 0x11
        @(posedge clock);
        `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000011;
        dcache_in.mem_size = 3'b000;
        dcache_in.is_store = 1'b1;
        dcache_in.value = 32'h000000EE;
        // hit
        @(posedge clock);
        `SD;
        // 0x10
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000010;
        dcache_in.mem_size = 3'b000;
        dcache_in.is_store = 1'b1;
        dcache_in.value = 32'h000000DD;
        // hit
        @(posedge clock);
        `SD;
        // 0x13
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000013;
        dcache_in.mem_size = 3'b000;
        dcache_in.is_store = 1'b1;
        dcache_in.value = 32'h000000BB;
        // hit
        @(posedge clock);
        `SD;
        // 0x14
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000014;
        dcache_in.mem_size = 3'b000;
        dcache_in.is_store = 1'b1;
        dcache_in.value = 32'h00000044;
        // hit
        @(posedge clock);
        `SD;
        // 0x15
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000015;
        dcache_in.mem_size = 3'b000;
        dcache_in.is_store = 1'b1;
        dcache_in.value = 32'h00000055;
        // hit
        @(posedge clock);
        `SD;
        // 0x16
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000017;
        dcache_in.mem_size = 3'b000;
        dcache_in.is_store = 1'b1;
        dcache_in.value = 32'h000000aa;
        // hit
        @(posedge clock);
        `SD;
        // 0x17
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000016;
        dcache_in.mem_size = 3'b000;
        dcache_in.is_store = 1'b1;
        dcache_in.value = 32'h00000077;
        // hit
        // Now the 0x10 block should be: 0x77665544BBEEFFDD

        // Touch 0x90 block so now 0x10 is the LRU
        @(posedge clock);
         `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000090;
        dcache_in.mem_size = 3'b001;
        dcache_in.is_store = 1'b0;
        dcache_in.value = 32'hDEADC0DE;
        // hit
        `SD;
        if (dcache_out.value != 32'h0000d593) begin
            $finish;
        end

        // Now grab 0x110 so that 0x10 will be evicted,
        // 0x10 is dirty!
        @(posedge clock);
         `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000110;
        dcache_in.mem_size = 3'b010;
        dcache_in.is_store = 1'b0;
        dcache_in.value = 32'h00000000;
        // miss
        @(posedge dcache_out.completed);
        `SD;
        assert(dcache_out.value == 32'h00000000) else begin
            $display("Actual value is: 0x%8h", dcache_out.value);
            $finish;
        end

        // Write 0x90 half-byte
        @(posedge clock);
        `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000092;
        dcache_in.mem_size = 3'b001;
        dcache_in.is_store = 1'b1;
        dcache_in.value = 32'hDEADC0DE;
        // hit
        `SD;
        @(posedge clock);
        `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000094;
        dcache_in.mem_size = 3'b001;
        dcache_in.is_store = 1'b1;
        dcache_in.value = 32'h0000DEAD;
        // hit
        `SD;

        // Touch 0x110
        @(posedge clock);
         `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000110;
        dcache_in.mem_size = 3'b010;
        dcache_in.is_store = 1'b0;
        dcache_in.value = 32'h00000000;
        // hit
        `SD;
        assert(dcache_out.value == 32'h00000000) else begin
            $display("Actual value is: 0x%8h", dcache_out.value);
            $finish;
        end

        // Now evict 0x90! This time test lsq squashing situation.
        // So squash happens in EVICT state.
        // We can still expect 0x90 writeback but 0x10 should be invalid.
        @(posedge clock);
        `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000012;
        dcache_in.mem_size = 3'b000;
        dcache_in.is_store = 1'b0;
        dcache_in.value = 32'hFFFFFFFF;
        @(posedge clock);
        `SD;
        // squash
        dcache_in.lsq_is_requesting = 1'b0;
        // miss, but don't care anymore...
        `SD;

        // Now really evict 0x90 and grab 0x10.
        // This should be a miss again!
        @(posedge clock);
        `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000010;
        dcache_in.mem_size = 3'b010;
        dcache_in.is_store = 1'b0;
        dcache_in.value = 32'hFFFFFFFF;
        // miss
        @(posedge dcache_out.completed);
        `SD;
        assert(dcache_out.value == 32'hbbffeedd) else begin
            $display("Actual value is: 0x%8h", dcache_out.value);
            $finish;
        end

        // Write 0x90 ocurred a miss,
        // but squash is happening after 1 cycle!
        // This should be a miss again!
        @(posedge clock);
        `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000090;
        dcache_in.mem_size = 3'b010;
        dcache_in.is_store = 1'b1;
        dcache_in.value = 32'hB16B00B5;
        // miss
        @(posedge clock);
        `SD;
        dcache_in.lsq_is_requesting = 1'b0;
        // At this point, B16B00B5 should not be written into dcache, since miss!

        @(posedge clock);
        `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000010;
        dcache_in.mem_size = 3'b010;
        dcache_in.is_store = 1'b0;
        dcache_in.value = 32'hB16B00B5;
        `SD;
        assert(dcache_out.value == 32'hbbffeedd) else begin
            $display("Actual value is: 0x%8h", dcache_out.value);
            $finish;
        end

        @(posedge clock);
        `SD;
        dcache_in.lsq_is_requesting = 1'b1;
        dcache_in.address = 32'h00000110;
        dcache_in.mem_size = 3'b010;
        dcache_in.is_store = 1'b0;
        dcache_in.value = 32'hB16B00B5;
        `SD;
        assert(dcache_out.value == 32'h00000000) else begin
            $display("Actual value is: 0x%8h", dcache_out.value);
            $finish;
        end


        @(posedge clock);
        `SD;

        repeat (10) @(posedge clock);
        `SD;

        // Flushing Dcache
        for (int i = 0; i < 16; i++) begin
            for (int j = 0; j < 2; j++) begin
                if (cache_data[i].line[j].valid) begin
                    flush_addr = {cache_data[i].line[j].tag, i[3:0]};
                    $display("Flushing 0x%h back to memory", {flush_addr, 3'b0});
                    memory.unified_memory[flush_addr] = cache_data[i].line[j].data;
                end
            end
        end
        $display("@@@ Unified Memory contents hex on left, decimal on right: ");
        show_mem_with_decimal(0,`MEM_64BIT_LINES - 1); 
        $display("@@@ PASSED ALL ASSERTS.");

        $finish;
    end

endmodule
