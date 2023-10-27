module control
    (
        input wire clk
    );

    logic[31:0] pc;
    logic[31:0] registers[32]; //TODO: x0 register must be zero
    logic[7:0][31:0] mem;
    logic[31:0] instr;
    wire OpCode opCode;
    wire DecodedAluCmd aluCmd;
    wire signed[11:0] jumpAddr;
    wire RegAddr rs1;
    wire RegAddr rs2;
    wire RegAddr rd;

    instr_decoder idc(
            .source_register_1(rs1),
            .source_register_2(rs2),
            .register_out_addr(rd),
            .*
        );

    always_ff @(posedge clk) begin
        instr <= mem[pc];
        pc <= pc+2;
    end

endmodule

module control_test;
    logic clk;
    control c(clk);

    logic[31:0] rom[] =
    {
        32'b00000000001000001000000110110011, // add  x3, x1, x2
        32'b00000111101100001000000110010011, // addi x3, x1, 123
        32'h00000000
    };

    initial begin
        foreach(rom[i])
            c.mem[i] = rom[i];

        $monitor("clk=%b pc=%h inst=%h", clk, c.pc, c.mem[c.pc]);
        //~ $readmemh("instr.txt", c.mem);
        //~ $dumpfile("control_test.vcd");
        //~ $dumpvars(0, control_test);

        clk = 0;

        repeat (10) #1 clk = ~clk;
    end

endmodule
