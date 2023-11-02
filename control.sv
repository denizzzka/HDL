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

    assign alu_perm_to_count = need_alu;

    always_ff @(posedge clk)
        if(~alu_busy)
            currState = nextState;

endmodule

typedef struct packed {
    logic[2:0] nibbles_num;
    logic isSigned;
} AluModeOption;

typedef enum AluModeOption {
    DISABLED =  {3'd0, 1'b1}, // magic value, means 1 nibble but signed
    INCREMENT = {3'd0, 1'b0}, // 4 bits
    BITS_8 =    {3'd1, 1'b0},
    BITS_16 =   {3'd3, 1'b0},
    BITS_32 =   {3'd7, 1'b0},
    BITS_12_SIGNED =   {3'd2, 1'b1}
} AluMode;

module control
    (
        input wire clk
    );

    logic[31:0] pc;
    logic[31:0] register_file[32]; //TODO: x0 is hardwired with all bits equal to 0
    logic[31:0][7:0] mem;

    ControlState currState;
    ControlState nextState;
    wire need_alu = (aluMode != DISABLED);
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

    wire[2:0] loop_nibbles_number = aluModeOption.nibbles_num;
    AluCtrl alu_ctrl;
    wire word2_is_signed_and_negative;
    AluMode aluMode;
    wire AluModeOption aluModeOption = aluMode;
    logic[31:0] alu_w1;
    logic[31:0] alu_w2;
    wire[31:0] alu_preinit_result;
    logic[31:0] alu_result;

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

    always_latch // TODO: why latch?
        unique case(currState)
            INSTR_FETCH: nextState = INCR_PC_CALC;
            INCR_PC_CALC: nextState = INCR_PC_STORE;
            INCR_PC_STORE: nextState = INSTR_DECODE;
            INSTR_DECODE:
            begin
                unique case(opCode)
                    LOAD: nextState = READ_MEMORY;
                    STORE: nextState = WRITE_MEMORY;
                    default: nextState = STORE_ALU_RESULT; // TODO: can be avoid by iimediate non-blocking assign?
                endcase
            end
            STORE_ALU_RESULT: nextState = INSTR_FETCH;
            READ_MEMORY: nextState = INSTR_FETCH;
            WRITE_MEMORY: nextState = INSTR_FETCH;
        endcase

    function [31:0] wordByAddr(input[31:0] addr);
        wordByAddr[0 +: 8] = mem[addr + 0];
        wordByAddr[8 +: 8] = mem[addr + 1];
        wordByAddr[16 +: 8] = mem[addr + 2];
        wordByAddr[24 +: 8] = mem[addr + 3];
    endfunction

    always_ff @(posedge clk)
        unique case(currState)
            INSTR_FETCH: instr <= wordByAddr(pc);
            INCR_PC_CALC: begin end
            INCR_PC_STORE: pc <= alu_result;
            INSTR_DECODE: begin end
            READ_MEMORY:
                register_file[rd] <= wordByAddr(alu_result);

            WRITE_MEMORY:
            begin
                c.mem[alu_result + 0] = register_file[rs2][0 +: 8];
                c.mem[alu_result + 1] = register_file[rs2][8 +: 8];
                c.mem[alu_result + 2] = register_file[rs2][16 +: 8];
                c.mem[alu_result + 3] = register_file[rs2][24 +: 8];
            end

            STORE_ALU_RESULT: register_file[rd] <= alu_result;
        endcase

    assign alu_preinit_result = (currState == INSTR_FETCH || currState == INCR_PC_CALC) ? pc : 0;

    wire signed[31:0] imm_word;
    wire AluMode imm_aluMode;
    wire imm_isNegative;
    ImmediateValueFormatter ivf(.immediate_value, .word(imm_word), .aluMode(imm_aluMode), .isNegative(imm_isNegative));

    always_comb
        unique case(currState)
            INSTR_FETCH:
            begin
                aluMode = DISABLED;
            end

            INCR_PC_CALC:
            begin
                alu_w1 = pc;
                alu_w2 = 4; // PC increment value
                aluMode = INCREMENT;
            end

            INCR_PC_STORE: aluMode = DISABLED;

            INSTR_DECODE:
            unique case(opCode)
                OP_IMM: begin
                    alu_w1 = register_file[rs1];
                    alu_w2 = imm_word;
                    aluMode = imm_aluMode;
                end

                LOAD: begin
                    unique case(instr.ip.ri.funct3.width)
                        BITS32: begin
                            // Calc mem address:
                            alu_w1 = register_file[rs1];
                            alu_w2 = imm_word;
                            aluMode = imm_aluMode;
                            word2_is_signed_and_negative = imm_isNegative;
                        end

                        default: begin end // FIXME: remove this line
                    endcase
                end

                STORE: begin
                    unique case(instr.ip.ri.funct3.width)
                        BITS32: begin
                            // Calc mem address:
                            alu_w1 = register_file[rs1];
                            alu_w2 = imm_word;
                            aluMode = imm_aluMode;
                        end

                        default: begin end // FIXME: remove this line
                    endcase
                end

                default: begin // FIXME: remove this line
                    aluMode = DISABLED;
                end
            endcase

            READ_MEMORY:
            begin
                aluMode = DISABLED;
            end

            default:
            begin
                aluMode = DISABLED;
            end
        endcase
