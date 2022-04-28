/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  sys_defs.vh                                         //
//                                                                     //
//  Description :  This file has the macro-defines for macros used in  //
//                 the pipeline design.                                //
//                                                                     //
/////////////////////////////////////////////////////////////////////////


`ifndef __SYS_DEFS_VH__
`define __SYS_DEFS_VH__

// `define DEBUG

/* Synthesis testing definition, used in DUT module instantiation */

`ifdef  SYNTH_TEST
`define DUT(mod) mod``_svsim
`else
`define DUT(mod) mod
`endif

//////////////////////////////////////////////
//
// Size attribute definitions
//
//////////////////////////////////////////////

`define ROB_SIZE 32
`define IF_SIZE 2
`define DP_SIZE 2
`define RT_SIZE 2
`define CDB_SIZE 2 // Complete size
`define RS_SIZE 16
`define RS_ADDR_BITS $clog2(`RS_SIZE)
`define ROB_ADDR_BITS $clog2(`ROB_SIZE)
// ximin debug
`define SQ_SIZE 8
`define CACHE_LINE 32
`define CACHE_LINE_BITS $clog2(`CACHE_LINE)

//////////////////////////////////////////////
//
// Memory/testbench attribute definitions
//
//////////////////////////////////////////////
`define CACHE_MODE //removes the byte-level interface from the memory mode, DO NOT MODIFY!
`define NUM_MEM_TAGS           15

`define MEM_SIZE_IN_BYTES      (64*1024)
`define MEM_64BIT_LINES        (`MEM_SIZE_IN_BYTES/8)

//you can change the clock period to whatever, 10 is just fine
`define VERILOG_CLOCK_PERIOD   10.0
`define SYNTH_CLOCK_PERIOD     15 // Clock period for synth and memory latency

`define MEM_LATENCY_IN_CYCLES (100.0/`SYNTH_CLOCK_PERIOD+0.49999)
// the 0.49999 is to force ceiling(100/period).  The default behavior for
// float to integer conversion is rounding to nearest

typedef union packed {
    logic [7:0][7:0] byte_level;
    logic [3:0][15:0] half_level;
    logic [1:0][31:0] word_level;
} EXAMPLE_CACHE_BLOCK;

//////////////////////////////////////////////
// Exception codes
// This mostly follows the RISC-V Privileged spec
// except a few add-ons for our infrastructure
// The majority of them won't be used, but it's
// good to know what they are
//////////////////////////////////////////////

typedef enum logic [3:0] {
	INST_ADDR_MISALIGN  = 4'h0,
	INST_ACCESS_FAULT   = 4'h1,
	ILLEGAL_INST        = 4'h2,
	BREAKPOINT          = 4'h3,
	LOAD_ADDR_MISALIGN  = 4'h4,
	LOAD_ACCESS_FAULT   = 4'h5,
	STORE_ADDR_MISALIGN = 4'h6,
	STORE_ACCESS_FAULT  = 4'h7,
	ECALL_U_MODE        = 4'h8,
	ECALL_S_MODE        = 4'h9,
	NO_ERROR            = 4'ha, //a reserved code that we modified for our purpose
	ECALL_M_MODE        = 4'hb,
	INST_PAGE_FAULT     = 4'hc,
	LOAD_PAGE_FAULT     = 4'hd,
	HALTED_ON_WFI       = 4'he, //another reserved code that we used
	STORE_PAGE_FAULT    = 4'hf
} EXCEPTION_CODE;


/////////////
//////////////////////////////////////////////

//
// ALU opA input mux selects
//
typedef enum logic [1:0] {
	OPA_IS_RS1  = 2'h0,
	OPA_IS_NPC  = 2'h1,
	OPA_IS_PC   = 2'h2,
	OPA_IS_ZERO = 2'h3
} ALU_OPA_SELECT;

//
// ALU opB input mux selects
//
typedef enum logic [3:0] {
	OPB_IS_RS2    = 4'h0,
	OPB_IS_I_IMM  = 4'h1,
	OPB_IS_S_IMM  = 4'h2,
	OPB_IS_B_IMM  = 4'h3,
	OPB_IS_U_IMM  = 4'h4,
	OPB_IS_J_IMM  = 4'h5
} ALU_OPB_SELECT;

//
// Destination register select
//
typedef enum logic [1:0] {
	DEST_RD = 2'h0,
	DEST_NONE  = 2'h1
} DEST_REG_SEL;

//
// ALU function code input
// probably want to leave these alone
//
typedef enum logic [4:0] {
	ALU_ADD     = 5'h00,
	ALU_SUB     = 5'h01,
	ALU_SLT     = 5'h02,
	ALU_SLTU    = 5'h03,
	ALU_AND     = 5'h04,
	ALU_OR      = 5'h05,
	ALU_XOR     = 5'h06,
	ALU_SLL     = 5'h07,
	ALU_SRL     = 5'h08,
	ALU_SRA     = 5'h09,
	ALU_MUL     = 5'h0a,
	ALU_MULH    = 5'h0b,
	ALU_MULHSU  = 5'h0c,
	ALU_MULHU   = 5'h0d,
	ALU_DIV     = 5'h0e,
	ALU_DIVU    = 5'h0f,
	ALU_REM     = 5'h10,
	ALU_REMU    = 5'h11
} ALU_FUNC;

//
// function unit 
//
typedef enum logic [1:0] {
	FUNC_NOP    = 2'h0,    // no instruction free, DO NOT USE THIS AS DEFAULT CASE!
	FUNC_ALU    = 2'h1,    // all of the instruction  except mult and load and store
	FUNC_MULT   = 2'h2,    // mult 
	FUNC_MEM    = 2'h3     // load and store
}FUNC_UNIT;

//////////////////////////////////////////////
//
// Assorted things it is not wise to change
//
//////////////////////////////////////////////

//
// actually, you might have to change this if you change VERILOG_CLOCK_PERIOD
// JK you don't ^^^
//
`define SD #1


// the RISCV register file zero register, any read of this register always
// returns a zero value, and any write to this register is thrown away
//
`define ZERO_REG 5'd0

//
// Memory bus commands control signals
//
typedef enum logic [1:0] {
	BUS_NONE     = 2'h0,
	BUS_LOAD     = 2'h1,
	BUS_STORE    = 2'h2
} BUS_COMMAND;

typedef enum logic [1:0] {
	BYTE = 2'h0,
	HALF = 2'h1,
	WORD = 2'h2,
	DOUBLE = 2'h3
} MEM_SIZE;

//
// useful boolean single-bit definitions
//
`define FALSE  1'h0
`define TRUE  1'h1

// RISCV ISA SPEC
`define XLEN 32
typedef union packed {
	logic [31:0] inst;
	struct packed {
		logic [6:0] funct7;
		logic [4:0] rs2;
		logic [4:0] rs1;
		logic [2:0] funct3;
		logic [4:0] rd;
		logic [6:0] opcode;
	} r; //register to register instructions
	struct packed {
		logic [11:0] imm;
		logic [4:0]  rs1; //base
		logic [2:0]  funct3;
		logic [4:0]  rd;  //dest
		logic [6:0]  opcode;
	} i; //immediate or load instructions
	struct packed {
		logic [6:0] off; //offset[11:5] for calculating address
		logic [4:0] rs2; //source
		logic [4:0] rs1; //base
		logic [2:0] funct3;
		logic [4:0] set; //offset[4:0] for calculating address
		logic [6:0] opcode;
	} s; //store instructions
	struct packed {
		logic       of; //offset[12]
		logic [5:0] s;  //offset[10:5]
		logic [4:0] rs2;//source 2
		logic [4:0] rs1;//source 1
		logic [2:0] funct3;
		logic [3:0] et; //offset[4:1]
		logic       f;  //offset[11]
		logic [6:0] opcode;
	} b; //branch instructions
	struct packed {
		logic [19:0] imm;
		logic [4:0]  rd;
		logic [6:0]  opcode;
	} u; //upper immediate instructions
	struct packed {
		logic       of; //offset[20]
		logic [9:0] et; //offset[10:1]
		logic       s;  //offset[11]
		logic [7:0] f;	//offset[19:12]
		logic [4:0] rd; //dest
		logic [6:0] opcode;
	} j;  //jump instructions
`ifdef ATOMIC_EXT
	struct packed {
		logic [4:0] funct5;
		logic       aq;
		logic       rl;
		logic [4:0] rs2;
		logic [6:0] op;
		logic [4:0] rs1;
		logic [2:0] funct3;
		logic [4:0] rd;
		logic [6:0] opcode;
	} a; //atomic instructions
`endif
`ifdef SYSTEM_EXT
	struct packed {
		logic [11:0] csr;
		logic [4:0]  rs1;
		logic [2:0]  funct3;
		logic [4:0]  rd;
		logic [6:0]  opcode;
	} sys; //system call instructions
`endif

} INST; //instruction typedef, this should cover all types of instructions

//
// Basic NOP instruction.  Allows pipline registers to clearly be reset with
// an instruction that does nothing instead of Zero which is really an ADDI x0, x0, 0
//
`define NOP 32'h00000013

//////////////////////////////////////////////
//
// BTB section
//
//////////////////////////////////////////////

`define BTB_SIZE 256
`define TAG_SIZE 10
`define VAL_SIZE 12

//////////////////////////////////////////////
//
// BHT section
//
//////////////////////////////////////////////
   
`define BHT_SIZE 256
`define BHT_WIDTH $clog2(`H_SIZE)

