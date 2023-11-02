#!/usr/bin/env bash
set -euxo pipefail

sv_files=(
    tests.sv
    alu.sv
    instr_decoder.sv
    nibble_loop.sv
    ram.sv
    control.sv
)

VERILATOR_ROOT=~/Dev/verilator/ \
~/Dev/verilator/bin/verilator +1800-2017ext+sv --assert --cc --build --exe --main --timing --trace --top-module tests "${sv_files[@]}"

./obj_dir/Vtests
