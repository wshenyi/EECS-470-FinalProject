module RAS(
    input clock,reset,
    input push,    // 1 if instruction is JAL
    input pop,     // 1 if instruction is JALR
    input [`XLEN-1:0] pc,    // link pc
    output logic [`XLEN-1:0] return_addr    // return pc
    
);
    logic [`XLEN-1:0] mem [`RAS_SIZE-1:0];
    logic [$clog2(`RAS_SIZE)-1:0] ptr, ptr_plus_1,ptr_minus_1 ;

  
    //assign empty = (ptr == 0);
    // read data
    assign return_addr = mem[ptr_minus_1];

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            ptr <= `SD 0;
            for (int i=0;i<`RAS_SIZE;i++) begin
                mem [i] <= `SD 32'h0;
            end
        end
        else begin
            if (push && pop) begin
                ptr <= `SD ptr;
            end
            else if (push) begin
                ptr <= `SD ptr_plus_1;
                mem[ptr] <= `SD pc + 4;
            end
            else if (pop) begin
                ptr <= `SD ptr_minus_1;
            end
            else 
                ptr <= `SD ptr;
        end
    end

    assign ptr_plus_1 = (&ptr) ? '0 : ptr + 1;
    assign ptr_minus_1 = (|ptr) ? ptr-1: '1;


endmodule