//////////////////////////////////////////////
//
// PHT section
//
//////////////////////////////////////////////

`define H_SIZE 8
`define PHT_SIZE 256
typedef enum logic [1:0]{
	NT_STRONG  = 2'h0,    // assume branch taken strong
	NT_WEAK    = 2'h1,    // assume branch taken weak
	T_WEAK     = 2'h2,
	T_STRONG   = 2'h3    // assume branch no taken
}PHT_STATE;

//////////////////////////////////////////////
//
// RAS section
//
//////////////////////////////////////////////

`define RAS_SIZE 8

//////////////////////////////////////////////
//
// IF Packets:
// Data that is exchanged between the IF and the ID stages  
//
//////////////////////////////////////////////

typedef struct packed {
	logic valid; // If low, the data in this struct is garbage
    INST  inst;  // fetched instruction out
	logic [`XLEN-1:0] NPC; // PC + 4
	logic [`XLEN-1:0] PC;  // PC 
} IF_DP_PACKET;

typedef struct packed {
	logic [`XLEN-1:0] Icache_addr_in;
	logic             Icache_request;
} IF_ICACHE_PACKET;

//////////////////////////////////////////////
//
// Dispatch stage section
//
////////////////////////////////////////////// 

`define INSN_BUFFER_BITS 3
`define INSN_BUFFER_SIZE 16

