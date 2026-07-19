# qmtech-artix-7-workspace-win

Build and verification **windows** workspace for FPGA projects on the QMTECH Artix-7
board (`xc7a100tfgg676-1`): RTL simulation (GHDL / Icarus Verilog), Vivado
synthesis and implementation, and SDF-annotated gate-level simulation,
all through `make.cmd`.

## Structure

```bash
qmtech-artix-7-workspace-win/
 Hardware/           # Board files
 projects/
   ram_test/         # VHDL project example
   sv_test/          # SystemVerilog project example
 scripts/
   build.tcl         # Vivado synthesis, implementation, bitstream
   sim_gate.tcl      # Vivado SDF-annotated gate-level simulation
   deploy_hw.tcl     # Board programming via Vivado Hardware Manager
 make.cmd
```

Check `.gitignore`.

## Requirements

- Windows 10/11
- Vivado (this workspace defaults to 2022.1)
- Icarus Verilog:
- GHDL

## Usage

In PowerShell

```bash
./make.cmd sim ram_test
./make.cmd build ram_test
./make.cmd sim-gate ram_test
./make.cmd deploy ram_test
./make.cmd all ram_test
./make.cmd clean ram_test
./make.cmd tidy
```

## License

[Apache 2.0](LICENSE)
