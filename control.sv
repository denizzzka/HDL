typedef enum logic[2:0] {
    INSTR_FETCH,
    INCR_PC_CALC,
    INCR_PC_STORE,
    INSTR_DECODE, // and call ALU if need
    READ_MEMORY,
    WRITE_MEMORY,
    STORE_ALU_RESULT
} ControlState;

module CtrlStateFSM
    (
        input wire clk,
        input wire need_alu, // ...loop before next state
        input wire alu_busy,
        input wire ControlState nextState,
        output wire alu_perm_to_count,
        output wire ControlState currState
    );

    //TODO: remove
    assign alu_perm_to_count = need_alu;

    always_ff @(posedge clk)
        if(~alu_busy)
            currState <= nextState;

endmodule

module control
    (
        input wire clk
    );

    logic[31:0] pc;
    logic[31:0] register_file[32]; //TODO: x0 is hardwired with all bits equal to 0

    ControlState currState;
    ControlState nextState;
    logic need_alu;
    wire alu_busy;
    wire alu_perm_to_count;
    CtrlStateFSM ctrlStateFSM(.*);

    Instruction instr;
    wire OpCode opCode;
    wire DecodedAluCmd decodedAluCmd;
    wire signed[11:0] jumpAddr;
    wire[11:0] immediate_value;
    wire RegAddr rs1;
    wire RegAddr rs2;
    wire RegAddr rd;

    instr_stencil i_s(
            .source_register_1(rs1),
            .source_register_2(rs2),
            .register_out_addr(rd),
            .*
        );

    logic[2:0] loop_nibbles_number;
    AluCtrl alu_ctrl;
    logic word2_is_signed_and_negative;
    logic[31:0] alu_w1;
    logic[31:0] alu_w2;
    wire[31:0] alu_preinit_result;
    logic[31:0] alu_result;

    typedef enum {
        DISABLED,
        INCREMENT,
        BITS_8,
        BITS_12,
        BITS_16,
        BITS_32
    } AluMode;

    typedef enum logic {
        UNSIGNED,
        SIGNED,
        UNDEF = 'x
    } Signed;

    function void setAluArgs
        (
            input AluMode aluMode,
            input Signed isSigned,
            input[31:0] word1,
            input[31:0] word2
        );
        logic msb; // of word2

        alu_w1 = word1;
        alu_w2 = word2;

        need_alu = (aluMode != DISABLED);

        unique case(aluMode)
            DISABLED: begin end
            INCREMENT: loop_nibbles_number = 0;
            BITS_8: loop_nibbles_number = 1;
            BITS_12: loop_nibbles_number = 2;
            BITS_16: loop_nibbles_number = 3;
            BITS_32: loop_nibbles_number = 7;
        endcase

        // Immediate values always signed
        //TODO: Check is unsupported by Verilator
        //if(aluMode == BITS_12)
            //assert property(isSigned);

        unique case(aluMode)
            BITS_8: msb = word2[7];
            BITS_12: msb = word2[11];
            BITS_16: msb = word2[15];
            BITS_32: msb = word2[31];
            default: msb = 'x;
        endcase

        word2_is_signed_and_negative = (isSigned == SIGNED) && msb;

    endfunction

    function void disableAlu;
        setAluArgs(DISABLED, UNDEF, 'x, 'x);
    endfunction

    loopOverAllNibbles l(
        .clk,
        .loop_perm_to_count(alu_perm_to_count),
        .ctrl(alu_ctrl),
        .word2_is_negative(word2_is_signed_and_negative),
        .word1(alu_w1),
        .word2(alu_w2),
        .preinit_result(alu_preinit_result),
        .result(alu_result),
        .busy(alu_busy),
        .*
    );

    logic write_enable;
    wire is32bitWrite; // = 1;
    logic[31:0] mem_addr_bus;
    wire[7:0] bus_to_mem;
    wire[31:0] bus_to_mem_32;
    wire[7:0] bus_from_mem;
    wire[31:0] bus_from_mem_32;

    Ram#('hffff/4) mem(.addr(mem_addr_bus), .*);

    always_latch // TODO: why latch?
        unique case(currState)
            INSTR_FETCH: nextState = INCR_PC_CALC;
            INCR_PC_CALC: nextState = INCR_PC_STORE;
            INCR_PC_STORE: nextState = INSTR_DECODE;
            INSTR_DECODE:
            begin
                unique case(opCode)
                    LOAD: nextState = READ_MEMORY;
                    default: nextState = STORE_ALU_RESULT; // TODO: can be avoid by iimediate non-blocking assign?
                endcase
            end
            STORE_ALU_RESULT: nextState = INSTR_FETCH;
            READ_MEMORY: nextState = INSTR_FETCH;
            WRITE_MEMORY: nextState = INSTR_FETCH;
        endcase

    // TODO: move to module bottom
    always_ff @(posedge clk)
        unique case(currState)
            INSTR_FETCH: instr <= bus_from_mem_32;
            INCR_PC_CALC: begin end
            INCR_PC_STORE: pc <= alu_result;
            INSTR_DECODE: begin end
            READ_MEMORY: register_file[rd] <= bus_from_mem_32;
            WRITE_MEMORY: begin end
            STORE_ALU_RESULT: register_file[rd] <= alu_result;
        endcase

    assign alu_preinit_result = (currState == INSTR_FETCH) ? pc : 0;

    function void prepareMemRead(input[31:0] address);
        write_enable = 0;
        mem_addr_bus = address;
    endfunction

    always_comb
        unique case(currState)
            INSTR_FETCH:
            begin
                disableAlu();
                prepareMemRead(pc);
            end

            INCR_PC_CALC:
            begin
                setAluArgs(
                    INCREMENT, UNSIGNED,
                    pc,
                    4 // PC increment value
                );
            end

            INCR_PC_STORE: disableAlu();

            INSTR_DECODE:
            unique case(opCode)
                OP_IMM: begin
                    setAluArgs(
                        BITS_12, SIGNED,
                        register_file[rs1],
                        32'(immediate_value)
                    );
                end

                LOAD: begin
                    unique case(instr.ip.ri.funct3.width)
                        BITS32: begin
                            // Calc mem address:
                            setAluArgs(
                                BITS_12, SIGNED,
                                register_file[rs1],
                                32'(immediate_value)
                            );
                        end

                        default: begin end // FIXME: remove this line
                    endcase
                end

                default: begin // FIXME: remove this line
                    disableAlu();
                end
            endcase

            READ_MEMORY:
            begin
                disableAlu();
                prepareMemRead(pc);
            end

            default:
            begin
                disableAlu();
            end
        endcase
