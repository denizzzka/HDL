typedef enum logic[4:0] {
    ADD  =5'b00000, // also left shift if A=B, AKA SLL
    SUB  =5'b11000, // carry_out is inverted for SUB operations
    XOR  =5'bx0100,
    XNOR =5'bx1100, // also NOT, if A=0
    COMP =5'b01000, // A-B-1 operation, established carry out means A>B, otherwise A<=B
    AND  =5'bx0101,
    OR   =5'bx0110,
    RSHFT=5'bx0111  // moves data2 bits to right (SLR), data1 is ignored
} AluCmd;

typedef struct packed
{
    logic carry_in; // carry input (for example, from prev stage)
    logic b_inv; // invert second operand?
    logic carry_disable;
    logic[1:0] cmd; // cmd for full adder mux switch
} AluCtrlInternal;

typedef union packed
{
    AluCmd cmd;
    AluCtrlInternal ctrl;
} AluCtrl;

typedef struct packed
{
    logic[3:0] d1;
    logic[3:0] d2;
    AluCtrl ctrl;
} AluArgs;

typedef struct packed
{
    logic carry_out;
    logic[3:0] res;
} AluRet;

module alu
    (
        input AluArgs args,
        output AluRet ret
    );

    wire[3:0] gen;
    wire[3:0] propagate;
    wire[4:0] d2_possible_inverted;
    wire[4:0] carry;

    wire carry_in = args.ctrl.ctrl.carry_in;
    assign carry[0] = carry_in;
    assign ret.carry_out = carry[4];
    assign d2_possible_inverted[4] = carry_in;

    for(genvar i = 0; i < 4; i++) begin
        wire right_bit = d2_possible_inverted[i+1];

        full_adder fa(
            .data1(args.d1[i]),
            .data2(args.d2[i]),
            .carry_in(carry[i]),
            .direct_in(right_bit),
            .ctrl(args.ctrl),
            .ret(ret.res[i]),
            .gen(gen[i]),
            .propagate(propagate[i]),
            .d2_possible_inverted(d2_possible_inverted[i])
        );
    end

    assign carry[1] = gen[0] ||
            (carry_in && propagate[0]);

    assign carry[2] = gen[1] || (
            (carry_in && propagate[0] && propagate[1]) ||
            (gen[0] && propagate[1])
        );

    assign carry[3] = gen[2] || (
            (carry_in && propagate[0] && propagate[1] && propagate[2]) ||
            (gen[0] && propagate[1] && propagate[2]) ||
            (gen[1] && propagate[2])
        );

    assign carry[4] = gen[3] || (
            (carry_in && propagate[0] && propagate[1] && propagate[2] && propagate[3]) ||
            (gen[0] && propagate[1] && propagate[2] && propagate[3]) ||
            (gen[1] && propagate[2] && propagate[3]) ||
            (gen[2] && propagate[3])
        );
endmodule

