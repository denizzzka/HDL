module nibble_counter
    #(parameter WIDTH)
    (
        input wire clk,
        input wire busy, // perm to count
        input wire reverse_direction,
        output wire is_latest,
        output logic[WIDTH-1:0] val
    );

    wire[WIDTH-1:0] fin_val = reverse_direction ? 0 : 0 - 1;
    assign is_latest = (val == fin_val);

    always_ff @(posedge clk)
        if(~busy)
            val <= reverse_direction ? 0 - 1 : 0;
        else
            if(~is_latest)
                val <= reverse_direction ? val-1 : val+1;

endmodule

module nibble_counter_test;
    logic clk;
    logic busy;
    logic reverse_direction;
    logic is_latest;
    logic[2:0] val;

    nibble_counter#(3) c(.*);

    initial begin
        //~ $monitor("clk=%b busy=%b val=%h is_latest=%b", clk, busy, val, is_latest);

        reverse_direction = 1;
        #1
        clk = 1;
        #1
        assert(~is_latest && (val == 'b111));

        busy = 1;
        clk = 0;
        #1
        clk = 1;

        repeat (20) #1 clk = ~clk;
        assert(is_latest && (val == 'b000)); else $error("val=%b", val);

        //~ $monitor("clk=%b busy=%b val=%h is_latest=%b", clk, busy, val, is_latest);

        clk = 0;
        reverse_direction = 0;
        busy = 0;

        #1
        clk = 1;
        #1
        assert(~is_latest && (val == 'b000));

        busy = 1;
        clk = 0;
        #1
        clk = 1;

        repeat (20) #1 clk = ~clk;
        assert(is_latest && (val == 'b111)); else $error("val=%b", val);
    end
endmodule
