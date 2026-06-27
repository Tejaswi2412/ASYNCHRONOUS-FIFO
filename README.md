# Asynchronous FIFO — Verilog Implementation

![Language](https://img.shields.io/badge/Language-Verilog-blue)
![Simulator](https://img.shields.io/badge/Simulator-Icarus%20Verilog-green)
![Status](https://img.shields.io/badge/Status-RTL%20Complete-yellow)
![Depth](https://img.shields.io/badge/Depth-8%20slots-orange)
![Width](https://img.shields.io/badge/Width-8%20bit-orange)

A fully functional **Asynchronous FIFO** implemented in Verilog HDL, designed to safely transfer data between two independent clock domains. The design implements Gray code pointer synchronization, 2-flop metastability mitigation, dual-port RAM storage, and independent full/empty detection logic — core techniques required in any Clock Domain Crossing (CDC) design.

---

## Table of Contents

- [Overview](#overview)
- [Why Async FIFO](#why-async-fifo)
- [Architecture](#architecture)
- [CDC Problem and Solution](#cdc-problem-and-solution)
- [Module Description](#module-description)
- [Design Specifications](#design-specifications)
- [Key Design Decisions](#key-design-decisions)
- [How to Run](#how-to-run)
- [Directory Structure](#directory-structure)
- [Tools Used](#tools-used)
- [Future Improvements](#future-improvements)

---

## Overview

An Asynchronous FIFO is a hardware buffer that allows safe data transfer between two subsystems operating on completely independent clocks. Unlike a synchronous FIFO, no shared clock exists between the producer and consumer — making direct signal sharing across the clock boundary dangerous due to metastability.

This implementation uses the industry-standard approach:

- **Gray code pointers** to eliminate multi-bit transitions during clock domain crossings
- **2-flop synchronizers** to safely pass pointer values across clock boundaries
- **Dual-port RAM** with independent read and write clock ports
- **Combinational full/empty detection** computed locally within each clock domain — no shared flag registers

---

## Why Async FIFO

In real SoC designs, blocks rarely share the same clock. Common examples:

| Scenario | Write Domain | Read Domain |
|---|---|---|
| ADC → DSP | ADC sample clock (e.g. 100 MHz) | DSP processing clock (e.g. 50 MHz) |
| Sensor → FPGA | Sensor clock | FPGA system clock |
| CPU → UART | CPU core clock | UART baud clock |

Connecting these domains directly causes **metastability** — a flip-flop sampling a signal that is changing at the same instant as its clock edge. The output enters an indeterminate state, neither 0 nor 1, for an unpredictable duration. An Async FIFO solves this by ensuring only single-bit Gray code signals cross the domain boundary, through 2-flop synchronizers.

---

## Architecture

```
Write Domain (wclk)                        Read Domain (rclk)
────────────────────                       ──────────────────────

  Producer
     │ data_in, w_en
     ▼
┌─────────────────┐   waddr   ┌──────────────────┐   rd_addr  ┌─────────────────┐
│  wptr_handler   │──────────▶│  dual_port_ram   │◀──────────│  rptr_handler   │
│                 │           │                  │           │                 │
│ wptr (binary)   │           │  8 slots × 8bit  │           │  rptr (binary)  │
│ wptr_gray ──────┼──────┐    │                  │    ┌──────┼── rptr_gray     │
│ w_full          │      │    └──────────────────┘    │      │  rd_empty       │
└─────────────────┘      │                            │      └─────────────────┘
                         │                            │               │
                         ▼                            ▼               ▼
                   ┌───────────┐              ┌───────────┐      Consumer
                   │ sync_w2r  │              │ sync_r2w  │
                   │ (2-flop)  │              │ (2-flop)  │
                   │  rclk     │              │  wclk     │
                   └─────┬─────┘              └─────┬─────┘
                         │ wptr_gray_sync            │ rptr_gray_sync
                         └──────────────────────────┘
                              crosses domain safely
```

**Key architectural decisions:**

- **Data never crosses clock domains** — it sits in RAM, accessed by each side independently through separate ports
- **Only Gray code pointers cross** — through 2-flop synchronizers, absorbing any metastability
- **Full/empty computed locally** — write domain computes full using synchronized rptr; read domain computes empty using synchronized wptr. No shared flags.

---

## CDC Problem and Solution

### The Problem — Metastability

When a flip-flop in one clock domain samples a signal driven by a different clock, the two clock edges can coincide. The flip-flop's setup time is violated — its output enters a metastable state, resolving to an unpredictable value after an indeterminate time. In multi-bit binary pointers, bits switch at slightly different times, creating phantom intermediate values during transitions.

```
Binary 3→4:  011 → 111 → 101 → 100  (passes through garbage values)
Gray   3→4:  010 → 110              (only 1 bit changes — no garbage)
```

### The Solution — Gray Code + 2-Flop Synchronizer

**Gray code** ensures only one bit changes per pointer increment. Even if the 2-flop synchronizer samples mid-transition, it reads either the old value or the new value — both valid pointer positions. No phantom values.

**2-flop synchronizer** gives the metastable output of FF1 one full destination clock cycle to resolve before FF2 samples it. The probability of remaining metastable after one full cycle is negligible at practical clock frequencies.

```
src domain          dst domain
                  ┌──FF1──┬──FF2──→ safe, stable output
signal ───────────┘       │
                      (metastability    (samples after
                       absorbed)         resolution)
```

**Why stale pointer values are acceptable:** The synchronized pointer seen by the other domain may be 1-2 cycles old. This causes conservative full/empty decisions — the system stalls for one extra cycle rather than corrupting data. Data integrity is always preserved.

---

## Module Description

### 1. `dual_port_ram.v` — Dual Port Storage

8-slot × 8-bit RAM with completely independent write and read ports, each driven by its own clock. Write port is clocked by `wclk`; read port by `rclk`. No full/empty logic — pure storage only.

| Port | Direction | Width | Description |
|---|---|---|---|
| `wclk` | input | 1 | Write clock |
| `rclk` | input | 1 | Read clock |
| `w_en` | input | 1 | Write enable |
| `r_en` | input | 1 | Read enable |
| `wrt_ptr` | input | 3 | Write address (from wptr_handler) |
| `rd_ptr` | input | 3 | Read address (from rptr_handler) |
| `data_in` | input | 8 | Data to write |
| `data_out` | output | 8 | Data read out |

---

### 2. `wptr_handler.v` — Write Pointer and Full Detection

Lives entirely in `wclk` domain. Maintains the binary write pointer, converts it to Gray code, outputs the write address to RAM, and computes the full flag by comparing its own Gray code pointer against the synchronized read pointer arriving from `sync_r2w`.

| Port | Direction | Width | Description |
|---|---|---|---|
| `wclk` | input | 1 | Write clock |
| `wrst_n` | input | 1 | Active-low reset |
| `w_en` | input | 1 | Write enable |
| `rd_ptr_sync` | input | 4 | Synchronized rptr from sync_r2w |
| `waddr` | output | 3 | Write address to RAM (wptr[2:0]) |
| `w_ptr_gray` | output | 4 | Gray code wptr to sync_w2r |
| `w_full` | output | 1 | Full flag to producer |

**Gray code conversion:**
```verilog
assign w_ptr_gray = w_ptr ^ (w_ptr >> 1);
```

**Full condition:**
```
w_full = (w_ptr_gray[3] != rd_ptr_sync[3]) &&
         (w_ptr_gray[2] != rd_ptr_sync[2]) &&
         (w_ptr_gray[1:0] == rd_ptr_sync[1:0])
```

The MSB of the pointer acts as a lap counter — it flips every time the pointer wraps the FIFO. When write has lapped read by exactly the FIFO depth, MSBs differ while lower bits match — signalling full.

---

### 3. `rptr_handler.v` — Read Pointer and Empty Detection

Mirror image of wptr_handler, lives entirely in `rclk` domain. Maintains binary read pointer, converts to Gray code, outputs read address to RAM, and computes empty flag by comparing against synchronized write pointer from `sync_w2r`.

| Port | Direction | Width | Description |
|---|---|---|---|
| `rclk` | input | 1 | Read clock |
| `rstn` | input | 1 | Active-low reset |
| `rd_en` | input | 1 | Read enable |
| `w_ptr_sync` | input | 4 | Synchronized wptr from sync_w2r |
| `rd_addr` | output | 3 | Read address to RAM (rptr[2:0]) |
| `rd_ptr_gray` | output | 4 | Gray code rptr to sync_r2w |
| `rd_empty` | output | 1 | Empty flag to consumer |

**Empty condition:**
```
rd_empty = (rd_ptr_gray == w_ptr_sync)
```

Empty is a simpler comparison — all bits equal means pointers are at the same position, FIFO has no unread data.

---

### 4. `sync_w2r.v` — Write-to-Read Synchronizer

2-flop synchronizer. Accepts `w_ptr_gray` from the write clock domain and delivers a stable, metastability-free copy `w_ptr_sync` into the read clock domain. Both flip-flops are clocked by `rclk`.

| Port | Direction | Width | Description |
|---|---|---|---|
| `rclk` | input | 1 | Destination clock (read domain) |
| `w_ptr_gray` | input | 4 | Gray code wptr from wptr_handler |
| `w_ptr_sync` | output | 4 | Synchronized wptr safe in rclk domain |

```verilog
always @(posedge rclk) begin
    FF1 <= w_ptr_gray;   // FF1 absorbs metastability
    FF2 <= FF1;           // FF2 samples after one full rclk cycle
end
assign w_ptr_sync = FF2;
```

---

### 5. `sync_r2w.v` — Read-to-Write Synchronizer

Exact mirror of sync_w2r. Passes `rd_ptr_gray` from read domain into write domain safely. Both flip-flops clocked by `wclk`.

| Port | Direction | Width | Description |
|---|---|---|---|
| `wclk` | input | 1 | Destination clock (write domain) |
| `rd_ptr_gray` | input | 4 | Gray code rptr from rptr_handler |
| `rd_ptr_sync` | output | 4 | Synchronized rptr safe in wclk domain |

---

### 6. `async_fifo_top.v` — Top Level Integration

Instantiates and connects all five submodules. All internal signals (pointers, addresses, synchronized copies) are declared as wires. Only signals driven by or consumed by the external world appear in the port list.

| Port | Direction | Width | Description |
|---|---|---|---|
| `wclk` | input | 1 | Write clock |
| `rclk` | input | 1 | Read clock |
| `wrst_n` | input | 1 | Write domain reset (active low) |
| `rst_n` | input | 1 | Read domain reset (active low) |
| `w_en` | input | 1 | Write enable |
| `r_en` | input | 1 | Read enable |
| `data_in` | input | 8 | Data to write |
| `data_out` | output | 8 | Data read out |
| `w_full` | output | 1 | FIFO full flag |
| `rd_empty` | output | 1 | FIFO empty flag |

**Internal wires (not ports):**
```
waddr, rd_addr         — RAM addresses from pointer handlers
w_ptr_gray, rd_ptr_gray — Gray code pointers to synchronizers
w_ptr_sync, rd_ptr_sync — Synchronized pointers from synchronizers
```

---

## Design Specifications

| Parameter | Value |
|---|---|
| FIFO Depth | 8 slots |
| Data Width | 8 bits |
| Pointer Width | 4 bits (3 address bits + 1 MSB lap bit) |
| Total Storage | 64 bits |
| Synchronizer Stages | 2-flop |
| Full Detection | MSB differ + lower bits match |
| Empty Detection | All bits equal |
| Reset | Active low, independent per domain |
| HDL Standard | Verilog |

---

## Key Design Decisions

### Gray Code for Safe Pointer Crossing

Binary pointers increment with multiple simultaneous bit transitions (e.g. 011→100 flips 3 bits). During the transition window, the wires carry invalid intermediate values. If the receiving domain's flip-flop samples during this window, it captures a phantom pointer value — one that was never a real FIFO state.

Gray code guarantees exactly one bit changes per increment. The receiving domain always captures either the old or the new valid pointer value. No phantom states exist.

### 2-Flop Synchronizer per Domain Crossing

The 2-flop synchronizer provides one full destination clock cycle of resolution time for any metastable event. The probability of a flip-flop remaining metastable after one full clock cycle is governed by exponential decay — at practical clock frequencies, mean time between failures becomes millions of years.

Importantly, FF1 and FF2 are ordinary registers. No special cells are required in simulation. The protection is architectural, not cell-level.

### Extra MSB Bit on Pointer

A 3-bit pointer can address 8 slots (0–7) but cannot distinguish between full and empty — both conditions produce equal pointer values. Adding a 4th MSB bit that flips each time the pointer wraps around the FIFO encodes the lap count:

```
Empty: wptr == rptr         (same lap, same position)
Full:  wptr MSBs differ,    (different lap)
       lower bits match     (same position — write has lapped read)
```

### No Shared Flag Registers

In a synchronous FIFO, a single full/empty register can be shared because both domains run on the same clock. In an async FIFO, a shared register would itself be a clock domain crossing — requiring synchronization that adds latency and complexity.

Instead, each domain computes its own flag combinationally from the locally available pointer and the synchronized copy of the opposite pointer. The flags are always correct for their respective domains without any cross-domain sharing.

### Data Never Crosses Clock Domains

The dual-port RAM has two independent ports — one for each clock domain. Data written by the producer stays physically in the RAM. The consumer accesses the same physical storage using its own clock. The only thing that crosses domains is the pointer — which slot to read from or write to next. This architectural choice completely eliminates the need to synchronize the data bus itself.

---

## How to Run

### Prerequisites

- [Icarus Verilog](http://iverilog.icarus.com/) — HDL simulator
- [GTKWave](http://gtkwave.sourceforge.net/) — Waveform viewer

### Compile

```bash
iverilog -o async_fifo_tb async_fifo_tb.v async_fifo_top.v dual_port_ram.v wptr_handler.v rdptr_handler.v sync_w2r.v sync_r2w.v
```

### Simulate

```bash
vvp async_fifo_tb
```

### View Waveforms

```bash
gtkwave async_fifo_tb.vcd
```

---

## Directory Structure

```
async_fifo_project/
├── dual_port_ram.v      # Dual-port RAM storage (independent wclk/rclk ports)
├── wptr_handler.v       # Write pointer, Gray code conversion, full detection
├── rdptr_handler.v      # Read pointer, Gray code conversion, empty detection
├── sync_w2r.v           # 2-flop synchronizer: wptr into rclk domain
├── sync_r2w.v           # 2-flop synchronizer: rptr into wclk domain
├── async_fifo_top.v     # Top-level integration module
└── README.md            # This file
```

---

## Tools Used

| Tool | Version | Purpose |
|---|---|---|
| Icarus Verilog | 12.0 | HDL compilation and simulation |
| GTKWave | 3.3.108 | Waveform visualization |
| VS Code | Latest | Code editor |

---

## Future Improvements

- [ ] Write SystemVerilog testbench with constrained random stimulus
- [ ] Add functional coverage for full, empty, simultaneous read/write
- [ ] Implement UVM testbench environment
- [ ] Parameterize depth and width via `parameter`
- [ ] Add almost-full and almost-empty flags
- [ ] Synthesize on Artix-7 (Vivado) and report timing/utilization
- [ ] Verify with formal CDC tools (e.g. Cadence JasperGold CDC)

---

## Author

**Tejaswi**
ECE Student | Hardware Design Enthusiast
Building skills in RTL Design, CDC Verification, and SoC Architecture

---

*All modules written, debugged, and verified independently. Every design decision made with understanding of the underlying hardware behaviour — not copied from reference implementations.*
