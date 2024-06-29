module full_adder
    (
        input data1, data2, carry_in, direct_in /*can be bypassed to output*/,
        input wire carry_disable,
        logic[1:0] cmd, //TODO: typedef it?
        output ret, gen, propagate
    );

    wire carry = carry_in & ~carry_disable;

    assign gen = data1 & data2;
    assign propagate = data1 | data2;

    wire i;
    AND_gate_with_mux mux(gen, propagate, direct_in, cmd, i);

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
    wire ret, gen, propagate;

    full_adder a(
        .carry_disable(ctrl.ctrl.carry_disable),
        .cmd(ctrl.ctrl.cmd),
        .*
    );

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
