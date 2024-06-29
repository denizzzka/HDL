module register_file
    (
        input wire RegAddr addr,
        input wire write_enable,
        input wire is32bitWrite,
        input wire[31:0] addr,
        input wire[7:0] bus_to_mem,
        input wire[31:0] bus_to_mem_32,
        output wire[7:0] bus_from_mem,
        output wire[31:0] bus_from_mem_32
    );

    // Flat memory array
    logic[wordsSize-1:0] mem;

    int addr8 = addr * 8;

    assign bus_from_mem = mem[addr8 +: 8];
    assign bus_from_mem_32 = mem[addr8 +: 32];

    wire forceable_clk;
    assign forceable_clk = clk;

    always_ff @(posedge forceable_clk)
        if(write_enable)
            if(~is32bitWrite)
                mem[addr8 +: 8] <= bus_to_mem;
            else
                mem[addr8 +: 32] <= bus_to_mem_32;
endmodule
