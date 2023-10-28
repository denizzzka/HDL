typedef enum {
    INSTR_DECODE,
    ADD_IMMUTABLE,
    //~ INCR_PC,
    STORE_RESULT
} ControlState;

module CtrlStateFSM
    (
        input wire clk,
        input wire need_add_immutable,
        input wire immutable_added,
        output ControlState currState
    );

    always_ff @(posedge clk)
        unique case(currState)
            INSTR_DECODE:
                if(need_add_immutable)
                    currState <= ADD_IMMUTABLE;

            ADD_IMMUTABLE:
                if(immutable_added)
                    currState <= STORE_RESULT;

            STORE_RESULT:
                currState <= INSTR_DECODE;
        endcase
endmodule

module control
    (
        input wire clk
    );

    logic[31:0] pc;
    logic[31:0] register_file[32]; //TODO: x0 register must be zero
    logic[7:0][31:0] mem;

    ControlState currState;
    logic need_add_immutable;
    wire immutable_added = ~busy;
    CtrlStateFSM ctrlStateFSM(.*);

    Instruction instr;
    wire OpCode opCode;
    wire DecodedAluCmd decodedAluCmd;
    wire signed[11:0] jumpAddr;
    wire[31:0] immutable_value;
    wire RegAddr rs1;
    wire RegAddr rs2;
    wire RegAddr rd;

    instr_decoder idc(
            .source_register_1(rs1),
            .source_register_2(rs2),
            .register_out_addr(rd),
            .*
        );

    wire perm_to_count = (currState == ADD_IMMUTABLE) ? 1 : 0;
    AluCtrl alu_ctrl;
    logic[31:0] alu_w1;
    logic[31:0] alu_w2;
    wire busy;
    logic[31:0] result; // TODO: rename to alu_result

    loopOverAllNibbles l(.ctrl(alu_ctrl), .word1(alu_w1), .word2(alu_w2), .*);

    always_comb
        unique case(opCode)
            OP_IMM: begin
                alu_w1 = register_file[rs1];
                alu_w2 = immutable_value;
                need_add_immutable = 1;
            end

            LOAD: begin
                need_add_immutable = 1;

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
                need_add_immutable = 0;
            end
        endcase

    always_ff @(posedge clk) begin
        instr <= mem[pc];
        //~ pc <= pc+2;
        //~ register_file[rd] <= result;
    end

    always_ff @(posedge clk)
        unique case(currState)
            INSTR_DECODE: begin end
            ADD_IMMUTABLE: begin end
            STORE_RESULT: register_file[rd] <= result;
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

        $monitor("clk=%b state=%h nibb=%h pc=%h inst=%h opCode=%b rs1=%h internal_imm=%h imm=%h ret=%h", clk, c.currState, c.l.curr_nibble_idx, c.pc, c.instr, c.opCode, c.rs1, c.instr.ip.ri.imm11, c.immutable_value, c.result);
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

        repeat (20) #1 clk = ~clk;
    end

endmodule