//////////////////////////////////////////////
//
// ID Packets:
// Data that is exchanged from ID to EX stage
//
//////////////////////////////////////////////

typedef struct packed {
	logic [`XLEN-1:0] NPC;   // PC + 4
	logic [`XLEN-1:0] PC;    // PC

	logic [`XLEN-1:0] rs1_value;    // reg A value                                  
	logic [`XLEN-1:0] rs2_value;    // reg B value                                  
	                                                                                
	ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
	ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)
	INST inst;                 // instruction
	
	logic [4:0] dest_reg_idx;  // destination (writeback) register index      
	ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)
	logic       rd_mem;        // does inst read memory?
	logic       wr_mem;        // does inst write memory?
	logic       cond_branch;   // is inst a conditional branch?
	logic       uncond_branch; // is inst an unconditional branch?
	logic       halt;          // is this a halt?
	logic       illegal;       // is this instruction illegal?
	logic       csr_op;        // is this a CSR operation? (we only used this as a cheap way to get return code)
	logic       valid;         // is inst a valid instruction to be counted for CPI calculations?
} ID_EX_PACKET;

//////////////////////////////////////////////
//
// EX Packets:
// Data that is exchanged from EX to MEM stage
//
//////////////////////////////////////////////

typedef struct packed {
	logic [`XLEN-1:0] alu_result;  // alu_result
//	logic             take_branch; // is this a taken branch?
	//pass throughs from decode stage
	logic [`XLEN-1:0] NPC;         // pc + 4
    INST              inst; // forwarded
	logic [`XLEN-1:0] rs2_value;
	logic             rd_mem, wr_mem;
	logic [4:0]       dest_reg_idx;
	logic             halt, illegal, csr_op, valid;
	logic [2:0]       mem_size;    // byte, half-word or word

	// ximin
	// store queue position
	logic [$clog2(`SQ_SIZE)-1:0] sq_pos;
	// ROB tag
	logic [`ROB_ADDR_BITS-1:0]  Tag;
} EX_MEM_PACKET;

//////////////////////////////////////////////
//
// Cache Section:
//
//////////////////////////////////////////////

`define ICACHE_WAY 2
`define ICACHE_LINE_NUM  (`CACHE_LINE/`ICACHE_WAY)
`define ICACHE_TAG_WIDTH (13-$clog2(`ICACHE_LINE_NUM))

`define DCACHE_WAY 1
`define DCACHE_LINE_NUM  (`CACHE_LINE/`DCACHE_WAY)
`define DCACHE_TAG_WIDTH (13-$clog2(`DCACHE_LINE_NUM))

typedef struct packed {
	logic [63:0] data;
	logic [8:0] tag;
	logic		 valid;
	logic		 dirty;
} CACHE_LINE;

typedef enum logic [1:0] {
	IDLE = 2'b00,
	LOAD = 2'b01,
	PREF = 2'b10
} PREFETCH_STATE;

typedef struct packed {
	logic [`XLEN-1:0] Icache_data_out;
	logic             Icache_hit;
	logic             Icache_valid_out;
} ICACHE_IF_PACKET;

//////////////////////////////////////////////
//
// ROB Section:
//
//////////////////////////////////////////////

typedef struct packed {
	logic [4:0] 		reg_idx; 
    logic [`XLEN-1:0]	value; // computing result from ex stage
	logic 				cp_bit;    // If current insn is complete
	logic				ep_bit;    // If current insn trigger exception
	logic [`XLEN-1:0]	NPC;
	logic [`XLEN-1:0]	PC;
	logic             	halt, illegal; // forwarded
	logic             	valid;    	// Used for CPI calculation
    logic               wr_mem; 		// forwarded
} ROB_ENTRY;

typedef struct packed {
	logic [$clog2(`ROB_SIZE)-1:0] Tag; 
    logic [`XLEN-1:0]             rs1_value, rs2_value;
} ROB_RS_PACKET;

typedef struct packed {
	// logic [4:0]					  dest_reg_idx; 
	logic [$clog2(`ROB_SIZE)-1:0] Tag;  
} ROB_MT_PACKET;     // used for dispatch

//////////////////////////////////////////////
//
// MapTable Section:
//
//////////////////////////////////////////////

typedef struct packed {
	logic [$clog2(`ROB_SIZE)-1:0]  RegS1_Tag;
	logic [$clog2(`ROB_SIZE)-1:0]  RegS2_Tag; 
	logic [1:0]					   valid_vector; // not valid means no #ROB
} MT_ROB_PACKET; //to ROB

typedef struct packed {
	logic						  Tag1_ready_in_rob; // plus sign
	logic						  Tag2_ready_in_rob;
	logic						  Tag1_valid;        //1 if the value of tag1 is valid, if ROB# exists
	logic						  Tag2_valid;
    logic [$clog2(`ROB_SIZE)-1:0] Tag1; 
    logic [$clog2(`ROB_SIZE)-1:0] Tag2;
} MT_RS_PACKET; //to RS

`define Not_Ready 2'b01    // plus sign, ROB valid
`define Ready_in_ROB 2'b11
`define Ready_in_RF 2'b00

//////////////////////////////////////////////
//
// DP Packets:
// Data that is sent to ROB, RS, and Map Table at DP stage
//
//////////////////////////////////////////////

typedef struct packed {
	logic [`XLEN-1:0] NPC;     // PC + 4
	logic [`XLEN-1:0] PC;      // PC          

	logic [`XLEN-1:0] rs1_value;    // reg A value                                  
	logic [`XLEN-1:0] rs2_value;    // reg B value   

	ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
	ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)
	INST inst;                 // instruction
	
	logic [4:0] dest_reg_idx;  // destination (writeback) register index      
	ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)
	logic       rd_mem;        // does inst read memory?
	logic       wr_mem;        // does inst write memory?
	logic       cond_branch;   // is inst a conditional branch?
	logic       uncond_branch; // is inst an unconditional branch?
	logic       halt;          // is this a halt?
	logic       illegal;       // is this instruction illegal?
	logic       csr_op;        // is this a CSR operation? (we only used this as a cheap way to get return code)
	logic       valid;         // is inst a valid instruction to be counted for CPI calculations?

	logic		rs1_exist;	   // is 0 if no source reg or source reg is reg0
	logic		rs2_exist;
	logic		dp_en;		   // come from insn buffer, 1 if dispatch signal is enable
	FUNC_UNIT   func_unit;     // function unit 
} DP_PACKET;

//////////////////////////////////////////////
//
// RS Section
//
//////////////////////////////////////////////

typedef enum logic[2:0] {
    INST1   = 3'h0,
    INST2   = 3'h1,
    NONE    = 3'h4
} RS_ENTRY_SEL;

typedef struct packed {
    logic [`XLEN-1:0]           rs1_value;
    logic [`XLEN-1:0]           rs2_value;
} REGFILE_RS_PACKET;

typedef struct packed {
    logic                       busy; // if RS entry is busy
	logic [`XLEN-1:0] NPC;     // PC + 4
	logic [`XLEN-1:0] PC;      // PC                                 

	logic [`XLEN-1:0] rs1_value;    // reg A value                                  
	logic [`XLEN-1:0] rs2_value;    // reg B value   

	ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
	ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)
	INST inst;                 // instruction
	
	logic [4:0] dest_reg_idx;  // destination (writeback) register index      
	ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)
	logic       rd_mem;        // does inst read memory?
	logic       wr_mem;        // does inst write memory?
	logic       cond_branch;   // is inst a conditional branch?
	logic       uncond_branch; // is inst an unconditional branch?
	logic       halt;          // is this a halt?
	logic       illegal;       // is this instruction illegal?
	logic       csr_op;        // is this a CSR operation? (we only used this as a cheap way to get return code)
	logic       valid;         // is inst a valid instruction to be counted for CPI calculations?

	logic		rs1_exist;	   // is 0 if no source reg or source reg is reg0
	logic		rs2_exist;

    logic [`ROB_ADDR_BITS-1:0]  Tag; 
    logic [`ROB_ADDR_BITS-1:0]  Tag1; 
    logic [`ROB_ADDR_BITS-1:0]  Tag2;
	logic						Tag1_valid;
	logic						Tag2_valid;
	FUNC_UNIT   func_unit;     // function unit
	logic [$clog2(`SQ_SIZE)-1:0] tail_pos;
} RS_ENTRY_PACKET;

typedef struct packed {
    logic tag1; 
    logic tag2;
} MATCH;

////////////////////////////////////////////////////////
//
// RS_IS_PACKET
//
///////////////////////////////////////////////////////

typedef struct packed {
	logic [`XLEN-1:0] NPC;     // PC + 4
	logic [`XLEN-1:0] PC;      // PC                                 

	logic [`XLEN-1:0] rs1_value;    // reg A value                                  
	logic [`XLEN-1:0] rs2_value;    // reg B value   

	ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
	ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)
	INST inst;                 // instruction
	
	logic [4:0] dest_reg_idx;  // destination (writeback) register index      
	ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)
	logic       rd_mem;        // does inst read memory?
	logic       wr_mem;        // does inst write memory?
	logic       cond_branch;   // is inst a conditional branch?
	logic       uncond_branch; // is inst an unconditional branch?
	logic       halt;          // is this a halt?
	logic       illegal;       // is this instruction illegal?
	logic       csr_op;        // is this a CSR operation? (we only used this as a cheap way to get return code)
	logic       valid;         // is inst a valid instruction to be counted for CPI calculations?

    logic [`ROB_ADDR_BITS-1:0]  Tag; 
	FUNC_UNIT   func_unit;     // function unit
	logic [$clog2(`SQ_SIZE)-1:0] tail_pos;
} RS_IS_PACKET;

////////////////////////////////////////////////////////
//
// IS_EX_PACKET
//
///////////////////////////////////////////////////////
typedef struct packed {
	logic [`XLEN-1:0] NPC;   // PC + 4
	logic [`XLEN-1:0] PC;    // PC
	logic [`XLEN-1:0] rs1_value;    // reg A value                                  
	logic [`XLEN-1:0] rs2_value;    // reg B value                                  
	                                                                                
	ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
	ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)
	INST inst;                 // instruction
	
	logic [4:0] dest_reg_idx;  // destination (writeback) register index      
	ALU_FUNC    alu_func;      // ALU function select (ALU_xxx *)
	logic       rd_mem;        // does inst read memory?
	logic       wr_mem;        // does inst write memory?
	logic       cond_branch;   // is inst a conditional branch?
	logic       uncond_branch; // is inst an unconditional branch?
	logic       halt;          // is this a halt?
	logic       illegal;       // is this instruction illegal?
	logic       csr_op;        // is this a CSR operation? (we only used this as a cheap way to get return code)
	logic       valid;         // is inst a valid instruction to be counted for CPI calculations?
	logic [`ROB_ADDR_BITS-1:0]  Tag; 
	logic [$clog2(`SQ_SIZE)-1:0] tail_pos;
} IS_EX_PACKET;


/////////////////////////////////////////////////////
//
// EX_CP_PACKET
//
////////////////////////////////////////////////////
typedef struct packed {
	logic [`XLEN-1:0] Value;  // alu_result, mem_result for load stor FU
	logic [`XLEN-1:0] NPC;         // next PC
	logic             take_branch; // is this a taken branch?, forwarded
    INST              inst; // forwarded
	logic [4:0]       dest_reg_idx; // forwardedforwarded
	logic             halt, illegal; // forwarded
	logic             done;    // 1 if alu0 fu is avaliable
	logic             valid;   // used for CPI calculation
	logic [`ROB_ADDR_BITS-1:0]  Tag;  // forwarded
} EX_CP_PACKET;

/////////////////////////////////////////////////////
//
// EX_BP_PACKET
//
////////////////////////////////////////////////////

typedef struct packed {
	logic con_br_en;    
	logic br_en;
	logic con_br_taken;    // condition branch taken
	logic [`XLEN-1:0] PC;    // current PC
	logic [`XLEN-1:0] tg_pc;    // target PC
}EX_BP_PACKET;

//////////////////////////////////////////////
//
// CDB Packet (CP_PACKET):
// Data that is sent to ROB, RS, and Map Table
//
//////////////////////////////////////////////

typedef struct packed {
	logic [`XLEN-1:0] Value;  // alu_result
	logic [`XLEN-1:0] NPC;         // pc + 4, forwarded
	logic             take_branch; // is this a taken branch?, forwarded
    INST              inst; 		// forwarded
	logic [4:0]       dest_reg_idx; // forwarded
	logic             halt, illegal; // forwarded
	logic             done;
	logic             valid;
	logic [`ROB_ADDR_BITS-1:0]  Tag;  // #ROB
} CDB_PACKET;

//////////////////////////////////////////////
//
// CP_RT_PACKET
//
//////////////////////////////////////////////

typedef struct packed {
	ROB_ENTRY		  			rob_entry;
	logic [`ROB_ADDR_BITS-1:0]  Tag;  // #ROB
} CP_RT_PACKET;

//////////////////////////////////////////////
//
// RT_PACKET
//
//////////////////////////////////////////////

typedef struct packed {
	logic [4:0] 	  			  retire_reg;  // Retired register
	logic [`XLEN-1:0] 			  value;// Value for retired register
	logic [$clog2(`ROB_SIZE)-1:0] retire_tag;  // #ROB for retired register
    logic                         valid;       // cp_bit
	logic 			  			  wr_en;	   // 0 if rd is `ZERO_REG
	logic						  illegal;
	logic						  halt;
	logic [`XLEN-1:0]             PC;
} RT_PACKET;

//////////////////////////////////////////////
//
// LSQ Section
//
//////////////////////////////////////////////

typedef struct packed {
	logic [`XLEN-1:2] word_addr;
	logic [1:0] res_addr;
	logic [`XLEN-1:0] value;
	logic [2:0] mem_size;
	logic valid;
	logic [`ROB_ADDR_BITS-1:0]  ROB_tag;
} SQ_ENTRY;

typedef struct packed {
	logic found_upper;
	logic found;
	logic [$clog2(`SQ_SIZE)-1:0] found_pos;
} SQ_FOUND_BYTE;

typedef struct packed {
	logic [`XLEN-1:0] addr;
    logic [`XLEN-1:0] wr_data;
    logic             wr_en; //0 for read, 1 for wr, if not ready or writing, lsq_valid should be 0
    logic             rd_en;
    // logic             lsq_valid; //indicate the status of the lsq
    // logic        	  load_request;//add
    // logic             lsq_stall;
    MEM_SIZE          mem_size;
} LSQ_DCACHE_PACKET;

// Dcache section

typedef struct packed {
    // 1 only if LSQ is requesting mem access, otherwise dcache will do nothing
    // Keep it 1 while OUT_PACKET.completed == 0! Otherwise dcache will consider a squash is happening and stop doing all ongoing jobs.
    // When squashing happens, lsq_is_requesting will change to 0 
    // for at least a cycle.
    // Don't change the address when lsq_is_requesting == 1 and complete == 0!
    // This will cause undefined behavior.
    logic lsq_is_requesting; 

    logic [`XLEN-1:0] address; // the address of the memory instruction
    logic is_store; // 1 if the insn is a "store", otherwise "load"
    logic [`XLEN-1:0] value; // only useful if the insn is a "store".

    // memory size of this instruction.
    // mem_size -> actual bytes
    // 2'b?00    -> 1 byte
    // 2'b?01    -> 2 bytes
    // 2'b?10    -> 4 bytes
    // 
    // The MSB represents signed(0)/unsigned(1).
    // See RISC-V reference card for more info.
    // NOTE: LSQ should handle the MSB-extends/zero-extends
    logic [2:0] mem_size; 
} DCACHE_PLANB_IN_PACKET;

typedef struct packed {
    // In the same cycle:
    // If the insn given by IN_PACKET is a "load": 1 if the OUT_PACKET.value is valid, otherwise 0.
    // If the insn is a "store": 1 if dcache completed this transaction (so insn can retire), otheriwse 0. 
    // If lsq_is_requesting == 0, then completed is always 0.
    logic completed;
    // Dcache is processing a miss. Don't let LSQ process any other instructions until = 0!
	// this is equivalent to (~completed | ~lsq_is_requesting).
	// It might cause logic loops
    // logic dcache_stall;
    logic [`XLEN-1:0] value; // only useful if the insn is a "load"
} DCACHE_PLANB_OUT_PACKET;

typedef struct packed {
    logic valid;
    // So the real address of this block is:
    // {tag, index, 3'b0}
    logic [24:0] tag;
    logic [63:0] data;
} DCACHE_PLANB_LINE;

// 2 cache lines make a cache set.
typedef struct packed {
    logic last_accessed;
    DCACHE_PLANB_LINE [1:0] line;
} DCACHE_PLANB_SET;

typedef enum logic [2:0] { 
    DCACHE_IDLE_HIT = 3'h0,
    DCACHE_ST_EVICT = 3'h1,
    DCACHE_LD_EVICT = 3'h2,
    DCACHE_ST_WAIT = 3'h3,
    DCACHE_LD_WAIT = 3'h4
} DCACHE_STATE;


`endif // __SYS_DEFS_VH__
