// Loops ALU calculations over all nibbles
module loopOverAllNibbles
    (
        input wire clk,
        input wire loop_perm_to_count, // otherwise - reset
        input wire loop_over_one_nibble, // for PC increment
        ref wire AluCtrl ctrl,
        input wire[7:0][3:0] word1,
        input wire[7:0][3:0] word2,
        input wire[31:0] preinit_result,
        output wire busy,
        output wire[7:0][3:0] result
    );

    localparam CNT_SIZE = 3;

    // "reverse" means from MSB to LSB
    wire reverse_direction;
    assign reverse_direction = (ctrl.cmd == RSHFT) ? 1 : 0;
    wire[CNT_SIZE-1:0] alu_arg2_width = 'b111; //TODO: zero means that ALU not needed?
    logic[CNT_SIZE-1:0] curr_nibble_idx;
    wire is_latest;
    logic perm_to_count;
    assign busy = perm_to_count && (~is_latest);

    always_comb
        if(loop_over_one_nibble && curr_nibble_idx != 0)
            perm_to_count = result_carry || ctrl.ctrl.carry_in;
        else
            perm_to_count = loop_perm_to_count;

    nibble_counter #(CNT_SIZE) nibble_counter(
        clk,
        perm_to_count,
        alu_arg2_width,
        reverse_direction,
        is_latest,
        curr_nibble_idx
    );

    wire AluArgs alu_args;
    wire AluRet alu_ret;
    assign alu_args.ctrl = ctrl;

    alu a(.args(alu_args), .ret(alu_ret));

    // All MUXes can be implemented with one selector driver
    assign alu_args.d1 = word1[curr_nibble_idx];
    assign alu_args.d2 = word2[curr_nibble_idx];

    wire result_carry = reverse_direction ? alu_args.d2[0] : alu_ret.carry_out;

    always_ff @(posedge clk) begin
        if(~loop_perm_to_count)
            result <= preinit_result;
        else begin
            result[curr_nibble_idx] <= alu_ret.res;
            ctrl.ctrl.carry_in <= result_carry;
        end
    end

endmodule

module loopOverAllNibbles_test;
    localparam RSH_VAL = 32'h_0600_0000;

    logic clk;
    logic loop_perm_to_count;
    logic loop_over_one_nibble;
    AluCtrl ctrl;
    logic[31:0] word1;
    logic[31:0] word2;
    wire[31:0] preinit_result = 'h_f000_0000;
    logic[31:0] result;
    wire busy;

    loopOverAllNibbles l(.*);

    task loop_one_word
        (
            input AluCmd cmd,
            input[31:0] w1,
            input[31:0] w2
        );

        //~ $monitor("clk=%b reverse=%b perm_to_count=%b idx=%h ctrl=%b d1=%h d2=%h nibble_ret=%h result=%h busy=%b",
            //~ clk, l.reverse_direction, perm_to_count, l.curr_nibble_idx, ctrl, l.d1, l.d2, l.nibble_ret, result, busy);

        //~ $display("cycle started");

        assert(clk == 0);

        #1
        word1 = w1;
        word2 = w2;

        result = 0;
        ctrl = 0;
        ctrl.cmd = cmd;

        loop_perm_to_count = 0;

        #1
        clk = 1;
        #1
        clk = 0;
        ctrl.ctrl.carry_in = 0;
        loop_perm_to_count = 1;

        //~ $display("cmd assigned");

        #1
        clk = 1;
        #1
        clk=0;

        //~ $display("init of cycle is done");

        while(busy) begin
            #1
            clk = ~clk;
        end

        assert(clk == 0);

        #1
        clk = 1;
        #1
        clk = 0;

        //~ $display("while cycle is done");
    endtask

    initial begin
        loop_one_word(ADD, 'h_0eff_ffff, 1);
        assert(result == 'h_0f00_0000); else $error("result=%h", result);

        loop_one_word(ADD, 'h_ffff_0fff, 2);
        assert(result == 'h_ffff_1001);

        loop_one_word(ADD, 'h_0000_0002, -3);
        assert(result == -1); else $error("result=%d", $signed(result));

        loop_one_word(RSHFT, 'h_xxxx_xxxx, RSH_VAL);
        assert(result == RSH_VAL >> 1); else $error("word2=%b result=%b must be=%b", word2, result, RSH_VAL >> 1);
    end
endmodule
