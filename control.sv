module control
    (
        input wire clk
    );

    logic[31:0] pc;
    logic[31:0] registers[32]; //TODO: x0 register must be zero
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

module loopOverAllNibbles
    (
        input wire clk,
        input wire[31:0] word1,
        input wire[31:0] word2,
        output wire[31:0] result
    );

    localparam CNT_SIZE = 3;
    logic[CNT_SIZE-1:0] curr_nibble;
    logic reset;

    counter #(CNT_SIZE) nibble_counter(reset, clk, curr_nibble);

    logic[3:0] d1;
    logic[3:0] d2;
    bit carry_in;
    logic carry_out;
    AluCtrl ctrl;
    wire[3:0] res;

    alu a(.*);

    for(genvar i = 0; i <= 7; i++) begin: muxed
        wire[3:0] src1 = word1[i*4+3:i*4];
        wire[3:0] src2 = word2[i*4+3:i*4];
        wire[3:0] dst;

        assign result[i*4+3:i*4] = dst;
    end

    // MUX
    always_comb
        unique case(curr_nibble)
            0: begin; d1 = muxed[0].src1; d2 = muxed[0].src2; muxed[0].dst = res; end
            1: begin; d1 = muxed[1].src1; d2 = muxed[1].src2; muxed[1].dst = res; end
            2: begin; d1 = muxed[2].src1; d2 = muxed[2].src2; muxed[2].dst = res; end
            3: begin; d1 = muxed[3].src1; d2 = muxed[3].src2; muxed[3].dst = res; end
            4: begin; d1 = muxed[4].src1; d2 = muxed[4].src2; muxed[4].dst = res; end
            5: begin; d1 = muxed[5].src1; d2 = muxed[5].src2; muxed[5].dst = res; end
            6: begin; d1 = muxed[6].src1; d2 = muxed[6].src2; muxed[6].dst = res; end
            7: begin; d1 = muxed[7].src1; d2 = muxed[7].src2; muxed[7].dst = res; end
        endcase
endmodule

module loopOverAllNibbles_test;
    logic clk;
    logic[31:0] word1;
    logic[31:0] word2;
    logic[31:0] result;

    loopOverAllNibbles l(.*);

    initial begin
        $monitor("clk=%b w1=%h w2=%h nibble_num=%h result=%h %b", clk, word1, word2, l.curr_nibble, result, result);

        clk = 0;
        word1 = 'hfffe;
        word2 = 1;

        repeat (20) begin
            #1
            clk = ~clk;
        end
    end
endmodule

module counter
    #(parameter WIDTH)
    (
        input wire reset,
        input wire clk,
        output logic[WIDTH-1:0] val
    );

    always_ff @(posedge clk)
        val++;

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