// Usable for immediate A==B compare during A-B-1 operation
module check_if_0xF (input [3:0] in, output ret);
    assign ret = (in == 'hf);
endmodule

module alu_test;
    wire AluArgs args;
    wire AluRet ret;

    logic[3:0] d1;
    logic[3:0] d2;
    assign args.d1 = d1;
    assign args.d2 = d2;

    wire carry_out = ret.carry_out;

    logic res_is_0xF;

    AluCtrl ctrl;
    assign args.ctrl = ctrl;

    wire[3:0] res = ret.res;

    alu a(.*);
    check_if_0xF res_chk(res, res_is_0xF);

    initial begin
        ctrl.ctrl.b_inv = 0;

        //~ $monitor("ctrl=%b d1=%0d d2=%0d gen=%b propagate=%b carry=%b res=%0d res=%b carry_out=%b", ctrl, d1, d2, a.gen, a.propagate, a.carry, res, res, carry_out);

        for(d2 = 0; d2 < 15; d2++)
        begin
            ctrl.cmd = RSHFT;
            #1
            assert(d2 >> 1 == res); // else $error("%b rshift = %b carry=%b", d2, res, a.carry);

            ctrl.ctrl.carry_in = 1;
            #1
            assert((d2 >> 1) + 'b1000 == res); else $error("%b rshift = %b carry=%b", d2, res, a.carry);

            d1 = 0; // TODO: Why d1 = 0 inside of "for" loop isn't works as expected?
            for(d1 = 0; d1 < 15; d1++)
            begin
                ctrl.cmd = ADD;
                #1
                assert(d1 + d2 == res); else $error("%h + %h = %h carry=%b", d1, d2, res, carry_out);
                assert((16'(d1) + 16'(d2) > 16'b1111) == carry_out); else $error("d1=%b d2=%b carry_out=%b", d1, d2, carry_out);
                assert((res == 'b1111) == res_is_0xF);

                ctrl.cmd = ADD;
                ctrl.ctrl.b_inv = 1;
                #1
                assert(d1 + ~d2 == res); else $error("%h + ~%h = %h (must be %h) carry=%b", d1, d2, res, d1 + ~d2, carry_out);
                assert((16'(d1) + 16'(4'(~d2)) > 16'b1111) == carry_out); else $error("d1=%b d2=%b carry_out=%b", d1, ~d2, carry_out);
                assert((res == 'b1111) == res_is_0xF);

                ctrl.cmd = SUB;
                #1
                assert(d1 - d2 == res); // else $error("%h - %h = %h carry=%b", d1, d2, res, a.carry);
                assert((d2 > d1) != carry_out); // else $error("d1=%h d2=%h carry_out=%b", d1, d2, carry_out);

                ctrl.cmd = XOR;
                #1
                assert((d1 ^ d2) == res); // else $error("%b xor %b = %b", d1, d2, res);

                ctrl.cmd = XNOR;
                #1
                assert(~(d1 ^ d2) == res); // else $error("%b xnor %b = %b", d1, d2, res);

                ctrl.cmd = AND;
                #1
                assert((d1 & d2) == res); // else $error("%b and %b = %b", d1, d2, res);

                ctrl.cmd = COMP;
                #1
                if(d1 != d2)
                    assert((d1 > d2) == carry_out); // else $error("%h > %h == %b", d1, d2, carry_out);

                ctrl.cmd = OR;
                #1
                assert((d1 | d2) == res); // else $error("%b or %b = %b", d1, d2, res);
            end
        end
    end
endmodule

module full_adder
    (
        input data1, data2, carry_in, direct_in /*can be bypassed to output*/,
        input AluCtrlInternal ctrl,
        output ret, gen, propagate, d2_possible_inverted
    );

    assign d2_possible_inverted = data2 ^ ctrl.b_inv; // optionally inverts data2
    wire carry = carry_in & ~ctrl.carry_disable;

    assign gen = data1 & d2_possible_inverted;
    assign propagate = data1 | d2_possible_inverted;

    wire i;
    AND_gate_with_mux mux(gen, propagate, direct_in, ctrl.cmd, i);

    assign ret = i ^ carry;
endmodule

// MUX used here to utilize 3-level DCTL logic
module AND_gate_with_mux
    (
        input from_AND, from_OR, direct_in,
        input[1:0] cmd,
        output logic r
    );

    wire interm = ~from_AND & from_OR;

    always_comb
        unique case(cmd)
            'b00: r = interm;
            'b01: r = from_AND;
            'b10: r = from_OR;
            'b11: r = direct_in;
        endcase
endmodule

module full_adder_test;
    bit data1, data2, carry_in, direct_in;
    AluCtrl ctrl;
    wire ret, gen, propagate, d2_possible_inverted;

    full_adder a(.*);

    initial begin
        ctrl.ctrl.b_inv = 0;
        ctrl.ctrl.cmd = 0;

        //~ $monitor("ctrl=%b carry_in=%b data1=%0d data2=%0d gen=%b propagate=%b ret=%b carry=%b", ctrl, carry_in, data1, data2, gen, propagate, ret, a.carry);

        #1
        data1 = 0;
        data2 = 0;

        #1
        data1 = 0;
        data2 = 1;

        #1
        data1 = 1;
        data2 = 0;

        #1
        data1 = 1;
        data2 = 1;

        #1
        ctrl.cmd = XOR;
        carry_in = 1;

        #1
        data1 = 0;
        data2 = 0;
        ctrl.cmd = SUB;
    end
endmodule
