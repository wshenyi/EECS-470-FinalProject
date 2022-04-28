module test0;
    parameter WIDTH = 16;
    logic     [WIDTH-1:0] req;
    FUNC_UNIT [WIDTH-1:0] func_in;
  
    logic     [WIDTH-1:0] gnt; // grant the oldest ready slot
    logic     [2*WIDTH-1:0] gnt_bus;
    FUNC_UNIT [1:0]         func_out;
    logic   ALU0_stall_in, ALU1_stall_in;

    logic     [1:0]       golden_empty ;
    logic [WIDTH-1:0]     golden_gnt;
    logic [2*WIDTH-1:0]   golden_gnt_bus;
    FUNC_UNIT [1:0] golden_func_out;

    integer i,k;
    ps_fu #(.WIDTH(WIDTH))t0 (
        .req(req),
        .func_in(func_in),
        .ALU0_stall_in(ALU0_stall_in),
        .ALU1_stall_in(ALU1_stall_in),
        .gnt(gnt),
        .gnt_bus(gnt_bus),
        .func_out(func_out)
    );

    // task issue;
    //     input  [WIDTH-1:0]           req;
    //     input  FUNC_UNIT [WIDTH-1:0] func_in;
    //     output [1:0]                 fu_valid_out;
    //     output [WIDTH-1:0]           gnt;
    //     output [2*WIDTH-1:0]         gnt_bus;
    //     output FUNC_UNIT [1:0]       func_out;
    //     integer i,j;
    //     begin
    //         fu_valid_out =0;
    //         gnt=0;
    //         gnt_bus=0;
    //         func_out[0]=ALU;
    //         func_out[1]=ALU;
    //         for (i=0;i<WIDTH;i--) begin
    //             if (req[i]) begin 
    //                 func_out [0] = func_in [i];
    //                 gnt [i] = 1;
    //                 gnt_bus [i] = 1;
    //                 if(func_in[i] == MULT) begin
    //                     for (j = i+1;j<WIDTH;j++) begin
    //                         if (req[j]==1 && func_in[j]!=MULT) begin
    //                             func_out [1] = func_in [j];
    //                             gnt [j] = 1;
    //                             gnt_bus [WIDTH+j] = 1;
    //                             break;
    //                         end
    //                     end
    //                     if (j == WIDTH) begin
    //                         func_out [1] = ALU;
    //                         fu_valid_out [1] = 1;
    //                     end
    //                 end
    //                 else if(func_in[i] == MEM) begin
    //                     for (j = i+1;j<WIDTH;j++) begin
    //                         if (req[j]==1 && func_in[j]!=MEM) begin
    //                             func_out [1] = func_in [j];
    //                             gnt [j] = 1;
    //                             gnt_bus [WIDTH+j] = 1;
    //                             break;
    //                         end
    //                     end
    //                     if (j == WIDTH) begin
    //                         func_out [1] = ALU;
    //                         fu_valid_out [1] = 1;
    //                     end
    //                 end
    //                 else if (~ALU1_stall_in) begin
    //                     for (j = i+1;j<WIDTH;j++) begin
    //                         if (req[j]) begin
    //                             func_out [1] = func_in [j];
    //                             gnt [j] = 1;
    //                             gnt_bus [WIDTH+j] = 1;
    //                             break;
    //                         end
    //                     end
    //                     if (j == WIDTH) begin
    //                         func_out [1] = ALU;
    //                         fu_valid_out [1] = 1;
    //                     end
    //                 end
    //                 else if (ALU1_stall_in) begin
    //                         func_out [1] = ALU;
    //                         fu_valid_out [1] = 1;
    //                 end
    //                 break;
    //             end   
    //         end
    //         if (i == WIDTH) begin
    //             fu_valid_out [0] = 1;
    //             fu_valid_out [1] = 1;
    //             func_out [0] =ALU;
    //             func_out [1] =ALU;
    //         end
    //     end
    // endtask

    // task compare_correct;
    //     input     [1:0]       fu_valid_out;
    //     input     [WIDTH-1:0] gnt; // grant the oldest ready slot
    //     input     [2*WIDTH-1:0] gnt_bus;
    //     input FUNC_UNIT [1:0]         func_out;
    //     input     [1:0]       g_empty;
    //     input     [WIDTH-1:0] g_gnt; // grant the oldest ready slot
    //     input     [2*WIDTH-1:0] g_gnt_bus;
    //     input FUNC_UNIT [1:0]         g_func_out;
    //     begin
    //         if (fu_valid_out == g_empty && gnt==g_gnt && gnt_bus == g_gnt_bus&&func_out==g_func_out) begin
    //             //$display("fu_valid_out[0]:%1b fu_valid_out[1]:%1b gnt:%1h func[0]:%1h func[1]:%1h", fu_valid_out[0], fu_valid_out[1], gnt, func_out[0], func_out[1]);
    //         end else begin
    //             $display("@@@failed");
    //             //$finish;
    //         end
    //     end
    // endtask

    initial begin
        i = 16'hFFFF;
        k = 0;
        ALU0_stall_in = 1;
        ALU1_stall_in = 0;
        for (int j=0;j<WIDTH;j=j+1) begin
            func_in[j]   = ALU;
        end
        repeat (16) begin
            req = i;
           
            #1;
            $display("req:%b gnt:%b", req, gnt );
        end
        $display("@@@test1pass");

        for (int j=0;j<WIDTH;j=j+1) begin
            func_in[j]   = MULT;
        end
        repeat (16) begin
            req = i;
            
            #1;
            $display("req:%b gnt:%b", req, gnt );
        
        end
        $display("@@@test2pass");

        for (int j=0;j<WIDTH;j=j+1) begin
            func_in[j]   = MEM;
        end
        repeat (16) begin
            req = i;
           
            #1;
            $display("req:%b gnt:%b", req, gnt );
    
        end


         $display("@@@test3pass");

         for (int j=0;j<WIDTH;j=j+1) begin
            func_in[j][0]   = 1'b1;
            func_in[j][1]   = 1'b1;
        end
        repeat (16) begin
            req = i;
          
            #1;
            $display("req:%b gnt:%b", req, gnt );
        
        end
        $display("@@@test4pass");
     
        func_in [0] = MULT;
        
        for (int j=1;j<WIDTH;j=j+1) begin
            func_in[j]  = ALU;
        end
        repeat (16) begin
            req = i;
           
            #1;
            $display("req:%b gnt:%b", req, gnt );
        end
       
        func_in [0] = MEM;
       
        for (int j=1;j<WIDTH;j=j+1) begin
            func_in[j]  = ALU;
        end
        repeat (16) begin
            req = i;
         
            #1;
            $display("req:%b gnt:%b", req, gnt );
        end
     
        func_in [0] = MULT;
        func_in [1] = MEM;
     
        for (int j=2;j<WIDTH;j=j+1) begin
            func_in[j]  = ALU;
        end
        repeat (16) begin
            req = i;
            
            #1;
            $display("req:%b gnt:%b", req, gnt );
        end


    
    end
        
endmodule