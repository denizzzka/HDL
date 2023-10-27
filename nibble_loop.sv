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

        //~ $monitor("clk=%b reverse=%b start=%b idx=%h ctrl=%b d1=%h d2=%h nibble_ret=%h result=%h latest_nibble=%b done=%b",
            //~ clk, reverse_direction, start, l.curr_nibble_idx, ctrl, l.d1, l.d2, l.nibble_ret, result, is_latest, loopIsDone);

        //~ $display("cycle started");

        assert(clk == 0);

        reverse_direction = (cmd == RSHFT) ? 1 : 0;
        start = 1;
        word1 = w1;
        word2 = w2;

        result = 0;
        ctrl = 0;
        ctrl.cmd = cmd;

        //~ $display("cmd assigned");

        #1
        clk = 1;
        #1
        start = 0;
        ctrl.ctrl.carry_in = 0;
        clk=0;

        //~ $display("init of cycle is done");

        while(~is_latest) begin
            loopIsDone = is_latest;
            #1
            clk = ~clk;
        end

        //~ $display("while cycle is done");

        #1
        clk = 0;

        #1
        clk = 1;

        #1
        clk = 0;

        //~ $display("FULL cycle is done");
    endtask

    initial begin
        loop_one_word(ADD, 'h_efff_ffff, 1);
        assert(result == 'h_f000_0000); else $error("result=%b", result);

        loop_one_word(ADD, 'h_ffff_0fff, 2);
        assert(result == 'h_ffff_1001);

        loop_one_word(RSHFT, 'h_xxxx_xxxx, RSH_VAL);
        assert(result == RSH_VAL >> 1); else $error("word2=%b result=%b must be=%b", word2, result, RSH_VAL >> 1);
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
