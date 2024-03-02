module shift_loop
    (
        input wire decrease_pulse,
        input wire reset,
        input wire[4:0] start_val,
        output wire busy
    );

    logic[4:0] curr_val;

    // TODO: implement partial steps counting if bits on edge nibbles is already shifted out

    assign busy = ~(curr_val == 0);

    always_ff @(posedge decrease_pulse)
        if(reset)
            curr_val <= start_val;
        else if(busy)
            curr_val <= curr_val - 1;
endmodule

module shift_loop_test;
endmodule
