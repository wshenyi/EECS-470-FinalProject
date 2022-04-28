module test1;
    parameter                 WIDTH = 16;
    logic         [WIDTH-1:0] req;
    RS_IS_PACKET  [WIDTH-1:0] rs_is_packet_in;
    logic                     ALU0_stall_in, ALU1_stall_in;
    RS_IS_PACKET              rs_is_alu0_out, rs_is_alu1_out, rs_is_mult_out, rs_is_mem_out;
    logic         [WIDTH-1:0] free;

    issue #(.WIDTH(WIDTH)) DUT(
        .rs_is_packet_in(rs_is_packet_in),
        .req(req),
        .ALU0_stall_in(ALU0_stall_in),
        .ALU1_stall_in(ALU1_stall_in),
        .rs_is_alu0_out(rs_is_alu0_out),
        .rs_is_alu1_out(rs_is_alu1_out),
        .rs_is_mult_out(rs_is_mult_out),
        .rs_is_mem_out(rs_is_mem_out),
        .free(free),
        .rs_is_alu0_vld(rs_is_alu0_vld), 
        .rs_is_alu1_vld(rs_is_alu1_vld), 
        .rs_is_mult_vld(rs_is_mult_vld), 
        .rs_is_mem_vld(rs_is_mem_vld)
    );

    initial begin
        req = 16'hFFFF;
        rs_is_packet_in = {WIDTH{{`XLEN{1'b0}},    // PC + 4
				{`XLEN{1'b0}},    // PC
				{`XLEN{1'b0}},    // reg A value
				{`XLEN{1'b0}},    // reg B value 
				OPA_IS_RS1, 
				OPB_IS_RS2, 
				`NOP,            // instruction
				`ZERO_REG,       // destination (writeback) register index 
				ALU_ADD,         // ALU function select (ALU_xxx *)
				1'b0, //rd_mem
				1'b0, //wr_mem
				1'b0, //cond
				1'b0, //uncond
				1'b0, //halt
				1'b0, //illegal
				1'b0, //csr_op
				1'b1,  //valid
                {`ROB_ADDR_BITS{1'b0}}, // Tag
                ALU    //FU
			}}; 
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        #1;
        for (int i=0;i<1;i++) begin
         rs_is_packet_in[i].func_unit = MULT; 
        end
        #1;
        for (int i=1;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = ALU; 
        end
        #1;
        for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = MEM; 
        end
        #1;
        req = 16'h0000;
          for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = ALU; 
        end
        #1;
        for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = MULT; 
        end
        #1;
        for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = MEM; 
        end
        
        #1;
        req = 16'hFFFE;
          for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = ALU; 
        end
        #1;
        for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = MULT; 
        end
        #1;
        for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = MEM; 
        end
        #1;
        req = 16'hFFFC;
          for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = ALU; 
        end
        #1;
        for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = MULT; 
        end
        #1;
        for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = MEM; 
        end
        #1;
        req = 16'hFFFA;
          for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = ALU; 
        end
        #1;
        for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = MULT; 
        end
        #1;
        for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = MEM; 
        end
        #1;  
        $finish;
    end
    
endmodule