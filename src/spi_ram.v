// =============================================================================
// spi_ram.v
// =============================================================================

`default_nettype none

module spi_ram #(
    parameter CLK_DIV        = 4,
    parameter CS_HIGH_CYCLES = 32
) (
    input  wire        clk,
    input  wire        rst,

    // ---- BF core memory bus ----
    input  wire [15:0] mem_addr,
    input  wire [7:0]  mem_write_data,
    input  wire        mem_read_en,
    input  wire        mem_write_en,
    output wire [7:0]  mem_read_data,
    output wire        mem_ready,

    // ---- SPI pins ----
    input  wire        spi_miso,
    output wire        spi_mosi,
    output wire        spi_sck,
    output wire        spi_cs_n
);

    // -------------------------------------------------------------------------
    // Request gating
    // -------------------------------------------------------------------------
    reg        busy;
    wire       want     = mem_read_en | mem_write_en;
    wire       req_fire = want & ~busy;

    wire       spi_req_rdy;
    wire       spi_resp_val;
    wire [7:0] spi_resp_rdata;

    // -------------------------------------------------------------------------
    // SPI engine
    // -------------------------------------------------------------------------
    spi_master #(
        .CLK_DIV        (CLK_DIV),
        .CS_HIGH_CYCLES (CS_HIGH_CYCLES)
    ) u_spi_master (
        .clk        (clk),
        .rst        (rst),
        .req_val    (req_fire),
        .req_rdy    (spi_req_rdy),
        .req_we     (mem_write_en),
        .req_addr   (mem_addr),
        .req_wdata  (mem_write_data),
        .resp_val   (spi_resp_val),
        .resp_rdata (spi_resp_rdata),
        .spi_cs_n   (spi_cs_n),
        .spi_sclk   (spi_sck),
        .spi_mosi   (spi_mosi),
        .spi_miso   (spi_miso)
    );

    // -------------------------------------------------------------------------
    // Busy tracking
    // -------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst)
            busy <= 1'b0;
        else if (req_fire & spi_req_rdy)
            busy <= 1'b1;
        else if (spi_resp_val)
            busy <= 1'b0;
    end

    // -------------------------------------------------------------------------
    // Response back to the BF core
    // -------------------------------------------------------------------------
    assign mem_ready     = spi_resp_val;
    assign mem_read_data = spi_resp_rdata;

endmodule

`default_nettype wire
