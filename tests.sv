module tests;
    full_adder_test fa;
    alu_test a;
    alu_4bit_test a4;
    alu16_test a16;
    loopOverAllNibbles_test lan;
    shift_loop_test sh;
    Ram_test r;
    control_test_bench tb;
    control_test c;
endmodule

// TODO: implement tests for all instructions
module control_test_bench;
    typedef enum logic[1:0] {
        X5      = 'b_00,
        MEM     = 'b_01,
        PC_BRN  = 'b_10  // successful branching
    } CheckType;

    typedef struct
    {
        logic[31:0] instr;
        logic[31:0] ret_must_be;
        CheckType ct;
    } TestCmd;

    // all commands starting from this address
    localparam start_addr = 32'h_ff0004;

    TestCmd cmdsToTest[] =
        '{
            // rd is always x5:
            '{instr: 'h_07b08293, ret_must_be: 123, ct: X5}, // addi x5, x1, 123
            '{instr: 'h_07b10293, ret_must_be: 124, ct: X5}, // addi x5, x2, 123
            '{instr: 'h_ffe10293, ret_must_be: -1, ct: X5},  // addi x5, x2, -2
            '{instr: 'h_00113293, ret_must_be: 0, ct: X5},  // sltiu x5, x2, 1
            '{instr: 'h_07b13293, ret_must_be: 1, ct: X5},  // sltiu x5, x2, 123
            '{instr: 'h_07b33293, ret_must_be: 0, ct: X5},  // sltiu x5, x6, 123
            '{instr: 'h_ffe62293, ret_must_be: 0, ct: X5},  // slti x5, x12, -2
            '{instr: 'h_ffe12293, ret_must_be: 0, ct: X5},  // slti x5, x2, -2
            '{instr: 'h_ffe32293, ret_must_be: 1, ct: X5},  // slti x5, x6, -2
            '{instr: 'h_ffd62293, ret_must_be: 0, ct: X5},  // slti x5, x12, -3
            '{instr: 'h_002132b3, ret_must_be: 0, ct: X5},  // sltu x5, x2, x2
            '{instr: 'h_003132b3, ret_must_be: 1, ct: X5},  // sltu x5, x2, x3
            '{instr: 'h_006132b3, ret_must_be: 1, ct: X5},  // sltu x5, x2, x6
            '{instr: 'h_003332b3, ret_must_be: 0, ct: X5},  // sltu x5, x6, x3
            '{instr: 'h_00c622b3, ret_must_be: 0, ct: X5},  // slt x5, x12, x12
            '{instr: 'h_00c322b3, ret_must_be: 1, ct: X5},  // slt x5, x6, x12
            '{instr: 'h_006122b3, ret_must_be: 0, ct: X5},  // slt x5, x2, x6
            '{instr: 'h_006622b3, ret_must_be: 0, ct: X5},  // slt x5, x12, x6
            '{instr: 'h_0163f293, ret_must_be: 'b_000010, ct: X5},  // andi x5, x7, 0x16
            '{instr: 'h_0163e293, ret_must_be: 'b_111110, ct: X5},  // ori x5, x7, 0x16
            '{instr: 'h_0163c293, ret_must_be: 'b_111100, ct: X5},  // xori x5, x7, 0x16
            '{instr: 'h_0081a283, ret_must_be: 'h_feff_1111, ct: X5},  // lw x5, 8(x3)
            '{instr: 'h_ff822283, ret_must_be: 'h_feff_1111, ct: X5},  // lw x5, -8(x4)
            '{instr: 'h_ff826283, ret_must_be: 'h_feff_1111, ct: X5},  // lwu x5, -8(x4) // not supported by RV32I standard
            '{instr: 'h_0091d283, ret_must_be: 'h_0000_ff11, ct: X5},  // lhu x5, 9(x3)
            '{instr: 'h_00919283, ret_must_be: 'h_ffff_ff11, ct: X5},  // lh x5, 9(x3)
            '{instr: 'h_00b1c283, ret_must_be: 'h_0000_00fe, ct: X5},  // lbu x5, 11(x3)
            '{instr: 'h_00b18283, ret_must_be: 'h_ffff_fffe, ct: X5},  // lb x5, 11(x3)
            '{instr: 'h_fe622c23, ret_must_be: 'h_cafe_babe, ct: MEM}, // sw x6, -8(x4)
            '{instr: 'h_00619423, ret_must_be: 'h_0000_babe, ct: MEM}, // sh x6, 8(x3)
            '{instr: 'h_00618423, ret_must_be: 'h_0000_00be, ct: MEM}, // sb x6, 8(x3)
            '{instr: 'h_fffff2b7, ret_must_be: 'h_fffff000, ct: X5},   // lui x5, 0xfffff
            '{instr: 'h_ffff0297, ret_must_be: start_addr + (-16 << 12), ct: X5},  // auipc x5, -16
            '{instr: 'h_ff9ff2ef, ret_must_be: start_addr + 4, ct: PC_BRN}, // jal x5, -8
            '{instr: 'h_ff8502e7, ret_must_be: start_addr + 4, ct: PC_BRN}, // jalr x5, -8(x10)
            '{instr: 'h_fe318ce3, ret_must_be: 'h_dead_beef, ct: PC_BRN},   // beq x3, x3, -8
            '{instr: 'h_fe418ce3, ret_must_be: 'h_dead_beef, ct: X5},       // beq x3, x4, -8
            '{instr: 'h_fe319ce3, ret_must_be: 'h_dead_beef, ct: X5},       // bne x3, x3, -8
            '{instr: 'h_fe419ce3, ret_must_be: 'h_dead_beef, ct: PC_BRN},   // bne x3, x4, -8
            '{instr: 'h_fe846ce3, ret_must_be: 'h_dead_beef, ct: X5},       // bltu x8, x8, -8
            '{instr: 'h_fe63ece3, ret_must_be: 'h_dead_beef, ct: PC_BRN},   // bltu x7, x6, -8
            '{instr: 'h_fe736ce3, ret_must_be: 'h_dead_beef, ct: X5},       // bltu x6, x7, -8
            '{instr: 'h_fe31fce3, ret_must_be: 'h_dead_beef, ct: PC_BRN},   // bgeu x3, x3, -8
            '{instr: 'h_fe41fce3, ret_must_be: 'h_dead_beef, ct: X5},       // bgeu x3, x4, -8
            '{instr: 'h_fe327ce3, ret_must_be: 'h_dead_beef, ct: PC_BRN},   // bgeu x4, x3, -8
            '{instr: 'h_fe844ce3, ret_must_be: 'h_dead_beef, ct: X5},       // blt x8, x8, -8
            '{instr: 'h_fe41cce3, ret_must_be: 'h_dead_beef, ct: PC_BRN},   // blt x3, x4, -8
            '{instr: 'h_fe63cce3, ret_must_be: 'h_dead_beef, ct: X5},       // blt x7, x6, -8
            '{instr: 'h_fe734ce3, ret_must_be: 'h_dead_beef, ct: PC_BRN},   // blt x6, x7, -8
            '{instr: 'h_fe635ce3, ret_must_be: 'h_dead_beef, ct: PC_BRN},   // bge x6, x6, -8
            '{instr: 'h_fe41dce3, ret_must_be: 'h_dead_beef, ct: X5},       // bge x3, x4, -8
            '{instr: 'h_fe535ce3, ret_must_be: 'h_dead_beef, ct: X5},       // bge x6, x5, -8
            '{instr: 'h_fe62dce3, ret_must_be: 'h_dead_beef, ct: PC_BRN},   // bge x5, x6, -8
            '{instr: 'h_004182b3, ret_must_be: 'h_210, ct: X5},     // add x5, x3, x4
            '{instr: 'h_0083f2b3, ret_must_be: 'b_000010, ct: X5},  // and x5, x7, x8
            '{instr: 'h_0083e2b3, ret_must_be: 'b_111110, ct: X5},  // or x5, x7, x8
            '{instr: 'h_0083c2b3, ret_must_be: 'b_111100, ct: X5},  // xor x5, x7, x8
            '{instr: 'h_403202b3, ret_must_be: 'h_010, ct: X5},     // sub x5, x4, x3
            '{instr: 'h_00041293, ret_must_be: 'b_010110, ct: X5},         // slli x5, x8, 0
            '{instr: 'h_00241293, ret_must_be: 'b_1011000, ct: X5},        // slli x5, x8, 2
            '{instr: 'h_00035293, ret_must_be: 'h_cafe_babe, ct: X5},      // srli x5, x6, 0
            '{instr: 'h_00235293, ret_must_be: 'h_cafe_babe >> 2, ct: X5}, // srli x5, x6, 2
            '{instr: 'h_00b412b3, ret_must_be: 'b_010110, ct: X5},         // sll x5, x8, x11
            '{instr: 'h_009412b3, ret_must_be: 'b_1011000, ct: X5},        // sll x5, x8, x9
            '{instr: 'h_00b352b3, ret_must_be: 'h_cafe_babe, ct: X5},      // srl x5, x6, x11
            '{instr: 'h_009352b3, ret_must_be: 'h_cafe_babe >> 2, ct: X5}, // srl x5, x6, x9
            '{instr: 'h_40b352b3, ret_must_be: 'h_cafe_babe, ct: X5},                              // sra x5, x6, x11
            '{instr: 'h_409352b3, ret_must_be: unsigned'(signed'('h_cafe_babe) >>> 2), ct: X5},    // sra x5, x6, x9
            '{instr: 'h_40035293, ret_must_be: 'h_cafe_babe, ct: X5},                              // srai x5, x6, 0
            '{instr: 'h_40235293, ret_must_be: unsigned'(signed'('h_cafe_babe) >>> 2), ct: X5}     // srai x5, x6, 2
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
            c.register_file[5] = 'h_dead_beef; // -559038737  (used as result register)
            c.register_file[6] = 'h_cafe_babe; // -889275714
            c.register_file[7] = 'b_101010;
            c.register_file[8] = 'b_010110;
            c.register_file[9] = 2;
            c.register_file[10] = start_addr;
            c.register_file[11] = 0;
            c.register_file[12] = -2;

            //~ $monitor("Test #%0d clk_count=%0d clk=%b state=%s next=%s opCode=%s prePC=%b pc=%h instr=%h nnumber=%h nibble=%h alu_result=%h", i, clk_count, c.clk, c.currState.name, c.nextState.name, c.opCode.name, c.pre_incr_pc, c.pc, c.instr, c.loop_nibbles_number, c.l.curr_nibble_idx, c.alu_result);
            //~ $monitor("Test #%0d state=%s next=%s opCode=%s prePC=%b pc=%h instr=%h nnumber=%h nibble=%h alu_result=%h alu_w2=%h", i, c.currState.name, c.nextState.name, c.opCode.name, c.pre_incr_pc, c.pc, c.instr, c.loop_nibbles_number, c.l.curr_nibble_idx, c.alu_result, c.alu_w2);
            //~ $monitor("Test #%0d state=%s next=%s opCode=%s prePC=%b pc=%h instr=%h nnumber=%h nibble=%h alu_result=%h carry_ret=%b check_0xF=%b alu_w1=%h alu_w2=%h alu_ctrl=%b", i, c.currState.name, c.nextState.name, c.opCode.name, c.pre_incr_pc, c.pc, c.instr, c.loop_nibbles_number, c.l.curr_nibble_idx, c.alu_result, c.carry_in_out, c.check_if_result_0xF, c.alu_w1, c.alu_w2, c.alu_ctrl);
            //~ $monitor("Test #%0d state=%s next=%s opCode=%s(%s) cknown=%b(%b) csign=%b cfail=%b pc=%h instr=%h nnumber=%h nibble=%h alu_result=%h carry_ret=%b check_0xF=%b alu_w1=%h alu_w2=%h alu_ctrl=%b", i, c.currState.name, c.nextState.name, c.opCode.name, c.i_s.riscv_branchCmd.name, c.compare_resultKnownAndValuesNotEqual, c.signedsDecis, c.i_s.is_comparison_signed_op, c.comparison_failed, c.pc, c.instr, c.loop_nibbles_number, c.l.curr_nibble_idx, c.alu_result, c.carry_in_out, c.check_if_result_0xF, c.alu_w1, c.alu_w2, c.alu_ctrl);
            //~ $monitor("Test #%0d stt=%s nxt=%s op=%s cmd=%s ins=%h shift_cnt=%h nnum=%h nibble=%h shift_busy=%b shift_step=%b alu_busy=%b perm=%b alu_res=%h carry=%b alu_w1(%h)=%h alu_w2=%h alu_ctrl=%b s&n=%b", i, c.currState.name, c.nextState.name, c.opCode.name, c.i_s.riscv_aluCmd.name, c.instr, c.sl.curr_val, c.loop_nibbles_number, c.l.curr_nibble_idx, c.shift_loop_busy, c.shift_loop_step, c.alu_busy, c.alu_perm_to_count, c.alu_result, c.carry_in_out, c.instr.rs1, c.alu_w1, c.alu_w2, c.alu_ctrl, c.word2_is_signed_and_negative);

            do begin
                assert(c.currState != ERROR); else $error("currState=%s", c.currState.name);
                assert(clk_count < 60); else $error("clk_count exceeded");

                #1 clk_count++;
            end while(!(c.currState == INSTR_FETCH && c.pc != start_addr && c.clk == 0));

            // command done, get result
            if(cmd.ct[0] == 0) // result from x5?
                ret = c.register_file[5];
            else
                ret = c.mem.mem['h_108*8 +: 32];

            assert(ret == cmd.ret_must_be); else $error("Test #%0d: ret=%h but expected %h", i, ret, cmd.ret_must_be);

            // successful branching?
            if(cmd.ct[1] == 1)
                assert(c.pc == start_addr - 8); else $error("Test #%0d: Unexpected PC=%h (expected %h)", i, c.pc, start_addr - 8);
            else
                assert(c.pc == start_addr + 4); else $error("Test #%0d: Unexpected PC=%h (expected %h)", i, c.pc, start_addr + 4);
        end
    end
endmodule
