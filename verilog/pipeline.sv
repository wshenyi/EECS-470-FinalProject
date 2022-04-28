/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  pipeline.v                                          //
//                                                                     //
//  Description :  Top-level module of the verisimple pipeline;        //
//                 This instantiates and connects the 5 stages of the  //
//                 Verisimple pipeline togeather.                      //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __PIPELINE_V__
`define __PIPELINE_V__

`timescale 1ns/100ps

module pipeline (

    input         clock,                    // System clock
    input         reset,                    // System reset
    input [3:0]   mem2proc_response,        // Tag from memory about current request
    input [63:0]  mem2proc_data,            // Data coming back from memory
    input [3:0]   mem2proc_tag,             // Tag from memory about current reply

    output BUS_COMMAND  proc2mem_command,   // command sent to memory
	output logic [`XLEN-1:0] proc2mem_addr, // Address sent to memory
	output logic [63:0] proc2mem_data,      // Data sent to memory

    output logic          [1:0]  [3:0]       pipeline_completed_insts,
    output EXCEPTION_CODE [1:0]              pipeline_error_status,
    output logic          [1:0]  [4:0]       pipeline_commit_wr_idx,
    output logic 		  [1:0]  [`XLEN-1:0] pipeline_commit_wr_data,
    output logic          [1:0]              pipeline_commit_wr_en,
    output logic          [1:0]  [`XLEN-1:0] pipeline_commit_PC,

    output DCACHE_PLANB_SET [15:0] dcache_data
    
    // testing hooks (these must be exported so we can test
    // the synthesized version) data is tested by looking at
    // the final values in memory
    
    
    // Outputs from IF-Stage 
    // output logic [`XLEN-1:0] if_NPC_out,
    // output logic [31:0] if_IR_out,
    // output logic        if_valid_inst_out,
    
    // Outputs from IF/ID Pipeline Register
    // output logic [`XLEN-1:0] if_id_NPC,
    // output logic [31:0] if_id_IR,
    // output logic        if_id_valid_inst,
    
    
    // Outputs from ID/EX Pipeline Register
    // output logic [`XLEN-1:0] id_ex_NPC,
    // output logic [31:0] id_ex_IR,
    // output logic        id_ex_valid_inst,
    
    
    // // Outputs from EX/MEM Pipeline Register
    // output logic [`XLEN-1:0] ex_mem_NPC,
    // output logic [31:0] ex_mem_IR,
    // output logic        ex_mem_valid_inst,
    
    
    // Outputs from MEM/WB Pipeline Register
    // output logic [`XLEN-1:0] mem_wb_NPC,
    // output logic [31:0] mem_wb_IR,
    // output logic        mem_wb_valid_inst
);

    // Pipeline register enables
    //logic   if_id_enable, id_ex_enable, ex_mem_enable, mem_wb_enable;
    logic   insn_enable;
    logic   ROB_enable;
    logic   RS_enable; 
    logic   is_ex_alu0_en, is_ex_alu1_en, is_ex_ld_en, is_ex_st_en,is_ex_mult_en;
    logic   ex_cp_alu0_en, ex_cp_alu1_en;

    // Outputs from I-cache
    ICACHE_IF_PACKET [1:0] Icache_IF_packet;
    logic [`XLEN-1:0] Icache2mem_addr; // goes to mem module, imem part
    BUS_COMMAND       Icache2mem_command;



    // Input for icache
    logic             mem2Icache_ack;

    // Outputs from IF-Stage
    IF_DP_PACKET     [1:0] if_ib_packet; 
    IF_DP_PACKET     [1:0] if_bp_packet;
    IF_ICACHE_PACKET [1:0] IF_Icache_packet;
    

    // Output from BP
    logic [1:0] [`XLEN-1:0] bp_pc, bp_npc;
    logic       bp_taken;
    

    // Outputs from insn_buffer
    // 2-way dispatch
    IF_DP_PACKET [1:0] ib_dp_packet;
    logic insn_full;

    // Outputs from DP stage
    DP_PACKET [1:0] dp_packet;
    logic [1:0] actual_dp_packets_count; // used by insn_buffer

    // Output from Maptable
    MT_ROB_PACKET     [1:0] MT_ROB_woTag_out;    // ROB # of rs, send to ROB 2*2
    MT_RS_PACKET      [1:0] MT_RS_wTag_out;      // ROB # and tag of rs, send to RS 2*2

    // Output from ROB
    logic         [1:0] dp_available;       // Output ROB space to tell how many space left in ROB
    ROB_RS_PACKET [1:0] ROB_RS_packet;  // At Dispatch stage, output dispatched tag and value of source reg
    ROB_MT_PACKET [1:0] ROB_MT_packet;  // At Dispatch stage, output dispatched tag
  
    // Outputs from LSQ
    logic [1:0] LSQ_dp_available;  // to dp
    logic [$clog2(`SQ_SIZE)-1:0] tail_pos_1, tail_pos_2;  // to RS
    logic lsq_ld_stall, lsq_st_stall; // to IS, mem FU
    logic [1:0] retire_disable;
    EX_CP_PACKET lsq_cp_packet;  // LSQ one way complete to cp stage
    DCACHE_PLANB_IN_PACKET LSQ_Dcache_packet; 

    // Outputs from RS
    logic leave_one_slot_empty;
    logic slot_full;
    logic [`RS_SIZE-1:0] ready;
    RS_IS_PACKET [`RS_SIZE-1:0] rs_is_packet_out;
    
    // Output from ISSUE stage
    IS_EX_PACKET    is_ex_packet_alu0, is_ex_packet_alu1, is_ex_packet_ld,is_ex_packet_st, is_ex_packet_mult;
    logic         [`RS_SIZE-1:0] free;

    // Output from IS/EX Pipeline Register
    IS_EX_PACKET is_ex_alu0, is_ex_alu1, is_ex_mult, is_ex_st, is_ex_ld;

    // Outputs from EX-Stage
    // Outputs from EX/CP Pipeline Register
    EX_CP_PACKET ex_cp_alu0, ex_cp_alu1, ex_cp_mult, ex_cp_mem; 
    EX_MEM_PACKET ex_lsq_store, ex_lsq_load; 
    EX_BP_PACKET [1:0] ex_bp_packet_out;

    // Outputs from CP stage
    CDB_PACKET [1:0]    CDB_packet;
    logic ALU0_stall_out, ALU1_stall_out;
    
    // Outputs from CP/RT Pipeline Register
    CP_RT_PACKET [1:0] cp_rt_packet;

    // Outputs from RT-Stage  (These loop back to the register file in ID)
    RT_PACKET [1:0] rt_packet;
    logic squash_signal;
    logic [`XLEN-1:0] RT_NPC;

    // Outputs from D-cache
    DCACHE_PLANB_OUT_PACKET Dcache_LSQ_packet;
    logic [`XLEN-1:0] proc2Dmem_addr; // goes to mem module, dmem part
    BUS_COMMAND proc2Dmem_command; // goes to mem module, dmem part
    logic [63:0] proc2Dmem_data; // goes to mem module, dmem part

    assign pipeline_completed_insts[0] = {3'b0, rt_packet[0].valid & ~retire_disable[0]};
    assign pipeline_error_status[0]    =  rt_packet[0].illegal ? ILLEGAL_INST :
                                          rt_packet[0].halt    ? HALTED_ON_WFI :
                                            NO_ERROR;
    
    assign pipeline_commit_wr_idx[0]  = rt_packet[0].retire_reg;
    assign pipeline_commit_wr_data[0] = rt_packet[0].value;
    assign pipeline_commit_wr_en[0]   = rt_packet[0].wr_en;

    assign pipeline_commit_PC[0]     = rt_packet[0].PC;
    

    assign pipeline_completed_insts[1] = {3'b0, rt_packet[1].valid & ~retire_disable[1]};
    assign pipeline_error_status[1]    = retire_disable[0] ? NO_ERROR :
                                        rt_packet[1].illegal ? ILLEGAL_INST :
                                        rt_packet[1].halt ? HALTED_ON_WFI  :
                                        NO_ERROR;
    
    assign pipeline_commit_wr_idx[1]  = rt_packet[1].retire_reg;
    assign pipeline_commit_wr_data[1] = rt_packet[1].value;
    assign pipeline_commit_wr_en[1]   = rt_packet[1].wr_en;

    assign pipeline_commit_PC[1]     = rt_packet[1].PC;

    // // From mem.sv, resolved to feed to icache/dcache separately.
    // logic [3:0] Imem2proc_response, Dmem2proc_response;
    // // If this cycle Dmem has insn, then mask response to Imem to 0
    // // So that icache knows it failed to request in this cycle.
    // // Vice versa for dcache.
    // assign Imem2proc_response =
    //      (Dcache2mem_command == BUS_NONE) ? mem2proc_response : 0;
    // assign Dmem2proc_response = 
    //      (Dcache2mem_command == BUS_NONE) ? 0 : mem2proc_response;

    assign mem2Icache_ack = (|mem2proc_response) && (|Icache2mem_command) && (!proc2Dmem_command);

    // We don't have proc2mem_size anymore! We are in CACHE_MODE!
    // Dmem insns supersedes Imem. If Dmem isn't requesting in this cycle,
    // just feed a BUS_LOAD to mem module 
    // (Instead of a BUS_NONE, which will cause mem response == 0)
    assign proc2mem_command = (proc2Dmem_command == BUS_NONE) ? Icache2mem_command : proc2Dmem_command;
    assign proc2mem_addr = (proc2Dmem_command == BUS_NONE) ? Icache2mem_addr : proc2Dmem_addr;
    // Imem/Icache can never write to memory.
    assign proc2mem_data = proc2Dmem_data;


//////////////////////////////////////////////////
//                                              //
//                  I-CACHE                     //
//                                              //
//////////////////////////////////////////////////

    icache icache_0(
        // Inputs
        .clock(clock),
        .reset(reset),
        .squash_en(squash_signal),
        .mem2Icache_response_in(mem2proc_response),  // from mem, note the "I"
        .mem2Icache_data_in(mem2proc_data),    // from mem
        .mem2Icache_tag_in(mem2proc_tag),    // from mem
        .mem2Icache_ack_in(mem2Icache_ack),
        .IF_Icache_packet_in(IF_Icache_packet),

        // Outputs
        .Icache2mem_command_out(Icache2mem_command),  // output to mem
        .Icache2mem_addr_out(Icache2mem_addr),    // output to mem
        .Icache_IF_packet_out(Icache_IF_packet)
    );

//////////////////////////////////////////////////
//                                              //
//                  D-CACHE                     //
//                                              //
//////////////////////////////////////////////////

    dcache_planb dcache_0(
        // Inputs
        .clock(clock),
        .reset(reset),
        .Dmem2proc_response(mem2proc_response),  // from mem, note the "I"
        .Dmem2proc_data(mem2proc_data),    // from mem
        .Dmem2proc_tag(mem2proc_tag),    // from mem
        .dcache_in(LSQ_Dcache_packet),

        // Outputs
        .proc2Dmem_addr(proc2Dmem_addr),  // output to mem
        .proc2Dmem_data(proc2Dmem_data),    // output to mem
        .proc2Dmem_command(proc2Dmem_command),
        .dcache_out(Dcache_LSQ_packet),

        // Only used by testbench.sv,
        // when WFI, flushing all Dcache content into memory
        .cache_data(dcache_data)
    );

//////////////////////////////////////////////////
//                                              //
//                  IF-Stage                    //
//                                              //
//////////////////////////////////////////////////

    if_stage if_stage_0(
        // Inputs
        .clock(clock),    // system clock
        .reset(reset),    // system reset
        .dp_stall(insn_full),
        .bp_pc(bp_pc),
        .bp_npc(bp_npc),
        .squash_en(squash_signal), // from retire stage
        .squashed_new_PC_in(RT_NPC), // from retire stage
        .icache_if_packet_in(Icache_IF_packet),
        .bp_taken(bp_taken),

        // Outputs
        .if_icache_packet_out(IF_Icache_packet), // to icache
        .if_bp_packet_out(if_bp_packet),
        .if_dp_packet_out(if_ib_packet) // to insn_fifo
    );

//////////////////////////////////////////////////
//                                              //
//                  Branch_prediction           //
//                                              //
//////////////////////////////////////////////////
    
    BP_top bp(
        .clock(clock),
        .reset(reset),
        .ex_bp_packet_in(ex_bp_packet_out),
        // .squash_en(squash_signal),
        .if_pc_in({if_bp_packet[1].PC, if_bp_packet[0].PC}),    //pc from if stage
        .inst({if_bp_packet[1].inst, if_bp_packet[0].inst}),    // instruction
        .valid({if_bp_packet[1].valid, if_bp_packet[0].valid}),
        // output
        .bp_pc_out(bp_pc),
        .bp_npc_out(bp_npc),
        .bp_taken(bp_taken)
    );


//////////////////////////////////////////////////
//                                              //
//            IF/DP Pipeline Register           //
//                                              //
//////////////////////////////////////////////////
    assign insn_enable = 1'b1;

	insn_buffer inst_buffer_0(
        .clock(clock),
        .reset(reset),
        .enable(insn_enable),
        .dp_packet_count_in(actual_dp_packets_count), // from DP-stage
        .squash_in(squash_signal),    // from retire stage
        .if_dp_packet_in(if_ib_packet),    // from insn_buffer
        
        // Output 
        .if_dp_packet_out(ib_dp_packet),    // going to dp stage
        .buffer_full(insn_full)
    );

   
//////////////////////////////////////////////////
//                                              //
//                  DP-Stage                    //
//                                              //
//////////////////////////////////////////////////
	
	dp_stage dp_stage_0 (
		// Inputs
		.clock(clock),
		.reset(reset),
		.rt_packet(rt_packet), // connect to ROB.RT_PACKET_out
		.if_dp_packet_in(ib_dp_packet),
		.slots_left_rob_in(dp_available), // connect to ROB.dp_available
		.slots_1_rs_in(leave_one_slot_empty), // connect to RS.leave_one_slot_empty
		.slots_0_rs_in(slot_full), // connect to RS.slot_full
        .slots_left_lsq_in(LSQ_dp_available), // connect to LSQ.dp_available
		
		// Outputs
		.dp_packet_out(dp_packet), // going down to RS, ROB, MapTable
		.dp_packet_count_out(actual_dp_packets_count) // going up to insn_buffer
	);
//////////////////////////////////////////////////
//                                              //
//                 Maptale                      //
//                                              //
//////////////////////////////////////////////////

     maptable maptable(
        // Inputs
        .clock              (clock), 
        .reset              (reset | squash_signal), 
        .DP_packet_in       (dp_packet),
        .RT_packet_in       (rt_packet),
        .ROB_DP_packet_in   (ROB_MT_packet),
        .CDB_packet_in      (CDB_packet),
        // Outputs
        .MT_ROB_woTag_out   (MT_ROB_woTag_out),    // going to ROB
        .MT_RS_wTag_out     (MT_RS_wTag_out)    // going to RS
    );

//////////////////////////////////////////////////
//                                              //
//                 ROB                          //
//                                              //
//////////////////////////////////////////////////

    assign ROB_enable = 1'b1;
    ROB rob(
        //Inputs
        .reset  (reset),
        .clock  (clock),
        .enable (ROB_enable),
        .squash_signal(squash_signal),    // squash signal in
        .retire_disable(retire_disable), // from LSQ
        .CDB_packet_in(CDB_packet),    // from CDB
        .DP_packet_in(dp_packet),    // From dispatch stage
        .MT_ROB_packet_in(MT_ROB_woTag_out),    // From Maptable
        //Outputs
        .dp_available(dp_available),    // going to DP_stage
        .CP_RT_packet_out(cp_rt_packet),    // going to retire stage
        .ROB_RS_packet_out(ROB_RS_packet),  // going to RS
        .ROB_MT_packet_out(ROB_MT_packet)    // going to maptable
    );

//////////////////////////////////////////////////
//                                              //
//                  LSQ                         //
//                                              //
//////////////////////////////////////////////////

    lsq lsq(
        // input
        .clock(clock),
        .reset(reset),
        .squash(squash_signal),
        // from dispatch signals
        .dp_packet_in(dp_packet),
        // from execute signals
        .ex_cp_mem_in_ld(ex_lsq_load),
        .ex_cp_mem_in_st(ex_lsq_store),
        // from cache
        .dcache_lsq_packet_in(Dcache_LSQ_packet),
        // from retire signals
        .rt_packet_in(rt_packet),

        //output
        // to dispatch
        .dp_available(LSQ_dp_available),
        // to RS
        .tail_pos_1(tail_pos_1), 
        .tail_pos_2(tail_pos_2), 
        .ld_stall_out(lsq_ld_stall), // to IS, mem FU
        .st_stall_out(lsq_st_stall),
        // to complete
        .lsq_cp_packet_out(lsq_cp_packet), // output port not defined in lsq yet
        // to dcache
        .lsq_dcache_packet_out(LSQ_Dcache_packet),
        .retire_disable(retire_disable)
    );

//////////////////////////////////////////////////
//                                              //
//                  RS                          //
//                                              //
//////////////////////////////////////////////////

    assign RS_enable = 1'b1;
    RS Rs_0 ( 
            // Input
            .clock(clock),
            .reset(reset),
            .enable(RS_enable),
            .squash_signal_in(squash_signal), // connect to retire stage squash_signal_out
            .mt_rs_in(MT_RS_wTag_out),  // From Maptable
            .dp_packet_in(dp_packet),  // From dipatch stage
            .rob_in(ROB_RS_packet),  // From ROB
            .cdb_in(CDB_packet),  // From CDB
            .free(free),  // From ISSUE stage
            // Inputs from lsq
            .tail_pos_1(tail_pos_1), 
            .tail_pos_2(tail_pos_2),             
            // Output 
            .leave_one_slot_empty(leave_one_slot_empty),  // going to Instructure buffer
            .slot_full(slot_full),  // going to Instructure buffer
            .RS_OUT(rs_is_packet_out),  // going to issue stage
            .ready(ready)  // going to issue stage
            );

//////////////////////////////////////////////////
//                                              //
//                  IS-Stage                    //
//                                              //
//////////////////////////////////////////////////
    
    issue  is_0(
        //Input
        .rs_is_packet_in(rs_is_packet_out),  // From RS 
        .req(ready),                         // From RS
        .ALU0_stall_in(ALU0_stall_out),       // From complete stage
        .ALU1_stall_in(ALU1_stall_out),       // From complete stage
        .ld_stall_in(lsq_ld_stall),           // from lsq
        .st_stall_in(lsq_st_stall),
        //Output
        .is_ex_packet_alu0(is_ex_packet_alu0),    // going to is_ex_alu0 reg
        .is_ex_packet_alu1(is_ex_packet_alu1),    // going to is_ex_alu1 reg
        .is_ex_packet_mult(is_ex_packet_mult),    // going to is_ex_mult reg
        .is_ex_packet_ld(is_ex_packet_ld),    // going to is_ex_mem reg
        .is_ex_packet_st(is_ex_packet_st),
        .free(free)    // going to RS stage
    );


//////////////////////////////////////////////////
//                                              //
//            IS/EX Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

	// assign is_ex_NPC        = is_ex_packet.NPC;
	// assign is_ex_IR         = is_ex_packet.inst;
	// assign is_ex_valid_inst = is_ex_packet.valid;

	// assign is_ex_enable = 1'b1; // always enabled
	// synopsys sync_set_reset "reset"
	assign is_ex_alu0_en = ~ALU0_stall_out;    // From cp stage
	assign is_ex_alu1_en = ~ALU1_stall_out;    // From cp stage
	assign is_ex_mult_en = 1'b1;    // always enable
	assign is_ex_st_en  = ~lsq_st_stall;    
    assign is_ex_ld_en  = ~lsq_ld_stall;
	
    // synopsys sync_set_reset "reset"
	always_ff @(posedge clock) begin
		if (reset) begin
			is_ex_alu0 <= `SD '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},     //PC
				{`XLEN{1'b0}},     // REG A
				{`XLEN{1'b0}},     // REG B
				OPA_IS_RS1,    
				OPB_IS_RS2, 
				`NOP,
				`ZERO_REG,
				ALU_ADD, 
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0,  //valid
				{`ROB_ADDR_BITS{1'b0}},    //Tag
                {($clog2(`SQ_SIZE)){1'b0}}
			}; 
		end else if (squash_signal) begin
			is_ex_alu0 <= `SD '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},     //PC
				{`XLEN{1'b0}},     // REG A
				{`XLEN{1'b0}},     // REG B
				OPA_IS_RS1,    
				OPB_IS_RS2, 
				`NOP,
				`ZERO_REG,
				ALU_ADD, 
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0,  //valid
				{`ROB_ADDR_BITS{1'b0}},    //Tag
                {($clog2(`SQ_SIZE)){1'b0}}
			}; 
		end else begin // if (reset)
			if (is_ex_alu0_en) begin
				is_ex_alu0 <= `SD is_ex_packet_alu0;
			end // if
		end // else: !if(reset)
	end // always

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
		if (reset) begin
			is_ex_alu1 <= `SD '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},     //PC
				{`XLEN{1'b0}},     // REG A
				{`XLEN{1'b0}},     // REG B
				OPA_IS_RS1,    
				OPB_IS_RS2, 
				`NOP,
				`ZERO_REG,
				ALU_ADD, 
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0,  //valid
				{`ROB_ADDR_BITS{1'b0}},    //Tag
                {($clog2(`SQ_SIZE)){1'b0}}
			}; 
		end else if (squash_signal) begin
			is_ex_alu1 <= `SD '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},     //PC
				{`XLEN{1'b0}},     // REG A
				{`XLEN{1'b0}},     // REG B
				OPA_IS_RS1,    
				OPB_IS_RS2, 
				`NOP,
				`ZERO_REG,
				ALU_ADD, 
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0,  //valid
				{`ROB_ADDR_BITS{1'b0}},    //Tag
                {($clog2(`SQ_SIZE)){1'b0}}
			}; 
		end else begin // if (reset)
			if (is_ex_alu1_en) begin
				is_ex_alu1 <= `SD is_ex_packet_alu1;
			end // if
		end // else: !if(reset)
	end // always

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
		if (reset) begin
			is_ex_mult <= `SD '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},     //PC
				{`XLEN{1'b0}},     // REG A
				{`XLEN{1'b0}},     // REG B
				OPA_IS_RS1,    
				OPB_IS_RS2, 
				`NOP,
				`ZERO_REG,
				ALU_ADD, 
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0,  //valid
				{`ROB_ADDR_BITS{1'b0}},    //Tag
                {($clog2(`SQ_SIZE)){1'b0}}
			}; 
		end else if (squash_signal) begin
			is_ex_mult <= `SD '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},     //PC
				{`XLEN{1'b0}},     // REG A
				{`XLEN{1'b0}},     // REG B
				OPA_IS_RS1,    
				OPB_IS_RS2, 
				`NOP,
				`ZERO_REG,
				ALU_ADD, 
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0,  //valid
				{`ROB_ADDR_BITS{1'b0}},    //Tag
                {($clog2(`SQ_SIZE)){1'b0}}
			}; 
		end else begin // if (reset)
			if (is_ex_mult_en) begin
				is_ex_mult <= `SD is_ex_packet_mult;
			end // if
		end // else: !if(reset)
	end // always

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
		if (reset) begin
			is_ex_ld <= `SD '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},     //PC
				{`XLEN{1'b0}},     // REG A
				{`XLEN{1'b0}},     // REG B
				OPA_IS_RS1,    
				OPB_IS_RS2, 
				`NOP,
				`ZERO_REG,
				ALU_ADD, 
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0,  //valid
				{`ROB_ADDR_BITS{1'b0}},    //Tag
                {($clog2(`SQ_SIZE)){1'b0}}
			}; 
		end else if (squash_signal) begin
			is_ex_ld <= `SD '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},     //PC
				{`XLEN{1'b0}},     // REG A
				{`XLEN{1'b0}},     // REG B
				OPA_IS_RS1,    
				OPB_IS_RS2, 
				`NOP,
				`ZERO_REG,
				ALU_ADD, 
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0,  //valid
				{`ROB_ADDR_BITS{1'b0}},    //Tag
                {($clog2(`SQ_SIZE)){1'b0}}
			}; 
		end else begin // if (reset)
			if (is_ex_ld_en) begin
				is_ex_ld <= `SD is_ex_packet_ld;
			end // if
		end // else: !if(reset)
	end // always

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
		if (reset) begin
			is_ex_st <= `SD '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},     //PC
				{`XLEN{1'b0}},     // REG A
				{`XLEN{1'b0}},     // REG B
				OPA_IS_RS1,    
				OPB_IS_RS2, 
				`NOP,
				`ZERO_REG,
				ALU_ADD, 
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0,  //valid
				{`ROB_ADDR_BITS{1'b0}},    //Tag
                {($clog2(`SQ_SIZE)){1'b0}}
			}; 
		end else if (squash_signal) begin
			is_ex_st <= `SD '{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},     //PC
				{`XLEN{1'b0}},     // REG A
				{`XLEN{1'b0}},     // REG B
				OPA_IS_RS1,    
				OPB_IS_RS2, 
				`NOP,
				`ZERO_REG,
				ALU_ADD, 
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b0,  //valid
				{`ROB_ADDR_BITS{1'b0}},    //Tag
                {($clog2(`SQ_SIZE)){1'b0}}
			}; 
		end else begin // if (reset)
			if (is_ex_st_en) begin
				is_ex_st <= `SD is_ex_packet_st;
			end // if
		end // else: !if(reset)
	end // always

//////////////////////////////////////////////////
//                                              //
//                  EX-Stage                    //
//                                              //
//           EX/CP Pipeline Register           //
//                                              //
//////////////////////////////////////////////////

    assign ex_cp_alu0_en = ~ ALU0_stall_out;    // From cp stage
    assign ex_cp_alu1_en = ~ ALU1_stall_out;    // From cp stage

    ex_stage ex0(
        // Inputs
        .clock(clock),
        .reset(reset),
        .squash_in(squash_signal),  // connect to retire squash_signal_out
        .ex_cp_alu0_en(ex_cp_alu0_en),   // alu0 ex_cp pipeline register enable 
        .ex_cp_alu1_en(ex_cp_alu1_en),    // alu1 ex_cp pipeline register enable 
        .is_ex_alu0(is_ex_alu0),    // from IS/EX pipeline reg
        .is_ex_alu1(is_ex_alu1),    // from IS/EX pipeline reg
        .is_ex_st(is_ex_st),    // from IS/EX pipeline reg
        .is_ex_ld(is_ex_ld),
        .is_ex_mult(is_ex_mult),    // from IS/EX pipeline reg
        .lsq_cp_packet_in(lsq_cp_packet), // from LSQ
        // Output 
        .ex_cp_alu0(ex_cp_alu0),    // going to CP stage
        .ex_cp_alu1(ex_cp_alu1),    // going to CP stage
        .ex_cp_mult(ex_cp_mult),    // going to CP stage
        .ex_cp_mem(ex_cp_mem),      // going to CP stage
        .ex_lsq_store_out(ex_lsq_store),        // to lsq
        .ex_lsq_load_out(ex_lsq_load),         // to lsq
        .ex_bp_packet_out(ex_bp_packet_out)     // going to CP stage
        );    
    

//////////////////////////////////////////////////
//                                              //
//                  CP-Stage                    //
//                                              //
//////////////////////////////////////////////////
    // mem_stage mem_stage_0 (
    // 	// Inputs
    // 	.clock(clock),
    // 	.reset(reset),
    // 	.ex_mem_packet_in(ex_mem_packet),
    // 	.Dmem2proc_data(mem2proc_data[`XLEN-1:0]),
        
    // 	// Outputs
    // 	.mem_result_out(mem_result_out),
    // 	.Dcache2mem_command(Dcache2mem_command),
    // 	.proc2Dmem_size(proc2Dmem_size),
    // 	.Dcache2mem_addr(Dcache2mem_addr),
    // 	.proc2Dmem_data(proc2Dmem_data)
    // );
    cp_stage cp_stage_0(
        //Input
        .ex_cp_packet_alu0(ex_cp_alu0),    // From EX/CP_alu0 reg
        .ex_cp_packet_alu1(ex_cp_alu1),    // From EX/CP_alu1 reg
        .ex_cp_packet_mult(ex_cp_mult),    // From EX/CP_mult reg
        .ex_cp_packet_mem(ex_cp_mem),    // From EX/CP_mem reg
        //Output
        .cdb_packet_out(CDB_packet),    // going to CDB
        .ALU0_stall_out(ALU0_stall_out),    // going to EX/CP_alu0 reg and IS/EX_alu0 reg
        .ALU1_stall_out(ALU1_stall_out)    // going to EX/CP_alu1 reg and IS/EX_alu1 reg
    );

//////////////////////////////////////////////////
//                                              //
//                  RT-Stage                    //
//                                              //
//////////////////////////////////////////////////
    rt_stage rt_stage_0(
        // Inputs
        .CP_RT_packet_in(cp_rt_packet),
        .retire_disable(retire_disable),
        //Outputs
        .RT_packet_out(rt_packet),
        .squash_signal_out(squash_signal),
        .RT_NPC(RT_NPC)
    );

endmodule  // module verisimple
`endif // __PIPELINE_V__
