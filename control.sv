typedef enum logic[3:0] {
    RESET,
    INSTR_FETCH, // Also preloads PC to ALU
    INCR_PC_CALC,
    INCR_PC_CALC_POST, // Same as INCR_PC_CALC but to distinguish return path after "on the fly" currState substitution
    INCR_PC_PRELOAD, // Need to preload ALU before INCR_PC_CALC_POST will be called
    INCR_PC_STORE, // Store incremented PC value from ALU accumulator register
    INSTR_PROCESS, // Calls ALU if need
    INSTR_BRANCH, // Processing instruction which implies PC changing
    READ_MEMORY,
    WRITE_MEMORY,
    ERROR
} ControlState;

module CtrlStateFSM
    (
        input wire clk,
        input wire need_alu, // ...loop before next state
        input wire alu_busy,
        input wire ControlState nextState,
        input wire pre_incr_pc,
        output wire alu_perm_to_count,
        output AluCtrl alu_ctrl,
        output wire ControlState currState
    );

    //TODO: remove
    assign alu_perm_to_count = need_alu;

    ControlState _currState;

    always_ff @(posedge clk)
        if(~alu_busy)
            _currState <= nextState;

    // This conditional is need to avoid unnecessary clock step to decide
    // next state in case of post-incremented PC instruction
    always_comb
        if(_currState == INCR_PC_CALC && !pre_incr_pc) // need to change path on the fly?
            currState = INSTR_PROCESS;
        else
            currState = _currState;

endmodule

