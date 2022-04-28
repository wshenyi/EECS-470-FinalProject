module insn_buffer (
    input clock, reset, enable,
    // from dp_stage
    // Actual number of insns dispatched in this cycle,
    // after considering structural hazards in ROB and RS.
    input [1:0] dp_packet_count_in,
    // 1 when ROB retiring a mispredicted insn.
    // The insn_buffer will need to clear all entries and 
    // fetch new insns from given PC.
    // Will act the same as reset (?)
    input squash_in,
    // Fetched data (insns) if_stage
    // Since if_stage is given available_in_size,
    // if_stage should not give insn_buffer more than it can hold
    input  IF_DP_PACKET [1:0] if_dp_packet_in,

    // Outputs
    // to if_stage, available slots in this buffer
    //output logic [1:0] available_in_size_out,
    // to dp_stage, insns that goes to "decode+dispatch"
    output logic buffer_full,
    output IF_DP_PACKET [1:0] if_dp_packet_out 
);
    parameter DEPTH = 16;
    localparam PTR_WIDTH = $clog2(DEPTH)+1;
    logic [PTR_WIDTH-1:0] wptr, n_wptr, wptr_p3, wptr_p2, wptr_p1;  // wptr plus 3
    logic [PTR_WIDTH-1:0] rptr, n_rptr, rptr_p1;  // rptr plus 1
    IF_DP_PACKET [DEPTH-1:0] mem ;
    IF_DP_PACKET [DEPTH-1:0] n_mem ;
    logic empty;
    logic [2:0]size;
    
    
    assign wptr_p1 = wptr+1;
    assign rptr_p1 = rptr+1;

    
    assign empty = (wptr == rptr) | (wptr == rptr_p1);
    assign buffer_full =  (wptr == {~rptr[PTR_WIDTH-1],rptr[PTR_WIDTH-2:0]}) |  (wptr_p1 == {~rptr[PTR_WIDTH-1],rptr[PTR_WIDTH-2:0]});
   
    always_comb begin
        n_wptr = wptr;
        for (int i=0;i<2;i++) begin
            if (if_dp_packet_in[i].valid) begin
                n_wptr = wptr + i + 1;
            end
        end
    end

    assign size = n_wptr - wptr;

    
    always_comb begin
        for (int j=0;j<DEPTH;j++) begin
            n_mem[j] = mem[j];
        end
        case (size)
        3'h1: begin
              n_mem [wptr[PTR_WIDTH-2:0]] = if_dp_packet_in[0];
              end
        3'h2: begin
              n_mem [wptr[PTR_WIDTH-2:0]] = if_dp_packet_in[0];
              n_mem [wptr_p1[PTR_WIDTH-2:0]] = if_dp_packet_in[1];
              end
        // 3'h3: begin
        //       n_mem [wptr[PTR_WIDTH-2:0]] = if_dp_packet_in[0];
        //       n_mem [wptr_p1[PTR_WIDTH-2:0]] = if_dp_packet_in[1];
        //       n_mem [wptr_p2[PTR_WIDTH-2:0]] = if_dp_packet_in[2];
        //       end
        // 3'h4: begin
        //       n_mem [wptr[PTR_WIDTH-2:0]] = if_dp_packet_in[0];
        //       n_mem [wptr_p1[PTR_WIDTH-2:0]] = if_dp_packet_in[1];
        //       n_mem [wptr_p2[PTR_WIDTH-2:0]] = if_dp_packet_in[2];
        //       n_mem [wptr_p3[PTR_WIDTH-2:0]] = if_dp_packet_in[3];
        //       end
        default: begin
                    n_mem = mem;
                end
        endcase
    end

    // Read from FIFO
    always_comb begin
        case (dp_packet_count_in)
        2'b00: begin n_rptr = rptr; end 
        2'b01: begin n_rptr = rptr+1; end
        2'b10: begin n_rptr = rptr+2; end
        default: n_rptr = rptr;
        endcase
    end

    always_comb begin
        if_dp_packet_out[0].valid = 0;
        if_dp_packet_out[0].inst = `NOP;
        if_dp_packet_out[0].NPC = 0;
        if_dp_packet_out[0].PC = 0;
        if_dp_packet_out[1].valid = 0;
        if_dp_packet_out[1].inst = `NOP;
        if_dp_packet_out[1].NPC = 0;
        if_dp_packet_out[1].PC = 0;
        case (dp_packet_count_in)
        2'b01: begin 
               if (!empty) begin
               if_dp_packet_out[0] = mem [rptr[PTR_WIDTH-2:0]];
               end
               end
        2'b10: begin
               if (!empty) begin
               if_dp_packet_out[0] = mem [rptr[PTR_WIDTH-2:0]];
               if_dp_packet_out[1] = mem [rptr_p1[PTR_WIDTH-2:0]];
               end 
        end

        endcase
    end

	// synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            wptr <= `SD 0;
            rptr <= `SD 0;
        end
        else if (squash_in) begin
            wptr <= `SD 0;
            rptr <= `SD 0;
        end
        else if (enable) begin
            if (!buffer_full) begin
                wptr <= `SD n_wptr;
            end
            if (!empty) begin
                rptr <= `SD n_rptr;
            end
        end
    end

    always_ff @(posedge clock) begin
        if (!buffer_full) begin
        mem <= `SD n_mem;
        end
    end


endmodule
