// Loops ALU calculations over all nibbles
module loopOverAllNibbles
    (
        input wire clk,
        //TODO: rename:
        input wire loop_perm_to_count, // otherwise - reset
        input wire[2:0] loop_nibbles_number,
        ref wire AluCtrl ctrl,
        input wire[7:0][3:0] word1,
        input wire[7:0][3:0] word2,
        input wire[31:0] preinit_result,
        output wire busy,
        output wire[7:0][3:0] result
    );

    // "reverse" means from MSB to LSB
    wire reverse_direction = (ctrl.cmd == RSHFT) ? 1 : 0;
    wire[3:0] reset_val = reverse_direction ? 4'(loop_nibbles_number) : 0;

    logic[3:0] counter; // is additional bit for overflow control
    wire[2:0] curr_nibble_idx = counter[2:0];

    //TODO: move overflow bit to outside to share this flag with another module?
    wire overflow = counter[3];

    always_ff @(posedge clk)
        if(~loop_perm_to_count)
        begin
            counter <= reset_val;
        end
        else
        begin
            if(processed_not_all)
                counter <= reverse_direction ? counter-1 : counter+1;

            if(last_nibble)
                counter[3] <= 1; // set overflow
        end

    wire last_nibble =
        reverse_direction
            ? curr_nibble_idx == 0
            : curr_nibble_idx == loop_nibbles_number;

    wire processed_not_all = ~last_nibble || ctrl.ctrl.carry_in;

    assign busy = loop_perm_to_count && ~overflow;// processed_not_all;

    wire AluArgs alu_args;
    wire AluRet alu_ret;
    assign alu_args.ctrl = ctrl;
    assign alu_args.d1 = word1[curr_nibble_idx];
    assign alu_args.d2 = word2[curr_nibble_idx];

    alu a(.args(alu_args), .ret(alu_ret));

    wire result_carry = reverse_direction ? alu_args.d2[0] : alu_ret.carry_out;

    always_ff @(posedge clk) begin
        if(~loop_perm_to_count)
            result <= preinit_result;
        else begin
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

        //~ $monitor("clk=%b perm=%b reverse=%b idx=%h ctrl=%b d1=%h d2=%h nibble_ret=%h result=%h busy=%b",
            //~ clk, l.loop_perm_to_count, l.reverse_direction, l.counter, ctrl, l.alu_args.d1, l.alu_args.d2, l.alu_ret.res, result, busy);

        $monitor("clk=%b perm=%b reverse=%b idx=%h ctrl=%b result=%h proc_not_all=%b last=%b busy=%b",
            clk, l.loop_perm_to_count, l.reverse_direction, l.curr_nibble_idx, ctrl, result, l.processed_not_all, l.last_nibble, busy);

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

        loop_nibbles_number = 'b111;

        loop_one_word(RSHFT, 'h_xxxx_xxxx, RSH_VAL);
        assert(result == RSH_VAL >> 1); else $error("word2=%b result=%b must be=%b", word2, result, RSH_VAL >> 1);
    end
endmodule