module control #(parameter START_ADDR = 0)
    (
        input wire clk
    );

    logic[31:0] pc;
    logic[31:0] register_file[32]; //TODO: x0 is hardwired with all bits equal to 0

    function void resetRegisters;
        pc <= START_ADDR;

        foreach(register_file[i])
            register_file[i] <= 0;
    endfunction

    wire ControlState currState;
    ControlState nextState;
    logic need_alu;
    wire alu_busy;
    wire alu_perm_to_count;
    CtrlStateFSM ctrlStateFSM(.*);

    Instruction instr;
    wire OpCode opCode;
    wire DecodedAluCmd decodedAluCmd;
    wire WiredDecisions decoded;

    instr_stencil i_s(.*);

    logic[2:0] loop_nibbles_number;
    AluCtrl alu_ctrl;
    logic check_if_result_0xF;
    logic word2_is_signed_and_negative;
    logic[31:0] alu_w1;
    logic[31:0] alu_w2;
    logic[31:0] alu_preinit_result;
    logic[31:0] alu_result;

    typedef enum {
        DISABLED,
        INCREMENT,
        BITS_8,
        BITS_12,
        BITS_16,
        BITS_24,
        BITS_32,
        BITS_32_COMPARE // enables check_if_result_0xF
    } AluMode;

    typedef enum logic {
        UNSIGNED,
        SIGNED,
        UNDEF = 'x
    } Signed;

    function void setAluArgs
        (
            input AluMode aluMode,
            input AluCtrl ctrl,
            input Signed isSigned,
            input[31:0] word1,
            input[31:0] word2
        );
        logic msb; // of word2

        alu_w1 = word1;
        alu_w2 = word2;
        alu_ctrl = ctrl;

        need_alu = (aluMode != DISABLED);
        assign check_if_result_0xF = (aluMode == BITS_32_COMPARE);

        unique case(aluMode)
            DISABLED: begin end
            INCREMENT: loop_nibbles_number = 0;
            BITS_8: loop_nibbles_number = 1;
            BITS_12: loop_nibbles_number = 2;
            BITS_16: loop_nibbles_number = 3;
            BITS_24: loop_nibbles_number = 5;
            BITS_32,
            BITS_32_COMPARE: loop_nibbles_number = 7;
        endcase

        // Immediate values always signed
        //TODO: Check is unsupported by Verilator
        //if(aluMode == BITS_12)
            //assert property(isSigned);

        unique case(aluMode)
            BITS_8: msb = word2[7];
            BITS_12: msb = word2[11];
            BITS_16: msb = word2[15];
            BITS_24: msb = word2[23];
            BITS_32,
            BITS_32_COMPARE: msb = word2[31];
            default: msb = 'x;
        endcase

        word2_is_signed_and_negative = (isSigned == SIGNED) && msb;

    endfunction

    function void disableAlu;
        setAluArgs(DISABLED, 5'bxxxxx, UNDEF, 'x, 'x);
    endfunction

    loopOverAllNibbles l(
        .clk,
        .loop_perm_to_count(alu_perm_to_count),
        .ctrl(alu_ctrl),
        .word1(alu_w1),
        .word2(alu_w2),
        .preinit_result(alu_preinit_result),
        .result(alu_result),
        .busy(alu_busy),
        .*
    );

    logic write_enable;
    wire is32bitWrite = 1;
    logic[31:0] mem_addr_bus;
    wire[7:0] bus_to_mem = 'haa;
    logic[31:0] bus_to_mem_32;
    wire[7:0] bus_from_mem;
    wire[31:0] bus_from_mem_32;

    Ram#('hffff/4) mem(.addr(mem_addr_bus), .*);

    // Increment PC before executing instruction?
    wire pre_incr_pc = !(opCode == AUIPC || opCode == BRANCH);

    wire comparison_result = alu_ctrl.ctrl.carry_in;

    always_comb
        unique case(currState)
            RESET: nextState = INSTR_FETCH;
            INSTR_FETCH: nextState = INCR_PC_CALC;
            INCR_PC_CALC: nextState = INCR_PC_STORE;
            INCR_PC_PRELOAD: nextState = INCR_PC_CALC_POST;
            INCR_PC_CALC_POST: nextState = INCR_PC_STORE;
            INCR_PC_STORE: nextState = pre_incr_pc ? ((opCode == JAL || opCode == JALR) ? INSTR_BRANCH : INSTR_PROCESS) : INSTR_FETCH;
            INSTR_PROCESS:
            begin
                unique case(opCode)
                    OP_IMM, LUI, JAL, JALR: nextState = INSTR_FETCH;
                    AUIPC: nextState = INCR_PC_PRELOAD;
                    BRANCH: nextState = comparison_result ? INSTR_BRANCH : INCR_PC_PRELOAD;
                    LOAD: nextState = READ_MEMORY;
                    STORE: nextState = WRITE_MEMORY;
                    default: nextState = ERROR;
                endcase
            end
            INSTR_BRANCH: nextState = INSTR_FETCH;
            READ_MEMORY: nextState = INSTR_FETCH;
            WRITE_MEMORY: nextState = INSTR_FETCH;
            default: nextState = ERROR;
        endcase

    // TODO: move to FSM always_comb block?
    always_comb
        unique case(nextState)
            INCR_PC_CALC,
            INCR_PC_CALC_POST:
                alu_preinit_result = pc;

            default:
            begin
                if(currState != INCR_PC_STORE)
                    alu_preinit_result = 0;
                else
                    unique case(opCode)
                        JAL: alu_preinit_result = pc;
                        JALR: alu_preinit_result = register_file[instr.rs1]; //TODO: can be =0 ?
                        BRANCH: alu_preinit_result = 0; //TODO: remove
                        default: alu_preinit_result = 0;
                    endcase
            end
        endcase

    function void prepareMemRead(input[31:0] address);
        write_enable = 0;
        mem_addr_bus = address;
    endfunction

    function void prepareMemWrite(input[31:0] address, input[31:0] data);
        write_enable = 1;
        mem_addr_bus = address;
        bus_to_mem_32 = data;
    endfunction

    task memWrite32(input[31:0] address, input[31:0] data);
        force write_enable = 1;
        force mem_addr_bus = address;
        force bus_to_mem_32 = data;

        mem.forceClkCycle();

        release write_enable;
        release mem_addr_bus;
        release bus_to_mem_32;
    endtask

    wire[31:0] rs1 = register_file[instr.rs1];
    wire[31:0] rs2 = register_file[instr.rs2];

    always_comb
        unique case(currState)
            INSTR_FETCH:
            begin
                disableAlu();
                prepareMemRead(pc);
            end

            INCR_PC_PRELOAD: disableAlu();

            INCR_PC_CALC,
            INCR_PC_CALC_POST:
            begin
                setAluArgs(
                    INCREMENT, ADD, UNSIGNED,
                    pc,
                    4 // PC increment value
                );
            end

            INCR_PC_STORE: disableAlu();

            INSTR_PROCESS:
            unique case(opCode)
                OP_IMM:
                    setAluArgs(
                        BITS_12, ADD, SIGNED,
                        register_file[instr.rs1],
                        32'(decoded.immediate_value12)
                    );

                AUIPC:
                    setAluArgs(
                        BITS_32, ADD, SIGNED,
                        pc,
                        { decoded.immediate_value20, 12'b0 }
                    );

                BRANCH:
                begin
                    setAluArgs(
                        BITS_32_COMPARE, XNOR, UNSIGNED,
                        rs1, rs2
                    );
                end

                LOAD: begin
                    unique case(decoded.width)
                        // FIXME: signed flag must be obtained from funct3
                        BITS32: begin
                            // Calc mem address:
                            setAluArgs(
                                BITS_12, ADD, SIGNED,
                                register_file[instr.rs1],
                                32'(decoded.immediate_value12)
                            );
                        end

                        default: begin end // FIXME: remove this line
                    endcase
                end

                STORE: begin
                    unique case(decoded.width)
                        BITS32: begin
                            // Calc mem address:
                            setAluArgs(
                                BITS_12, ADD, SIGNED,
                                register_file[instr.rs1],
                                32'(decoded.immediate_value12)
                            );
                        end

                        default: begin end // FIXME: remove this line
                    endcase
                end

                default: begin // FIXME: remove this line
                    disableAlu();
                end
            endcase

            INSTR_BRANCH:
            unique case(opCode)
                JAL:
                    setAluArgs(
                        // TODO: Can loop over 20 bits only and use MSB to stop. Will save a whole cycle. Implies ALU changes
                        BITS_24, ADD, SIGNED,
                        pc,
                        { 8'b0, decoded.immediate_jump }
                    );

                JALR:
                    setAluArgs(
                        BITS_12, ADD, SIGNED,
                        register_file[instr.rs1],
                        32'(decoded.immediate_value12)
                    );
                    /* TODO: RISC-V spec:
                    The JALR instruction now clears the lowest bit of
                    the calculated target address, to simplify hardware
                    and to allow auxiliary information to be stored in
                    function pointers.
                    */

                BRANCH:
                    setAluArgs(
                        BITS_12, ADD, SIGNED,
                        pc,
                        { 19'b0, decoded.immediate_value12, 1'b0 }
                    );

                default: disableAlu();
            endcase

            READ_MEMORY:
            begin
                disableAlu();
                prepareMemRead(alu_result);
            end

            WRITE_MEMORY:
            begin
                disableAlu();
                prepareMemWrite(alu_result, register_file[instr.rs2]);
            end

            default:
            begin
                disableAlu();
            end
        endcase

    always_ff @(posedge clk)
        unique case(currState)
            RESET: resetRegisters();
            INSTR_FETCH: instr <= bus_from_mem_32;
            INCR_PC_PRELOAD,
            INCR_PC_CALC,
            INCR_PC_CALC_POST: begin end
            INCR_PC_STORE:
            begin
                if(opCode == JAL || opCode == JALR)
                    register_file[instr.rd] <= alu_result;
                else
                    pc <= alu_result;
            end
            INSTR_PROCESS:
            begin
                // Short cycle, like as for LUI instruction
                if(
                    nextState == INSTR_FETCH ||
                    nextState == INCR_PC_PRELOAD
                )
                    register_file[instr.rd] <= (opCode != LUI) ? alu_result : { decoded.immediate_value20, 12'b0 };
            end
            INSTR_BRANCH: pc <= alu_result;
            READ_MEMORY: register_file[instr.rd] <= bus_from_mem_32;
            WRITE_MEMORY: begin end
            ERROR: begin end
        endcase

endmodule

module control_test;
    logic clk;
    control c(clk);

    logic[31:0] rom[] =
    {
        32'b00000111101100000000001010010011, // addi x5, x0, 123
        32'b00000000001000101000001100010011, // addi x6, x5, 2
        32'b00000000010100101010001110000011, // lw x7, 5(x5)
        32'b11111110011100101010111100100011, // sw x7, -2(x5)
        32'b10000000000000000000010010010011, // addi x9, x0, 0x800 (-2048)
        32'h_000f0537,                        // lui x10, 240
        32'b00000000000000000000000001110011 // ecall/ebreak
    };

    initial begin
        localparam start_address = 'hff; // First instruction, leads carry on PC calculation for test purpose

        c.memWrite32(128, 'h58); // for lw command check

        foreach(rom[i])
            c.memWrite32(i*4 + start_address, rom[i]);

        //~ $monitor("clk=%b opCode=%s state=%s nibb=%h perm=%b busy=%b alu_ret=%h d1=%h d2=%h sig_neg=%b carry=(%b %b) pc=%h inst=%h rs1=%h(%h) rs2=%h(%h) rd=%h(%h) imm=%h mem32%s=%h(a:%h)",
            //~ clk, c.opCode.name, c.currState.name, c.l.curr_nibble_idx, c.l.loop_perm_to_count,
            //~ c.alu_busy, c.alu_result, c.l.alu_args.d1, c.l.alu_args.d2, c.word2_is_signed_and_negative,
            //~ c.l.result_carry, c.l.ctrl.ctrl.carry_in, c.pc, c.instr,
            //~ c.register_file[c.instr.rs1], c.instr.rs1,
            //~ c.register_file[c.instr.rs2], c.instr.rs2,
            //~ c.register_file[c.instr.rd], c.instr.rd,
            //~ c.decoded.immediate_value20,
            //~ c.write_enable ? "W" : "R" , c.write_enable ? c.bus_to_mem_32 : c.bus_from_mem_32, c.mem_addr_bus
        //~ );

        //~ $monitor("state=%s alu_ret=%h opcode=%s regs=x4:%h x5:%h x6:%h x7:%h x8:%h x9:%h", c.currState.name, c.alu_result, c.opCode.name,
            //~ c.register_file[4],
            //~ c.register_file[5],
            //~ c.register_file[6],
            //~ c.register_file[7],
            //~ c.register_file[8],
            //~ c.register_file[9]
        //~ );

        //~ $readmemh("instr.txt", c.mem);
        //~ $dumpfile("control_test.vcd");
        //~ $dumpvars(0, control_test);

        // Initial state
        c.currState = RESET;
        #1 clk = ~clk;
        #1 clk = ~clk;

        c.pc = start_address;

        assert(clk == 0);

        while(c.opCode != SYSTEM) begin
            #1
            clk = ~clk;
        end

        assert(clk == 0);

        assert(c.register_file[5] == 123); else $error(c.register_file[5]);
        assert(c.register_file[6] == 125); else $error(c.register_file[6]);

        // Check lw command:
        assert(c.register_file[7] == 'h58); else $error("%h", c.register_file[7]);

        // Check sw command:
        assert(c.mem.mem['h79*8 +: 8] == 'h58); else $error("%h", c.mem.mem['h79*8 +: 8]);

        // addi with negative arg
        assert(c.register_file[9] == -2048); else $error("%d %h", $signed(c.register_file[9]), c.register_file[9]);

        // Check LUI:
        assert(c.register_file[10] == {20'(240), 12'h_000}); else $error("%h %h", c.register_file[10], {20'(240), 12'h_000});
    end

endmodule
