module control
    (
        input wire clk
    );

    logic[31:0] pc;
    logic[31:0] registers[32];
    logic[31:0] mem[2048];
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

    initial begin
        $monitor("clk=%b pc=%h", clk, c.pc);
        //~ $readmemh("instr.txt", c.mem);
        //~ $dumpfile("control_test.vcd");
        //~ $dumpvars(0, control_test);

        clk = 0;

        repeat (10) #1 clk = ~clk;
    end

endmodule
