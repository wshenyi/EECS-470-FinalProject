module test1;
    parameter                 WIDTH = 16;
    logic         [WIDTH-1:0] req;
    RS_IS_PACKET  [WIDTH-1:0] rs_is_packet_in;
    logic                     ALU0_stall_in, ALU1_stall_in, ld_stall_in, st_stall_in;
    IS_EX_PACKET              is_ex_packet_alu0,is_ex_packet_alu1,is_ex_packet_ld,is_ex_packet_st,is_ex_packet_mult;
    logic         [WIDTH-1:0] free;

    issue #(.WIDTH(WIDTH)) DUT(
        .rs_is_packet_in(rs_is_packet_in),
        .req(req),
        .ALU0_stall_in(ALU0_stall_in),
        .ALU1_stall_in(ALU1_stall_in),
        .ld_stall_in(ld_stall_in),
        .st_stall_in(st_stall_in),
        .is_ex_packet_alu0(is_ex_packet_alu0),
        .is_ex_packet_alu1(is_ex_packet_alu1),
        .is_ex_packet_mult(is_ex_packet_mult),
        .is_ex_packet_ld(is_ex_packet_ld),
        .is_ex_packet_st(is_ex_packet_st),
        .free(free)
    );

    initial begin
        req = 16'hFFFF;
        st_stall_in = 0;
        ld_stall_in = 0;
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
        FUNC_ALU,    //FU
        '0
			}}; 
        for (int i=0;i<16;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_ALU; 
         rs_is_packet_in[i].valid = 1; 
        end
        for (int i=1;i<16;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_MULT; 
        end
        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        #1;
        for (int i=0;i<4;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_MEM; 
         rs_is_packet_in[i].rd_mem = 1;
         rs_is_packet_in[i].wr_mem = 0; 
        end
        for (int i=4;i<8;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_MEM;
         rs_is_packet_in[i].rd_mem = 0;
         rs_is_packet_in[i].wr_mem = 1;  
        end
        for (int i=8;i<16;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_ALU;
         rs_is_packet_in[i].rd_mem = 0;
         rs_is_packet_in[i].wr_mem = 0;  
        end
        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        st_stall_in = 1;
        ld_stall_in = 0;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        st_stall_in = 1;
        ld_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        st_stall_in = 1;
        ld_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        st_stall_in = 1;
        ld_stall_in = 0;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        st_stall_in = 1;
        ld_stall_in = 1;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        st_stall_in = 1;
        ld_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        st_stall_in = 1;
        ld_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        st_stall_in = 1;
        ld_stall_in = 1;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        st_stall_in = 0;
        ld_stall_in = 0;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        st_stall_in = 0;
        ld_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        st_stall_in = 0;
        ld_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        st_stall_in = 0;
        ld_stall_in = 0;
        #1;

        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        st_stall_in = 0;
        ld_stall_in = 1;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        st_stall_in = 0;
        ld_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        st_stall_in = 0;
        ld_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        st_stall_in = 0;
        ld_stall_in = 1;
        #1;
        for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_MEM; 
        end
       
        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        #1;
       
          for (int i=0;i<WIDTH-4;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_ALU; 
        end
        for (int i=WIDTH-4;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_MEM; 
        end
         
       
        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        #1;
       
         req = 16'h0000;
        for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_MULT; 
        end
      
        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        #1;
        for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_MEM; 
        end
        
        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        #1;
        req = 16'hFFFE;
          for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_ALU; 
        end
        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        #1;
        for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_MULT; 
        end
        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        #1;
        for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_MEM; 
        end
        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        #1;
        req = 16'hFFFC;
          for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_ALU; 
        end
        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        #1;
        for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_MULT; 
        end
        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        #1;
        for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_MEM; 
        end
        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        #1;
        req = 16'hFFFA;
          for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_ALU; 
        end
        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        #1;
        for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_MULT; 
        end
        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        #1;
        for (int i=0;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_MEM; 
        end
        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        #1; 
        
        
        req = 16'h0003;
        rs_is_packet_in[0].func_unit = FUNC_MEM;
        for (int i=1;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_ALU; 
        end
        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        #1; 
          req = 16'hFFFF;
        rs_is_packet_in[0].func_unit = FUNC_MEM;
        for (int i=1;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_MULT; 
        end
        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        #1; 
         req = 16'hFFFF;
        rs_is_packet_in[0].func_unit = FUNC_MULT;
        for (int i=1;i<WIDTH;i++) begin
         rs_is_packet_in[i].func_unit = FUNC_MEM; 
        end
        ALU0_stall_in = 0;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 0;
        ALU1_stall_in = 1;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        #1;
        ALU0_stall_in = 1;
        ALU1_stall_in = 1;
        #1; 
        $finish;
    end
    
endmodule