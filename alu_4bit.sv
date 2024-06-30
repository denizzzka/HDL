typedef struct packed
{
    logic[3:0] d1;
    logic[3:0] d2;
} Alu4bitArgs;

module alu_4bit
    (
        input Alu4bitArgs args,
        input wire carry_in,
        input wire carry_disable,
        logic[1:0] cmd, // cmd for full adder mux switch
        output wire[3:0] res,
        output wire carry_out, // AKA "generate"
        output wire[3:0] internal_propagate // zero cost, can be left unused
    );

    wire[3:0] carry;
    assign carry[0] = carry_in;

    wire[3:0] internal_gen;

    wire[4:0] withLeftBit = { carry_in, args.d2 };

    for(genvar i = 0; i < 4; i++) begin
        wire left_bit = withLeftBit[i+1]; // used for right shift operation

        full_adder fa(
            .data1(args.d1[i]),
            .data2(args.d2[i]),
            .carry_in(carry[i]),
            .carry_disable(carry_disable),
            .direct_in(left_bit),
            .cmd,
            .gen(internal_gen[i]),
            .propagate(internal_propagate[i]),
            .ret(res[i])
        );
    end

    carry_gen cg(
        .carry_in,
        .gen(internal_gen),
        .prop(internal_propagate),
        .carry(carry[3:1]),
        .gen_out(carry_out)
    );
endmodule

module alu_4bit_test;
    wire Alu4bitArgs args;
    wire[3:0] res;

    logic[3:0] d1;
    logic[3:0] d2;
    assign args.d1 = d1;
    assign args.d2 = d2;

    AluCtrl ctrl;
    wire carry_in = ctrl.ctrl.carry_in;
    wire carry_disable = ctrl.ctrl.carry_disable;
    wire[1:0] cmd = ctrl.ctrl.cmd;

    wire carry_out;
    wire[3:0] internal_propagate;

    alu_4bit a(
        .*
    );

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

                ctrl.cmd = XOR;
                #1
                assert((d1 ^ d2) == res); // else $error("%b xor %b = %b", d1, d2, res);

                ctrl.cmd = AND;
                #1
                assert((d1 & d2) == res); // else $error("%b and %b = %b", d1, d2, res);

                ctrl.cmd = OR;
                #1
                assert((d1 | d2) == res); // else $error("%b or %b = %b", d1, d2, res);
            end
        end
    end
endmodule
