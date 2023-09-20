module clk_source
    #(parameter LEN)
    (
        input clk,
        output bit f1, f2
    );

    bit[LEN-1:0] q;

    for(genvar i = 0; i < LEN-1; i++)
        always_ff @(posedge clk)
                q[i+1] <= q[i];

    always_ff @(posedge clk)
        q[0] <= ~q[LEN-1];

    assign f1 = q[0] & q[1];
    assign f2 = ~(q[0] | q[1]);

    initial begin
        assert(LEN >= 2);
    end
endmodule

module clk_test;
    logic clk, f1, f2;
    localparam LEN = 5;

    clk_source #(LEN) c (clk, f1, f2);

    assert property(@(posedge clk) ~(f1 && f2));

    initial begin
        //~ $monitor("time=%0d clk=%b f1=%b f2=%b", $time, clk, f1, f2);
        $dumpfile("clk_output.vcd");
        $dumpvars(0, clk_test);

        clk = 0;
        repeat (LEN * 10) #1 clk = ~clk;
    end
endmodule
