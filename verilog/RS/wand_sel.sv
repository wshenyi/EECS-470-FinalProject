/*
   wand_sel - Priority selector module.
*/

module wand_sel (req,gnt);
  //synopsys template
  parameter WIDTH=16;
  input wire  [WIDTH-1:0] req;
  output wand [WIDTH-1:0] gnt;

  //priority selector
  genvar i;

  for (i = 0; i < WIDTH-1 ; i = i + 1)
  begin : foo
    assign gnt [WIDTH-1:i] = {{(WIDTH-1-i){~req[i]}},req[i]};
  end
  assign gnt[WIDTH-1] = req[WIDTH-1];

endmodule