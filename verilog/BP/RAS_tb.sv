module t0();
    logic clock,reset;
    logic push, pop;
    logic [`XLEN-1:0] pc;    // link pc
    logic [`XLEN-1:0] return_addr;    // return pc
    

    RAS DUT(
        .clock(clock),
        .reset(reset),
        .push(push),
        .pop(pop),
        .pc(pc),
        .return_addr(return_addr)
    );

    always begin
        #5;
        clock = ~clock;
    end

    initial begin
        clock = 0;
        reset = 1;
        push = 1;
        pop = 0;
        pc =0;
        for (int i=0;i< 60;i++) begin
        @(negedge clock);
        reset = 0;
        push =1;
        pop = 0;
        pc= i+1;
        if (i >= 1) begin
            push = 1;
            pop = 0;
        end
        if (i >= 5) begin
            push = 0;
            pop = 1;
        end
         if (i >= 10) begin
            push = 1;
            pop = 0;
        end
        if (i >= 50) begin
            push = 0;
            pop = 1;
        end
        end
        $finish;
    end 

endmodule