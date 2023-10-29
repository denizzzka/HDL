typedef enum logic[2:0] {
    INSTR_FETCH,
    INCR_PC_CALC, // TODO: join with INSTR_FETCH
    INCR_PC_STORE,
    INSTR_DECODE,
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

module control
    (
        input wire clk
    );

    logic[31:0] pc; // TODO: wire it to register file
    logic[31:0] register_file[32]; //TODO: x0 register must be zero
    logic[7:0][31:0] mem;

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
    wire[31:0] immutable_value;
    wire RegAddr rs1;
    wire RegAddr rs2;
    wire RegAddr rd;

    instr_stencil i_s(
            .source_register_1(rs1),
            .source_register_2(rs2),
            .register_out_addr(rd),
            .*
        );

    AluCtrl alu_ctrl;
    logic[31:0] alu_w1;
    logic[31:0] alu_w2;
    logic[31:0] alu_result;

    loopOverAllNibbles l(
        .clk,
        .ctrl(alu_ctrl),
        .word1(alu_w1),
        .word2(alu_w2),
        .result(alu_result),
        .perm_to_count(alu_perm_to_count),
        .busy(alu_busy)
    );

    always_latch // TODO: why latch?
        unique case(currState)
            INSTR_FETCH: nextState = INCR_PC_CALC;
            INCR_PC_CALC: nextState = INCR_PC_STORE;
            INCR_PC_STORE: nextState = INSTR_DECODE;
            INSTR_DECODE: nextState = READ_MEMORY;
            READ_MEMORY: nextState = STORE_ALU_RESULT; // FIXME
            WRITE_MEMORY: nextState = STORE_ALU_RESULT; // FIXME
            STORE_ALU_RESULT: nextState = INSTR_FETCH;
        endcase

    always_ff @(posedge clk)
        unique case(currState)
            INSTR_FETCH: instr <= mem[pc];
            INCR_PC_CALC: begin end
            INCR_PC_STORE: pc <= alu_result;
            INSTR_DECODE: begin end
            READ_MEMORY: begin end
            WRITE_MEMORY: begin end
            STORE_ALU_RESULT: register_file[rd] <= alu_result;
        endcase

    always_comb
        unique case(currState)
            INSTR_FETCH: need_alu = 0;

            INCR_PC_CALC:
            begin
                alu_w1 = pc;
                alu_w2 = 1;
                need_alu = 1;
            end

            INCR_PC_STORE: need_alu = 0;

            INSTR_DECODE:
            //TODO: move need_alu to here?
            unique case(opCode)
                OP_IMM: begin
                    alu_w1 = register_file[rs1];
                    alu_w2 = immutable_value;
                    need_alu = 1;
                end

                LOAD: begin
                    need_alu = 1;

                    unique case(instr.ip.ri.funct3.width)
                        //TODO: add ability to loop only over 1 and 2 bytes
                        BITS32: begin
                            alu_w1 = mem[register_file[rs1]];
                            alu_w2 = immutable_value;
                        end

                        default: begin end // FIXME: remove this line
                    endcase
                end

                default: begin // FIXME: remove this line
                    need_alu = 0;
                end
            endcase

            default: begin end
        endcase
endmodule

module control_test;
    logic clk;
    control c(clk);

    logic[31:0] rom[] =
    {
        32'b00000111101100000000001010010011, // addi x5, x0, 123
        32'b00000000010100101010001100000011, // lw x6, 5(x5)
        32'b00000000001000001000000110110011, // add  x3, x1, x2
        32'b00000111101100001000000110010011, // addi x3, x1, 123
        32'h00000000
    };

    initial begin
        foreach(rom[i])
            c.mem[i] = rom[i];

        $monitor("clk=%b state=%h nibb=%h perm=%b busy=%b pc=%h inst=%h opCode=%b rs1=%h internal_imm=%h imm=%h alu_ret=%h",
            clk, c.currState, c.l.curr_nibble_idx, c.alu_perm_to_count, c.alu_busy, c.pc, c.instr, c.opCode, c.rs1, c.instr.ip.ri.imm11, c.immutable_value, c.alu_result);
        //~ $readmemh("instr.txt", c.mem);
        //~ $dumpfile("control_test.vcd");
        //~ $dumpvars(0, control_test);

        //~ clk = 0;
        //~ #1
        //~ clk = 1;
        //~ #1
        //~ clk = 0;
        //~ #1
        //~ clk = 1;
        //~ assert(c.mem[5] == 123); else $error(c.mem[5]);

        repeat (45) #1 clk = ~clk;
    end

endmodule
