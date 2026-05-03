module bf (
    input wire clk,
    input wire rst,
    input wire [7:0] in,
    output reg [7:0] out,

    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe    // IOs: Enable path (active high: 0=input, 1=output)
);
// > = 62 : increment the data pointer
// < = 60 : decrement the data pointer
// + = 43 : increment the byte at the data pointer
// - = 45 : decrement the byte at the data pointer
// . = 46 : output the byte at the data pointer
// , = 44: input a byte and store it in the byte at the data pointer
// [ = 91 : if the byte at the data pointer is zero, jump forward to the command after the matching ] command
// ] = 93 : if the byte at the data pointer is nonzero, jump

wire[7:0] instr;
assign instr = in;
reg [7:0] data[0:16];

case (instr)
    8'd62: // >, increment the data pointer
        ;
    8'd60: // <, decrement the data pointer
        ;

    8'd43: // +, increment the byte at the data pointer
        ;

    8'd45: // -, decrement the byte at the data pointer
        ;

    8'd46: // ., output the byte at the data pointer
        ;

    8'd44: // input a byte and store it in the byte at the data pointer
        ;
endcase

endmodule