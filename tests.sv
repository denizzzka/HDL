module tests;
    full_adder_test fa;
    alu_test a;
    loopOverAllNibbles_test lan;
    Ram_test r;
    control_test c;
    //~ control_test_bench tb;
endmodule

// TODO: implement tests for all instructions
module control_test_bench;
    typedef struct packed
    {
        logic[31:0] instr;
        logic[31:0] ret_must_be;
    } TestCmd;

    //FIXME: Verilator issue? It wants first struct as a separate defined variable for some reason
    localparam TestCmd s = '{ instr: 'h_07b08293 /* addi x5, x1, 123 */, ret_must_be: 123 };

    TestCmd cmdsToTest[] =
    {
        s, // addi x5, x1, 123
        '{instr: 'h_07b08293, ret_must_be: 0}
    };

    logic[7:0] clk_count;
    control c(clk_count[0]);

    TestCmd cmd;

    initial begin
        // all commands starting from this address
        localparam start_addr = 32'h_ff0004;

        foreach(cmdsToTest[i])
        begin
            clk_count = 0;
            cmd = cmdsToTest[i];

            // preload instruction
            c.memWrite32(start_addr, cmd.instr);

            // reset all registers
            c.pc = start_addr;

            foreach(c.register_file[i])
                c.register_file[i] = 0;

            c.currState = INSTR_FETCH;

            $monitor("clk=%b clk_count=%h state=%s opCode=%s pc=%h instr=%h", c.clk, clk_count, c.currState.name, c.opCode.name, c.pc, c.instr);

            do begin
                assert(clk_count < 100); else $error("clk_count exceeded");

                #1 clk_count++;
            end while(!(c.currState == INSTR_FETCH && c.pc != start_addr && c.clk == 0));

            // command done, check result
            // rd is always x5
            assert(c.register_file[5] == cmd.ret_must_be); else $error("rd=%h but expected %h", c.register_file[5], cmd.ret_must_be);

            assert(c.pc == start_addr + 4); else $error("%h", c.pc);
        end
    end
endmodule
