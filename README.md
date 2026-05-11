# Runtime-Reconfigurable 32-bit Multiplier for RISC-V

## Overview
This project implements a **runtime-reconfigurable 32-bit multiplier** designed for integration within a RISC-V (RV32IM) processor. The architecture enables dynamic switching between accurate and approximate computation using a Control and Status Register (CSR), allowing trade-offs between **accuracy, power, and performance** at runtime.

The multiplier is hierarchically constructed using **8-bit reconfigurable multiplier blocks**, combined to form higher-order multipliers.

---

## Architecture

### Hierarchical Design
The 32-bit multiplication is decomposed as follows:

- 32-bit operands → split into **16-bit halves**
- Each 16-bit multiplication → decomposed into **8-bit multipliers**
- Final result → accumulated using shift-and-add logic

This modular design improves scalability, flexibility, and hardware efficiency.

---

### Reconfigurable 8-bit Multiplier
The core building block is a **proposed 8-bit unsigned reconfigurable multiplier** controlled by an error signal (`Er`).

Features:
- Supports both **accurate and approximate modes**
- Enables **runtime configurability**
- Provides **energy-efficient computation**

---

### Compressor-Based Reduction

Partial products are reduced using advanced compressor architectures:

#### SSM (Single Stage Stacking Multiplier)
- Implemented in `Compressor_prop`
- Reduces logic depth
- Improves speed and efficiency

#### DFC (Dual Fuller Adder based Multiplier)
- Implemented using `cmp_e5_Er`
- Enables runtime adaptability
- Supports approximate computation via control signal (`Er`)
---

### Runtime Control via CSR

The multiplier behavior is controlled using a dedicated CSR (`mulcsr`):

| Bits        | Function |
|------------|---------|
| [0]        | Mode Select (0 = Accurate, 1 = Approximate) |
| [2:1]      | Circuit Selection |
| [10:3]     | Error control for lower 8-bit multiplier |
| [18:11]    | Error control for middle multipliers |
| [26:19]    | Error control for upper multiplier |
| [31:27]    | Custom user-defined |

This allows fine-grained accuracy tuning across different parts of the multiplier.

---

## Supported Instructions

This multiplier supports RISC-V M-extension instructions:

- `MUL`
- `MULH`
- `MULHSU`
- `MULHU`

---

## Features

- Runtime reconfigurable accuracy  
- Modular hierarchical design (32 → 16 → 8-bit)  
- Custom 8-bit approximate multiplier  
- SSM-based compressor design  
- DFC-based reconfigurable full adders  
- Easy integration with RISC-V cores  

---

## Applications

- Approximate computing  
- Energy-efficient processors  
- AI/ML accelerators  
- DSP systems with error tolerance  

---

## Citation

If you use this code in your research or project, please cite the following paper:

```bibtex
@article{your_paper_reference,
  author  = {Pragun Jaswal},
  title   = {A Reconfigurable Multiplier Architecture for Error-Resilient Applications in an RISC-V Core},
  journal = {ISVLSI},
  year    = {2026}
}
