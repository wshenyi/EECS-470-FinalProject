/////////////////////////////////////////////////////////////////////////
//
//   Modulename :  sel_ctl.sv
//
//  Description :  control if instruction need to move zero slot /one slot/ two slots
//
//
//
//
/////////////////////////////////////////////////////////////////////////

module sel_ctl (
  input  [`RS_SIZE-1:0] req,
  output wor [`RS_SIZE-1:0] sel_1,
  output wor [`RS_SIZE-1:0] sel_2);


  wire [`RS_SIZE-1:0] sel_1_tmp;
  wire [`RS_SIZE-2:0] sel_1_and_req;

  assign sel_1_tmp = sel_1;

  //eg. transfer 01010 to 01111
  genvar i;
  for (i = 0; i < `RS_SIZE-1 ; i = i + 1) begin
    assign sel_1 [`RS_SIZE-1:i] = {(`RS_SIZE-i){req [i]}};
  end
  assign sel_1 [`RS_SIZE-1] = req [`RS_SIZE-1];

  //eg. transfer 01010 to 00111
  genvar j,k;
  for (j = 0; j < `RS_SIZE-1 ; j = j + 1) begin
    assign sel_1_and_req  [j]         = sel_1_tmp [j] & req [j+1];
    assign sel_2          [`RS_SIZE-1:j] = {(`RS_SIZE-j){sel_1_and_req [j]}};
  end



endmodule
