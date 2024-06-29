// Look-Ahead Carry Generator

module carry_gen
    (
        input wire carry_in,
        input wire[3:0] gen,
        input wire[3:0] prop,
        output wire[3:0] carry
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

    assign carry[3] = gen[3] || (
            (carry_in && prop[0] && prop[1] && prop[2] && prop[3]) ||
            (gen[0] && prop[1] && prop[2] && prop[3]) ||
            (gen[1] && prop[2] && prop[3]) ||
            (gen[2] && prop[3])
        );
endmodule
