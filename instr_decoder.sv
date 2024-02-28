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
    logic[23:0] immediate_jump;
    logic isStoreFunct3msbEnabledError; // 14 bit of instruction can't be 1 for STORE instr
    logic isLoadingSignedValue;
    LoadStoreResultWidth width;
} WiredDecisions;

module instr_stencil
    (
        input Instruction instr,
        output OpCode opCode,
        output DecodedAluCmd decodedAluCmd,
        output wire WiredDecisions decoded
    );

    assign opCode = instr.opCode;
    assign decoded.isLoadingSignedValue = instr.funct3[2];
    assign decoded.width = LoadStoreResultWidth'(instr.funct3[1:0]);
    assign decoded.immediate_value20 = instr[31:12];
    assign decoded.immediate_jump = { instr[31], instr[31], instr[31], instr[31], instr[19:12],  instr[20], instr[30:21], 1'b0 };

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
            OP_IMM,
            JALR: decoded.immediate_value12 = { instr.funct7, instr.rs2 };
            STORE: decoded.immediate_value12 = { instr.funct7, instr.rd };
            BRANCH: decoded.immediate_value12 = { instr.funct7[6], instr.rd[4], instr.funct7[5:0], instr.rd[4:1] }; //TODO: brrr!
            default: decoded.immediate_value12 = 'h_ded; /* FIXME: add handling for unknown opcodes */
        endcase

endmodule
