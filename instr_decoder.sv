import alu_::AluCmd;

typedef enum logic[4:0] {
    LOAD   = 5'b00000, // Load Instructions
    STORE  = 5'b01000, // Store Instructions
    OP_IMM = 5'b00100, // Integer Register-Immediate Instructions
    OP     = 5'b01100, // Integer Register-Register Operations
    LUI    = 5'b01101, // Load Upper Immediate
    AUIPC  = 5'b00101, // Add Upper Immediate To PC
    BRANCH = 5'b11000, // Conditional Branches
    JAL    = 5'b11011, // Jump And Link
    JALR   = 5'b11001, // Jump And Link Register
    SYSTEM = 5'b11100  // Environment Call and Breakpoints
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

typedef struct packed
{
    logic[6:0] imm;
    RegAddr source_register_2; // rs2
    RegAddr source_register_1; // rs1
    logic[2:0] functor; // func3
    RegAddr dest_register; // rd
} StoreInstr;

typedef struct packed
{
    logic sign;
    logic[5:0] offset_HighestPart;
    RegAddr source_register_2; // rs2
    RegAddr source_register_1; // rs1
    logic[2:0] functor; // func3
    logic[3:0] offset_LowestPart;
    logic offset_MSB; // 0xef00 (3840 decimal) will be encoded as 0b0_1110000000_1
} BranchingInstr;

typedef union packed
{
    RegisterImmediateInstr ri;
    RegisterRegisterInstr rr;
    BranchingInstr b;
} InstructionPayload;

typedef struct packed
{
    InstructionPayload ip;
    OpCode opCode;
    logic[1:0] unused_always11;
} Instruction;

class en;
    typedef enum logic[2:0] {
        ADD  =3'b000,
        SLL  =3'b001,
        SLT  =3'b010,
        SLTU =3'b011,
        XOR  =3'b100,
        SRLA =3'b101, // SRL / SRA (logical right shift / arithmetic right shift (the original sign bit is copied into the vacated upper bits)
        OR   =3'b110,
        AND  =3'b111
    } RiscV_Spec_AluCmd;
endclass;

typedef struct packed {
    AluCmd cmd;
    logic isUnsignedCompOrLeftShift;
} DecodedAluCmd;

module instr_decoder
    (
        input Instruction instr,
        output OpCode opCode,
        output DecodedAluCmd aluCmd,
        output RegAddr source_register_1,
        output RegAddr source_register_2,
        output logic signed[11:0] jumpAddr,
        output RegAddr register_out_addr
    );

    assign opCode = instr.opCode;

    always_comb
        unique case(en::RiscV_Spec_AluCmd'(instr.ip.rr.functor))
            en::ADD:  aluCmd.cmd = ADD;
            en::SLL:  aluCmd.cmd = ADD;
            en::SLT:  aluCmd.cmd = COMP;
            en::SLTU: aluCmd.cmd = COMP;
            en::XOR:  aluCmd.cmd = XOR;
            en::SRLA: aluCmd.cmd = RSHFT;
            en::OR:   aluCmd.cmd = OR;
            en::AND:  aluCmd.cmd = AND;
        endcase

    assign aluCmd.isUnsignedCompOrLeftShift = instr.ip.rr.functor[0];

    assign jumpAddr = {
            instr.ip.b.sign,
            instr.ip.b.offset_MSB,
            instr.ip.b.offset_HighestPart,
            instr.ip.b.offset_LowestPart
        };

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
    OpCode opCode;
    DecodedAluCmd aluCmd;
    RegAddr reg_addr1;
    RegAddr reg_addr2;
    RegAddr reg_dst;
    logic signed[11:0] jumpAddr;
    logic[31:0] ret;

    instr_decoder decoder(
        .source_register_1(reg_addr1),
        .source_register_2(reg_addr2),
        .register_out_addr(reg_dst),
        .*
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
