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

typedef enum logic[1:0] {
    BITS8 =  'b00,
    BITS16 = 'b01,
    BITS32 = 'b10,
    ERRVAL = 'b11
} LoadStoreResultWidth;

typedef struct packed
{
    logic isSigned;
    LoadStoreResultWidth width;
} FunctLoad;

typedef struct packed
{
    logic[11:0] imm11;
    RegAddr source_register_1; // rs1
    union packed
    {
        logic[2:0] funct3;
        FunctLoad load;
    } funct3;
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
    logic[6:0] imm2;
    RegAddr source_register_2; // rs2
    RegAddr source_register_1; // rs1
    logic unused_must_be_zero; //TODO: add error check
    LoadStoreResultWidth width;
    logic[4:0] imm1;
} StoreInstr;

typedef struct packed
{
    logic[19:0] immediate_value20;
    RegAddr rd;
} UpperImmediateInstr;

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
    StoreInstr s;
    UpperImmediateInstr u;
    BranchingInstr b;
} InstructionPayload;

typedef struct packed
{
    logic[6:0] funct7;
    RegAddr rs2;
    RegAddr rs1;
    logic[2:0] funct3;
    RegAddr rd;
    OpCode opCode;
    logic[1:0] unused_always11; // TODO: add check if not equal to 'b11
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
    AluCtrl ctrl;
    logic isUnsignedCompOrLeftShift;
} DecodedAluCmd;

typedef struct packed {
    logic[11:0] immediate_value12;
    logic[19:0] immediate_value20;
    logic isStoreFunct3msbEnabledError; // 14 bit of instruction can't be 1 for STORE instr
    LoadStoreResultWidth width;
} WiredDecisions;

module instr_stencil
    (
        input Instruction instr,
        output OpCode opCode,
        output DecodedAluCmd decodedAluCmd,
        output wire WiredDecisions decoded,
        output RegAddr source_register_1,
        output RegAddr source_register_2,
        output wire signed[11:0] immediate_value,
        output logic signed[11:0] jumpAddr, //TODO: remove?
        output RegAddr register_out_addr
    );

    assign opCode = instr.opCode;
    assign decoded.width = LoadStoreResultWidth'(instr.funct3[1:0]);

    always_comb
        unique case(en::RiscV_Spec_AluCmd'(instr.funct3))
            en::ADD:  decodedAluCmd.ctrl = ADD;
            en::SLL:  decodedAluCmd.ctrl = ADD;
            en::SLT:  decodedAluCmd.ctrl = COMP;
            en::SLTU: decodedAluCmd.ctrl = COMP;
            en::XOR:  decodedAluCmd.ctrl = XOR;
            en::SRLA: decodedAluCmd.ctrl = RSHFT;
            en::OR:   decodedAluCmd.ctrl = OR;
            en::AND:  decodedAluCmd.ctrl = AND;
        endcase

    assign decodedAluCmd.isUnsignedCompOrLeftShift = instr.funct3[0];

    always_comb
        unique case(instr.opCode)
            LOAD,
            OP_IMM:
            begin
                source_register_1 = instr.rs1;
                register_out_addr = instr.rd;
                immediate_value = { instr.funct7, instr.rs2 };
            end

            STORE:
            begin
                source_register_1 = instr.rs1;
                source_register_2 = instr.rs2;
                immediate_value = { instr.funct7, instr.rd };
            end

            default: register_out_addr = 'x /* FIXME: add handling for unknown opcodes */;
        endcase

endmodule
