module tests;
    full_adder_test fa;
    alu_test a;
    loopOverAllNibbles_test lan;
    shift_loop_test sh;
    Ram_test r;
    control_test c;
    control_test_bench tb;
endmodule

// TODO: implement tests for all instructions
module control_test_bench;
    typedef struct
    {
        logic[31:0] instr;
        logic[31:0] ret_must_be;
        logic check_memory; // otherwise x5 register
    } TestCmd;

    // all commands starting from this address
    localparam start_addr = 32'h_ff0004;

    TestCmd cmdsToTest[] =
        '{
            // rd is always x5:
            '{instr: 'h_07b08293, ret_must_be: 123, check_memory: 0}, // addi x5, x1, 123
            '{instr: 'h_07b10293, ret_must_be: 124, check_memory: 0}, // addi x5, x2, 123
            '{instr: 'h_ffe10293, ret_must_be: -1, check_memory: 0},  // addi x5, x2, -2
            '{instr: 'h_0081a283, ret_must_be: 'h_feff_1111, check_memory: 0},  // lw x5, 8(x3)
            '{instr: 'h_ff822283, ret_must_be: 'h_feff_1111, check_memory: 0},  // lw x5, -8(x4)
            '{instr: 'h_fe622c23, ret_must_be: 'h_cafe_babe, check_memory: 1},  // sw x6, -8(x4)
            '{instr: 'h_fffff2b7, ret_must_be: 'h_fffff000, check_memory: 0},   // lui x5, 0xfffff
            '{instr: 'h_ffff0297, ret_must_be: start_addr + (-16 << 12), check_memory: 0},  // auipc x5, -16
            '{instr: 'h_ff9ff2ef, ret_must_be: start_addr + 4, check_memory: 0},    // jal x5, -8
            '{instr: 'h_ff8502e7, ret_must_be: start_addr + 4, check_memory: 0},    // jalr x5, -8(x10)
            '{instr: 'h_fe318ce3, ret_must_be: start_addr + 4, check_memory: 0},    // beq x3, x3, -8
            '{instr: 'h_fe418ce3, ret_must_be: start_addr + 4, check_memory: 0},    // beq x3, x4, -8
            '{instr: 'h_004182b3, ret_must_be: 'h_210, check_memory: 0},    // add x5, x3, x4
            '{instr: 'h_0083f2b3, ret_must_be: 'b_000010, check_memory: 0}, // and x5, x7, x8
            '{instr: 'h_0083e2b3, ret_must_be: 'b_111110, check_memory: 0}, // or x5, x7, x8
            '{instr: 'h_0083c2b3, ret_must_be: 'b_111100, check_memory: 0}, // xor x5, x7, x8
            '{instr: 'h_403202b3, ret_must_be: 'h_010, check_memory: 0},    // sub x5, x4, x3
            '{instr: 'h_00041293, ret_must_be: 'b_010110, check_memory: 0}, // slli x5, x8, 0
            '{instr: 'h_00241293, ret_must_be: 'b_1011000, check_memory: 0},    // slli x5, x8, 2
            '{instr: 'h_00b412b3, ret_must_be: 'b_010110, check_memory: 0}, // sll x5, x8, x11
            '{instr: 'h_009412b3, ret_must_be: 'b_1011000, check_memory: 0} // sll x5, x8, x9
        };

    logic[7:0] clk_count;
    control #(.START_ADDR(start_addr)) c(clk_count[0]);

    TestCmd cmd;
    logic[31:0] ret;

    initial begin
        foreach(cmdsToTest[i])
        begin
            clk_count = 0;
            cmd = cmdsToTest[i];

            // Predefined memory values
            c.memWrite32('h_108, 'h_feff_1111); // some value for commands check

            // Place instruction into RAM
            c.memWrite32(start_addr, cmd.instr);

            // Initial CPU state
            c.currState = RESET;

            // Predefined register values
            #1 clk_count++;
            #1 clk_count++;
            c.register_file[2] = 1;
            c.register_file[3] = 'h_100;
            c.register_file[4] = 'h_110;
            c.register_file[6] = 'h_cafe_babe;
            c.register_file[7] = 'b_101010;
            c.register_file[8] = 'b_010110;
            c.register_file[9] = 2;
            c.register_file[10] = start_addr;
            c.register_file[11] = 0;

            //~ $monitor("Test #%0d clk_count=%0d clk=%b state=%s next=%s opCode=%s prePC=%b pc=%h instr=%h nnumber=%h nibble=%h alu_result=%h", i, clk_count, c.clk, c.currState.name, c.nextState.name, c.opCode.name, c.pre_incr_pc, c.pc, c.instr, c.loop_nibbles_number, c.l.curr_nibble_idx, c.alu_result);
            //~ $monitor("Test #%0d state=%s next=%s opCode=%s prePC=%b pc=%h instr=%h nnumber=%h nibble=%h alu_result=%h alu_w2=%h", i, c.currState.name, c.nextState.name, c.opCode.name, c.pre_incr_pc, c.pc, c.instr, c.loop_nibbles_number, c.l.curr_nibble_idx, c.alu_result, c.alu_w2);
            //~ $monitor("Test #%0d state=%s next=%s opCode=%s prePC=%b pc=%h instr=%h nnumber=%h nibble=%h alu_result=%h carry_ret=%b check_0xF=%b alu_w1=%h alu_w2=%h alu_ctrl=%b", i, c.currState.name, c.nextState.name, c.opCode.name, c.pre_incr_pc, c.pc, c.instr, c.loop_nibbles_number, c.l.curr_nibble_idx, c.alu_result, c.carry_in_out, c.check_if_result_0xF, c.alu_w1, c.alu_w2, c.alu_ctrl);
            //~ $monitor("Test #%0d stt=%s nxt=%s op=%s cmd=%s ins=%h shift_cnt=%h nnum=%h nibble=%h shift_busy=%b shift_step=%b alu_busy=%b alu_res=%h carry=%b alu_w1(%h)=%h alu_w2=%h alu_ctrl=%b", i, c.currState.name, c.nextState.name, c.opCode.name, c.i_s.riscv_aluCmd.name, c.instr, c.sl.curr_val, c.loop_nibbles_number, c.l.curr_nibble_idx, c.shift_loop_busy, c.shift_loop_step, c.alu_busy, c.alu_result, c.carry_in_out, c.instr.rs1, c.alu_w1, c.alu_w2, c.alu_ctrl);

            do begin
                assert(c.currState != ERROR); else $error("currState=%s", c.currState.name);
                assert(clk_count < 60); else $error("clk_count exceeded");

                #1 clk_count++;
            end while(!(c.currState == INSTR_FETCH && c.pc != start_addr && c.clk == 0));

            // command done, check result
            if(!cmd.check_memory)
                ret = c.register_file[5];
            else
                ret = c.mem.mem['h_108*8 +: 32];

            if(!(i == 10 || i == 11)) // except beq
                assert(ret == cmd.ret_must_be); else $error("Test #%0d: ret=%h but expected %h", i, ret, cmd.ret_must_be);

            if(!(i == 8 || i == 9 || i == 10))
                assert(c.pc == start_addr + 4); else $error("Unexpected PC=%h", c.pc);
            else // jal || jarl || beq(success)
                assert(c.pc == start_addr - 8); else $error("Unexpected PC=%h (expected %h)", c.pc, start_addr - 8);
        end
    end
endmodule
