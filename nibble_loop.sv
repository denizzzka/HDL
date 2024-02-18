// Loops ALU calculations over all nibbles
module loopOverAllNibbles
    (
        input wire clk,
        //TODO: rename:
        input wire loop_perm_to_count, // otherwise - reset
        input wire[2:0] loop_nibbles_number,
        ref wire AluCtrl ctrl,
        //TODO: rename to "is signed and negative"
        input wire word2_is_negative, // useful for SUB on signed values shorter than 8 nibbles
        input wire[7:0][3:0] word1, //TODO: remove in favor to preinit_result value?
        input wire[7:0][3:0] word2,
        input wire[31:0] preinit_result,
        output wire busy,
        output wire[7:0][3:0] result
    );

    // "reverse" means from MSB to LSB
    wire reverse_direction = (ctrl.cmd == RSHFT) ? 1 : 0;
    wire[3:0] reset_val = reverse_direction ? 4'(loop_nibbles_number) : 0;

    logic[3:0] counter; // contains additional overflow control bit
    wire[2:0] curr_nibble_idx = counter[2:0];

    //TODO: move overflow bit to outside to share this flag with another module?
    wire overflow = counter[3];

    // Last nibble without considering possible carry processing
    wire last_nibble =
        reverse_direction
            ? curr_nibble_idx == 0
            : curr_nibble_idx == loop_nibbles_number;

    // TODO: use it as overflow bit (combine with final values)
    // Last nibble passed
    logic was_last_nibble;

    always_ff @(posedge clk)
        if(last_nibble && loop_perm_to_count)
            was_last_nibble <= 1;

    always_ff @(posedge clk)
        if(~loop_perm_to_count)
        begin
            counter <= reset_val;
            was_last_nibble <= 0;
        end
        else
            if(~process_done)
                counter <= reverse_direction ? counter-1 : counter+1;
            else
                counter[3] <= 1; // set overflow

    logic process_done;

    always_comb
        if(overflow)
            process_done = 1;
        else
            if(invert_curr_nibble) // loop over negative signed must run over whole word to msb
                process_done = 0;
            else
                process_done = was_last_nibble && ~result_carry;

    assign busy = loop_perm_to_count && ~overflow;

    // Support small signed word2 values
    // For example, if 0x0 arg nibble passed it inverts it to 0xF
    wire invert_curr_nibble = word2_is_negative && was_last_nibble;

    wire AluArgs alu_args;
    wire AluRet alu_ret;
    assign alu_args.ctrl.ctrl.carry_in = ctrl.ctrl.carry_in;
    assign alu_args.ctrl.ctrl.b_inv = invert_curr_nibble;
    assign alu_args.ctrl.ctrl.carry_disable = ctrl.ctrl.carry_disable;
    assign alu_args.ctrl.ctrl.cmd = ctrl.ctrl.cmd;

    assign alu_args.d1 = word1[curr_nibble_idx];
    assign alu_args.d2 = word2[curr_nibble_idx];

    alu a(.args(alu_args), .ret(alu_ret));

    wire result_carry = reverse_direction ? alu_args.d2[0] : alu_ret.carry_out;

    always_ff @(posedge clk) begin
        if(~loop_perm_to_count)
        begin
            ctrl.ctrl.carry_in <= 0;
            result <= preinit_result;
        end
        else
            if(busy)
            begin
                result[counter] <= alu_ret.res;
                ctrl.ctrl.carry_in <= result_carry;
            end
    end

endmodule

module loopOverAllNibbles_test;
    localparam RSH_VAL = 32'h_0600_0000;

    logic clk;
    logic loop_perm_to_count;
    logic[2:0] loop_nibbles_number;
    AluCtrl ctrl;
    logic word2_is_negative;
    logic[31:0] word1;
    logic[31:0] word2;
    logic[31:0] preinit_result;
    logic[31:0] result;
    wire busy;

    loopOverAllNibbles l(.*);

    task loop_one_word
        (
            input AluCmd cmd,
            input[31:0] w1,
            input[31:0] w2
        );

        //~ $monitor("clk=%b perm=%b reverse=%b idx=%h ctrl=%b d1=%h d2=%h alu_ret=%h result=%h proc_not_all=%b result_carry=%b was_last=%b busy=%b",
            //~ clk, l.loop_perm_to_count, l.reverse_direction, l.curr_nibble_idx, l.alu_args.ctrl, l.alu_args.d1, l.alu_args.d2, l.alu_ret.res, result, ~l.process_done, l.result_carry, l.was_last_nibble, busy);

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

        //~ $display("while cycle is done");
    endtask

    initial begin
        //~ $dumpfile("loopOverAllNibbles_test.vcd");
        //~ $dumpvars(0, loopOverAllNibbles_test);

        preinit_result = 32'h_ff0004;
        loop_nibbles_number = 'b000;

        loop_one_word(ADD, 32'h_ff0004, 4);
        assert(result == 'h_ff0008); else $error("result=%h", result);

        preinit_result = 'h_0000_0000;
        loop_nibbles_number = 2;
        loop_one_word(ADD, 0, 'h_07b);
        assert(result == 'h_07b); else $error("result=%h", result);

        preinit_result = 'h_f000_0000;
        loop_nibbles_number = 'b111;

        loop_one_word(ADD, 'h_0eff_ffff, 1);
        assert(result == 'h_0f00_0000); else $error("result=%h", result);

        loop_one_word(ADD, 'h_ffff_0fff, 2);
        assert(result == 'h_ffff_1001);

        loop_one_word(ADD, 'h_0000_0002, -3);
        assert(result == -1); else $error("result=%d", $signed(result));

        loop_nibbles_number = 3;
        loop_one_word(ADD, 'h_0000_0001, 32'(12'(-2)));
        assert(12'(result) == 12'(-1)); else $error("result=%d", $signed(12'(result)));

        preinit_result = 0;
        loop_nibbles_number = 1; // 8 bits
        word2_is_negative = 1; // treat arg2 as signed negative value
        loop_one_word(ADD, 32'h_0000_ffff, 32'h_0000_00ff); // w2 is 8 bit value -1
        assert(result == 65534); else $error("result=%d (%h)", $signed(result), result);

        preinit_result = 0;
        loop_nibbles_number = 2; // 8 bits
        word2_is_negative = 1; // treat arg2 as signed negative value
        loop_one_word(ADD, 32'h_0000_0000, 32'h_0000_0800); // w2 is 8 bit value -1
        assert(result == -2048); else $error("result=%d (%h), reference: %h=-2048", $signed(result), result, -2048);

        word2_is_negative = 0;
        loop_nibbles_number = 0;
        loop_one_word(ADD, 'h_0000_0aff, 1);
        assert(result == 'h_0000_0b00); else $error("result=%h", result);

        loop_nibbles_number = 'b111;

        loop_one_word(RSHFT, 'h_xxxx_xxxx, RSH_VAL);
        assert(result == RSH_VAL >> 1); else $error("word2=%b result=%b must be=%b", word2, result, RSH_VAL >> 1);
    end
endmodule
