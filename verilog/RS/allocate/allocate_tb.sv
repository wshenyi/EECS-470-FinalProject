module t1 ();
    logic [`RS_SIZE-1:0]  req;
    logic [`RS_SIZE-1:0]  gnt_1, gnt_2;
    logic [`RS_SIZE-1:0]  gnt_1_expected, gnt_2_expected;
    parameter NUM = 4;
    integer i;

    task reset_expected();
        gnt_1_expected = {`RS_SIZE{1'b0}}; 
        gnt_2_expected = {`RS_SIZE{1'b0}};
    endtask

    task assert_correct();
        assert(gnt_1 == gnt_1_expected) else $finish;
        assert(gnt_2 == gnt_2_expected) else $finish;
    endtask

    allocate DUT (
        .req(req),
        .gnt_1(gnt_1),
        .gnt_2(gnt_2)
    );

    initial begin
        $monitor("req=%b, gnt_1=%b, gnt_2=%b", req, gnt_1, gnt_2);
        req = {`RS_SIZE{1'b1}};
        reset_expected();
        gnt_1_expected[0] = 1'b1;
        gnt_2_expected[1] = 1'b1;
        #1;
        assert_correct();

        for (i = 0; i < `RS_SIZE; i++) begin
            req[i] = 1'b0;
            reset_expected();
            if (i + 1 < `RS_SIZE)
                gnt_1_expected[i+1] = 1'b1;
            if (i + 2 < `RS_SIZE)
                gnt_2_expected[i+2] = 1'b1;
            #1;
            assert_correct();
        end
        #1;
        $display("@@@ Passed");
        $finish;
    end 
endmodule
