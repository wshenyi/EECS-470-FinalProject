/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  rt_stage.v                                          //
//                                                                     //
//  Description :   retire (RT) stage of the pipeline;                 //
//                  determine the destination register of the          //
//                  instruction and write the result to the register   //
//                  file (if not to the zero register), also reset the //
//                  NPC in the fetch stage to the correct next PC      //
//                  address.                                           // 
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`timescale 1ns/100ps

module rt_stage(
    // Inputs
    input  CP_RT_PACKET  [1:0] CP_RT_packet_in,
    input                [1:0] retire_disable,
    // Outputs
    output RT_PACKET     [1:0] RT_packet_out,
    output logic               squash_signal_out,
    output logic   [`XLEN-1:0] RT_NPC  // retired PC
);

    logic [1:0] cp_vc;
    logic [1:0] ep_vc;

    assign cp_vc = {CP_RT_packet_in[1].rob_entry.cp_bit, CP_RT_packet_in[0].rob_entry.cp_bit};
    assign ep_vc = {CP_RT_packet_in[1].rob_entry.ep_bit, CP_RT_packet_in[0].rob_entry.ep_bit};

    assign RT_packet_out[0].retire_reg  = cp_vc[0] ? CP_RT_packet_in[0].rob_entry.reg_idx : 0;
    assign RT_packet_out[0].retire_tag  = cp_vc[0] ? CP_RT_packet_in[0].Tag : 0;
    assign RT_packet_out[0].wr_en       = cp_vc[0] ? CP_RT_packet_in[0].rob_entry.reg_idx != `ZERO_REG : 0;
    assign RT_packet_out[0].value       = cp_vc[0] ? CP_RT_packet_in[0].rob_entry.value : 0;
    assign RT_packet_out[0].illegal     = cp_vc[0] ? CP_RT_packet_in[0].rob_entry.illegal : 0;
    assign RT_packet_out[0].halt        = cp_vc[0] ? CP_RT_packet_in[0].rob_entry.halt : 0;
    assign RT_packet_out[0].valid       = cp_vc[0] ? CP_RT_packet_in[0].rob_entry.valid : 0;
    assign RT_packet_out[0].PC         = cp_vc[0] ? CP_RT_packet_in[0].rob_entry.PC : 0;

    assign RT_packet_out[1].retire_reg  = (&cp_vc) & ~ep_vc[0] ? CP_RT_packet_in[1].rob_entry.reg_idx : 0;
    assign RT_packet_out[1].retire_tag  = (&cp_vc) & ~ep_vc[0] ? CP_RT_packet_in[1].Tag : 0;
    assign RT_packet_out[1].value       = (&cp_vc) & ~ep_vc[0] ? CP_RT_packet_in[1].rob_entry.value  : 0;
    assign RT_packet_out[1].illegal     = (&cp_vc) & ~ep_vc[0] ? CP_RT_packet_in[1].rob_entry.illegal : 0;
    assign RT_packet_out[1].halt        = (&cp_vc) & ~ep_vc[0] ? CP_RT_packet_in[1].rob_entry.halt : 0;
    assign RT_packet_out[1].PC         = (&cp_vc) & ~ep_vc[0] ? CP_RT_packet_in[1].rob_entry.PC : 0;
    // Don't retire rt_packet[1] if rt_packet[0] is a WFI command
    always_comb begin
        RT_packet_out[1].wr_en = (&cp_vc) & ~ep_vc[0] ? CP_RT_packet_in[1].rob_entry.reg_idx != `ZERO_REG : 0;
        RT_packet_out[1].valid = (&cp_vc) & ~ep_vc[0] ? CP_RT_packet_in[1].rob_entry.valid : 0;
        if (RT_packet_out[0].valid && RT_packet_out[0].halt) begin
            RT_packet_out[1].wr_en = 0;
            RT_packet_out[1].valid = 0;
        end
    end

    assign RT_NPC = cp_vc[0] ? (ep_vc[0] ? CP_RT_packet_in[0].rob_entry.NPC : (cp_vc[1] & ep_vc[1] ? CP_RT_packet_in[1].rob_entry.NPC : 0)) : 0;

    assign squash_signal_out = ~(|retire_disable) ? (cp_vc[0] & ep_vc[0]) | ((&cp_vc) & (|ep_vc)) : 0;

endmodule // module wb_stage

