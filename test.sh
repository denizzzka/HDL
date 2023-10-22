#!/bin/sh
verilator +1800-2017ext+sv --assert --cc --build --exe --main --timing --trace --top-module loopOverAllNibbles_test alu.sv instr_decoder.sv control.sv

./obj_dir/VloopOverAllNibbles_test