endmodule

// Formats ALU arguments for using 11 bit signed immediate value
module ImmediateValueFormatter
    (
        input wire[11:0] immediate_value,
        output wire AluMode aluMode,
        output wire isNegative,
        output wire signed[31:0] word
    );

    assign isNegative = immediate_value[11];
    assign aluMode = BITS_12_SIGNED;
    assign word = 32'(immediate_value);
endmodule

module control_test;
    logic clk;
    control c(clk);

    logic[31:0] rom[] =
    {
        //~ 32'b00000111101100000000001010010011, // addi x5, x0, 123
        //~ 32'b00000000001000101000001100010011, // addi x6, x5, 2
        //~ 32'b00000000010100101010001110000011, // lw x7, 5(x5)
        //~ 32'b11111110011100110010111100100011, // sw x7, -2(x6)
        32'b10000000000000000000010010010011, // addi x9, x0, 0x800 (-2048)
        32'b00000000000000000000000001110011 // ecall/ebreak
    };

    initial begin
        c.pc = 'haef; // First instruction leads carry on PC calculation

        c.mem[128] = 88; // for lw command check

        foreach(rom[i])
        begin
            int n = i*4 + c.pc;

            c.mem[n + 0] = rom[i][0 +: 8];
            c.mem[n + 1] = rom[i][8 +: 8];
            c.mem[n + 2] = rom[i][16 +: 8];
            c.mem[n + 3] = rom[i][24 +: 8];
        end

        $monitor("clk=%b state=%h nibb=%h perm=%b busy=%b alu_ret=%h d1=%h d2=%h carry=(%b %b) pc=%h inst=%h opCode=%b rs1=%h(%h) rs2=%h(%h) rd=%h(%h) imm=(%d %h)",
            clk, c.currState, c.l.curr_nibble_idx, c.l.loop_perm_to_count,
            c.alu_busy, c.alu_result, c.l.alu_args.d1, c.l.alu_args.d2,
            c.l.result_carry, c.l.ctrl.ctrl.carry_in, c.pc, c.instr,
            c.opCode,
            c.register_file[c.rs1], c.rs1,
            c.register_file[c.rs2], c.rs2,
            c.register_file[c.rd], c.rd,
            c.imm_word, c.imm_word);

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

        //~ assert(c.register_file[5] == 123); else $error(c.register_file[5]);
        //~ assert(c.register_file[6] == 125); else $error(c.register_file[6]);

        // Check lw command:
        //~ assert(c.register_file[7] == 88); else $error(c.register_file[7]);

        // Check sw command:
        //~ assert(c.mem[123] == 88); else $error(c.mem[123]);

        // addi with negative arg
        assert(c.register_file[9] == -2048); else $error("%d %h", $signed(c.register_file[9]), c.register_file[9]);
    end

endmodule
