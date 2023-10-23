#!/usr/bin/env bash
set -euxo pipefail

verilator +1800-2017ext+sv --assert --cc --build --exe --main --timing --trace --top-module tests tests.sv alu.sv instr_decoder.sv control.sv

./obj_dir/Vtests