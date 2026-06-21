// tb_spi.v -- testbench for the SPI subsystem: drives the BF memory bus into
// spi_ram and watches it round-trip through spi_ram_model over real SPI.

`default_nettype none
`timescale 1ns / 1ps

module tb_spi ();

    initial begin
        $dumpfile("tb_spi.fst");
        $dumpvars(0, tb_spi);
        #1;
    end

    reg clk;
    reg rst;

    reg  [15:0] mem_addr;
    reg  [7:0]  mem_write_data;
    reg         mem_read_en;
    reg         mem_write_en;
    wire [7:0]  mem_read_data;
    wire        mem_ready;

    wire cs_n;
    wire sck;
    wire mosi;
    wire miso;

    spi_ram #(
        .CLK_DIV (4)
    ) dut (
        .clk            (clk),
        .rst            (rst),
        .mem_addr       (mem_addr),
        .mem_write_data (mem_write_data),
        .mem_read_en    (mem_read_en),
        .mem_write_en   (mem_write_en),
        .mem_read_data  (mem_read_data),
        .mem_ready      (mem_ready),
        .spi_cs_n       (cs_n),
        .spi_sck        (sck),
        .spi_mosi       (mosi),
        .spi_miso       (miso)
    );

    spi_ram_model ram (
        .cs_n (cs_n),
        .sclk (sck),
        .mosi (mosi),
        .miso (miso)
    );

endmodule

`default_nettype wire
