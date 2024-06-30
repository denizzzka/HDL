module alu
    (
        input AluArgs args,
        output AluRet ret
    );

    wire carry_in = args.ctrl.ctrl.carry_in;

    wire[4:0] carry;
    assign carry[0] = carry_in;

    wire Alu16bitArgs internalArgs;
    assign internalArgs.d1 = args.d1;
    // optionally inverts data2
    assign internalArgs.d2 = args.d2 ^ { $bits(args.d2) {args.ctrl.ctrl.b_inv} };

    alu_16bit a(
        .args(internalArgs),
        .carry_in,
        .carry_disable(args.ctrl.ctrl.carry_disable),
        .cmd(args.ctrl.ctrl.cmd),
        .res(ret.res),
        .carry_out(ret.carry_out)
    );
endmodule

// Usable for immediate A==B compare during A-B-1 operation
module check_if_0xF (input AluVal in, output ret);
    assign ret = (in == { $bits(in) {1'b1} });
endmodule

module alu_test;
    wire AluArgs args;
    wire AluRet ret;

    AluVal d1;
    AluVal d2;
    assign args.d1 = d1;
    assign args.d2 = d2;

    wire carry_out = ret.carry_out;

    logic res_is_0xF;

    AluCtrl ctrl;
    assign args.ctrl = ctrl;

    wire AluVal res = ret.res;

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
            assert((d2 >> 1) + { 1'b1, { $bits(AluVal)-1 {1'b0} } } == res); else $error("%b rshift = %b carry=%b", d2, res, a.carry);

            d1 = 0; // TODO: Why d1 = 0 inside of "for" loop isn't works as expected?
            for(d1 = 0; d1 < 15; d1++)
            begin
                ctrl.cmd = ADD;
                #1
                assert(d1 + d2 == res); else $error("%h + %h = %h carry=%b", d1, d2, res, carry_out);
                assert((32'(d1) + 32'(d2) > {$bits(AluVal){1'b1}}) == carry_out); else $error("d1=%b d2=%b carry_out=%b", d1, d2, carry_out);

                ctrl.cmd = ADD;
                ctrl.ctrl.b_inv = 1;
                #1
                assert(d1 + ~d2 == res); else $error("%h + ~%h = %h (must be %h) carry=%b", d1, d2, res, d1 + ~d2, carry_out);
                assert((16'(d1) + 16'(4'(~d2)) > 16'b1111) == carry_out); else $error("d1=%b d2=%b carry_out=%b", d1, ~d2, carry_out);
                assert((res == {$bits(AluVal){1'b1}}) == res_is_0xF);

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
