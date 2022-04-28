`ifndef __MULT_SV__
`define __MULT_SV__

module mult #(parameter XLEN = 32, parameter NUM_STAGE = 4) (
				input clock, reset,squash_in,
				input start,
				input [1:0] sign,
				input [XLEN-1:0] mcand, mplier,

				input [XLEN-1:0] IS_EX_NPC,
				input INST IS_EX_inst,
				input [4:0] IS_EX_reg_idx,
				input [`ROB_ADDR_BITS-1:0]  IS_EX_Tag,
				input ALU_FUNC func_in,
				input halt_in, illegal_in, valid_in,
				

				output [XLEN-1:0] EX_CP_NPC,
				output INST EX_CP_inst,
				output [4:0] EX_CP_reg_idx,
				output [`ROB_ADDR_BITS-1:0]  EX_CP_Tag,
				output ALU_FUNC func_out,
				output logic halt_out, illegal_out, valid_out,

				output [(2*XLEN)-1:0] product,
				output done
			);
	logic [(2*XLEN)-1:0] mcand_out, mplier_out, mcand_in, mplier_in;
	logic [NUM_STAGE:0][2*XLEN-1:0] internal_mcands, internal_mpliers;
	logic [NUM_STAGE:0][2*XLEN-1:0] internal_products;
	logic [NUM_STAGE:0] internal_dones;

	// signal forwarding
	logic [NUM_STAGE:0][XLEN-1:0] internal_NPC;
	INST [NUM_STAGE:0] internal_inst;
	logic [NUM_STAGE:0][4:0] internal_reg_idx;
	logic [NUM_STAGE:0][`ROB_ADDR_BITS-1:0]  internal_Tag;
	ALU_FUNC [NUM_STAGE:0] internal_func;
	logic [NUM_STAGE:0] internal_halt;
	logic [NUM_STAGE:0] internal_illegal;
	logic [NUM_STAGE:0] internal_valid;

	assign mcand_in  = sign[0] ? {{XLEN{mcand[XLEN-1]}}, mcand}   : {{XLEN{1'b0}}, mcand} ;
	assign mplier_in = sign[1] ? {{XLEN{mplier[XLEN-1]}}, mplier} : {{XLEN{1'b0}}, mplier};

	assign internal_mcands[0]   = mcand_in;
	assign internal_mpliers[0]  = mplier_in;
	assign internal_products[0] = 'h0;
	assign internal_dones[0]    = start;

	assign done    = internal_dones[NUM_STAGE];
	assign product = internal_products[NUM_STAGE];

	assign internal_NPC[0] = IS_EX_NPC;
	assign internal_inst[0] = IS_EX_inst;
	assign internal_reg_idx[0] = IS_EX_reg_idx;
	assign internal_Tag[0] = IS_EX_Tag;
	assign internal_func[0] = func_in;
	assign internal_halt[0] = halt_in;
	assign internal_illegal[0]= illegal_in;
	assign internal_valid[0] = valid_in;

	assign EX_CP_NPC = internal_NPC[NUM_STAGE];
	assign EX_CP_inst = internal_inst[NUM_STAGE];
	assign EX_CP_reg_idx = internal_reg_idx[NUM_STAGE];
	assign EX_CP_Tag = internal_Tag[NUM_STAGE];
	assign func_out = internal_func [NUM_STAGE];
	assign halt_out = internal_halt[NUM_STAGE] ;
	assign illegal_out = internal_illegal[NUM_STAGE];
	assign valid_out = internal_valid[NUM_STAGE];

	genvar i;
	for (i = 0; i < NUM_STAGE; ++i) begin : mstage
		mult_stage #(.XLEN(XLEN), .NUM_STAGE(NUM_STAGE)) ms (
			.clock(clock),
			.reset(reset),
			.squash_in(squash_in),
			.product_in(internal_products[i]),
			.mplier_in(internal_mpliers[i]),
			.mcand_in(internal_mcands[i]),
			.start(internal_dones[i]),
			.product_out(internal_products[i+1]),
			.mplier_out(internal_mpliers[i+1]),
			.mcand_out(internal_mcands[i+1]),
			.done(internal_dones[i+1])
		);
	end

	// NPC INST Dest_reg_idx Tag passing
	genvar j;
	for (j = 0; j < NUM_STAGE; ++j) begin : signalstage
		NIDRT_stage #(.XLEN(XLEN)) nidrt_s (
			.clock(clock),
			.NPC_in(internal_NPC[j]),
			.inst_in(internal_inst[j]),
			.dest_reg_idx_in(internal_reg_idx[j]),
			.Tag_in(internal_Tag[j]),
			.func_in(internal_func[j]),
			.halt_in(internal_halt[j]),
			.illegal_in(internal_illegal[j]),
			.valid_in(internal_valid[j]),
			.NPC_out(internal_NPC[j+1]),
			.inst_out(internal_inst[j+1]),
			.dest_reg_idx_out(internal_reg_idx[j+1]),
			.Tag_out(internal_Tag[j+1]),
			.func_out(internal_func[j+1]),
			.halt_out(internal_halt[j+1]),
			.illegal_out(internal_illegal[j+1]),
			.valid_out(internal_valid[j+1])
		);
	end

endmodule

module mult_stage #(parameter XLEN = 32, parameter NUM_STAGE = 4) (
					input clock, reset, start,
					input [(2*XLEN)-1:0] mplier_in, mcand_in,
					input [(2*XLEN)-1:0] product_in,
					input squash_in,    // suqash_signal

					output logic done,
					output logic [(2*XLEN)-1:0] mplier_out, mcand_out,
					output logic [(2*XLEN)-1:0] product_out
				);

	parameter NUM_BITS = (2*XLEN)/NUM_STAGE;

	logic [(2*XLEN)-1:0] prod_in_reg, partial_prod, next_partial_product, partial_prod_unsigned;
	logic [(2*XLEN)-1:0] next_mplier, next_mcand;

	assign product_out = prod_in_reg + partial_prod;

	assign next_partial_product = mplier_in[(NUM_BITS-1):0] * mcand_in;

	assign next_mplier = {{(NUM_BITS){1'b0}},mplier_in[2*XLEN-1:(NUM_BITS)]};
	assign next_mcand  = {mcand_in[(2*XLEN-1-NUM_BITS):0],{(NUM_BITS){1'b0}}};

	always_ff @(posedge clock) begin
		prod_in_reg      <= `SD product_in;
		partial_prod     <= `SD next_partial_product;
		mplier_out       <= `SD next_mplier;
		mcand_out        <= `SD next_mcand;
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if(reset) begin
			done     <= `SD 1'b0;
		end else if (squash_in) begin
			done     <= `SD 1'b0;
		end else begin
			done     <= `SD start;
		end
	end

endmodule
//
// NPC INST Dest_reg_idx Tag SIGNAL  forwarding
//
module NIDRT_stage #(parameter XLEN = 32)(
	input clock,
	// forwarding signal
	input [XLEN-1:0] NPC_in,
	input INST inst_in,
	input [4:0] dest_reg_idx_in,
	input [`ROB_ADDR_BITS-1:0]  Tag_in,
	input ALU_FUNC func_in,
	input halt_in, illegal_in, valid_in,
	// Output
	output logic [XLEN-1:0] NPC_out,
	output INST inst_out,
	output logic [4:0] dest_reg_idx_out,
	output logic [`ROB_ADDR_BITS-1:0]  Tag_out,
	output ALU_FUNC func_out,
	output logic halt_out, illegal_out, valid_out
);
	always_ff @(posedge clock) begin
		NPC_out <= `SD NPC_in;
		inst_out <= `SD inst_in;
		dest_reg_idx_out <= `SD dest_reg_idx_in;
		Tag_out <= `SD Tag_in;
		func_out <= `SD func_in;
		halt_out <= `SD halt_in;
		illegal_out <= `SD illegal_in;
		valid_out <= `SD valid_in;
	end
