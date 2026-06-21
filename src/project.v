/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

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

  // Pins: uio[0]=CS uio[1]=MOSI uio[2]=MISO uio[3]=SCK (standard spi-ram-emu),
  // uio[4]=start, uio[5]=out_valid, uio[6]=in_valid, uio[7]=in_ack,
  // ui_in = ',' input byte, uo_out = '.' output byte.
  wire spi_cs_n;
  wire spi_mosi;
  wire spi_sck;
  wire spi_miso  = uio_in[2];
  wire start_btn = uio_in[4];
  wire in_valid  = uio_in[6];

  reg [7:0] out_reg;
  reg       out_valid;
  reg       in_ack;
  reg       io_ready;
  reg       io_busy;

  assign uio_out[0] = spi_cs_n;
  assign uio_out[1] = spi_mosi;
  assign uio_out[2] = 1'b0;
  assign uio_out[3] = spi_sck;
  assign uio_out[4] = 1'b0;
  assign uio_out[5] = out_valid;
  assign uio_out[6] = 1'b0;
  assign uio_out[7] = in_ack;
  assign uio_oe     = 8'b1010_1011;   // outputs: CS, MOSI, SCK, out_valid, in_ack

  assign uo_out = out_reg;

  wire [15:0] mem_addr;
  wire [7:0]  mem_write_data;
  wire [7:0]  mem_read_data;
  wire        mem_read_en;
  wire        mem_write_en;
  wire        mem_resp_val;

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

  // 0xFFFF = memory-mapped I/O ( ',' and '.' ); every other address is SPI RAM.
  wire is_io = (mem_addr == 16'hFFFF);
  wire io_wr = is_io & mem_write_en;
  wire io_rd = is_io & mem_read_en;

  wire [7:0] ram_read_data;
  wire       ram_ready;

  spi_ram memory_bus (
      .clk(clk),
      .rst(rst),
      .mem_addr(mem_addr),
      .mem_write_data(mem_write_data),
      .mem_read_en (mem_read_en  & ~is_io),
      .mem_write_en(mem_write_en & ~is_io),
      .mem_read_data(ram_read_data),
      .mem_ready(ram_ready),
      .spi_miso(spi_miso),
      .spi_mosi(spi_mosi),
      .spi_sck(spi_sck),
      .spi_cs_n(spi_cs_n)
  );

  // '.' latches uo_out + pulses out_valid; ',' waits for in_valid then returns
  // ui_in + pulses in_ack. bf stalls on ',' until input is ready.
  always @(posedge clk) begin
    if (rst) begin
      out_reg   <= 8'd0;
      out_valid <= 1'b0;
      in_ack    <= 1'b0;
      io_ready  <= 1'b0;
      io_busy   <= 1'b0;
    end else begin
      io_ready  <= 1'b0;
      out_valid <= 1'b0;
      in_ack    <= 1'b0;

      if (~io_busy) begin
        if (io_wr) begin
          out_reg   <= mem_write_data;
          out_valid <= 1'b1;
          io_ready  <= 1'b1;
          io_busy   <= 1'b1;
        end else if (io_rd & in_valid) begin
          in_ack    <= 1'b1;
          io_ready  <= 1'b1;
          io_busy   <= 1'b1;
        end
      end else if (~io_wr & ~io_rd) begin
        io_busy <= 1'b0;
      end
    end
  end

  assign mem_read_data = is_io ? ui_in    : ram_read_data;
  assign mem_resp_val  = is_io ? io_ready : ram_ready;

  wire _unused = &{ena, uio_in[1:0], uio_in[3], uio_in[5], uio_in[7], 1'b0};

endmodule
