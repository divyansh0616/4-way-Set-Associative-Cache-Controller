`timescale 1ns / 1ps
module top_module#( 
    parameter DATA_W=8,
    parameter ADDR_W=16,
    parameter BLOCK_SIZE = 4
)(
    input clk,
    input areset,
    input [ADDR_W-1:0]phy_addr,
    input [DATA_W-1:0]data_in,
    input rd_req, wr_req,
    output [DATA_W-1:0]data_out,
    output ready
    );
    
    wire mem_rd, mem_wr, mem_rd_done;
    wire [(BLOCK_SIZE*DATA_W)-1:0] mem_data_in, mem_data_out;
    wire [ADDR_W-1:0] mem_addr_rd, mem_addr_wr;
    
    ///instantiation
    cache dut(
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
    
    main_mem uut(
        clk,
        mem_rd,
        mem_wr,
        mem_data_out,
        mem_addr_rd,
        mem_addr_wr,
        mem_data_in,
        mem_rd_done
    );
    
endmodule
