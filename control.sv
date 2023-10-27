module control
    (
        input wire clk
    );

    logic[31:0] pc;
    logic[31:0] register_file[32]; //TODO: x0 register must be zero
    logic[7:0][31:0] mem;
    Instruction instr;
    wire OpCode opCode;
    wire DecodedAluCmd aluCmd;
    wire signed[11:0] jumpAddr;
    wire[11:0] immutable_value;
    wire RegAddr rs1;
    wire RegAddr rs2;
    wire RegAddr rd;
    logic[31:0] unsaved_result;

    instr_decoder idc(
            .source_register_1(rs1),
            .source_register_2(rs2),
            .register_out_addr(rd),
            .*
        );

    always_comb
        unique case(opCode)
            OP_IMM: begin
                unsaved_result = register_file[rs1] + 32'(immutable_value); // FIXME: use ALU instead of "plus"
            end

            LOAD: begin
                unique case(instr.ip.ri.funct3.width)
                    BITS32: unsaved_result = mem[register_file[rs1]] + 32'(immutable_value); // FIXME: use ALU instead of "plus"

                    default: begin end // FIXME: remove this line
                endcase
            end

            default: begin
            end
        endcase

    always_ff @(posedge clk) begin
        instr <= mem[pc];
        //~ pc <= pc+2;
        register_file[rd] <= unsaved_result;
    end

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

        $monitor("clk=%b pc=%h inst=%h opCode=%b rs1=%h internal_imm=%h imm=%h uns_ret=%h", clk, c.pc, c.instr, c.opCode, c.rs1, c.instr.ip.ri.imm11, c.immutable_value, c.unsaved_result);
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

        repeat (10) #1 clk = ~clk;
    end

endmodule
