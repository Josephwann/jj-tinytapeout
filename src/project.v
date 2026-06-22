// =============================================================================
// project.v  --  Top-level Tiny Tapeout module for BF interpreter
// =============================================================================
//
// Instantiates the BF FSM core, SPI RAM adapter, and SPI master to enable
// the chip to fetch and execute BF programs from external SPI SRAM.
//
// Copyright (c) 2024 Joseph Wan & Joseph Mensah
// SPDX-License-Identifier: Apache-2.0

`default_nettype none

module tt_um_joseph_bf (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
  wire rst = ~rst_n;

  // SPI Pins
  wire spi_cs_n;
  wire spi_mosi;
  wire spi_sck;
  wire spi_miso  = uio_in[2];
  
  // Control Pins
  wire start_btn = uio_in[4];

  // Map outputs
  assign uio_out[0] = spi_cs_n;
  assign uio_out[1] = spi_mosi;
  assign uio_out[2] = 1'b0;
  assign uio_out[3] = spi_sck;
  assign uio_out[7:4] = 4'b0000;

  // CS (0), MOSI (1), and SCK (3) are outputs
  assign uio_oe = 8'b0000_1011;   

  assign uo_out = 8'd0;

  // Internal memory bus
  wire [15:0] mem_addr;
  wire [7:0]  mem_write_data;
  wire [7:0]  mem_read_data;
  wire        mem_read_en;
  wire        mem_write_en;
  wire        mem_resp_val;

  // BF Core
  bf bf_core (
      .clk(clk),
      .rst(rst),
      .start(start_btn),
      .mem_addr(mem_addr),
      .mem_write_data(mem_write_data),
      .mem_read_en(mem_read_en),
      .mem_write_en(mem_write_en),
      .mem_read_data(mem_read_data),
      .mem_resp_val(mem_resp_val)
  );

  // Connect BF core SPI RAM adapter
  spi_ram memory_bus (
      .clk(clk),
      .rst(rst),
      .mem_addr(mem_addr),
      .mem_write_data(mem_write_data),
      .mem_read_en(mem_read_en),
      .mem_write_en(mem_write_en),
      .mem_read_data(mem_read_data),
      .mem_ready(mem_resp_val),
      .spi_miso(spi_miso),
      .spi_mosi(spi_mosi),
      .spi_sck(spi_sck),
      .spi_cs_n(spi_cs_n)
  );

  wire _unused = &{ena, ui_in, uio_in[1:0], uio_in[3], uio_in[7:5], 1'b0};

endmodule