endmodule

module mult_fu #(parameter XLEN = 32, parameter NUM_STAGE = 4)(
	input clock,               // system clock
	input reset,               // system reset
	input squash_in,
	input IS_EX_PACKET   is_ex_packet_in,
	output EX_CP_PACKET  ex_cp_packet_out
);
	ALU_FUNC                 func_in, func_out;
	logic [1:0]              sign; 
    logic [(2*XLEN)-1:0]    product;
    logic [XLEN-1:0]        result; 

	assign func_in = is_ex_packet_in.alu_func;

	always_comb begin
		case (func_in)
            ALU_MUL:        begin sign = 2'b11; end
            ALU_MULH:       begin sign = 2'b11; end
            ALU_MULHSU:     begin sign = 2'b01; end// opA signed, opB unsigned
            ALU_MULHU:      begin sign = 2'b00; end
			default:        begin sign = 2'b10; end  // here to prevent latches
		endcase
	end

	always_comb begin
		case (func_out)
			ALU_MUL:        begin result = product[XLEN-1:0]; end
            ALU_MULH:       begin result = product[2*XLEN-1:XLEN]; end
            ALU_MULHSU:     begin result = product[2*XLEN-1:XLEN]; end// opA signed, opB unsigned
            ALU_MULHU:      begin result = product[2*XLEN-1:XLEN]; end
			default:        begin result = `XLEN'hfacebeec;          end  // here to prevent latches
		endcase
	end

    assign ex_cp_packet_out.Value = result;   

	// signals that always be 0
	assign ex_cp_packet_out.take_branch = 1'b0;
	// assign ex_cp_packet_out.halt = is_ex_packet_in.halt;
	// assign ex_cp_packet_out.illegal = is_ex_packet_in.illegal;
	// assign ex_cp_packet_out.valid = is_ex_packet_in.valid;

	// initialize 4-stage mult
	mult #(.XLEN(XLEN), .NUM_STAGE(NUM_STAGE)) mult0 (
				// Input 
				.clock(clock), 
				.reset(reset),
				.squash_in(squash_in),
				.start(is_ex_packet_in.valid),
				.sign(sign),
				.mcand(is_ex_packet_in.rs1_value), // mcand -> opA 
				.mplier(is_ex_packet_in.rs2_value),  // mplier -> opB

				.IS_EX_NPC(is_ex_packet_in.NPC),
				.IS_EX_inst(is_ex_packet_in.inst),
				.IS_EX_reg_idx(is_ex_packet_in.dest_reg_idx),
				.IS_EX_Tag(is_ex_packet_in.Tag),
				.halt_in(is_ex_packet_in.halt),
				.illegal_in(is_ex_packet_in.illegal),
				.valid_in(is_ex_packet_in.valid),
				.func_in(func_in),
				// Output 
				.EX_CP_NPC(ex_cp_packet_out.NPC),
				.EX_CP_inst(ex_cp_packet_out.inst),
				.EX_CP_reg_idx(ex_cp_packet_out.dest_reg_idx),
				.EX_CP_Tag(ex_cp_packet_out.Tag),
				.func_out(func_out),
				.halt_out(ex_cp_packet_out.halt),
				.illegal_out(ex_cp_packet_out.illegal),
				.valid_out(ex_cp_packet_out.valid),
				.product(product),
				.done(ex_cp_packet_out.done)
			);
	
	
endmodule

`endif //__MULT_SV__
