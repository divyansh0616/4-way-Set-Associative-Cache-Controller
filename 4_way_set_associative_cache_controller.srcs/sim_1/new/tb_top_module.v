`timescale 1ns / 1ps

module tb_top_module;
    
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

    wire [DATA_W-1:0] data_out;
    wire ready;
    
    top_module tm(
        clk,
        areset,
        phy_addr,
        data_in,
        rd_req,
        wr_req,
        data_out,
        ready
    );
    
    initial begin
        clk=0;
        forever #5 clk=~clk;
    end
    
    integer i,j,k;
    initial begin
         for(i=0; i<(CACHE_SIZE/4); i=i+1) begin
            for(j=0; j<4; j=j+1) begin
                tm.dut.cache_mem[i][j] = $random;
                tm.dut.tag_dir[i][j] = 0;
            end
        end
        
        for (k=0; k<2**(ADDR_W-2); k=k+1)begin
            tm.uut.main_mem[k] = $random;
        end
    end
    
    integer set, line, offset;
    //TASK: READ_HIT
    task read_hit;
    input [ADDR_W-1:0] addr;
    input [1:0]line;
    begin
        set = addr[ADDR_W-TAG_W-1 : $clog2(BLOCK_SIZE)];
        line = line;
        offset = addr[($clog2(BLOCK_SIZE))-1 : 0];
        tm.dut.tag_dir[set][line] = addr[ADDR_W-1:ADDR_W-TAG_W];
        tm.dut.valid[set][line]=1;
        wait(tm.dut.stall==0);
        @(posedge clk);
        wr_req = 0;
        rd_req = 1;
        data_in = 0;
        phy_addr = addr;
        $display("---> the value read is %h", tm.dut.cache_mem[set][line][offset*DATA_W +: DATA_W]);
        $display("//the set is %h", set);   
    end
    endtask
    
    //TASK:WRITE_HIT
    task write_hit;
    input [ADDR_W-1:0] addr;
    input [1:0] line;
    input [DATA_W-1:0] data;
    begin
        set = addr[ADDR_W-TAG_W-1 : $clog2(BLOCK_SIZE)];
        line = line;
        offset = addr[($clog2(BLOCK_SIZE))-1 : 0];
        tm.dut.tag_dir[set][line] = addr[ADDR_W-1:ADDR_W-TAG_W];
        tm.dut.valid[set][line]=1;
        wait(tm.dut.stall ==0);
        @(posedge clk);
        wr_req = 1;
        rd_req = 0;
        data_in = data;
        phy_addr = addr;
        $display("the data that is being changed is %h",tm.dut.cache_mem[set][line]);
        $display("the set is %d", set);
    end
    endtask
    
    // TASK:READ_MISS
    task read_miss;
    input [ADDR_W-1:0] addr;
    begin
        set = addr[ADDR_W-TAG_W-1 : $clog2(BLOCK_SIZE)];
        offset = addr[($clog2(BLOCK_SIZE))-1 : 0];
        wait(tm.dut.stall ==0);
        @(posedge clk);
        rd_req =1 ;
        wr_req = 0;
        phy_addr = addr;
        data_in = 0;
        $display("----> the data fetched from main mem is %h", tm.uut.main_mem[addr[ADDR_W-1 : 2]]);
        $display("the set is %d", set);
    end
    endtask
    
    //TASK:WRITE_MISS
    task write_miss;
    input [ADDR_W-1:0] addr;
    input [DATA_W-1:0]data;
    begin
        set = addr[ADDR_W-TAG_W-1 : $clog2(BLOCK_SIZE)];
        offset = addr[($clog2(BLOCK_SIZE))-1 : 0];
        wait(tm.dut.stall ==0);
        @(posedge clk);
        rd_req =0;
        wr_req = 1;
        phy_addr = addr;
        data_in = data;
        $display("----> the data fetched from main mem is %h", tm.uut.main_mem[addr[ADDR_W-1 : 2]]);
        $display("the set is %d", set);
    end
    endtask
    
    initial begin
        areset=1;
        clk=0;
        phy_addr=0;
        data_in=0;
        rd_req=0;
        wr_req=0;
        
        #10
        areset=0;
        read_hit(16'h6afd, 2'h2);
        write_hit(16'h2fd3, 2'h1, 8'h2a);
        write_hit(16'h4cd3, 2'h2, 8'h4f);
        write_hit(16'h28d3, 2'h3, 8'h37);
        write_hit(16'h3dd3, 2'h0, 8'h7a);
        read_miss(16'h2cd2 );
        write_miss(16'hffd1, 8'h23);
        @(posedge clk);
        wait(tm.dut.stall == 0);
        read_miss(16'h4312);
        @(posedge clk);
        wait(tm.dut.stall == 0);
        write_miss(16'had13, 8'h00);
        @(posedge clk);
        wr_req = 0;
        rd_req = 0;
        data_in = 0;
        phy_addr = 0;
//        tm.dut.tag_dir[4'hd][0] = 10'h048;
//        tm.dut.valid[4'hd][0] = 1;
//        @(posedge clk);
//        phy_addr=16'h1234;
//        rd_req=1;
//        @(posedge clk);
//        phy_addr=0;
//        rd_req = 0;
//        wr_req = 1;
//        phy_addr= 16'h324a;
//        data_in = 8'h2a;
//        @(posedge clk);
//        wr_req = 0;
//        phy_addr= 0;
//        data_in = 0;
//        $display("%h", tm.uut.main_mem[14'h048d]); 
//        $display("%h", tm.uut.main_mem[14'h0c92]); 
//        repeat(4) @(posedge clk);
//        $display("%h", tm.dut.cache_mem[4'hd][0]);
//        repeat(4) @(posedge clk);
//        $display("%h", tm.dut.cache_mem[4'h2][0]);
////        wait(tm.ready ==1);
////        phy_addr = 16'h546a;
////        data_in = 8'h4f;
////        wr_req = 1;
////        @(posedge clk);
////        wr_req = 0;
        
        #200;
        $finish;
    end
         
endmodule
