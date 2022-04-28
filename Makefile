# make          <- runs simv (after compiling simv if needed)
# make all      <- runs simv (after compiling simv if needed)
# make simv     <- compile simv if needed (but do not run)
# make syn      <- runs syn_simv (after synthesizing if needed then 
#                                 compiling synsimv if needed)
# make clean    <- remove files created during compilations (but not synthesis)
# make nuke     <- remove all files created during compilation and synthesis
#
# To compile additional files, add them to the TESTBENCH or SIMFILES as needed
# Every .vg file will need its own rule and one or more synthesis scripts
# The information contained here (in the rules for those vg files) will be 
# similar to the information in those scripts but that seems hard to avoid.
#
#

SOURCE = test_progs/rv32_mult_no_lsq.s

CRT = crt.s
LINKERS = linker.lds
ASLINKERS = aslinker.lds

DEBUG_FLAG = -g
CFLAGS =  -mno-relax -march=rv32im -mabi=ilp32 -nostartfiles -std=gnu11 -mstrict-align -mno-div 
OFLAGS = -O0
ASFLAGS = -mno-relax -march=rv32im -mabi=ilp32 -nostartfiles -Wno-main -mstrict-align
OBJFLAGS = -SD -M no-aliases 
OBJDFLAGS = -SD -M numeric,no-aliases

##########################################################################
# IF YOU AREN'T USING A CAEN MACHINE, CHANGE THIS TO FALSE OR OVERRIDE IT
CAEN = 1
##########################################################################
ifeq (1, $(CAEN))
	GCC = riscv gcc
	OBJDUMP = riscv objdump
	AS = riscv as
	ELF2HEX = riscv elf2hex
else
	GCC = riscv64-unknown-elf-gcc
	OBJDUMP = riscv64-unknown-elf-objdump
	AS = riscv64-unknown-elf-as
	ELF2HEX = elf2hex
endif


VCS = vcs -V -sverilog +vc -Mupdate -line -full64 +vcs+vcdpluson -debug_pp 
LIB = /afs/umich.edu/class/eecs470/lib/verilog/lec25dscc25.v

# SIMULATION CONFIG

