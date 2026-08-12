# Pipelined 4-Way Set Associative Cache

A parameterized Verilog implementation of an L1 cache. It features a 3-stage pipeline, Pseudo-LRU (PLRU) replacement policy, Write-Back, and Write-Allocate memory management.

## Features
* **4-Way Set Associative:** 64 total cache lines organized into 16 sets by default.
* **Pipelined Design:** 3 distinct stages for Address Decode, Tag Comparison, and Data Access/Allocation to improve throughput.
* **Pseudo-LRU (PLRU) Replacement:** Efficient 3-bit binary tree tracking per set for fast victim selection.
* **Write-Back & Write-Allocate:** Minimizes main memory traffic by only writing modified (dirty) lines back to memory upon eviction.
* **Fully Parameterized:** Easily adjust word size, block size, address width, and cache size.

## Pipeline Architecture
1. **Stage 1 (Decode):** Latches the incoming physical address and decodes the tag, set, and block offset.
2. **Stage 2 (Compare):** Compares the tag against the 4 ways in the targeted set to determine a hit or miss.
3. **Stage 3 (Execute):** 
   - **Hit:** Reads or writes the data to the cache memory and updates PLRU bits.
   - **Miss:** Asserts a stall, evicts a dirty block to main memory if necessary, and waits for the new block to be allocated from main memory.

## Parameters

| Parameter | Default Value | Description |
| :--- | :--- | :--- |
| `DATA_W` | 8 | Width of a single data word in bits. |
| `BLOCK_SIZE` | 4 | Number of words per cache block (line). |
| `ADDR_W` | 16 | Width of the physical address in bits. |
| `TAG_W` | 10 | Width of the tag field in bits. |
| `CACHE_SIZE` | 64 | Total number of blocks (lines) in the cache. |

## Interface Signals

### Processor Interface
* `clk`, `areset`: Clock and active-high asynchronous reset.
* `phy_addr`: Physical address from the CPU.
* `data_in`: Data to be written to the cache.
* `rd_req`, `wr_req`: Read and write request flags.
* `data_out`: Data read from the cache.
* `ready`: Asserts when the cache operation is complete (Hit or resolved Miss).

### Main Memory Interface
* `mem_data_in`: Entire block of data fetched from main memory.
* `mem_rd_done`: Signal from memory indicating the requested block is ready.
* `mem_addr_rd`, `mem_addr_wr`: Memory addresses for reading missed blocks and writing back dirty blocks.
* `mem_rd`, `mem_wr`: Memory read and write enable signals.
* `mem_data_out`: Entire block of data to be written back (evicted) to main memory.

## Usage
Instantiate the `cache` module in your top-level design, wire it to your processor and memory controller, and adjust the parameters as needed to fit your system's architecture.
