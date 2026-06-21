`default_nettype none
`timescale 1ns / 1ps

module tb_bf ();

  initial begin
    $dumpfile("tb_bf.fst");
    $dumpvars(0, tb_bf);
    #1;
  end

  reg        clk;
  reg        rst;
  reg        start;

  wire [15:0] mem_addr;
  wire [7:0]  mem_write_data;
  wire        mem_read_en;
  wire        mem_write_en;
  reg  [7:0]  mem_read_data;
  reg         mem_ready;

  // Instantiate the isolated BF core
  bf uut (
    .clk(clk),
    .rst(rst),
    .start(start),
    .mem_addr(mem_addr),
    .mem_write_data(mem_write_data),
    .mem_read_en(mem_read_en),
    .mem_write_en(mem_write_en),
    .mem_read_data(mem_read_data),
    .mem_ready(mem_ready)
  );

endmodule