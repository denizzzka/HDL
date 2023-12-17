module Ram
    #(parameter wordsSize = 256 * 1024 /*1Mb*/)
    (
        input clk,
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

    task forceClkCycle;
        assert(forceable_clk == 0);

        #1 force forceable_clk = 1;
        #1 force forceable_clk = 0;
        #1 release forceable_clk;
    endtask
endmodule

module Ram_test;
    logic clk;
    logic write_enable;
    logic is32bitWrite;
    logic[31:0] addr;
    logic[7:0] bus_to_mem;
    logic[31:0] bus_to_mem_32;
    wire[7:0] bus_from_mem;
    wire[31:0] bus_from_mem_32;

    Ram m(.*);

    initial begin
        //~ $monitor("clk=%b addr=%h we=%b is32=%b data_out=%h data_out_32=%h", clk, addr, write_enable, is32bitWrite, bus_from_mem, bus_from_mem_32);

        is32bitWrite = 1;
        write_enable = 1;
        addr = 'h58;
        bus_to_mem_32 = 'h_aabbccdd;
        #1 clk=1; #1 clk=0;

        is32bitWrite = 0;

        #1 clk=1; #1 clk=0;
        addr = 'h59;
        bus_to_mem = 'hee;
        #1 clk=1; #1 clk=0;

        write_enable = 0;
        #1 clk=1; #1 clk=0;

        assert(bus_from_mem == 'hee); else $error("%h", bus_from_mem);
        assert(bus_from_mem_32 == 'h_00aabbee); else $error("%h", bus_from_mem_32);
    end
endmodule