HEADERS     = $(wildcard *.svh)
TESTBENCH   = $(wildcard testbench/*.sv)
TESTBENCH  += $(wildcard testbench/*.c)
PIPEFILES   = verilog/pipeline.sv
PIPEFILES  += verilog/ROB/ROB.sv
PIPEFILES  += verilog/Cache/icache/icache.sv verilog/Cache/icache/cache.sv verilog/Cache/dcache/dcache_planb.sv  
PIPEFILES  += verilog/BP/BP_top.sv verilog/BP/pre_decode.sv verilog/BP/RAS.sv verilog/BP/BHT.sv verilog/BP/BTB.sv verilog/BP/PHT.sv
PIPEFILES  += verilog/RS/RS.sv verilog/RS/RS_one.sv verilog/RS/allocate/allocate.sv verilog/RS/sel_ctl/sel_ctl.sv
PIPEFILES  += verilog/MapTable/maptable.sv verilog/MapTable/MapTableRF.sv
PIPEFILES  += verilog/FETCH/if_stage.sv verilog/FETCH/insn_buffer/insn_buffer.sv
PIPEFILES  += verilog/DISPATCH/dp_stage.sv verilog/DISPATCH/REGFILE/regfile.sv
PIPEFILES  += verilog/ISSUE/issue_stage.sv verilog/ISSUE/ps_fu.sv verilog/ISSUE/ps_stage1.sv \
			  verilog/ISSUE/ps_no_mask.sv verilog/ISSUE/ps_mask_mem.sv verilog/ISSUE/ps_mask_mult.sv \
			  verilog/ISSUE/ps_no_mask_s.sv verilog/ISSUE/ps_mask_mem_s.sv verilog/ISSUE/ps_mask_mult_s.sv
PIPEFILES  += verilog/EXECUTE/ex_stage.sv verilog/EXECUTE/mult_fu.sv verilog/EXECUTE/alu_fu.sv verilog/EXECUTE/mem_fu.sv 
PIPEFILES  += verilog/COMPLETE/cp_stage.sv verilog/COMPLETE/ps.sv verilog/COMPLETE/wand_sel.sv
PIPEFILES  += verilog/RETIRE/rt_stage.sv
PIPEFILES  += verilog/LSQ/lsq.sv

SIMFILES    = $(PIPEFILES)

# SYNTHESIS CONFIG
SYNTH_DIR = ./synth

export CACHE_NAME=icache
export HEADERS
export PIPEFILES

export PIPELINE_NAME=pipeline


PIPELINE  = $(SYNTH_DIR)/$(PIPELINE_NAME).vg 
SYNFILES  = $(PIPELINE) $(SYNTH_DIR)/$(PIPELINE_NAME)_svsim.sv


# Passed through to .tcl scripts:
export CLOCK_NET_NAME = clock
export RESET_NET_NAME = reset
export CLOCK_PERIOD   = 15	# TODO: You will need to make match SYNTH_CLOCK_PERIOD in sys_defs
                                #       and make this more aggressive

################################################################################
## RULES
################################################################################

# Default target:
all:    simv
	./simv | tee program.out

.PHONY: all

# Simulation:

sim:	simv
	./simv | tee sim_program.out

simv:	$(HEADERS) $(SIMFILES) $(TESTBENCH)
	$(VCS) $^ -o simv

.PHONY: sim

# Programs

compile: $(CRT) $(LINKERS)
	$(GCC) $(CFLAGS) $(OFLAGS) $(CRT) $(SOURCE) -T $(LINKERS) -o program.elf
	$(GCC) $(CFLAGS) $(DEBUG_FLAG) $(CRT) $(SOURCE) -T $(LINKERS) -o program.debug.elf
assemble: $(ASLINKERS)
	$(GCC) $(ASFLAGS) $(SOURCE) -T $(ASLINKERS) -o program.elf 
	cp program.elf program.debug.elf
disassemble: program.debug.elf
	$(OBJDUMP) $(OBJFLAGS) program.debug.elf > program.dump
	$(OBJDUMP) $(OBJDFLAGS) program.debug.elf > program.debug.dump
	rm program.debug.elf
hex: program.elf
	$(ELF2HEX) 8 8192 program.elf > program.mem

program: compile disassemble hex
	@:

debug_program:
	gcc -lm -g -std=gnu11 -DDEBUG $(SOURCE) -o debug_bin
assembly: assemble disassemble hex
	@:


# Synthesis

$(PIPELINE): $(SIMFILES) $(SYNTH_DIR)/$(PIPELINE_NAME).tcl
	cd $(SYNTH_DIR) && dc_shell-t -f ./$(PIPELINE_NAME).tcl | tee $(PIPELINE_NAME)_synth.out
	echo -e -n 'H\n1\ni\n`timescale 1ns/100ps\n.\nw\nq\n' | ed $(PIPELINE)

syn:	syn_simv 
	./syn_simv | tee syn_program.out

syn_simv:	$(HEADERS) $(SYNFILES) $(TESTBENCH)
	$(VCS) $^ $(LIB) +define+SYNTH_TEST -o syn_simv 

.PHONY: syn

# Debugging

dve:	sim
	./simv -gui &

dve_syn: syn_simv 
	./syn_simv -gui &

.PHONY: dve dve_syn 

clean:
	rm -rf *simv *simv.daidir csrc vcs.key program.out *.key
	rm -rf vis_simv vis_simv.daidir
	rm -rf dve* inter.vpd DVEfiles
	rm -rf syn_simv syn_simv.daidir syn_program.out
	rm -rf synsimv synsimv.daidir csrc vcdplus.vpd vcs.key synprog.out pipeline.out writeback.out vc_hdrs.h
	rm -f *.elf *.dump *.mem debug_bin

nuke:	clean
	rm -rf synth/*.vg synth/*.rep synth/*.ddc synth/*.chk synth/*.log synth/*.syn
	rm -rf synth/*.out command.log synth/*.db synth/*.svf synth/*.mr synth/*.pvl
