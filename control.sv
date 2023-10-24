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
        input wire start,
        input wire reverse_direction, // reverse means from MSB to LSB
        ref wire AluCtrl ctrl,
        input wire[31:0] word1,
        input wire[31:0] word2,
        output wire is_latest,
        output logic[31:0] result
    );

    localparam CNT_SIZE = 3;
    logic[CNT_SIZE-1:0] curr_nibble_idx;

    nibble_counter #(CNT_SIZE) nibble_counter(
        clk,
        start,
        reverse_direction,
        is_latest,
        curr_nibble_idx
    );

    wire[3:0] d1;
    wire[3:0] d2;
    wire carry_out;
    wire[3:0] nibble_ret;

    // All MUXes can be implemented with one selector driver
    nibble_mux mux1(word1, curr_nibble_idx, d1);
    nibble_mux mux2(word2, curr_nibble_idx, d2);

    alu a(.res(nibble_ret), .*);

    wire[31:0] ret_unstored;
    nibble_demux nibble_set(result, curr_nibble_idx, nibble_ret, ret_unstored);

    always_ff @(posedge clk) begin
        result <= ret_unstored;
        ctrl.ctrl.carry_in <= reverse_direction ? d2[0] : carry_out;
    end

endmodule

module loopOverAllNibbles_test;
    localparam RSH_VAL = 32'h_0600_0000;

    logic clk;
    logic start;
    AluCtrl ctrl;
    logic reverse_direction;
    logic[31:0] word1;
    logic[31:0] word2;
    logic[31:0] result;
    wire is_latest;
    logic loopIsDone;

    loopOverAllNibbles l(.*);

    task loop_one_word
        (
            input AluCmd cmd,
            input[31:0] w1,
            input[31:0] w2
        );

        $monitor("clk=%b reverse=%b start=%b idx=%h result=%h latest_nibble=%b done=%b", clk, reverse_direction, start, l.curr_nibble_idx, result, is_latest, loopIsDone);

        $display("cycle started");

        reverse_direction = (cmd == RSHFT) ? 1 : 0;
        word1 = w1;
        word2 = w2;

        result = 0;
        ctrl = 0;
        ctrl.cmd = cmd;

        //~ start = 1;
        //~ clk = 0;
        //~ #1
        //~ clk = 1;
        //~ #1
        //~ start = 0;
        //~ clk = 0;

        //~ $display("init of cycle is done");

        while(~is_latest) begin
            loopIsDone = is_latest;
            #1
            clk = ~clk;
        end

        $display("while cycle is done");

        #1
        clk = 0;

        #1
        clk = 1;

        #1
        clk = 0;

        $display("FULL cycle is done");
    endtask

    initial begin
        loop_one_word(ADD, 'h_efff_ffff, 1);
        assert(result == 'h_f000_0000); else $error("result=%b", result);

        start = 1;
        #1
        clk = 1;
        #1
        clk=0;
        start = 0;

        loop_one_word(ADD, 'h_ffff_0fff, 2);
        assert(result == 'h_ffff_1001);

        //~ loop_one_word(RSHFT, 'h_xxxx_xxxx, RSH_VAL);
        //~ assert(result == RSH_VAL >> 1); else $error("word2=%b result=%b must be=%b", word2, result, RSH_VAL >> 1);
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
