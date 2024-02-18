module tests;
    full_adder_test fa;
    alu_test a;
    loopOverAllNibbles_test lan;
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
    } TestCmd;

    TestCmd cmdsToTest[] =
        '{
            '{instr: 'h_07b08293, ret_must_be: 123}, // addi x5, x1, 123
            '{instr: 'h_07b10293, ret_must_be: 124}, // addi x5, x2, 123
            '{instr: 'h_ffe10293, ret_must_be: -1},  // addi x5, x2, -2
            '{instr: 'h_0081a283, ret_must_be: 'h_feff_1111}, // lw x5, 8(x3)
            '{instr: 'h_ff822283, ret_must_be: 'h_feff_1111}, // lw x5, -8(x4)
            '{instr: 'h_07b08293, ret_must_be: 123} //TODO: replace by another test
        };

    // all commands starting from this address
    localparam start_addr = 32'h_ff0004;
    logic[7:0] clk_count;
    control #(.START_ADDR(start_addr)) c(clk_count[0]);

    TestCmd cmd;

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

            //~ $monitor("clk=%b clk_count=%0d state=%s opCode=%s pc=%h instr=%h clk_count=%0d alu_perm_to_count=%b busy=%b overflow=%b was_last_nibble=%b loop_nibbles_number=%h nibble=%h alu_result=%h", c.clk, clk_count, c.currState.name, c.opCode.name, c.pc, c.instr, clk_count, c.alu_perm_to_count, c.l.busy, c.l.overflow, c.l.was_last_nibble, c.loop_nibbles_number, c.l.curr_nibble_idx, c.alu_result);

            do begin
                assert(c.currState != ERROR);
                assert(clk_count < 40); else $error("clk_count exceeded");

                #1 clk_count++;
            end while(!(c.currState == INSTR_FETCH && c.pc != start_addr && c.clk == 0));

            // command done, check result
            // rd is always x5
            assert(c.register_file[5] == cmd.ret_must_be); else $error("Test #%0d: rd=%h but expected %h", i, c.register_file[5], cmd.ret_must_be);

            assert(c.pc == start_addr + 4); else $error("%h", c.pc);
        end
    end
endmodule
