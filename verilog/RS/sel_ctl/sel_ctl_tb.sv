// EECS 470 group13w22
// Testbench for the module sel_ctl in sel_ctl.sv
`ifndef RS_SIZE
`define RS_SIZE 16
`endif // RS_SIZE

module sel_ctl_testbench();
    logic [`RS_SIZE-1:0] req, sel_1, sel_2;

    function [`RS_SIZE-1:0] shift_1_func(
        [`RS_SIZE-1:0] req_value
    );
        int cum_sum;
        cum_sum = 0;
        shift_1_func = 0;
        for (int i = 0; i < `RS_SIZE; i++) begin
            if (req_value[i]) begin
                cum_sum++;
            end
            if (cum_sum > 0) begin
                shift_1_func[i] = 1'b1;
            end
        end
        return shift_1_func;
    endfunction

    function [`RS_SIZE-1:0] shift_2_func(
        [`RS_SIZE-1:0] req_value
    );
        int cum_sum;
        cum_sum = 0;
        shift_2_func = 0;
        for (int i = 0; i < `RS_SIZE; i++) begin
            if (req_value[i]) begin
                cum_sum++;
            end
            if (cum_sum == 1) begin
                if (i < `RS_SIZE-1 && req_value[i+1])
                    shift_2_func[i] = 1'b1;
            end else if (cum_sum > 1) begin
                shift_2_func[i] = 1'b1;
            end
        end
    endfunction

    sel_ctl sc(
        .req(req),
        .sel_1(sel_1),
        .sel_2(sel_2)
    );

    initial begin 
        $monitor("req=%b, sel_1=%b, sel_2=%b", req, sel_1, sel_2);
        repeat(1000) begin
            req = {$random}[15:0];
            #5;
            assert(sel_1 == shift_1_func(req)) else $finish;
            assert(sel_2 == shift_2_func(req)) else $finish;
        end;

        $display("@@@ Passed");
        $finish;
        
    end
endmodule
