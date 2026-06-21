/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_joseph_bf (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.

  // SPI Pin Mappings
  wire spi_miso = ui_in[0];
  wire spi_mosi;
  wire spi_sck;
  wire spi_cs_n;

  assign uo_out[0] = spi_mosi;
  assign uo_out[1] = spi_sck;
  assign uo_out[2] = spi_cs_n;
  assign uo_out[7:3] = 5'b0; // Unused

  // Start signal
  wire start_btn = ui_in[1];

  // Internal Bus Wires
  wire [15:0] mem_addr;
  wire [7:0]  mem_write_data;
  wire [7:0]  mem_read_data;
  wire        mem_read_en;
  wire        mem_write_en;
  wire        mem_ready;

  // BF Core
  bf bf_core (
      .clk(clk),
      .rst(~rst_n),
      .start(start_btn),
      
      .mem_addr(mem_addr),
      .mem_write_data(mem_write_data),
      .mem_read_en(mem_read_en),
      .mem_write_en(mem_write_en),
      .mem_read_data(mem_read_data),
      .mem_ready(mem_ready)
  );

  //  SPI RAM (connects to SPI master)
  spi_ram memory_bus (
      .clk(clk),
      .rst(~rst_n),
      
      // convert core's memory requests to SPI
      .mem_addr(mem_addr),
      .mem_write_data(mem_write_data),
      .mem_read_en(mem_read_en),
      .mem_write_en(mem_write_en),
      .mem_read_data(mem_read_data),
      .mem_ready(mem_ready),
      
      .spi_miso(spi_miso),
      .spi_mosi(spi_mosi),
      .spi_sck(spi_sck),
      .spi_cs_n(spi_cs_n)
  );

  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, ui_in[7:2], uio_in};

endmodule
