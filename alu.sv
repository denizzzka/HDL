module alu
    (
        input[3:0] d1,
        input[3:0] d2,
        input carry_in,
        input[3:0] ctrl,
        output[3:0] res,
        output carry_out
    );

    wire[3:0] gen;
    wire[3:0] propagate;
    wire[4:0] carry;

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
    bit[3:0] ctrl;
    logic[3:0] res;

    full_adder_test f();
    alu a(.*);

    initial begin
        //~ $monitor("ctrl=%b d1=%0d d2=%0d gen=%b propagate=%b carry=%b res=%0d res=%b carry_out=%b", ctrl, d1, d2, a.gen, a.propagate, a.carry, res, res, carry_out);

        for(d1 = 0; d1 < 15; d1++)
        begin
            for(d2 = 0; d2 < 15; d2++)
            begin
                #1
                ctrl = ctrl;
                assert(d1 + d2 == res) else $error("%h + %h = %h carry=%b", d1, d2, res, a.carry);
                assert((int'(d1) + d2 > 4'b1111) == carry_out) else $error("d1=%b d2=%b carry_out=%b", d1, d2, carry_out);
            end
        end
    end
endmodule;

module full_adder
    (
        input data1, data2, carry_in,
        input[3:0] ctrl,
        output ret, gen, propagate
    );

    wire prep_data2 = data2 ^ b_inv; // optionally inverts data2
    wire carry_disable = ctrl[1];
    wire carry = carry_in & ~carry_disable; // optionally can be disabled, TODO: can be disabled once for whole circuit?
    wire b_inv = ctrl[0];

    assign gen = data1 & prep_data2;
    assign propagate = data1 | prep_data2;

    wire i;
    AND_gate_with_mux mux(gen, propagate, ctrl[3:2], i);

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
    bit[3:0] ctrl;
    logic ret, gen, propagate;

    full_adder a(.*);

    initial begin
        $monitor("ctrl=%b carry_in=%b data1=%0d data2=%0d gen=%b propagate=%b ret=%b", ctrl, carry_in, data1, data2, gen, propagate, ret);

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
    end
endmodule
