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
        output logic[31:0] result
    );

    localparam CNT_SIZE = 3;
    logic[CNT_SIZE-1:0] curr_nibble_idx;
    logic reset; //TODO: ?

    counter #(CNT_SIZE) nibble_counter(reset, clk, curr_nibble_idx);

    wire[3:0] d1;
    wire[3:0] d2;
    bit carry;
    AluCtrl ctrl;
    wire[3:0] nibble_ret;

    // All MUXes can be implemented with one selector driver
    nibble_mux mux1(word1, curr_nibble_idx, d1);
    nibble_mux mux2(word2, curr_nibble_idx, d2);

    alu a(.carry_out(carry), .res(nibble_ret), .*);

    wire[31:0] ret_unstored;
    nibble_demux nibble_set(result, curr_nibble_idx, nibble_ret, ret_unstored);

    always_ff @(posedge clk)
        result <= ret_unstored;

endmodule

module loopOverAllNibbles_test;
    logic clk;
    logic[31:0] word1;
    logic[31:0] word2;
    logic[31:0] result;

    loopOverAllNibbles l(.*);

    initial begin
        $monitor("clk=%b w1=%h w2=%h nibble_num=%h d1=%b d2=%b alu.ret=%b result=%h %b", clk, word1, word2, l.curr_nibble_idx, l.d1, l.d2, l.nibble_ret, result, result);

        clk = 0;
        word1 = 32'h_efff_ffff;
        word2 = 1;

        repeat (16) begin
            #1
            clk = ~clk;
        end
    end
endmodule

module nibble_mux
    (
        input wire[31:0] word,
        input wire[2:0] select,
        output logic[3:0] nibble
    );

    // To avoid offset calculation of each nibble in "case" block
    for(genvar i = 0; i <= 7; i++) begin: muxed
        wire[3:0] src = word[i*4+3:i*4];
    end

    always_comb
        unique case(select)
            0: nibble = muxed[0].src;
            1: nibble = muxed[1].src;
            2: nibble = muxed[2].src;
            3: nibble = muxed[3].src;
            4: nibble = muxed[4].src;
            5: nibble = muxed[5].src;
            6: nibble = muxed[6].src;
            7: nibble = muxed[7].src;
        endcase
endmodule

module nibble_demux
    (
        input wire[31:0] in,
        input wire[2:0] select,
        input wire[3:0] nibble,
        output logic[31:0] ret
    );

    // To avoid offset calculation of each nibble in "case" block
    for(genvar i = 0; i <= 7; i++) begin: muxed
        wire[31:0] r;

        if(i > 0)
            assign r[i*4-1:0] = in[i*4-1:0];

        assign r[i*4+3:i*4] = nibble;

        if(i < 7)
            assign r[31:i*4+4] = in[31:i*4+4];
    end

    always_comb
        unique case(select)
            0: ret = muxed[0].r;
            1: ret = muxed[1].r;
            2: ret = muxed[2].r;
            3: ret = muxed[3].r;
            4: ret = muxed[4].r;
            5: ret = muxed[5].r;
            6: ret = muxed[6].r;
            7: ret = muxed[7].r;
        endcase
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
