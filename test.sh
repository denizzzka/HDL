#!/usr/bin/env bash
set -euxo pipefail

sv_files=(
    tests.sv
    alu_args.sv
    alu_4bit.sv
    alu_16bit.sv
    alu.sv
    full_adder.sv
    carry_gen.sv
    instr_decoder.sv
    nibble_loop.sv
    shift_loop.sv
    ram.sv
    control.sv
)

VERILATOR_ROOT=~/Dev/verilator/ \
~/Dev/verilator/bin/verilator +1800-2017ext+sv --assert --cc --build --exe --main --timing --trace \
--top-module tests \
-DALU_BITS_WIDTH_16 \
"${sv_files[@]}"

./obj_dir/Vtests
