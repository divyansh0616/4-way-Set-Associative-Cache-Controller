`timescale 1ns / 1ps

module tb_main_mem#(
    parameter DATA_W = 8,
    parameter BLOCK_SIZE = 4,
    parameter ADDR_W = 16,
    parameter MEM_SIZE = 65536
);
    
    reg clk;
    reg mem_rd;
    reg mem_wr;
    reg [(BLOCK_SIZE*DATA_W)-1 : 0]mem_data_out;
    reg [ADDR_W-1 : 0] mem_addr;
    wire [(BLOCK_SIZE*DATA_W)-1 : 0] mem_data_in;
    wire mem_rd_done;
    
    main_mem dut(
        clk,
        mem_rd,
        mem_wr,
        mem_data_out,
        mem_addr,
        mem_data_in,
        mem_rd_done
    );
    
    initial begin
        clk=0;
        forever #5 clk=~clk;
    end
    
    task read;
        input [ADDR_W-1 : 0] addr;
        input [(BLOCK_SIZE*DATA_W)-1 : 0]data;
        begin
            dut.main_mem[addr+3] = data[7:0];
            dut.main_mem[addr+2] = data[15:8];
            dut.main_mem[addr+1] = data[23:16];
            dut.main_mem[addr] = data[31:24];
            mem_addr = addr;
            mem_rd = 1;
            mem_wr = 0;
            @(posedge clk);
            $display("the data sent is %h", dut.main_mem[addr +: 4]);
            mem_rd = 0;
            @(posedge clk);
            @(posedge clk);
            wait(mem_rd_done == 0);
        end
    endtask
    
    task write;
        input [ADDR_W-1 : 0] addr;
        input [(BLOCK_SIZE*DATA_W)-1 : 0] data;
        begin
            mem_data_out = data;
            mem_addr = addr;
            mem_rd = 0;
            mem_wr = 1;
            @(posedge clk);
            mem_wr=0;
            @(posedge clk);
            @(posedge clk);
            $display("the data stored is %h", dut.main_mem[addr +: 4]);
        end
    endtask
    
    initial begin
        clk=0;
        mem_rd = 0;
        mem_wr = 0;
        mem_data_out = 0;
        mem_addr = 0;
         
        @(posedge clk);
        read(16'h1234, 32'h12345678);  
        write(16'h6574, 32'h6a534ff3);
        
        #50
        $finish;
    end
    
endmodule
