import alu_::AluCmd;

typedef enum logic[6:0] {
    OP_IMM = 7'b0010011, // Integer Register-Immediate Instructions
    OP     = 7'b0110011 // Integer Register-Register Operations
} OpCode;

typedef logic[4:0] RegAddr;

typedef struct packed
{
    logic[11:0] imm11;
    RegAddr source_register_1; // rs1
    logic[2:0] functor; // func3
    RegAddr dest_register; // rd
} RegisterImmediateInstr;

typedef struct packed
{
    logic[6:0] funct7;
    RegAddr source_register_2; // rs2
    RegAddr source_register_1; // rs1
    logic[2:0] functor; // func3
    RegAddr dest_register; // rd
} RegisterRegisterInstr;

typedef union packed
{
    RegisterImmediateInstr ri;
    RegisterRegisterInstr rr;
} InstructionPayload;

typedef struct packed
{
    InstructionPayload ip;
    OpCode opCode;
} Instruction;

module instr_decoder
    (
        input Instruction instr,
        output AluCmd aluCmd,
        output RegAddr source_register_1,
        output RegAddr source_register_2,
        output RegAddr register_out_addr
    );

    always_comb
        unique case(instr.ip.rr.functor)
            3'b000: aluCmd = ADD;
            3'b001: aluCmd = AND; //FIXME // SLL
            3'b010: aluCmd = AND; //FIXME // SLT
            3'b011: aluCmd = AND; //FIXME // SLTU
            3'b100: aluCmd = XOR;
            3'b101: aluCmd = AND; //FIXME // SRL / SRA (logical right shift / arithmetic right shift (the original sign bit is copied into the vacated upper bits)
            3'b110: aluCmd = OR;
            3'b111: aluCmd = AND;
        endcase

    always_comb
        unique case(instr.opCode)
            OP_IMM: begin
                source_register_1 = instr.ip.ri.source_register_1;
                register_out_addr = instr.ip.ri.dest_register;
            end
            OP: begin
                register_out_addr = instr.ip.rr.dest_register;
            end

            default: register_out_addr = 'x /* FIXME: add handling for unknown opcodes */;
        endcase

endmodule

module instr_decoder_test;
    logic[31:0] registers[32];
    Instruction instr;
    AluCmd aluCmd;
    RegAddr reg_addr1;
    RegAddr reg_addr2;
    RegAddr reg_dst;
    logic[31:0] ret;

    instr_decoder decoder(
        instr,
        aluCmd,
        reg_addr1,
        reg_addr2,
        reg_dst
    );

    initial begin
        $monitor("instr=%b reg_addr=%0d", instr, reg_dst);

        instr.ip.ri.dest_register = 2;
        instr.ip.ri.imm11 = 123;
        instr.opCode = OP_IMM;

        for(logic[2:0] func3 = 0; func3 < 'b111; func3++) begin
            #1
            instr.ip.ri.functor = func3;
        end

        instr.opCode = OP;
    end

endmodule
