module test0;
    parameter WIDTH = 6;
    logic     [WIDTH-1:0] req;
    FUNC_UNIT [WIDTH-1:0] func_in;
    logic     [WIDTH-1:0] gnt; // grant the oldest ready slot
    FUNC_UNIT             func_out;

    integer i,k;
    ps_stage_1 #(.WIDTH(WIDTH))t0 (
        .req(req),
        .func_in(func_in),
        .gnt(gnt),
        .func_out(func_out)
    );

    initial begin
        i = 0;
        k = 0;
        for (int j=0;j<WIDTH;j=j+1) begin
            func_in[j]   = j;
            //func_in[j+1] = k;
            //k++; 
        end
        repeat (64) begin
            req = i;
            i++;
            #1;
        end
    end

endmodule