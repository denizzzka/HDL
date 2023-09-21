typedef enum logic[4:0] {
    ADD  =5'b00000, // also left shift if A=B, AKA SLL
    SUB  =5'b11000, // carry_out is inverted for SUB operations
    XOR  =5'bx0100,
    XNOR =5'bx1100, // also NOT, if A=0
    COMP =5'b01000, // A-B-1 operation, if A=B bit isn't set then established carry out bit means A>B, otherwise A<B
    AND  =5'bx0101,
    OR   =5'bx0110
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

module alu
    (
        input[3:0] d1,
        input[3:0] d2,
        input AluCtrl ctrl,
        output[3:0] res,
        output carry_out
    );

    wire[3:0] gen;
    wire[3:0] propagate;
    wire[4:0] carry;

    wire carry_in = ctrl.ctrl.carry_in;
    assign carry[0] = carry_in;
    assign carry_out = carry[4];

    for(genvar i = 0; i < 4; i++)
        full_adder fa(d1[i], d2[i], carry[i], ctrl, res[i], gen[i], propagate[i]);

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

module alu_test;
    logic[3:0] d1;
    logic[3:0] d2;
    bit carry_in;
    logic carry_out;
    AluCtrl ctrl;
    logic[3:0] res;

    full_adder_test f();
    alu a(.*);

    initial begin
        ctrl.ctrl.b_inv = 0;

        //~ $monitor("ctrl=%b d1=%0d d2=%0d gen=%b propagate=%b carry=%b res=%0d res=%b carry_out=%b", ctrl, d1, d2, a.gen, a.propagate, a.carry, res, res, carry_out);

        for(d1 = 0; d1 < 15; d1++)
        begin
            for(d2 = 0; d2 < 15; d2++)
            begin
                ctrl.cmd = ADD;
                #1
                assert(d1 + d2 == res) else $error("%h + %h = %h carry=%b", d1, d2, res, a.carry);
                assert((int'(d1) + d2 > 4'b1111) == carry_out) else $error("d1=%b d2=%b carry_out=%b", d1, d2, carry_out);

                ctrl.cmd = SUB;
                #1
                assert(d1 - d2 == res) else $error("%h - %h = %h carry=%b", d1, d2, res, a.carry);
                assert((d2 > d1) != carry_out) else $error("d1=%h d2=%h carry_out=%b", d1, d2, carry_out);

                ctrl.cmd = XOR;
                #1
                assert(d1 ^ d2 == res) else $error("%b xor %b = %b", d1, d2, res);

                ctrl.cmd = XNOR;
                #1
                assert(~(d1 ^ d2) == res) else $error("%b xnor %b = %b", d1, d2, res);

                ctrl.cmd = AND;
                #1
                assert((d1 & d2) == res) else $error("%b and %b = %b", d1, d2, res);

                ctrl.cmd = COMP;
                #1
                if(d1 != d2)
                    assert((d1 > d2) == carry_out) else $error("%h > %h == %b", d1, d2, carry_out);

                ctrl.cmd = OR;
                #1
                assert((d1 | d2) == res) else $error("%b or %b = %b", d1, d2, res);
            end
        end
    end
endmodule;

module full_adder
    (
        input data1, data2, carry_in,
        input AluCtrl ctrl,
        output ret, gen, propagate
    );

    wire prep_data2 = data2 ^ ctrl.ctrl.b_inv; // optionally inverts data2
    wire carry_disable = ctrl[2];
    wire carry = carry_in & ~carry_disable;

    assign gen = data1 & prep_data2;
    assign propagate = data1 | prep_data2;

    wire i;
    AND_gate_with_mux mux(gen, propagate, ctrl[1:0], i);

    assign ret = i ^ carry;
endmodule

// Some trick to utilize 2-level DCTL logic, need more work here
module AND_gate_with_mux
    (
        input from_AND, from_OR,
        input[1:0] ctrl,
        output result
    );

    wire interm = ~from_AND & from_OR;
    mux_4to1 m(result, interm, from_AND, from_OR, 1'bx /*unused*/, ctrl);

endmodule

module mux_4to1 (
        output r,
        input a,
        input b,
        input c,
        input d,
        input[1:0] sel
    );

    assign r = sel[1] ? (sel[0] ? d : c) : (sel[0] ? b : a);
endmodule;

module full_adder_test;
    bit data1, data2, carry_in;
    AluCtrl ctrl;
    logic ret, gen, propagate;

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
        ctrl.ctrl.cmd = SUB;
    end
endmodule
