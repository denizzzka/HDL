// Look-Ahead Carry Generator

module carry_gen
    (
        input wire carry_in,
        input wire[3:0] gen,
        input wire[3:0] prop,
        output wire[2:0] carry,
        output wire gen_out // AKA carry out, TODO: try to create two wires, one another is carry[3]
    );

    assign carry[0] = gen[0] ||
            (carry_in && prop[0]);

    assign carry[1] = gen[1] || (
            (carry_in && prop[0] && prop[1]) ||
            (gen[0] && prop[1])
        );

    assign carry[2] = gen[2] || (
            (carry_in && prop[0] && prop[1] && prop[2]) ||
            (gen[0] && prop[1] && prop[2]) ||
            (gen[1] && prop[2])
        );

    assign gen_out = gen[3] || (
            (carry_in && prop[0] && prop[1] && prop[2] && prop[3]) ||
            (gen[0] && prop[1] && prop[2] && prop[3]) ||
            (gen[1] && prop[2] && prop[3]) ||
            (gen[2] && prop[3])
        );
endmodule

module propagate_out
    (
        input wire[3:0] prop,
        output wire prop_out // AKA all propagate inputs == 1
    );

    assign prop_out = (prop == 'hf);
endmodule
