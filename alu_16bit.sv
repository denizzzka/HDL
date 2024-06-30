typedef struct packed
{
    logic[15:0] d1;
    logic[15:0] d2;
} Alu16bitArgs;

module alu_16bit
    (
        input Alu16bitArgs args,
        input wire carry_in,
        input wire carry_disable,
        logic[1:0] cmd, // cmd for full adder mux switch
        output wire[15:0] res,
        output wire carry_out
    );

    wire[3:0] carry;
    assign carry[0] = carry_in;

    wire[3:0] rshift_carry;
    assign rshift_carry[0] = args.d2[4];
    assign rshift_carry[1] = args.d2[8];
    assign rshift_carry[2] = args.d2[12];
    assign rshift_carry[3] = carry_in;

    wire isRShiftOP = (carry_disable && cmd == 'b11);

    wire[3:0] gen;
    wire[3:0] prop;

    for(genvar i = 0; i < 16; i+=4) begin
        wire Alu4bitArgs args4b;
        assign args4b.d1 = args.d1[i+3:i];
        assign args4b.d2 = args.d2[i+3:i];

        wire[3:0] internal_propagate;

        // for RSHIFT op
        wire local_carry = isRShiftOP ? rshift_carry[i/4] : carry[i/4];

        alu_4bit a4b(
            .args(args4b),
            .carry_in(local_carry),
            .carry_disable,
            .cmd,
            .res(res[i+3:i]),
            .internal_propagate,
            .carry_out(gen[i/4])
        );

        propagate_out po(
            .prop(internal_propagate),
            .prop_out(prop[i/4])
        );
    end

    carry_gen cg(
        .carry_in,
        .gen,
        .prop,
        .carry(carry[3:1]),
        .gen_out(carry_out)
    );
endmodule

module alu16_test;
    wire Alu16bitArgs args;
    wire[15:0] res;

    logic[15:0] d1;
    logic[15:0] d2;
    assign args.d1 = d1;
    assign args.d2 = d2;

    wire carry_in = ctrl.ctrl.carry_in;
    wire carry_disable = ctrl.ctrl.carry_disable;
    wire[1:0] cmd = ctrl.ctrl.cmd;
    wire carry_out;

    AluCtrl ctrl;

    alu_16bit a(.*);

    initial begin
        //~ $monitor("ctrl=%b d1=%0d d2=%0d gen=%b propagate=%b carry=%b res=%0d res=%b carry_out=%b", ctrl, d1, d2, a.gen, a.propagate, a.carry, res, res, carry_out);

        for(d2 = 0; d2 < 256; d2++)
        begin
            ctrl.cmd = RSHFT;
            #1
            assert(d2 >> 1 == res); else $error("%b rshift = %b carry_out=%b carry=%b gen=%b prop=%b", d2, res, carry_out, a.carry, a.gen, a.prop);

            ctrl.ctrl.carry_in = 1;
            #1
            assert((d2 >> 1) + 'b1000_0000_0000_0000 == res); else $error("%b rshift = %b carry=%b", d2, res, a.carry);

            d1 = 0; // TODO: Why d1 = 0 inside of "for" loop isn't works as expected?
            for(d1 = 0; d1 < 15; d1++)
            begin
                ctrl.cmd = ADD;
                #1
                assert(d1 + d2 == res); else $error("%h + %h = %h carry=%b", d1, d2, res, carry_out);
                assert((32'(d1) + 32'(d2) > 32'hffff) == carry_out); else $error("d1=%b d2=%b carry_out=%b", d1, d2, carry_out);

                ctrl.cmd = SUB;
                #1
                //~ assert(d1 - d2 == res); else $error("%h - %h = %h carry=%b", d1, d2, res, a.carry);
                //~ assert((d2 > d1) != carry_out); else $error("d1=%h d2=%h carry_out=%b", d1, d2, carry_out);

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
