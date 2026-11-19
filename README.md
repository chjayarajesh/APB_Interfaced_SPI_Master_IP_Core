# APB Interfaced SPI Master IP Core

A fully synthesizable, high-performance, and feature-rich **AMBA APB (Advanced Peripheral Bus) Interfaced SPI Master IP Core** implemented in Verilog HDL. This core bridges an APB system bus to standard SPI slave peripherals, supporting all four SPI modes (CPOL / CPHA combinations), variable baud rates, programmable bit-order (MSB/LSB first), and robust hardware interrupt handshakes.

---

## 🚀 Key Architectural Innovations & Problem Solutions

This IP core introduces several unique architectural design improvements and solves critical hardware edge-case challenges commonly found in standard SPI Master implementations:

### 1. Solving the Baud Divisor BD = 2 Hardware Corner Case
In standard SPI clock generator designs, the baud divisor is governed by:

```verilog
assign baud_divisor = (sppr + 1) << (spr + 1);
```

For standard operation (`baud_divisor > 2`), internal toggling and strobe generation use counter comparisons:
- **MISO sample strobe:** `count == (baud_divisor / 2) - 1`
- **MOSI shift strobe:** `count == (baud_divisor / 2) - 2`

#### The Problem:
When the core is configured for maximum SPI transmission speed (`baud_divisor = 2`):
$$(BD / 2) - 2 = 1 - 2 = -1$$

In unsigned hardware counter arithmetic (12-bit register), `-1` evaluates to `12'hFFF` (4095). Since `count` only counts from `0` to `(baud_divisor / 2) - 1 = 0`, `count` never matches `-1`. Consequently, the MOSI shift strobe never fires, locking up data transmission and causing SPI communication to completely fail at highest baud rates.

#### The Unique Solution:
A dedicated cycle-accurate condition block was designed for `baud_divisor == 2`. By tracking the instantaneous state of `sclk` in conjunction with `cpol` and `cpha`, accurate 1-cycle pulses for both MOSI shifting (`mosi_pos`, `mosi_neg`) and MISO sampling (`miso_pos`, `miso_neg`) are asserted deterministically.

#### BD = 2 Timing and Strobe Condition Table

##### MISO Sampling Strobe Conditions (`baud_divisor == 2`)
| SCLK State | CPOL | CPHA | SPI Mode | Triggered Strobe | Action Description |
| :---: | :---: | :---: | :---: | :---: | :--- |
| **High (`1`)** | `0` | `0` | Mode 0 | `miso_pos <= 1'b1` | Latch incoming MISO bit on SCLK rising edge |
| **High (`1`)** | `0` | `1` | Mode 1 | `miso_neg <= 1'b1` | Latch incoming MISO bit on SCLK falling edge |
| **Low (`0`)** | `1` | `0` | Mode 2 | `miso_neg <= 1'b1` | Latch incoming MISO bit on SCLK falling edge |
| **Low (`0`)** | `1` | `1` | Mode 3 | `miso_pos <= 1'b1` | Latch incoming MISO bit on SCLK rising edge |

##### MOSI Shifting Strobe Conditions (`baud_divisor == 2`)
| SCLK State | CPOL | CPHA | SPI Mode | Triggered Strobe | Action Description |
| :---: | :---: | :---: | :---: | :---: | :--- |
| **High (`1`)** | `1` | `0` | Mode 2 | `mosi_pos <= 1'b1` | Drive next MOSI bit on SCLK rising edge |
| **High (`1`)** | `1` | `1` | Mode 3 | `mosi_neg <= 1'b1` | Drive next MOSI bit on SCLK falling edge |
| **Low (`0`)** | `0` | `0` | Mode 0 | `mosi_neg <= 1'b1` | Drive next MOSI bit on SCLK falling edge |
| **Low (`0`)** | `0` | `1` | Mode 1 | `mosi_pos <= 1'b1` | Drive next MOSI bit on SCLK rising edge |

---

### 2. Optimized Shifter Architecture: 2 Counters and 1 Register
Traditional SPI Master shifters often employ 2 full 8-bit data registers (separate TX and RX shift buffers) along with 4 separate 4-bit counters (`count_up_1`, `count_down_1`, `count_up_2`, `count_down_2`) to handle bidirectional transfers in MSB/LSB modes.

