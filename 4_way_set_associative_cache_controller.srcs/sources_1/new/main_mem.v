`timescale 1ns / 1ps
  
module main_mem#(
    parameter DATA_W = 8,
    parameter BLOCK_SIZE = 4,
    parameter ADDR_W = 16,
    parameter MEM_SIZE = 65536
)(
    input clk,
    input mem_rd,
    input mem_wr,
    input [(BLOCK_SIZE*DATA_W)-1 : 0]mem_data_out,
    input [ADDR_W-1 : 0] mem_addr_rd,
    input [ADDR_W-1 : 0] mem_addr_wr,
    output reg [(BLOCK_SIZE*DATA_W)-1 : 0] mem_data_in,                   //cache in
    output reg mem_rd_done
    );
    localparam IDLE=2'b00, READ=2'b01, WRITE=2'b10;
    reg [(BLOCK_SIZE*DATA_W)-1:0] main_mem [0: (MEM_SIZE/4)-1];
    reg [1:0] ps, ns;
    
    always @(posedge clk)begin
        ps <= ns;
        case(ps)
            IDLE: begin
                mem_rd_done <= 0;
//                mem_data_in <= 0;                                                                                //cache in 
            end
            READ: begin
                mem_data_in <= main_mem[mem_addr_rd[ADDR_W-1: $clog2(BLOCK_SIZE)] ];
                mem_rd_done <= 1;
            end
            WRITE: begin
                main_mem[mem_addr_wr[ADDR_W-1: $clog2(BLOCK_SIZE)] ] <= mem_data_out;
            end
            default:begin
                mem_rd_done <= 0;
                mem_data_in <= 0;
            end
        endcase
    end
    
    always @(*) begin
        ns = ps;
        case(ps)
            IDLE: begin
                if(mem_rd) ns=READ;
                else if(mem_wr) ns=WRITE;
                else ns=IDLE;
            end
            
            READ: begin
                if(mem_wr) ns=WRITE;
                else if(mem_rd_done) ns=IDLE;
                else ns=READ;
            end
            
            WRITE: begin
                if(mem_rd) ns = READ;
                else if(!mem_wr) ns=IDLE;
                else ns = WRITE;
            end
            
            default: ns=IDLE;
        endcase
    end
    
endmodule
