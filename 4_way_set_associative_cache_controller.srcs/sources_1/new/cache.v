`timescale 1ns / 1ps

module cache#(
    parameter  DATA_W=8,
    parameter BLOCK_SIZE=4,
    parameter  ADDR_W=16,
    parameter TAG_W=10,
    parameter CACHE_SIZE=64
     //block size is 4 words , byte addressable, 10 bit tag, 64 line cache thus 16 sets, total mem blocks is 2^14
)(
    input clk,
    input areset,
    input [ADDR_W-1:0] phy_addr,
    input [DATA_W-1:0] data_in,
    input rd_req,
    input wr_req,
    input [(BLOCK_SIZE*DATA_W)-1:0] mem_data_in,
    input mem_rd_done,
    output reg [DATA_W-1:0] data_out,
    output reg  [ADDR_W-1:0] mem_addr_rd,
    output reg  [ADDR_W-1:0] mem_addr_wr,
    output reg mem_rd, mem_wr,
    output reg [(BLOCK_SIZE*DATA_W)-1:0] mem_data_out,                                
    output ready
    );
    localparam IDLE_HIT=1'h0, MISS_ALLOCATE = 1'h1;                    
    
    reg [TAG_W-1:0] tag_dir [0:(CACHE_SIZE/4)-1][0:3];
    reg [(BLOCK_SIZE*DATA_W)-1:0] cache_mem [0:(CACHE_SIZE/4)-1][0:3];
    reg valid[0:(CACHE_SIZE/4)-1][0:3];
    reg dirty[0:(CACHE_SIZE/4)-1][0:3];
    
    reg [TAG_W-1:0]  l12_tag;
    reg [$clog2(CACHE_SIZE/4)-1:0] l12_set;
    reg [$clog2(BLOCK_SIZE)-1:0]l12_offset;
    reg [DATA_W-1:0] l12_data;
    reg l12_rd, l12_wr;
    
    reg  l23_rd, l23_wr;
    reg [TAG_W-1:0]  l23_tag;
    reg [$clog2(CACHE_SIZE/4)-1:0] l23_set;
    reg [$clog2(BLOCK_SIZE)-1:0] l23_offset;
    reg [DATA_W-1:0] l23_data;
    reg [1:0]l23_set_line;                                                                           //to store the set offset
    
    wire stall;
    
    reg [2:0]plru[0:15];       ///har set ka plru register
    
    reg hit, miss;
    reg pseudo_hit;
    reg  ps,ns;
    integer k,i;
    
    ///tell the processor when stall happens
    assign stall = (ps==MISS_ALLOCATE || (ps==IDLE_HIT && ns==MISS_ALLOCATE));
    assign ready = (hit || pseudo_hit);
    
    ///task for reset
    task reset;
    begin
        for(k=0; k<(CACHE_SIZE/4); k=k+1) begin
            for(i=0; i<4; i=i+1) begin                                                                                      
                valid[k][i]=0;
                dirty[k][i]=0;
                plru[k] = 0;
            end  
        end
        l12_tag=0; l12_rd=0; l12_wr=0; l12_offset=0; l12_set=0; l12_data=0;
        l23_rd=0; l23_wr=0; l23_data=0;  l23_offset=0; l23_set=0; l23_tag=0 ; l23_set_line =0;
        hit=0; miss=0; 
        pseudo_hit = 0; 
        ps = IDLE_HIT;
        data_out = 0;
        mem_rd = 0;
        mem_wr = 0;
        mem_addr_rd = 0;
        mem_addr_wr = 0;
        mem_data_out = 0;
    end
    endtask
   
    ///function to get the plru address for storing data from main memory during miss thus evicting the plru data
    function [1:0] victim_idx;
    input [2:0]plru_reg;
    input [$clog2(CACHE_SIZE/4)-1:0]set;   
        begin
            if(!valid[set][0])  victim_idx = 0;
            else if(!valid[set][1]) victim_idx = 1;
            else if(!valid[set][2]) victim_idx = 2;
            else if(!valid[set][3]) victim_idx = 3;
            else begin
                if(plru_reg[2]==0) begin
                    if(plru_reg[1]==0) victim_idx = 0;
                    else victim_idx = 1;
                end
                else begin
                    if(plru_reg[0]==0) victim_idx = 2;
                    else victim_idx = 3;
                end
            end     
        end
    endfunction
    
    ///task to update the set plru register
    task update_plru;
    input [$clog2(CACHE_SIZE/4)-1:0]set;                        //set bits use karlo for accessing plru of that set
    input [1:0]set_idx;                                                        
    begin
        case(set_idx)
            0:  begin
                plru[set][2] <= 1;
                plru[set][1] <= 1;
            end
             1:  begin
                plru[set][2] <= 1;
                plru[set][1] <= 0;
            end
             2:  begin
                plru[set][2] <= 0;
                plru[set][0] <= 1;
            end
             3:  begin
                plru[set][2] <= 0;
                plru[set][0] <= 0;
            end
        endcase
    end
    endtask
    
    /// task to write_back to main mem
    task evict;
        input [$clog2(CACHE_SIZE/4)-1:0]set;
        input [1:0]set_idx;    
        begin
            if(dirty[set][set_idx])begin
            
                mem_wr <= 1;
                mem_data_out <= cache_mem[set][set_idx];
                mem_addr_wr <=  {tag_dir[set][set_idx], set, {$clog2(BLOCK_SIZE){1'b0}}};                                  ///{$clog2(BLOCK_SIZE){1'b0}} concatenated.
                dirty[set][set_idx] <= 0;
                
            end
            
            else begin
                mem_wr <= 0;
            end
        end
    endtask
    
    ///task to allocate
    task allocate;
        input [(BLOCK_SIZE*DATA_W)-1:0] data;
        input [$clog2(CACHE_SIZE/4)-1:0]set;
        input [1:0]set_idx; 
        begin
            cache_mem[set][set_idx] <= data;
            valid[set][set_idx] <= 1;
            
        end
    endtask
    
    
    //stage 1 : decode address bits
    always @(posedge clk or posedge areset) begin                       //isme aur 2nd stage mei abhi stalling nahi kari hai
        if (areset) begin
            reset;
        end
        else begin
            if(!stall) begin
                l12_rd <= rd_req;
                l12_wr <= wr_req;
                l12_tag <= phy_addr[ADDR_W-1 : (ADDR_W-TAG_W)];
                l12_set <= phy_addr[(ADDR_W-TAG_W-1) : $clog2(BLOCK_SIZE)];
                l12_offset <= phy_addr[$clog2(BLOCK_SIZE)-1:0];
                l12_data <= data_in;
           end
        end
    end
    
    //stage 2 : compare tag bits
    always @(posedge clk or posedge areset) begin
        if(areset) begin
            reset;
        end
        else begin
        if(!stall) begin
            if((l12_tag == tag_dir[l12_set][0]))begin
                if(valid[l12_set][0])hit <= 1;
                else hit <= 0;
                miss <= 0;
                mem_rd <= 0;
                l23_set_line <= 0;
            end    
            else if((l12_tag == tag_dir[l12_set][1]))begin
                if(valid[l12_set][1])hit <= 1;
                else hit <= 0;
                miss <= 0;
                mem_rd <= 0;
                l23_set_line <= 1;
            end   
            else if((l12_tag == tag_dir[l12_set][2]))begin
                if(valid[l12_set][2])hit <= 1;
                else hit <= 0;
                miss <= 0;
                mem_rd <= 0;
                l23_set_line <= 2;
            end   
            else if((l12_tag == tag_dir[l12_set][3]))begin
                if(valid[l12_set][3])hit <= 1;
                else hit <= 0;
                miss <= 0;
                mem_rd <= 0;
                l23_set_line <= 3;
            end   
            else begin
                miss <= 1;
                hit <= 0;
                mem_rd <= 1;
                mem_addr_rd <= {l12_tag, l12_set, {$clog2(BLOCK_SIZE){1'b0}}};
            end      
        
        l23_tag <= l12_tag;
        l23_rd <= l12_rd;
        l23_wr <= l12_wr;
        l23_offset <= l12_offset;
        l23_set <= l12_set;
        l23_data <= l12_data;
        
        ///iss stage mei stall kardenge only for miss case
        end
        end
    end
    
    //stage 3 : read hit, read miss, write hit, write miss
    always @(posedge clk or posedge areset) begin
        if(areset) begin
            reset;
        end
        else begin
        ps <= ns;
        case(ps)
            IDLE_HIT: begin
                mem_wr <= 0;
                if(l23_rd && (hit || pseudo_hit)) begin            ///read now
                    case(l23_offset)
                        0: data_out <= cache_mem[l23_set][l23_set_line][DATA_W-1 : 0];
                        1: data_out <= cache_mem[l23_set][l23_set_line][2*DATA_W-1 : DATA_W];
                        2: data_out <= cache_mem[l23_set][l23_set_line][3*DATA_W-1 : 2*DATA_W];
                        3: data_out <= cache_mem[l23_set][l23_set_line][4*DATA_W-1 : 3*DATA_W];
                    endcase
                    update_plru(l23_set, l23_set_line);
                    pseudo_hit <= 0;
                end
                
                else if(l23_wr && (hit ||pseudo_hit) )begin
                    case(l23_offset)
                        0: cache_mem[l23_set][l23_set_line][DATA_W-1:0] <= l23_data;
                        1: cache_mem[l23_set][l23_set_line][2*DATA_W-1 : DATA_W] <= l23_data;
                        2: cache_mem[l23_set][l23_set_line][3*DATA_W-1 : 2*DATA_W] <= l23_data;
                        3: cache_mem[l23_set][l23_set_line][4*DATA_W-1 : 3*DATA_W] <= l23_data;
                    endcase
                    dirty[l23_set][l23_set_line]<=1;
                    update_plru(l23_set, l23_set_line);
                    pseudo_hit <= 0;
                end
                
                else begin
//                    data_out <= 0;                                     //not required
//                    mem_rd <= 0;
                end
            end
            
            MISS_ALLOCATE: begin
                mem_rd <= 0;
                if(mem_rd_done) begin
                    evict(l23_set, victim_idx(plru[l23_set], l23_set));
                    allocate(mem_data_in, l23_set, victim_idx(plru[l23_set], l23_set) );
                    tag_dir[l23_set][ victim_idx(plru[l23_set], l23_set) ] <= l23_tag;
                    l23_set_line <= victim_idx(plru[l23_set], l23_set);
                    valid[l23_set][victim_idx(plru[l23_set], l23_set)] <= 1 ;
                    pseudo_hit <= 1;
                end      
            end
        endcase
        end
    end
    
    //state transition logic
    always @(*) begin
    ns = ps;
    
    case(ps)

    IDLE_HIT: begin                                                       //including read_hit nad write_hit
        if(miss &&  (~pseudo_hit))                                        //bcoz pseudo hit is initially 0 and after miss and me_rd_done we assert it and then we do not want to get in miss state
            ns = MISS_ALLOCATE;
        else ns = IDLE_HIT;
    end

     MISS_ALLOCATE: begin
            if(mem_rd_done) ns = IDLE_HIT;
            else ns = MISS_ALLOCATE;
    end

    endcase
end


endmodule








