module nibble_counter
    #(parameter WIDTH)
    (
        input wire clk,
        input wire perm_to_count, // otherwise - reset
        input wire[WIDTH-1:0] arg2_width, // defined in nibbles, TODO: replace by enum
        input wire reverse_direction,
        output wire is_latest,
        output logic[WIDTH-1:0] val
    );

    wire[WIDTH-1:0] fin_val = reverse_direction ? 0 : arg2_width;
    assign is_latest = (val == fin_val);

    always_ff @(posedge clk)
        if(~perm_to_count)
            val <= reverse_direction ? arg2_width : 0;
        else
            if(~is_latest)
                val <= reverse_direction ? val-1 : val+1;

endmodule

module nibble_counter_test;
    logic clk;
    logic perm_to_count;
    logic reverse_direction;
    logic is_latest;
    logic[2:0] arg2_width;
    logic[2:0] val;

    nibble_counter#(3) c(.*);

    initial begin
        //~ $monitor("clk=%b perm_to_count=%b val=%h is_latest=%b", clk, perm_to_count, val, is_latest);

        arg2_width = 'b010; // 2 bytes
        reverse_direction = 1;
        #1
        clk = 1;
        #1
        assert(~is_latest && (val == 'b010)); else $error("is_latest=%b val=%b", is_latest, val);

        perm_to_count = 1;
        clk = 0;
        #1
        clk = 1;

        repeat (20) #1 clk = ~clk;
        assert(is_latest && (val == 'b000)); else $error("val=%b", val);

        //~ $monitor("clk=%b perm_to_count=%b val=%h is_latest=%b", clk, perm_to_count, val, is_latest);

        clk = 0;
        arg2_width = 'b111;
        reverse_direction = 0;
        perm_to_count = 0;

        #1
        clk = 1;
        #1
        assert(~is_latest && (val == 'b000));

        perm_to_count = 1;
        clk = 0;
        #1
        clk = 1;

        repeat (20) #1 clk = ~clk;
        assert(is_latest && (val == 'b111)); else $error("val=%b", val);
    end
endmodule
