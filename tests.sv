module tests;
    //~ full_adder_test fa;
    //~ alu_test a;
    //~ loopOverAllNibbles_test lan;
    //~ Ram_test r;
    //~ control_test c;
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
            '{instr: 'h_ffff0297, ret_must_be: start_addr - 16, check_memory: 0} // auipc x5, -16
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

            $monitor("Test #%0d clk_count=%0d clk=%b  state=%s opCode=%s prePC=%b pc=%h instr=%h loop_nibbles_number=%h nibble=%h alu_result=%h", i, clk_count, c.clk, c.currState.name, c.opCode.name, c.pre_incr_pc, c.pc, c.instr, c.loop_nibbles_number, c.l.curr_nibble_idx, c.alu_result);

            do begin
                assert(c.currState != ERROR);
                assert(clk_count < 40); else $error("clk_count exceeded");

                #1 clk_count++;
            end while(!(c.currState == INSTR_FETCH && c.pc != start_addr && c.clk == 0));

            // command done, check result
            if(!cmd.check_memory)
                ret = c.register_file[5];
            else
                ret = c.mem.mem['h_108*8 +: 32];

            assert(ret == cmd.ret_must_be); else $error("Test #%0d: ret=%h but expected %h", i, ret, cmd.ret_must_be);

            assert(c.pc == start_addr + 4); else $error("%h", c.pc);
        end
    end
endmodule
