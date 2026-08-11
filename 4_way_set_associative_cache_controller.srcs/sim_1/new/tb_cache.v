`timescale 1ns / 1ps

module tb_cache;

    parameter DATA_W      = 8;
    parameter BLOCK_SIZE  = 4;
    parameter ADDR_W      = 16;
    parameter TAG_W       = 10;
    parameter CACHE_SIZE  = 64;

    reg clk;
    reg areset;

    reg [ADDR_W-1:0] phy_addr;
    reg [DATA_W-1:0] data_in;
    reg rd_req;
    reg wr_req;

    reg [(BLOCK_SIZE*DATA_W)-1:0] mem_data_in;
    reg mem_rd_done;

    wire [DATA_W-1:0] data_out;
    wire [ADDR_W-1:0] mem_addr;
    wire mem_rd, mem_wr;
    wire [(BLOCK_SIZE*DATA_W)-1:0] mem_data_out;
    wire ready;

    // DUT INSTANTIATION
    cache uut(
        .clk(clk),
        .areset(areset),
        .phy_addr(phy_addr),
        .data_in(data_in),
        .rd_req(rd_req),
        .wr_req(wr_req),
        .mem_data_in(mem_data_in),
        .mem_rd_done(mem_rd_done),
        .data_out(data_out),
        .mem_addr_rd(mem_addr_rd),
        .mem_addr_wr(mem_addr_wr),
        .mem_rd(mem_rd),
        .mem_wr(mem_wr),
        .mem_data_out(mem_data_out),
        .ready(ready)
    );

    // CLOCK GENERATION
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    //random data in cache
    integer i,j;
    initial begin
        for(i=0; i<(CACHE_SIZE/4); i=i+1) begin
            for(j=0; j<4; j=j+1) begin
                uut.cache_mem[i][j] = $random;
                uut.tag_dir[i][j] = 0;
            end
        end
    end

    integer s,l,o;         //for set, line, offset
 
     // TASK : READ HIT CASE   
    task read_hit;
        input [ADDR_W-1:0] addr;
        input [1:0]line;
        begin
            s = addr[(ADDR_W-TAG_W-1) : $clog2(BLOCK_SIZE)];
            l = line;
            uut.tag_dir[s][l] = addr[ADDR_W-1 : ADDR_W -TAG_W];
            uut.valid[s][l] = 1;
            @(posedge clk);
            phy_addr <= addr;
            rd_req   <= 1;
            wr_req   <= 0;
            repeat(3) @(posedge clk);
            $display("offset is %h, line is %h", uut.l23_offset, uut.l23_set_line);
        end
    endtask

    // TASK : WRITE HIT
    task write_hit;
        input [ADDR_W-1:0] addr;
        input [DATA_W-1:0] data;
        input [1:0]line;
        begin
            s = addr[(ADDR_W-TAG_W-1) : $clog2(BLOCK_SIZE)];
            l = line;
            o = addr[$clog2(BLOCK_SIZE)-1 : 0];
            uut.tag_dir[s][l] = addr[ADDR_W-1 : ADDR_W -TAG_W];
            uut.valid[s][l] = 1;
            
            @(posedge clk);
            phy_addr <= addr;
            data_in  <= data;
            wr_req   <= 1;
            rd_req   <= 0;
            wait(uut.l23_data == data);                                ///the tag for every line must be different 
            @(posedge clk);
            @(posedge clk);
            
            ///VERY IMPORTANT LINE FOR INDEXING IN VERILOG
            
            $display("the value written is  %h, plru is %h", uut.cache_mem[s][l][o*DATA_W +: DATA_W], uut.plru[s]);
        end
    endtask

    //TASK: READ_MISS
    task read_miss;
    input [ADDR_W-1:0] addr;
    input [(BLOCK_SIZE*DATA_W)-1:0] data_mem;
    begin
    s = addr[(ADDR_W-TAG_W-1) : $clog2(BLOCK_SIZE)];
        @(posedge clk);
        phy_addr = addr;
        rd_req = 1;
        wr_req = 0;
        repeat(4) @(posedge clk);
        l = uut.victim_idx(uut.plru[uut.l23_set], uut.l23_set);
        $display("victim %h, the dirty value is %h, dirty bit is %h", l, uut.cache_mem[s][l], uut.dirty[s][l] );
        mem_rd_done =1;
        mem_data_in = data_mem;
        @(posedge clk);
        mem_rd_done = 0;
        repeat(2)@(posedge clk);
        $display("updated plru is %h, dirty bit is %h", uut.plru[s], uut.dirty[s][l]);
    end
    endtask


    //TASK: WRITE_MISS
    task write_miss;
    input [ADDR_W-1:0] addr;
    input [DATA_W-1:0] data;
    input [(BLOCK_SIZE*DATA_W)-1:0] data_mem;
    begin
    s = addr[(ADDR_W-TAG_W-1) : $clog2(BLOCK_SIZE)];
        @(posedge clk);
        phy_addr = addr;
        data_in = data;
        rd_req = 0;
        wr_req = 1;
        repeat(4) @(posedge clk);
        l = uut.victim_idx(uut.plru[uut.l23_set], uut.l23_set);
        $display("victim %h, the dirty value is %h, dirty bit is %h", l, uut.cache_mem[s][l], uut.dirty[s][l] );
        mem_rd_done =1;
        mem_data_in = data_mem;
        @(posedge clk);
        mem_rd_done = 0;
        repeat(2)@(posedge clk);
        
        $display("updated plru is %h, dirty bit is %h", uut.plru[s], uut.dirty[s][l]);
    end
    endtask
    initial begin

        phy_addr   = 0;
        data_in    = 0;
        rd_req     = 0;
        wr_req     = 0;
        mem_data_in = 0;
        mem_rd_done = 0;

        areset = 1;
        #20;
        areset = 0;


//     tag bits must be different for all else it will always point to the same line always;
        write_hit(16'h2345, 8'h23, 2'h0);
        $display("previous value is %h", uut.cache_mem[1][0]);
       write_hit(16'h3145, 8'h43, 2'h1);
        write_hit(16'h2245, 8'hff, 2'h2);
        write_hit(16'h2445, 8'h20, 2'h3);
//        read_hit(16'h2445, 2'h3);
        @(posedge clk);
        
//        read_hit(16'h2245, 2'h2);
//        @(posedge clk);
//        read_hit(16'h2345, 2'h0);
//        @(posedge clk);
//        read_hit(16'h3145, 2'h1);
//        repeat(8) @(posedge clk);

        write_miss(16'h1345, 8'h06, 32'h12345678);
        write_miss(16'h1876, 8'h05, 32'h1afdce78);
        write_miss(16'h1978, 8'h31, 32'h17fc5678);
        $display("updated value is %h", uut.cache_mem[1][0]);
        
        #10;

        #50;

        $finish;

    end

endmodule