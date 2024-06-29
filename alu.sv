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

    wire carry_in = args.ctrl.ctrl.carry_in;

    wire[4:0] carry;
    assign carry[0] = carry_in;

    wire[3:0] d2_possible_inverted = args.d2 ^ {4{args.ctrl.ctrl.b_inv}}; // optionally inverts data2

    wire Alu4bitArgs args4b;
    assign args4b.d1 = args.d1;
    assign args4b.d2 = d2_possible_inverted[3:0];

    alu_4bit a4b(
        .args(args4b),
        .carry_in,
        .carry_disable(args.ctrl.ctrl.carry_disable),
        .cmd(args.ctrl.ctrl.cmd),
        .res(ret.res),
        .carry_out(ret.carry_out)
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
