`timescale 1ns/100ps

module MSHR_icache #(parameter LENGTH=4)(
        // interface with icache
        input  logic clock,
        input  logic reset,
        input  logic [63:0]         mem2Icache_data,
        input  logic [3:0]          mem2Icache_tag,
        input  logic [3:0]          mem2Icache_response,
        input  logic                mem2Icache_ack,
        input  logic [`XLEN-1:0]    load_addr,
        input  logic                load_request,
        
        output logic                load_full,   //load queue is full, can not take any misses
        output logic                load_empty,  //load queue is empty
        output logic [63:0]         queue_data,
        output logic [`XLEN-1:0]    queue_addr,
        output logic                queue_dvalid,
        output logic                queue_clear, // all entry in this queue is
 
        output logic [`XLEN-1:0]    Icache2mem_addr,
        output BUS_COMMAND          Icache2mem_command
    );

    logic [`XLEN-1:0]   lq_addr     [LENGTH-1:0];
    logic [12:0]        valid_addr  [LENGTH-1:0];
    logic [LENGTH-1:0]  addr_same; 
    logic [3:0]         lq_tag      [LENGTH-1:0];
    logic [LENGTH-1:0]  lq_valid   ;
    logic [$clog2(LENGTH):0]  head_ptr, tail_ptr, disp_ptr;
    logic head_en;

    always_comb begin
        for(int i = 0;  i < LENGTH; i++)begin
            valid_addr[i] = (lq_valid[i]) ? lq_addr[i][15:3] : '1;
            addr_same[i]  = (valid_addr[i] == load_addr[15:3]);
        end

        queue_dvalid = (mem2Icache_tag == lq_tag[tail_ptr[1:0]]) && (|mem2Icache_tag) 
                        && (lq_valid[tail_ptr[1:0]]) && (tail_ptr != disp_ptr);
        queue_data   = mem2Icache_data;
        queue_clear  = disp_ptr == head_ptr;
        queue_addr   = lq_addr[tail_ptr[1:0]];

        load_full  = (&lq_valid);
        load_empty = !lq_valid;
        Icache2mem_command = (disp_ptr != head_ptr) | ((disp_ptr == head_ptr) && load_request) ? BUS_LOAD : BUS_NONE;
        Icache2mem_addr    = (head_ptr == disp_ptr) ? load_addr : lq_addr[disp_ptr[1:0]];
        head_en            = load_request && (addr_same == 0) && ((load_full == 0) || queue_dvalid);
    end

    // synopsys sync_set_reset "reset"
    always_ff@(posedge clock) begin
        if(reset)begin
            lq_addr  <= `SD '{LENGTH{0}};
            lq_tag   <= `SD '{LENGTH{0}};
            lq_valid <= `SD '{LENGTH{0}};
            head_ptr <= `SD 0;
            tail_ptr <= `SD 0;
            disp_ptr <= `SD 0;
        end else begin
            // tail pointer
            if ((mem2Icache_tag == lq_tag[tail_ptr[1:0]]) && (|mem2Icache_tag) && (lq_valid[tail_ptr[1:0]]) && (tail_ptr!=disp_ptr)) begin
                tail_ptr                <= `SD tail_ptr + 1'b1;
                lq_valid[tail_ptr[1:0]] <= `SD 1'b0;
            end
            
            // head pointer           
            if(head_en) begin
                head_ptr                <= `SD head_ptr + 1'b1;
                lq_addr [head_ptr[1:0]] <= `SD load_addr;
                lq_valid[head_ptr[1:0]] <= `SD 1'b1;
            end

            // dispatch pointer
            if( (mem2Icache_ack) && (|(mem2Icache_response)) && (head_en || (disp_ptr != head_ptr))) begin
                disp_ptr                <= `SD disp_ptr + 1'b1;
                lq_tag[disp_ptr[1:0]]   <= `SD mem2Icache_response;
            end

        end
    end

endmodule

module icache (
    input  logic clock,
    input  logic reset,
    input  logic squash_en,
    input  logic [63:0]           mem2Icache_data_in,     
    input  logic [3:0]            mem2Icache_tag_in,         // tag of finished load transaction
    input  logic [3:0]            mem2Icache_response_in,    // tag of input load transaction
    input  logic                  mem2Icache_ack_in,
    input  IF_ICACHE_PACKET [1:0] IF_Icache_packet_in,

    output logic [`XLEN-1:0]      Icache2mem_addr_out,        // Only one read request each cycle 
    output BUS_COMMAND            Icache2mem_command_out,     // `BUS_NONE `BUS_LOAD or `BUS_STORE
    output ICACHE_IF_PACKET [1:0] Icache_IF_packet_out
);

    // pre-fetcher FSM
    PREFETCH_STATE      prefetch_state, prefetch_state_n;
    // pre-fecthing logic
    logic [`XLEN-1:0]   pref_addr;
    logic               pref_req; //prefetching request, if this addr is hit in the icache, then pull this low
    logic               pref_hs;
    logic [`XLEN-1:0]   pref_adreg;
    logic [1:0]         pref_cnt;   // prefetch 2 lines at total for now
    logic [$clog2(`ICACHE_LINE_NUM)-1:0] pref_idx;
    logic [`ICACHE_TAG_WIDTH-1:0]        pref_tag;
    logic [`ICACHE_WAY-1:0]              pref_skip;
    // memory miss request queue
    logic [`XLEN-1:0]   last_pc;
    logic               change_pc;
    logic [1:0]         inst_miss;
    logic [1:0]         inst_hit;
    logic [1:0]         inst_same; //denotes two insts come from the same address
    logic [1:0]         miss_request;
    logic [1:0]         miss_ack;
    logic               pri_request;
    logic [`XLEN-1:0]   pri_addr;
    // Simple 1-bit NRU algorithm for cache replacement
    logic   [`ICACHE_WAY-1:0]   nru_tab [`ICACHE_LINE_NUM-1:0] ;
    logic   [`ICACHE_WAY-1:0]   nru_mask;
    // MSHR instantiation
    logic   [`XLEN-1:0] mshr_Iaddr;
    logic               mshr_Irequest;
    logic               mshr_full;
    logic               mshr_empty;
    logic   [63:0]      mshr_Odata;
    logic   [`XLEN-1:0] mshr_Oaddr;
    logic               mshr_Ovalid;
    logic               mshr_clear;
    // cache instantiation
    logic   [1:0]        rd_bo;
    logic   [1:0]        rd_valid [`ICACHE_WAY-1:0];
    logic   [1:0][63:0]  rd_data  [`ICACHE_WAY-1:0];//original read data
    logic   [63:0]     valid_data [1:0];          //valid read data
    logic   [1:0][$clog2(`ICACHE_LINE_NUM)-1:0]  rd_idx;
    logic   [1:0][`ICACHE_TAG_WIDTH-1:0]         rd_tag;
    logic   [$clog2(`ICACHE_LINE_NUM)-1:0]       wr_idx;
    logic   [`ICACHE_TAG_WIDTH-1:0]              wr_tag;
    logic   [`ICACHE_WAY-1:0]                    wr_en;
    logic   [63:0]                               wr_data;
    logic   [`ICACHE_LINE_NUM-1:0]  block_valid     [`ICACHE_WAY-1:0];
    logic   [`ICACHE_LINE_NUM-1:0]  block_fillen    [`ICACHE_WAY-1:0];  // whether one block is empty


    // pre-fetching FSM, state transition
    always_comb begin
        case(prefetch_state)
            IDLE:begin
                    if(change_pc && (|miss_request)) 
                        prefetch_state_n = LOAD;
                    else 
                        prefetch_state_n = IDLE;
                end
            LOAD:begin
                    if (squash_en | (Icache_IF_packet_out[0].Icache_valid_out & Icache_IF_packet_out[1].Icache_valid_out))
                        prefetch_state_n = IDLE;
                    else if((miss_request == miss_ack)) // all miss requests sent but in-the-flight 
                        prefetch_state_n = PREF;
                    else
                        prefetch_state_n = LOAD;
                end
            PREF:begin
                    if (squash_en | (Icache_IF_packet_out[0].Icache_valid_out & Icache_IF_packet_out[1].Icache_valid_out))
                        prefetch_state_n = IDLE;
                    else if((change_pc) && (|miss_request))
                        prefetch_state_n = LOAD;
                    else 
                        prefetch_state_n = PREF;
                end
            default:    prefetch_state_n = IDLE;
        endcase
    end

    // pre-fetching FSM, state drive
    // synopsys sync_set_reset "reset"
    always_ff@(posedge clock)begin
        if(reset)begin
            prefetch_state <= IDLE;
        end else begin
            prefetch_state <= prefetch_state_n;
        end
    end

    // pre-fetching output logic drive
    always_comb begin
        pref_hs   = pref_req && mshr_Irequest;
        pref_addr = pref_adreg;
        pref_req  = (prefetch_state[1])  && (!pref_skip);
        {pref_tag,pref_idx} = pref_addr[15:3];
    end
    // synopsys sync_set_reset "reset"
    always_ff@(posedge clock)begin
        if(reset)begin
            pref_adreg <= '0;
            pref_cnt <= '0;
        end else begin
            case(prefetch_state)
                IDLE: begin
                    pref_adreg <= '0;
                    pref_cnt <= '0;
                end
                LOAD: begin
                    pref_adreg <= {last_pc[31:3], 3'b0} + 8;
                    pref_cnt <= '0;
                end
                PREF: begin
                    if(pref_hs|pref_skip)begin
                        pref_adreg <= pref_adreg + 8;
                        pref_cnt <= pref_cnt + 1'b1;
                    end
                end
            endcase
        end
    end

    // track last PC to denotes address change
    // synopsys sync_set_reset "reset"
    always_ff@(posedge clock)begin
       if(reset)begin
           last_pc <= '1;
       end else begin
           if(IF_Icache_packet_in[1].Icache_request | IF_Icache_packet_in[0].Icache_request) begin
                last_pc <= IF_Icache_packet_in[1].Icache_addr_in;
           end
       end
    end

    // priority mux 
    // synopsys sync_set_reset "reset"
    always_ff@(posedge clock)begin
        if(reset)begin
            miss_ack <= `SD 0;
        end else begin
            if (miss_request && (!mshr_full))begin
                if (miss_request[0] && !miss_ack[0] && mem2Icache_ack_in) begin
                    miss_ack[0] <= `SD 1'b1;
                    if(inst_same) miss_ack[1] <= `SD 1'b1;
                end else if(miss_request[1] && !miss_ack[1] && mem2Icache_ack_in) begin
                    miss_ack[1] <= `SD 1'b1;
                end
            end 
            else if(squash_en | (Icache_IF_packet_out[0].Icache_valid_out & Icache_IF_packet_out[1].Icache_valid_out))begin
                miss_ack <= `SD 2'b0;
            end
        end
    end

    always_comb begin
        // priority drive
        inst_same    =  IF_Icache_packet_in[0].Icache_addr_in[31:3] == IF_Icache_packet_in[1].Icache_addr_in[31:3];
        miss_request = {IF_Icache_packet_in[0].Icache_request, IF_Icache_packet_in[0].Icache_request} & ~(rd_valid[0] | rd_valid[1]) ; // data request but miss in both cachemem
        pri_request  = |(miss_request   & ~miss_ack);
        pri_addr     = (miss_request[0] & !miss_ack[0]) ? { IF_Icache_packet_in[0].Icache_addr_in[31:3] , 3'b0 } :
                       (miss_request[1] & !miss_ack[1] & !inst_same) ? { IF_Icache_packet_in[1].Icache_addr_in[31:3] , 3'b0 } : '0;
        // mshr drive
        change_pc  = last_pc != IF_Icache_packet_in[1].Icache_addr_in;
        mshr_Iaddr = prefetch_state[1] ?   pref_addr   : pri_addr ;
        mshr_Irequest = prefetch_state[1] ? pref_req   : ( pri_request );
                         
        // miss state drive  
        inst_miss = miss_request | miss_ack;
        inst_hit  = (rd_valid[0] | rd_valid[1]) & (~inst_miss);            
    end


    // replacement drive
    always_comb begin
        wr_data = mshr_Odata;
        {wr_tag,wr_idx} = mshr_Oaddr[15:3];

        // compulsory miss, mask nru-bit
        for(int i = 0; i < `ICACHE_LINE_NUM; i++) begin
            block_fillen[0][i] = ~block_valid[0][i];
            block_fillen[1][i] = ( block_valid[0][i] & ~block_valid[1][i]);  // block 0 write first
        end
        
        nru_mask = (block_fillen [0][wr_idx] | block_fillen [1][wr_idx]) ? 2'b00 : 2'b11;

        for (int i = 0; i < `ICACHE_WAY; i++) begin //!TODO: modify this to use different replacement strategy
            wr_en[i] =  mshr_Ovalid & nru_tab[wr_idx][i]; 
        end
    end

    // output drive
    always_comb begin
        for (int i = 0; i < 2; i++) begin
            {rd_tag[i],rd_idx[i],rd_bo[i]} = IF_Icache_packet_in[i].Icache_addr_in[15:2];
            valid_data[i] = rd_valid[0][i] ? rd_data[0][i] :
                            rd_valid[1][i] ? rd_data[1][i] : '0;
            Icache_IF_packet_out[i].Icache_valid_out = (rd_valid[0][i] | rd_valid[1][i]); // only output valid until three instructions are all valid
            Icache_IF_packet_out[i].Icache_data_out  = rd_bo[i] ? valid_data[i][63:32] : valid_data[i][31:0];
            Icache_IF_packet_out[i].Icache_hit       = inst_hit[i];
        end
    end

    // nru table drive
    // synopsys sync_set_reset "reset"
    always_ff@(posedge clock)begin
        if(reset)begin
            nru_tab <= `SD '{`ICACHE_LINE_NUM{2'b1}};
        end else begin
            // nru update when cache hit
            for (int i = 0; i < 2; i++)begin
                if((rd_valid[0][i] | rd_valid[1][i]) && change_pc) begin // there's a hit
                    nru_tab[rd_idx[i]] <= `SD ~{rd_valid[1][i], rd_valid[0][i]};
                end 
                else if(|wr_en) begin
                    nru_tab[wr_idx]    <= `SD ~{wr_en};
                end
            end            
        end
    end

    // MSHR instantiation, 4 entries at total here.
    MSHR_icache #(.LENGTH(4)) mshr_ic(
        .clock(clock),
        .reset(reset),
        .load_addr(mshr_Iaddr),
        .load_request(mshr_Irequest),
        .load_full(mshr_full), //load queue is full ,can not take any misses
        .load_empty(mshr_empty),//load queue is empty
        .queue_data(mshr_Odata),
        .queue_addr(mshr_Oaddr),
        .queue_dvalid(mshr_Ovalid),
        .queue_clear(mshr_clear),
        .Icache2mem_command(Icache2mem_command_out),
        .Icache2mem_addr(Icache2mem_addr_out),
        .mem2Icache_ack(mem2Icache_ack_in),
        .mem2Icache_response(mem2Icache_response_in),
        .mem2Icache_tag(mem2Icache_tag_in),
        .mem2Icache_data(mem2Icache_data_in)
    );

    // cache memory instantiation, 2-way x 16 lines x 8 byte for now
    generate 
        for (genvar i = 0; i < `ICACHE_WAY; i++)
            cache #(.LINE_NUM(`ICACHE_LINE_NUM), .TAG_WIDTH(`ICACHE_TAG_WIDTH), .READ_WIDTH(`ICACHE_WAY)) 
                icache_block(
                    .clock(clock), 
                    .reset(reset), 

                    .wr_en(wr_en[i]),
                    .wr_command(),
                    .wr_idx(wr_idx), 
                    .wr_tag(wr_tag), 
                    .wr_data(wr_data), 
                    .wr_data_old(),
                    .wr_valid(),

                    .wb_data(),
                    .wb_addr(),
                    .wb_request(),
                    .wb_dirty(),

                    .cache_table(),

                    .rd_idx(rd_idx),
                    .rd_tag(rd_tag),
                    .rd_data(rd_data[i]),
                    .rd_valid(rd_valid[i]),
                    .block_valid(block_valid[i]),

                    .pref_idx(pref_idx),
                    .pref_tag(pref_tag),
                    .pref_skip(pref_skip[i])
            );
    endgenerate 

endmodule
