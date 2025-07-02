
---

# Full-Bypassing 4-Stage Pipelined RISC-V Processor

A Bluespec SystemVerilog (BSV) implementation of a 4-stage RISC-V processor, with full bypassing and separate instruction/data caches. The pipeline is divided into:

* **Fetch**
* **Decode**
* **Execute**
* **Writeback**

### 🔧 Features

* Full data bypassing from Execute and Writeback to Decode
* PC+4 prediction with annul logic on mispredictions
* Instruction cache (Direct-Mapped)
* Data cache (Two-Way Set Associative)
* Stall logic for hazard and memory delays

---

## 📁 Module Descriptions

<details>
<summary><strong><code>ALU.ms</code></strong></summary>

Implements the ALU. Uses a recursive adder that adds the left half and right half separately, then combines them — improving timing at the cost of more area.

</details>

<details>
<summary><strong><code>CacheHelpers.ms</code></strong></summary>

Provides helper functions to extract specific fields (like offsets, tags) used in RISC-V store instructions (`SW`, `SH`, `SB`, etc.).

</details>

<details>
<summary><strong><code>CacheTypes.ms</code></strong></summary>

Defines data structures used for cache communication (e.g., `MemReq`, `MemData`, and status dictionaries).

</details>

<details>
<summary><strong><code>Decode.ms</code></strong></summary>

Decodes raw instructions into the `DecodedInst` type. Extracts opcode, `funct3`, `funct7`, `rd`, `rs1`, and `rs2`.

</details>

<details>
<summary><strong><code>DirectMappedCache.ms</code></strong></summary>

Implements a direct-mapped instruction cache. Handles:

* Hits
* Clean misses
* Dirty misses
  Interacts with `MainMemory.ms`.

</details>

<details>
<summary><strong><code>Execute.ms</code></strong></summary>

Receives a `DecodedInst` and operands. Executes it using the ALU and determines the next PC. Returns an `ExecInst` with result and next PC.

</details>

<details>
<summary><strong><code>MainMemory.ms</code></strong> (Not written by me)</summary>

Simulates DRAM with line-based access. Ensures memory alignment and enforces single request per cycle. Useful for cache miss emulation.

</details>

<details>
<summary><strong><code>ProcTypes.ms</code></strong></summary>

Defines key processor types and enums:

* Instruction types (`IType`)
* Decoded instruction (`DecodedInst`)
* Branch function (`BrFunc`)
* Aliases for functions like `fnAdd` instead of using raw bits

</details>

<details>
<summary><strong><code>Processor.ms</code></strong></summary>

Top-level pipelined processor implementation.

* **Fetch**: Uses a direct-mapped instruction cache and PC+4 prediction with redirect support.
* **Decode**: Implements hazard detection and full bypassing from Execute and Writeback. Decodes instructions and drives fetch control.
* **Execute**: Runs instructions through ALU, calculates next PC, and issues memory requests for loads/stores.
* **Writeback**: Writes results back to register file. Load data is received here.

Includes logic for:

* Annulment (misprediction recovery)
* Load/store stalls
* Forwarding logic
* Instruction counting and debugging

</details>

<details>
<summary><strong><code>RegisterFile.ms</code></strong> (Not written by me)</summary>

Implements register read/write logic with appropriate synchronous ticking.

</details>

<details>
<summary><strong><code>SRAM.ms</code></strong> (Not written by me)</summary>

Simulates SRAM behavior used internally by `MainMemory.ms`.

</details>

<details>
<summary><strong><code>TwoWayCache.ms</code></strong></summary>

Two-way set associative data cache with LRU eviction. Handles:

* Hits
* Clean misses
* Dirty misses

Used by the data memory system of the processor.

</details>

---

