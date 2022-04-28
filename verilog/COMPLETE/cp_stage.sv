`timescale 1ns/100ps

module cp_stage (
    input   EX_CP_PACKET ex_cp_packet_alu0, ex_cp_packet_alu1, ex_cp_packet_mult, ex_cp_packet_mem,
    // to CDB
    output  CDB_PACKET [1:0]    cdb_packet_out, 
    // to issue stage and the reg
    output  logic               ALU0_stall_out, ALU1_stall_out
);


    wire  [3:0] fu_rdy;
    wire [3:0] cdb_in_flag;
    wire [7:0] cdb_in_flag_bus;

    assign fu_rdy[0] = ex_cp_packet_mult.done;
    assign fu_rdy[1] = ex_cp_packet_mem.done;
    assign fu_rdy[2] = ex_cp_packet_alu0.done;
    assign fu_rdy[3] = ex_cp_packet_alu1.done;
   

  
    assign ALU0_stall_out = (cdb_in_flag[2]==0) & (fu_rdy [2]==1);
    assign ALU1_stall_out = (cdb_in_flag[3]==0) & (fu_rdy [3]==1);


    // select the FU data out to CDB 
    // choose 2 result to CDB from 4 FU
    psel_gen #(.REQS(2), .WIDTH(4)) ps_ex(
        .req(fu_rdy),
        .gnt(cdb_in_flag),
        .gnt_bus(cdb_in_flag_bus)
    );

    // output ex_packet_out to cdb[0]
    always_comb begin  
        case (cdb_in_flag_bus[3:0]) 
        default:begin
                cdb_packet_out[0].Value         = 0;
                cdb_packet_out[0].NPC           = 0;
                cdb_packet_out[0].take_branch   = 0; 
                cdb_packet_out[0].inst          = `NOP;
                cdb_packet_out[0].dest_reg_idx  = `ZERO_REG;
                cdb_packet_out[0].halt          = 0;
                cdb_packet_out[0].illegal       = 0;
                cdb_packet_out[0].valid         = 0;
                cdb_packet_out[0].Tag           = 0;
                cdb_packet_out[0].done          = 0;
                end    
        4'b0001:begin
                cdb_packet_out[0] = ex_cp_packet_mult;
                end
        4'b0010:begin
                cdb_packet_out[0] = ex_cp_packet_mem;
                end
        4'b0100:begin
                cdb_packet_out[0] = ex_cp_packet_alu0;
                end
        4'b1000:begin
                cdb_packet_out[0] = ex_cp_packet_alu1;
                end   
        endcase
    end

    // output ex_packet_out to cdb[1]
    always_comb begin  
        case (cdb_in_flag_bus[7:4]) 
        default:begin
                cdb_packet_out[1].Value         = 0;
                cdb_packet_out[1].NPC           = 0;
                cdb_packet_out[1].take_branch   = 0; 
                cdb_packet_out[1].inst          = `NOP;
                cdb_packet_out[1].dest_reg_idx  = `ZERO_REG;
                cdb_packet_out[1].halt          = 0;
                cdb_packet_out[1].illegal       = 0;
                cdb_packet_out[1].valid         = 0;
                cdb_packet_out[1].Tag           = 0;
                cdb_packet_out[1].done          = 0;
                end    
        4'b0001:begin
                cdb_packet_out[1] = ex_cp_packet_mult;
                end
        4'b0010:begin
                cdb_packet_out[1] = ex_cp_packet_mem;
                end
        4'b0100:begin
                cdb_packet_out[1] = ex_cp_packet_alu0;
                end
        4'b1000:begin
                cdb_packet_out[1] = ex_cp_packet_alu1;
                end   
        endcase
    end
endmodule