#### Unique Implementation:
This design optimizes the shifter core (`spi_shifter.v`) down to:
- **One 8-bit Data Register (`register`):** Acts as a unified storage element for outgoing byte transmission and incoming bit assembly, eliminating redundant register flip-flops.
- **Two 4-bit Index Counters (`count1` & `count2`):**
  - `count1`: Exclusively controls the bit index for MOSI serial shifting.
  - `count2`: Exclusively controls the bit index for MISO serial sampling.
- **Dynamic Direction Indexing:** Seamlessly switches between MSB-First (`lsbfe = 0`, decrementing from 7 to 0) and LSB-First (`lsbfe = 1`, incrementing from 0 to 7) without duplicating hardware multiplexers.
- **Race-Free Bit Tracking:** Completely decouples transmit and receive timing across all four SPI modes, preventing any data overwrites during full-duplex transfers.

---

### 3. Event-Driven APB Data Register (DR) Handshake (Overcoming the Zero-Data Hazard)

#### The Problem:
In naive APB-to-SPI bridge designs, transfer initiation and buffer status are often inferred by checking whether the Data Register is non-zero (e.g., `if (DR != 8'h00)`). If the system attempts to transmit legitimate `8'h00` data (e.g., zero bytes in network headers, padding, or null payloads), the logic incorrectly assumes that no data is pending or that the register is empty. This leads to dropped bytes, corrupted transmissions, and hanging status flags.

#### The Unique Solution:
The APB Slave Interface (`APB_slave_interface.v`) implements a robust, purely event-driven control handshake that never compares data values to zero:
- **Cycle-Accurate Write Detection:** `tx_write` is asserted strictly based on APB bus qualifiers:
  ```verilog
  wire tx_write = wr_enable && (paddr == 3'b101) && spi_active && sptef;
  ```
- **State-Tracking Signals:**
  - `tx_pending`: Flags that valid data has been written to `DR` and is awaiting transmission.
  - `send_data`: Pulses high for exactly one clock cycle when the SPI engine is ready to capture `DR` into `data_mosi`.
  - `transferred`: Acknowledges the transfer and resets the pending state.
  - `recieve_delay`: Synchronizes the capture of `data_miso` into `DR` when reception completes.
- **Deterministic Status Register (`SR`) Updates:**
  - `SPTEF` (SPI Transmit Empty Flag): Cleared immediately on `tx_write`, and re-asserted when data is dispatched (`transferred == 1`).
  - `SPIF` (SPI Interrupt / Transfer Complete Flag): Asserted cleanly when `recieve_delay` fires, signaling new data is in `DR`.
  - **Atomic Hardware Clearing Sequence:** Automatically tracks reading the Status Register (`paddr == 3'b011` -> sets `sr_read_done`), followed by reading the Data Register (`paddr == 3'b101` -> clears `spif`), adhering strictly to standard SPI hardware specifications.

---

## 📂 Repository Structure

```text
APB_Interfaced_SPI_Master_IP_Core/
├── rtl/                               # Synthesizable Verilog Source Files
│   ├── APB_slave_interface.v          # APB3 bus slave interface & register bank
│   ├── baud_rate_generator.v          # SCLK & edge strobe generator (with BD=2 fix)
│   ├── spi_shifter.v                  # 1-register, 2-counter optimized shifter
│   ├── spi_slave_control_select.v     # Slave select (SS) & transfer timing control
│   └── top_module.v                   # Top-level IP core module
│
├── tb/                                # Comprehensive Testbenches
│   ├── APB_slave_interface_tb.v       # APB interface unit testbench
│   ├── baud_rate_generator_tb.v       # Baud rate generator testbench
│   ├── spi_shifter_tb.v               # Shifter unit testbench
│   ├── spi_slave_control_select_tb.v  # Slave select unit testbench
│   └── top_module_tb.v                # Full chip top-level verification testbench
│
└── README.md                          # Project documentation
```

---

## ⚙️ Module Descriptions

### 1. `top_module.v`
Top-level structural wrapper interconnecting:
- **`APB_slave_interface` (M1):** Handles host CPU read/write transactions via APB.
- **`baud_rate_generator` (M2):** Generates `sclk`, MOSI shift pulses, and MISO sample pulses.
- **`spi_slave_control_select` (M3):** Controls active-low slave select (`ss`), transfer-in-progress (`tip`), and receive triggers.
- **`spi_shifter` (M4):** Executes full-duplex serial shifting on `mosi_out` and `miso_in`.

