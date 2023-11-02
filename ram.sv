module Ram
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

    logic[31:0][7:0] mem;

    assign bus_from_mem = mem[addr];

    always_comb
    begin
        bus_from_mem_32[0 +: 8] = mem[addr + 0];
        bus_from_mem_32[8 +: 8] = mem[addr + 1];
        bus_from_mem_32[16 +: 8] = mem[addr + 2];
        bus_from_mem_32[24 +: 8] = mem[addr + 3];
    end

    always_ff @(posedge clk)
        if(write_enable)
            if(~is32bitWrite)
                mem[addr] <= bus_to_mem;
            else begin
                mem[addr + 0] <= bus_to_mem_32[0 +: 8];
                mem[addr + 1] <= bus_to_mem_32[8 +: 8];
                mem[addr + 2] <= bus_to_mem_32[16 +: 8];
                mem[addr + 3] <= bus_to_mem_32[24 +: 8];
            end
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
        addr = 'hff;
        bus_to_mem = 'hab;
        #1 clk=1; #1 clk=0;

        write_enable = 0;
        #1 clk=1; #1 clk=0;

        assert(bus_from_mem == 'hab); else $error("%h", bus_from_mem);

        addr = 'h59;
        #1 clk=1; #1 clk=0;

        assert(bus_from_mem_32 == 'h_00aabbcc); else $error("%h", bus_from_mem_32);
        assert(bus_from_mem == 'h_cc); else $error("%h", bus_from_mem);
    end
endmodule
