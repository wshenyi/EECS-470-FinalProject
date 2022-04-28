module testbench();

	logic clock;               // system clock
	logic reset;           // system reset
    logic squash_in;
	IS_EX_PACKET   is_ex_packet_in;
	EX_CP_PACKET   ex_packet_mult_out;


    logic [`XLEN-1:0] result;
    

	mult_fu #(.XLEN(32),.NUM_STAGE(4))m0(	.clock(clock),
                .reset(reset),
                .squash_in(squash_in),
                .is_ex_packet_in(is_ex_packet_in),
                .ex_cp_packet_out(ex_packet_mult_out)
                );

	always begin
        #5;
        clock = ~clock;
    end

    task mult_sim;
    input [`XLEN-1:0] rs1_value;
    input [`XLEN-1:0] rs2_value;
    input ALU_FUNC func;
    output logic [`XLEN-1:0] product;
    logic [2*`XLEN-1:0] opa, opb;
    logic [2*`XLEN-1:0] signed_opa,signed_opb;
    logic [2*`XLEN-1:0] signed_mul,mixed_mul;
    logic [2*`XLEN-1:0] unsigned_mul;
    logic [`XLEN-1:0] result;
    begin
    opa = {{32{1'b0}},rs1_value};
    opb = {{32{1'b0}},rs2_value};
    signed_opa = {{32{rs1_value[31]}},rs1_value};
    signed_opb = {{32{rs2_value[31]}},rs2_value};
    signed_mul = signed_opa * signed_opb;
    unsigned_mul = opa * opb;
    mixed_mul = signed_opa * opb;
    if (func == ALU_MUL) begin
        result = signed_mul[`XLEN-1:0];
    end 
    else if (func == ALU_MULH) begin
        result = signed_mul[2*`XLEN-1:`XLEN];
    end 
    else if (func == ALU_MULHSU) begin
        result = mixed_mul[2*`XLEN-1:`XLEN];
    end 
    else if (func == ALU_MULHU) begin
        result = unsigned_mul[2*`XLEN-1:`XLEN];
    end
    else begin
        result = `XLEN'hfacebeec;
    end 
    repeat (4)@(negedge clock);
    product = result;
    end
    endtask

    task compare;
    input [`XLEN-1:0] result, product;
    begin
        if (result != product ) begin
            $display("@@@failed");
            $finish;
        end
    end
    endtask
	initial begin
		clock=0;
	    reset = 1;
        squash_in = 0;
        is_ex_packet_in = {{`XLEN{1'b0}},    // NPC
                {`XLEN{1'b0}},    // PC
                {`XLEN{1'b0}},    // reg A
                {`XLEN{1'b0}},
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
                {`ROB_ADDR_BITS{1'b0}}
        };
		@(negedge clock);
		reset = 0;
        is_ex_packet_in.valid = 0;
        mult_sim(is_ex_packet_in.rs1_value, is_ex_packet_in.rs2_value, is_ex_packet_in.alu_func, result);
        compare(result,ex_packet_mult_out.Value);
        $display("noalu @@@pass");
        repeat (5) @(negedge clock) begin
        is_ex_packet_in.alu_func = ALU_MUL;
        is_ex_packet_in.valid = 1;
        is_ex_packet_in.illegal = 1;
        is_ex_packet_in.rs1_value = $random;
        is_ex_packet_in.rs2_value = $random;
        mult_sim(is_ex_packet_in.rs1_value, is_ex_packet_in.rs2_value, is_ex_packet_in.alu_func, result);
        compare(result,ex_packet_mult_out.Value);
        end
        $display("ALU_MUL @@@pass");
        @(negedge clock);
        squash_in = 1;
        repeat (5) @(negedge clock) begin
        is_ex_packet_in.alu_func = ALU_MULH;
        is_ex_packet_in.rs1_value = $random;
        is_ex_packet_in.rs2_value = $random;
        mult_sim(is_ex_packet_in.rs1_value, is_ex_packet_in.rs2_value, is_ex_packet_in.alu_func, result);
        compare(result,ex_packet_mult_out.Value);
        end
        $display("ALU_MULH@@@pass");
        repeat (5) @(negedge clock) begin
        is_ex_packet_in.alu_func = ALU_MULHSU;
        is_ex_packet_in.rs1_value = $random;
        is_ex_packet_in.rs2_value = $random;
        mult_sim(is_ex_packet_in.rs1_value, is_ex_packet_in.rs2_value, is_ex_packet_in.alu_func, result);
        compare(result,ex_packet_mult_out.Value);
        end
        $display("ALU_MULHSU@@@pass");
        repeat (5) @(negedge clock) begin
        is_ex_packet_in.alu_func = ALU_MULHU;
        is_ex_packet_in.rs1_value = $random;
        is_ex_packet_in.rs2_value = $random;
        mult_sim(is_ex_packet_in.rs1_value, is_ex_packet_in.rs2_value, is_ex_packet_in.alu_func, result);
        compare(result,ex_packet_mult_out.Value);
        end
        $display("ALU_MULHU@@@pass");
        
		$finish;
	end

endmodule



  
  
