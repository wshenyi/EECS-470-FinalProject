/////////////////////////////////////////////////////////////////////////
//
//   Modulename :  allocate.sv
//
//  Description :  allocate instruction to RS. Find 4 lowest slots that are 0's
//  provided by req, and using one-hot output format to 4 gnt's.
//
//
//
//
/////////////////////////////////////////////////////////////////////////
module allocate (
    // req must be the after-squeezing signal, that is 1...10...0.
    // No ...01... pattern is allowed.
    input   [`RS_SIZE-1:0]  req,
    output  [`RS_SIZE-1:0]  gnt_1, gnt_2
);

    // find the lowest address that is 0
    genvar j;
    for (j = 0; j < `RS_SIZE; j = j + 1) begin
        if (j==0) begin
            assign gnt_1 [j] = req [j];
        end else begin
            assign gnt_1 [j] = ~req [j-1] & req [j];
        end
    end

    //find the rest of lowest empty addresses
    assign gnt_2 = {gnt_1 [`RS_SIZE-2 : 0], 1'b0};

endmodule
