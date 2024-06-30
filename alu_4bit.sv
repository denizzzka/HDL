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
        output wire[3:0] internal_propagate // zero cost, can be leave unused
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
