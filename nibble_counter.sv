module nibble_counter
    #(parameter WIDTH)
    (
        input wire clk,
        input wire start,
        input wire reverse_direction,
        output wire is_latest,
        output logic[WIDTH-1:0] val
    );

    wire[WIDTH-1:0] fin_val = reverse_direction ? 0 : 0 - 1;
    assign is_latest = (val == fin_val);

    always_ff @(posedge clk)
        if(start)
            val <= reverse_direction ? 0 - 1 : 0;
        else
            if(~is_latest)
                val <= reverse_direction ? val-1 : val+1;

endmodule

module nibble_counter_test;
    logic clk;
    logic start;
    logic reverse_direction;
    logic is_latest;
    logic[2:0] val;

    nibble_counter#(3) c(.*);

    initial begin
        //~ $monitor("clk=%b start=%b val=%h is_latest=%b", clk, start, val, is_latest);

        reverse_direction = 1;
        start = 1;
        clk = 0;
        #1
        clk = 1;
        #1
        clk = 0;
        start = 0;
        assert(~is_latest && (val == 'b111));
        repeat (20) #1 clk = ~clk;
        assert(is_latest && (val == 'b000)); else $error("val=%b", val);

        //~ $monitor("clk=%b start=%b val=%h done=%b", clk, start, val, done);

        reverse_direction = 0;
        start = 1;
        clk = 0;
        #1
        clk = 1;
        #1
        start = 0;
        assert(~is_latest && (val == 'b000));
        repeat (20) #1 clk = ~clk;
        assert(is_latest && (val == 'b111)); else $error("val=%b", val);
    end
endmodule
