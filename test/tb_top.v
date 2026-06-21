// tb_top.v -- full-chip testbench: tt_um_joseph_bf with a mock SPI RAM on the
// uio pins, like the demo board's RP2040.

`default_nettype none
`timescale 1ns / 1ps

module tb_top ();

    initial begin
        $dumpfile("tb_top.fst");
        $dumpvars(0, tb_top);
        #1;
    end

    reg        clk;
    reg        rst_n;
    reg        ena;
    reg  [7:0] ui_in;        // ',' input byte
    reg        r_start;      // -> uio_in[4]
    reg        r_in_valid;   // -> uio_in[6]

    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    wire spi_cs_n = uio_out[0];
    wire spi_mosi = uio_out[1];
    wire spi_sck  = uio_out[3];
    wire spi_miso;

    // MISO on [2], start on [4], in_valid on [6]; the rest are chip outputs.
    wire [7:0] uio_in;
    assign uio_in[0] = 1'b0;
    assign uio_in[1] = 1'b0;
    assign uio_in[2] = spi_miso;
    assign uio_in[3] = 1'b0;
    assign uio_in[4] = r_start;
    assign uio_in[5] = 1'b0;
    assign uio_in[6] = r_in_valid;
    assign uio_in[7] = 1'b0;

    tt_um_joseph_bf dut (
        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe),
        .ena     (ena),
        .clk     (clk),
        .rst_n   (rst_n)
    );

    spi_ram_model ram (
        .cs_n (spi_cs_n),
        .sclk (spi_sck),
        .mosi (spi_mosi),
        .miso (spi_miso)
    );

endmodule

`default_nettype wire
