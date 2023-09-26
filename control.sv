import alu_::AluCmd;

typedef enum logic[6:0] {
    OP_IMM = 7'b0010011, // Integer Register-Immediate Instructions
    OP     = 7'b0110011 // Integer Register-Register Operations
} OpCode;

typedef logic[4:0] RegAddr;

typedef struct packed
{
    logic[11:0] immediate_value;
    RegAddr source_register_1; // rs1
    logic[2:0] functor; // func3
    RegAddr dest_register; // rd
} RegisterImmediateInstr;

typedef union packed
{
    RegisterImmediateInstr ri;
} InstructionPayload;

typedef struct packed
{
    InstructionPayload ip;
    OpCode opCode;
} Instruction;

module control
    (
        input Instruction instr,
        output AluCmd aluCmd,
        output RegAddr register_out_addr
    );

    always_comb
        unique case(instr.opCode)
            OP_IMM: begin
                register_out_addr = instr.ip.ri.dest_register;

                unique case(instr.ip.ri.functor)
                    3'b000: aluCmd = ADD; // ADDI
                    3'b001: ; // SLLI
                    3'b010: ; // SLTI
                    3'b011: ; // SLTIU
                    3'b100: aluCmd = XOR; // XORI
                    3'b101: ; // SRLI / SRAI (logical right shift / arithmetic right shift (the original sign bit is copied into the vacated upper bits)
                    3'b110: aluCmd = OR; // ORI
                    3'b111: aluCmd = AND; // ANDI
                endcase
            end

            default: register_out_addr = 'x /* FIXME: add handling for unknown opcodes */;
        endcase

endmodule

module control_test;
    logic[31:0] registers[32];
    Instruction instr;
    AluCmd aluCmd;
    RegAddr reg_addr;

    control c(instr, aluCmd, reg_addr);

    initial begin
        $monitor("instr=%b reg_addr=%0d", instr, reg_addr);

        instr.opCode = OP_IMM;
        instr.ip.ri.dest_register = 2;
        instr.ip.ri.immediate_value = 12;

        #1
        instr.opCode = OP;
    end

endmodule
