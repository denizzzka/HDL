// Loops ALU calculations over all nibbles
module loopOverAllNibbles
    #(parameter ALU_BITS_WIDTH)
    (
        input wire clk,
        //TODO: rename:
        input wire loop_perm_to_count, // otherwise - reset
        input wire[NIBBLES_NUM_WIDTH-1:0] loop_nibbles_number,
        input wire AluCtrl ctrl,
        ref logic carry_in_out, // TODO: duplicates carry_in from AluCtrl ctrl
        input wire check_if_result_0xF, // for A==B comparison
        input wire word2_is_signed_and_negative, // useful for SUB on signed values shorter than 8 nibbles
        input wire[32/$bits(aluParams#(ALU_BITS_WIDTH)::AluVal)-1:0][$bits(aluParams#(ALU_BITS_WIDTH)::AluVal)-1:0] word1, //TODO: remove in favor to preinit_result value?
        input wire[32/$bits(aluParams#(ALU_BITS_WIDTH)::AluVal)-1:0][$bits(aluParams#(ALU_BITS_WIDTH)::AluVal)-1:0] word2,
        input wire enable_preinit_only, // Hack for fast zero bits shifting
        input wire[31:0] preinit_result,
        output wire busy,
        output wire[32/$bits(aluParams#(ALU_BITS_WIDTH)::AluVal)-1:0][$bits(aluParams#(ALU_BITS_WIDTH)::AluVal)-1:0] result
    );

    localparam NIBBLES_NUM_WIDTH = $clog2(32 / ALU_BITS_WIDTH);

    // "reverse" means from MSB to LSB
    wire reverse_direction = (ctrl.ctrl.cmd == 'b_11 /* RSHFT */);
    wire[NIBBLES_NUM_WIDTH:0] reset_val = reverse_direction ? (NIBBLES_NUM_WIDTH+1)'(loop_nibbles_number) : 0;

    logic[NIBBLES_NUM_WIDTH:0] counter; // contains additional overflow control bit
    wire[NIBBLES_NUM_WIDTH-1:0] curr_nibble_idx = counter[NIBBLES_NUM_WIDTH-1:0];

    //TODO: move overflow bit to outside to share this flag with another module?
    wire overflow = counter[NIBBLES_NUM_WIDTH];

    wire is_result_0xF;
    wire result_0xF_check_failed = check_if_result_0xF && ~is_result_0xF;

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
                counter[NIBBLES_NUM_WIDTH] <= 1; // set overflow

    logic process_done;

    always_comb
        if(overflow || result_0xF_check_failed)
            process_done = 1;
        else
            if(word2_is_signed_and_negative) // loop over negative signed must run over whole word to msb
                process_done = 0;
            else
                process_done = was_last_nibble && ~result_carry;

    assign busy = loop_perm_to_count && ~overflow;

    wire aluParams#(ALU_BITS_WIDTH)::AluArgs alu_args;
    wire aluParams#(ALU_BITS_WIDTH)::AluRet alu_ret;
    assign alu_args.ctrl.ctrl.carry_in = carry_in_out;
    assign alu_args.ctrl.ctrl.b_inv = ctrl.ctrl.b_inv;;
    assign alu_args.ctrl.ctrl.carry_disable = ctrl.ctrl.carry_disable;
    assign alu_args.ctrl.ctrl.cmd = ctrl.ctrl.cmd;

    assign alu_args.d1 = word1[curr_nibble_idx];
    assign alu_args.d2 = word2[curr_nibble_idx];

    alu#(ALU_BITS_WIDTH) a(.args(alu_args), .ret(alu_ret));
    check_if_0xF#(ALU_BITS_WIDTH) chk_0xf(.in(alu_ret.res), .ret(is_result_0xF));

    wire result_carry = reverse_direction ? alu_args.d2[0] : alu_ret.carry_out;

    always_ff @(posedge clk) begin
        if(enable_preinit_only)
            result <= preinit_result;
        else if(~loop_perm_to_count)
        begin
            carry_in_out <= ctrl.ctrl.carry_in;
            result <= preinit_result;
        end
        else
            if(busy)
            begin
                result[counter] <= alu_ret.res;

                if(~check_if_result_0xF)
                    carry_in_out <= result_carry;
                else
                    carry_in_out <= is_result_0xF;
            end
    end

endmodule

module loopOverAllNibbles_test;
    localparam RSH_VAL = 32'h_0600_0000;

    logic clk;
    logic loop_perm_to_count;
    //~ logic[2:0] loop_nibbles_number;
    logic[0:0] loop_nibbles_number;
    AluCtrl ctrl;
    logic carry_in_out;
    logic check_if_result_0xF;
    logic word2_is_signed_and_negative;
    logic[31:0] word1;
    logic[31:0] word2;
    logic[31:0] preinit_result;
    logic enable_preinit_only;
    logic[31:0] result;
    wire busy;

    loopOverAllNibbles #(16) l(.*);

    AluCtrl rshft;

    task loop_one_word
        (
            input AluCmd cmd,
            input[31:0] w1,
            input[31:0] w2
        );

        //~ $monitor("clk=%b perm=%b reverse=%b idx=%h ctrl=%b b_inv=%b d1=%h d2=%h alu_ret=%h result=%h process_done=%b result_carry=%b carry_in_out=%b was_last_nibble=%b busy=%b",
            //~ clk, l.loop_perm_to_count, l.reverse_direction, l.curr_nibble_idx, l.alu_args.ctrl, l.alu_args.ctrl.ctrl.b_inv, l.alu_args.d1, l.alu_args.d2, l.alu_ret.res, result, l.process_done, l.result_carry, l.carry_in_out, l.was_last_nibble, busy);

        //~ $display("cycle started");

        assert(clk == 0);

        #1
        word1 = w1;
        word2 = w2;

        result = 0;
        ctrl = 0;
        ctrl.cmd = cmd;
        carry_in_out = 0;

        loop_perm_to_count = 0;

        #1
        clk = 1;
        #1
        clk = 0;
        loop_perm_to_count = 1;

        //~ $display("assigned ctrl=%b", ctrl);

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

        check_if_result_0xF = 0;
        preinit_result = 32'h_ff0004;
        loop_nibbles_number = 'b000;

        loop_one_word(ADD, 32'h_ff0004, 4);
        assert(result == 'h_ff0008); else $error("result=%h", result);

        preinit_result = 'h_0000_0000;
        //~ loop_nibbles_number = 2;
        loop_nibbles_number = 0;
        loop_one_word(ADD, 0, 'h_07b);
        assert(result == 'h_07b); else $error("result=%h", result);

        preinit_result = 'h_f000_0000;
        //~ loop_nibbles_number = 'b111;
        loop_nibbles_number = 1;

        loop_one_word(ADD, 'h_0eff_ffff, 1);
        assert(result == 'h_0f00_0000); else $error("result=%h", result);

        loop_one_word(ADD, 'h_ffff_0fff, 2);
        assert(result == 'h_ffff_1001);

        loop_one_word(ADD, 'h_0000_0002, -3);
        assert(result == -1); else $error("result=%d", $signed(result));

        //~ loop_nibbles_number = 3;
        loop_nibbles_number = 1;
        loop_one_word(ADD, 'h_0000_0001, 32'(12'(-2)));
        assert(12'(result) == 12'(-1)); else $error("result=%d", $signed(12'(result)));

        preinit_result = 0;
        loop_nibbles_number = 0; // 16-bits
        word2_is_signed_and_negative = 1; // treat arg2 as signed negative value
        loop_one_word(ADD, 32'h_0000_ffff, 32'h_ffff_ffff); // w2 is 16-bit value -1
        assert(result == 65534); else $error("result=%d (%h)", $signed(result), result);

        preinit_result = 0;
        //~ loop_nibbles_number = 2; // 8 bits
        loop_nibbles_number = 0; // 16 bits
        word2_is_signed_and_negative = 1; // treat arg2 as signed negative value
        loop_one_word(ADD, 32'h_0000_0000, 32'h_ffff_f800); // w2 is 16 bit value -2048
        assert(result == -2048); else $error("result=%d (%h), reference: %h=-2048", $signed(result), result, -2048);

        word2_is_signed_and_negative = 0;
        loop_nibbles_number = 0;
        loop_one_word(ADD, 'h_0000_0aff, 1);
        assert(result == 'h_0000_0b00); else $error("result=%h", result);

        //~ loop_nibbles_number = 'b111;
        loop_nibbles_number = 1;

        rshft.cmd = RSHFT;
        rshft.ctrl.carry_in = 0;
        loop_one_word(rshft.cmd, 'h_xxxx_xxxx, RSH_VAL);
        assert(result == RSH_VAL >> 1); else $error("word2=%b result=%b must be=%b", word2, result, RSH_VAL >> 1);

        rshft.ctrl.carry_in = 1;
        loop_one_word(rshft.cmd, 'h_xxxx_xxxx, RSH_VAL);
        assert(result == (RSH_VAL >> 1) + 32'h_8000_0000); else $error("word2=%h result=%h must be=%h", word2, result, (RSH_VAL >> 1) + 32'h_8000_0000);

        loop_one_word(COMP, 'h_1234_1234, 'h_1234_1234); // A-B-1 operation, A == B
        assert(result == 'h_ffff_ffff); else $error("result=%h", result);
        assert(carry_in_out == 0); // A <= B

        loop_one_word(COMP, 'h_1234_1233, 'h_1234_1234); // A-B-1 operation, A < B
        assert(result == 'h_ffff_fffe); else $error("result=%h", result);
        assert(carry_in_out == 0); // A <= B

        loop_one_word(COMP, 'h_1234_1234, 'h_1234_1233); // A-B-1 operation, A > B
        assert(result == 'h_0000_0000); else $error("result=%h", result);
        assert(carry_in_out == 1); // A > B

        loop_one_word(SUB, 'h_0000_1000, 'h_0000_0500);
        assert(result == 'h_0000_0b00); else $error("result=%h", result);

        // equality check operation
        check_if_result_0xF = 1;
        loop_one_word(XNOR, 'h_1234_1234, 'h_1234_1234);
        assert(carry_in_out); else $error("result=%h", result);

        // failed equality check operation
        loop_one_word(XNOR, 'h_2234_1234, 'h_1234_1234);
        assert(~carry_in_out); else $error("result=%h", result);

        // failed equality check operation (short loop)
        loop_one_word(XNOR, 'h_1234_1134, 'h_1234_1234);
        assert(~carry_in_out); else $error("result=%h", result);
    end
endmodule
