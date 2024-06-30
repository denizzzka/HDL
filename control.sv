typedef enum logic[3:0] {
    RESET,
    INSTR_FETCH, // Also preloads PC to ALU
    INCR_PC_CALC,
    INCR_PC_CALC_POST, // Same as INCR_PC_CALC but to distinguish return path after "on the fly" currState substitution
    INCR_PC_PRELOAD, // Need to preload ALU before INCR_PC_CALC_POST will be called
    INCR_PC_STORE, // Store incremented PC value from ALU accumulator register
    INSTR_PROCESS, // Calls ALU if need
    PREP_NEXT_SHIFT, // Prepare next shift stage, TODO: rename to PREP_NEXT_SHIFT
    INSTR_BRANCH, // Processing instruction which implies (unconditional?) PC changing
    BRANCH_PC_CALC,
    BRANCH_PC_PRELOAD,
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
    wire shift_loop_busy;
    CtrlStateFSM ctrlStateFSM(.*);

    Instruction instr;
    wire OpCode opCode;
    wire DecodedAluCmd decodedAluCmd;
    wire WiredDecisions decoded;

    instr_stencil i_s(.*);

    logic[2:0] loop_nibbles_number;
    AluCtrl alu_ctrl;
    logic carry_in_out;
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
        BITS_12_COMPARE,
        BITS_16,
        BITS_24,
        BITS_32,
        BITS_32_COMPARE,
        BITS_32_EQUALITY // enables check_if_result_0xF
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
        logic isSortOfComparision;
        logic swap_args;

        isSortOfComparision = (aluMode == BITS_12_COMPARE || aluMode == BITS_32_COMPARE || aluMode == BITS_32_EQUALITY);

        swap_args = isSortOfComparision;

        alu_w1 = swap_args ? word2 : word1;
        alu_w2 = swap_args ? word1 : word2;

        msb = alu_w2[31];
        // TODO: rename to alu_w2_is_signed_and_negative
        word2_is_signed_and_negative = ~isSortOfComparision && isSigned == SIGNED && msb;

        alu_ctrl = ctrl;

        compare_resultKnownAndValuesNotEqual = (word1[31] != word2[31]);
        need_alu = ~(aluMode == DISABLED || (isSortOfComparision && compare_resultKnownAndValuesNotEqual));
        assign check_if_result_0xF = (aluMode == BITS_32_EQUALITY);

        unique case(aluMode)
            DISABLED: loop_nibbles_number = 7; // 7 is for RSHFT preinit
            INCREMENT: loop_nibbles_number = 0;
            BITS_8: loop_nibbles_number = 1;
            BITS_12,
            BITS_12_COMPARE: loop_nibbles_number = 2;
            BITS_16: loop_nibbles_number = 3;
            BITS_24: loop_nibbles_number = 5;
            BITS_32,
            BITS_32_COMPARE,
            BITS_32_EQUALITY: loop_nibbles_number = 7;
        endcase

        // Immediate values always signed
        //TODO: Check is unsupported by Verilator
        //if(aluMode == BITS_12)
            //assert property(isSigned);

    endfunction

    function void disableAlu;
        AluCtrl ctrl;
        ctrl = 5'bxxxxx;

        if(enable_preinit_only_for_shift || currState == PREP_NEXT_SHIFT)
            ctrl = decodedAluCmd.ctrl; // for RSHFT operation
        else
            // Need preinit carry_in=1 for SUB operations
            ctrl.ctrl.carry_in = (opCode == OP) ? i_s.sub_sra_modifier : 0;

        setAluArgs(DISABLED, ctrl, UNDEF, 'x, 'x);
    endfunction

    wire enable_preinit_only_for_shift = (currState == INCR_PC_STORE && i_s.is_shift_operation);

    loopOverAllNibbles #(3) l(
        .clk,
        .loop_perm_to_count(alu_perm_to_count),
        .ctrl(alu_ctrl),
        .word1(alu_w1),
        .word2(alu_w2),
        .preinit_result(alu_preinit_result),
        .enable_preinit_only(enable_preinit_only_for_shift),
        .result(alu_result),
        .busy(alu_busy),
        .*
    );

    //TODO: start value can be commutated for free at any state except INSTR_PROCESS
    wire[4:0] shift_loop_start_val = (opCode == OP_IMM) ? instr.rs2 :  5'(rs2) /* OP */; //TODO: store shift_counter[4:0] directly in instr.rs2 register
    wire shift_reset = (currState == INCR_PC_STORE) && i_s.is_shift_operation;
    wire shift_loop_step = (~alu_busy && currState == INSTR_PROCESS) || shift_reset;

    shift_loop sl(
        .decrease_pulse(shift_loop_step),
        .reset(shift_reset),
        .start_val(shift_loop_start_val),
        .busy(shift_loop_busy)
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

    logic comparison_failed;

    always_comb
    begin
        logic comparison_success;

        if(compare_resultKnownAndValuesNotEqual)
        begin
            if(opCode == BRANCH && ~i_s.branch_lessMoreOperation) // BEQ or BNE
                comparison_success = 0;
            else if(~i_s.is_comparison_signed_op)
                comparison_success = (signedsDecis == RS1_lt_RS2); //TODO can be checked only one bit here
            else
                comparison_success = ~(signedsDecis == RS1_lt_RS2);
        end
        else
            comparison_success = carry_in_out; // ^ (i_s.is_comparison_signed_op && signedsDecis == NEGATIVES);

        if(i_s.is_SLT_operation)
            comparison_failed = ~comparison_success;
        else
            comparison_failed = ~comparison_success ^ i_s.branch_invertOperation;
    end

    always_comb
        unique case(currState)
            RESET: nextState = INSTR_FETCH;
            INSTR_FETCH: nextState = INCR_PC_CALC; // special case, see module CtrlStateFSM, TODO: remove this line?
            INCR_PC_CALC: nextState = INCR_PC_STORE;
            INCR_PC_PRELOAD: nextState = INCR_PC_CALC_POST;
            INCR_PC_CALC_POST: nextState = INCR_PC_STORE;
            INCR_PC_STORE: nextState = pre_incr_pc ? ((opCode == JAL || opCode == JALR) ? INSTR_BRANCH : INSTR_PROCESS) : INSTR_FETCH;
            INSTR_PROCESS:
            begin
                unique case(opCode)
                    LUI, JAL, JALR: nextState = INSTR_FETCH;
                    OP, OP_IMM: nextState = (i_s.is_shift_operation && shift_loop_busy) ? PREP_NEXT_SHIFT : INSTR_FETCH;
                    AUIPC: nextState = INCR_PC_PRELOAD;
                    BRANCH: nextState = comparison_failed ? INCR_PC_PRELOAD : BRANCH_PC_PRELOAD;
                    LOAD: nextState = READ_MEMORY;
                    STORE: nextState = WRITE_MEMORY;
                    default: nextState = ERROR;
                endcase
            end
            INSTR_BRANCH: nextState = INSTR_FETCH;
            BRANCH_PC_PRELOAD: nextState = BRANCH_PC_CALC;
            BRANCH_PC_CALC: nextState = INCR_PC_STORE;
            PREP_NEXT_SHIFT: nextState = INSTR_PROCESS;
            READ_MEMORY: nextState = INSTR_FETCH;
            WRITE_MEMORY: nextState = INSTR_FETCH;
            default: nextState = ERROR; //TODO: remove
        endcase

    // TODO: move to FSM always_comb block?
    always_comb
        unique case(nextState)
            BRANCH_PC_CALC,
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
                        JALR: alu_preinit_result = register_file[instr.rs1];
                        OP_IMM, OP: alu_preinit_result = i_s.is_shift_operation ? rs1 : 0;
                        LOAD, STORE: alu_preinit_result = rs1;
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

    //TODO: rename RS1_lt_RS2 -> aluW1_lt_aluW2?
    typedef enum logic[1:0] {
        RS1_lt_RS2  = 'b_10, // rs1 < rs2 if signed, rs1 > rs2 if unsigned
        RS1_gt_RS2  = 'b_01, // rs1 > rs2 if signed, rs1 < rs2 if unsigned
        POSITIVES   = 'b_00,
        NEGATIVES   = 'b_11
    } SignedsCmpDecision;

    // Makes some decisions about two signed values by comparing its signs
    //TODO: use rs1 and rs2 here instead of ALU wires? To decrease comb logic path length
    wire SignedsCmpDecision signedsDecis = SignedsCmpDecision'({ alu_w1[31], alu_w2[31] });
    logic compare_resultKnownAndValuesNotEqual;

    wire[31:0] rs1 = register_file[instr.rs1];
    wire[31:0] rs2 = register_file[instr.rs2];

    always_comb
        unique case(currState)
            RESET,
            ERROR:
                disableAlu();

            INSTR_FETCH:
            begin
                disableAlu();
                prepareMemRead(pc);
            end

            BRANCH_PC_PRELOAD,
            INCR_PC_PRELOAD: disableAlu();

            INCR_PC_CALC,
            INCR_PC_CALC_POST:
                setAluArgs(
                    INCREMENT, ADD, UNSIGNED, pc,
                    4 // PC increment value
                );

            // conditional jump
            BRANCH_PC_CALC:
                setAluArgs(
                    BITS_16, ADD, SIGNED, pc,
                    decoded.immediate_valueB
                );

            INCR_PC_STORE: disableAlu();

            INSTR_PROCESS:
            begin
            unique case(opCode)
                OP_IMM:
                begin
                    if(~i_s.is_shift_operation)
                        setAluArgs(
                            i_s.is_SLT_operation ? BITS_12_COMPARE : BITS_12,
                            decodedAluCmd.ctrl,
                            i_s.is_UnsignedSLT_operation ? UNSIGNED : SIGNED,
                            rs1,
                            decoded.immediate_value12
                        );
                    else
                    begin
                        if(~shift_loop_busy) // zero shift
                            disableAlu();
                        else
                            setAluArgs(
                                BITS_32, decodedAluCmd.ctrl, UNSIGNED,
                                rs1, rs1
                            );
                    end
                end

                OP:
                begin
                    if(~i_s.is_shift_operation)
                        setAluArgs(
                            i_s.is_SLT_operation ? BITS_32_COMPARE : BITS_32,
                            decodedAluCmd.ctrl, UNSIGNED,
                            rs1, rs2
                        );
                    else
                    begin
                        if(~shift_loop_busy) // zero shift
                            disableAlu();
                        else
                            setAluArgs(
                                BITS_32, decodedAluCmd.ctrl, UNSIGNED,
                                rs1, rs1
                            );
                    end
                end

                AUIPC:
                    setAluArgs(
                        BITS_32, ADD, SIGNED,
                        pc,
                        { decoded.immediate_value20, 12'b0 }
                    );

                BRANCH:
                begin
                    setAluArgs(
                        i_s.branch_lessMoreOperation ? BITS_32_COMPARE : BITS_32_EQUALITY,
                        decodedAluCmd.ctrl,
                        i_s.branch_isUnsignedOperation ? UNSIGNED : SIGNED,
                        rs1, rs2
                    );
                end

                LOAD:
                    setAluArgs(
                        BITS_12, ADD, SIGNED,
                        rs1, decoded.immediate_value12
                    );

                STORE: begin
                    setAluArgs(
                        BITS_12, ADD, SIGNED,
                        rs1, decoded.immediate_value12
                    );
                end

                default: begin // FIXME: remove this line
                    disableAlu();
                end
            endcase
            end

            INSTR_BRANCH:
            unique case(opCode)
                JAL:
                    setAluArgs(
                        // TODO: Can loop over 20 bits only and use MSB to stop. Will save a whole cycle. Implies ALU changes
                        BITS_24, ADD, SIGNED,
                        pc,
                        decoded.immediate_jump
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

                default: disableAlu();
            endcase

            PREP_NEXT_SHIFT: disableAlu();

            READ_MEMORY:
            begin
                disableAlu();
                prepareMemRead(alu_result);
            end

            WRITE_MEMORY:
            begin
                disableAlu();

                unique case(decoded.width)
                    BITS32: prepareMemWrite(alu_result, rs2);
                    BITS16: prepareMemWrite(alu_result, {{16{1'b0}}, rs2[15:0]});
                    BITS8:  prepareMemWrite(alu_result, {{24{1'b0}}, rs2[7:0]});
                    ERRVAL: prepareMemWrite(alu_result, 'h_deaddead); // FIXME: error processing
                endcase
            end
        endcase

    always_ff @(posedge clk)
        unique case(currState)
            RESET: resetRegisters();
            INSTR_FETCH: instr <= bus_from_mem_32;
            INCR_PC_PRELOAD,
            INCR_PC_CALC,
            BRANCH_PC_PRELOAD,
            BRANCH_PC_CALC,
            INCR_PC_CALC_POST: begin end
            INCR_PC_STORE:
            begin
                if(opCode == JAL || opCode == JALR)
                    register_file[instr.rd] <= alu_result;
                else
                    pc <= alu_result;

                // places MSB for arithmetic shifts
                if(i_s.is_shift_operation && i_s.sub_sra_modifier)
                    carry_in_out <= rs1[31];
            end
            INSTR_PROCESS:
            begin
                if(~alu_busy)
                    if(opCode == LUI)
                        register_file[instr.rd] <= { decoded.immediate_value20, 12'b0 };
                    else if(i_s.is_SLT_operation)
                        register_file[instr.rd] <= comparison_failed ? 0 : 1;
                    else
                        register_file[instr.rd] <= alu_result;
            end
            INSTR_BRANCH: pc <= alu_result;
            PREP_NEXT_SHIFT:
            begin
                instr.rs1 <= instr.rd;

                // places MSB for arithmetic shifts (TODO: duplicates code from INCR_PC_STORE)
                carry_in_out <= i_s.sub_sra_modifier && rs1[31];
            end
            READ_MEMORY:
            begin
                unique case(decoded.width)
                    BITS32: register_file[instr.rd] <= bus_from_mem_32;
                    BITS16: register_file[instr.rd] <= { {16{ decoded.isLoadingUnsignedValue ? 1'b0 : bus_from_mem_32[15] }}, bus_from_mem_32[15:0] };
                    BITS8: register_file[instr.rd] <=  { {24{ decoded.isLoadingUnsignedValue ? 1'b0 : bus_from_mem_32[7]  }}, bus_from_mem_32[7:0] };
                    ERRVAL: register_file[instr.rd] <= 'h_deaddead; // FIXME: error processing
                endcase
            end
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