endmodule

module control_test;
    logic clk;
    control c(clk);

    logic[31:0] rom[] =
    {
        32'b00000111101100000000001010010011, // addi x5, x0, 123
        //~ 32'b00000000001000101000001100010011, // addi x6, x5, 2
        //~ 32'b00000000010100101010001110000011, // lw x7, 5(x5)
        //~ 32'b00000000001000001000000110110011, // add  x3, x1, x2
        32'b00000000000000000000000001110011 // ecall/ebreak
    };

    initial begin
        localparam start_address = 'hff; // First instruction, leads carry on PC calculation for test purpose
        localparam start_addres_in_bits = start_address * 8;

        c.pc = start_address;

        c.mem.mem[128*8 : 8] = 88; // for lw command check

        foreach(rom[i])
        begin
            int n = i*32 + start_addres_in_bits;

            c.mem.mem[n +: 32] = rom[i];
        end

        $display("%h", c.mem.mem[start_addres_in_bits +: 31*10]);

        $monitor("clk=%b op:%.6s s:%.16s nibb=%h perm=%b busy=%b alu_ret=%h d1=%h d2=%h carry=(%b %b) pc=%h inst=%h rs1=%h rd=%h internal_imm=%h imm=%h mem32=%h(a:%h)",
            clk, c.opCode.name, c.currState.name, c.l.curr_nibble_idx, c.l.loop_perm_to_count, c.alu_busy, c.alu_result,
            c.l.alu_args.d1, c.l.alu_args.d2, c.l.result_carry, c.l.ctrl.ctrl.carry_in, c.pc, c.instr,c.rs1,
            c.rd, c.instr.ip.ri.imm11, c.immediate_value, c.bus_from_mem_32, c.mem_addr_bus);

        //~ $monitor("state=%h alu_ret=%h regs=%h %h %h %h", c.currState, c.alu_result, c.register_file[4], c.register_file[5], c.register_file[6], c.register_file[7]);

        //~ $readmemh("instr.txt", c.mem);
        //~ $dumpfile("control_test.vcd");
        //~ $dumpvars(0, control_test);

        // Initial state
        c.currState = STORE_ALU_RESULT;

        assert(clk == 0);

        while(c.opCode != SYSTEM) begin
            #1
            clk = ~clk;
        end

        assert(c.register_file[5] == 123); else $error(c.register_file[5]);
        assert(c.register_file[6] == 125); else $error(c.register_file[6]);

        // Check lw command:
        //~ assert(c.register_file[7] == 88); else $error(c.register_file[7]);
    end

endmodule