### 2. `APB_slave_interface.v`
- Implements standard APB3 Slave protocol (`IDLE` -> `SETUP` -> `ENABLE`).
- Memory-mapped internal registers:
  - `CR1` (Address `3'b000`): Control Register 1 (`SPIE`, `SPE`, `SPTIE`, `MSTR`, `CPOL`, `CPHA`, `LSBFE`).
  - `CR2` (Address `3'b001`): Control Register 2 (`MODFEN`, `SPISWAI`).
  - `BR` (Address `3'b010`): Baud Rate Register (`SPPR[6:4]`, `SPR[2:0]`).
  - `SR` (Address `3'b011`): Status Register (`SPIF`, `SPTEF`, `MODF`).
  - `DR` (Address `3'b101`): Data Register (Transmit/Receive).
- Manages SPI power states: `SPI_RUN`, `SPI_WAIT`, `SPI_STOP`.

### 3. `baud_rate_generator.v`
- Programmable divider supporting division ratios from `baud_divisor = 2` up to `baud_divisor = 4096`.
- Generates directional strobes (`mosi_pos`, `mosi_neg`, `miso_pos`, `miso_neg`) for all 4 SPI modes.
- Integrated `baud_divisor == 2` corner-case correction logic.

### 4. `spi_slave_control_select.v`
- Calculates target transfer duration:
  ```verilog
  wire [14:0] target = baud_divisor << 3; // (baud_divisor * 8 bits)
  ```
- Drives active-low Slave Select (`ss`) and Transfer-in-Progress (`tip`) indicator.
- Asserts `recieve_data` at the exact completion cycle.

### 5. `spi_shifter.v`
- Compact 1-register, 2-counter design.
- Supports MSB-first and LSB-first serial streaming.
- Full-duplex shift operation driven by precise generator pulses.

---

## 📊 Register Memory Map

| Address Offset (`paddr`) | Register | Access | Description |
| :---: | :---: | :---: | :--- |
| `3'b000` (`0x00`) | **CR1** | R/W | Control Register 1: `[7] SPIE`, `[6] SPE`, `[5] SPTIE`, `[4] MSTR`, `[3] CPOL`, `[2] CPHA`, `[0] LSBFE` |
| `3'b001` (`0x01`) | **CR2** | R/W | Control Register 2: `[4] MODFEN`, `[1] SPISWAI` |
| `3'b010` (`0x02`) | **BR**  | R/W | Baud Rate Register: `[6:4] SPPR`, `[2:0] SPR` |
| `3'b011` (`0x03`) | **SR**  | R   | Status Register: `[7] SPIF`, `[5] SPTEF`, `[4] MODF` |
| `3'b101` (`0x05`) | **DR**  | R/W | Data Register: Transmit buffer (Write), Receive buffer (Read) |

---

## 🔬 Verification & Testbenches

The IP core is comprehensively verified across all hierarchy levels:
- **`top_module_tb.v`**: Full system verification covering APB register configuration, clock generation, transmission, reception, mode switching, and flag handshakes.
- **`baud_rate_generator_tb.v`**: Rigorous testing of baud divisor ratios including the `BD = 2` corner case and all CPOL/CPHA modes.
- **`spi_shifter_tb.v`**: Verification of MSB/LSB data shifting and full-duplex operation.
- **`APB_slave_interface_tb.v`**: Verification of APB FSM, interrupt generation, and zero-data transfer robustness.
- **`spi_slave_control_select_tb.v`**: Verification of chip select timing and transfer duration accuracy.

---

## 🛠️ How to Simulate

You can simulate the core using ModelSim, QuestaSim, Vivado, or Icarus Verilog.

Example with Icarus Verilog:
```bash
# Compile top-level design with testbench
iverilog -o sim_top rtl/*.v tb/top_module_tb.v

# Run simulation
vvp sim_top

# View waveforms in GTKWave
gtkwave dump.vcd
```

---

## 👤 Author
- **GitHub:** [@chjayarajesh](https://github.com/chjayarajesh)
- **Project Repository:** [APB_Interfaced_SPI_Master_IP_Core](https://github.com/chjayarajesh/APB_Interfaced_SPI_Master_IP_Core)
